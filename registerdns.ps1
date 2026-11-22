#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$server = '127.0.0.1'
$url = 'https://localhost:15053/dns-query'
$namespace = '.dev.internal'

$rules = @(Get-DnsClientNrptRule | Where-Object Namespace -contains $namespace)
if ($rules | Where-Object { ($_.NameServers -join ',') -ne $server }) {
    throw "An existing $namespace rule points to another DNS server."
}
$doh = Get-DnsClientDohServerAddress | Where-Object ServerAddress -eq $server
if (!$doh) {
    Add-DnsClientDohServerAddress -ServerAddress $server -DohTemplate $url -AutoUpgrade $true -AllowFallbackToUdp $false | Out-Null
} elseif ($doh.DohTemplate -cne $url -or !$doh.AutoUpgrade -or $doh.AllowFallbackToUdp) {
    throw "An existing DoH registration for $server has different settings."
}
if (!$rules.Count) {
    Add-DnsClientNrptRule -Namespace $namespace -NameServers $server | Out-Null
}

Resolve-DnsName podman-doh.dev.internal. -Type A -DnsOnly -NoHostsFile |
    Where-Object Section -eq Answer | Select-Object Name, IPAddress -Unique
