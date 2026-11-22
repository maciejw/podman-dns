#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Nginx sample from Windows' {
    It 'resolves the nginx service to Windows loopback' {
        $addresses = [Net.Dns]::GetHostAddresses('nginx.dev.internal.') |
            Select-Object -ExpandProperty IPAddressToString -Unique
        $addresses | Should-Be '127.0.0.1'
    }

    It 'opens the Nginx welcome page on its published port from Windows' {
        $page = Invoke-WebRequest 'https://nginx.dev.internal:8443/' -NoProxy -TimeoutSec 5
        $page.StatusCode | Should-Be 200
        $page.Content.Contains('Welcome to nginx!') | Should-BeTrue
    }
}
