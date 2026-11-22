#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Integration checks for the running setup. Run with Invoke-Pester .\podman-doh.Tests.ps1.
Describe 'Rootless Podman DNS over HTTPS on Windows' {
    BeforeAll {
        $certDir = Join-Path $PSScriptRoot '.certs'
        $container = podman inspect podman-doh | ConvertFrom-Json
        if ($LASTEXITCODE) { throw 'Start the resolver with podman compose up -d before running these tests.' }
        $resolver = @($container)[0]
    }

    It 'runs as a nonroot user in rootless Podman and publishes HTTPS on loopback' {
        (podman info --format '{{.Host.Security.Rootless}}') | Should-Be 'true'
        $resolver.State.Running | Should-BeTrue
        $resolver.Config.User | Should-Be '65532:65532'
        (podman port podman-doh 1053/tcp) | Should-Be '127.0.0.1:15053'
    }

    It 'has a protected project-local key and a certificate trusted by Windows DNS Client' {
        (Test-Path -LiteralPath (Join-Path $certDir 'cert.key') -PathType Leaf) | Should-BeTrue
        (Get-Acl -LiteralPath $certDir).AreAccessRulesProtected | Should-BeTrue
        $pem = Get-Content -Raw -LiteralPath (Join-Path $certDir 'cert.pem')
        $cert = [Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($pem)
        (Test-Path "Cert:\LocalMachine\Root\$($cert.Thumbprint)") | Should-BeTrue
    }

    It 'mounts the project-local .certs directory read-only at /doh' {
        $machine = podman machine inspect --format '{{.Name}}'
        $expected = wsl.exe -d $machine --exec wslpath -u $certDir.Replace('\', '/')
        $mount = $resolver.Mounts | Where-Object Destination -eq '/doh'
        $mount.Type | Should-Be 'bind'
        $mount.Source | Should-Be $expected
        $mount.RW | Should-Be $false
    }

    It 'routes .dev.internal through localhost DoH with plaintext fallback disabled' {
        $policy = @(Get-DnsClientNrptPolicy -Effective | Where-Object Namespace -contains '.dev.internal')
        $policy.Count | Should-Be 1
        ($policy[0].NameServers -join ',') | Should-Be '127.0.0.1'
        $doh = Get-DnsClientDohServerAddress -ServerAddress '127.0.0.1'
        $doh.DohTemplate | Should-Be 'https://localhost:15053/dns-query'
        $doh.AutoUpgrade | Should-BeTrue
        $doh.AllowFallbackToUdp | Should-Be $false
    }

    It 'returns no address for a fresh unregistered service name' {
        $name = "pester-$([guid]::NewGuid().ToString('N')).dev.internal."
        $records = Resolve-DnsName $name -Type A -DnsOnly -NoHostsFile -QuickTimeout -ErrorAction SilentlyContinue
        @($records | Where-Object IPAddress).Count | Should-Be 0
        $logs = podman logs --since 30s podman-doh 2>&1
        [bool]($logs -match [regex]::Escape("$name A IN")) | Should-BeTrue
    }

    It 'returns loopback for the registered resolver name to a Windows application' {
        $addresses = [Net.Dns]::GetHostAddresses('podman-doh.dev.internal.') |
            Where-Object AddressFamily -eq InterNetwork | Select-Object -ExpandProperty IPAddressToString -Unique
        $addresses | Should-Be '127.0.0.1'
    }
}
