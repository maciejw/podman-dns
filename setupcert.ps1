#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

# Restrict the project-local folder before exporting the development key.
$dir = Join-Path $PSScriptRoot '.certs'
$pem = Join-Path $dir 'cert.pem'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
icacls.exe $dir /inheritance:r /grant:r "*${sid}:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE) { throw "Could not protect the certificate directory: $dir" }

dotnet dev-certs https --trust --export-path $pem --format PEM --no-password
if ($LASTEXITCODE) { throw 'Could not export the .NET development certificate.' }

# The Windows DNS Client service uses machine trust.
Import-Certificate -FilePath $pem -CertStoreLocation Cert:\LocalMachine\Root | Out-Null

# Compose shares this rootless network with the containers you want to resolve.
podman network create --ignore appnet
if ($LASTEXITCODE) { throw 'Could not prepare the appnet network.' }
