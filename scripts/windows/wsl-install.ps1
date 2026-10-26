<#
Installs WSL2 and Ubuntu 24.04 without `wsl --install` or winget, both of which fail or hang over SSH.
Run over SSH (scripts/mac/winps), in two stages with a restart between:

  -Stage 1   enable the two Windows features (then: shutdown /r /t 0)
  -Stage 2   install the signed WSL MSI from GitHub, then the Ubuntu .wsl image (checksum verified)
#>
param([Parameter(Mandatory)][ValidateSet(1, 2)][int]$Stage, [string]$Distro = 'Ubuntu-24.04')
$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'

if ($Stage -eq 1) {
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart | Out-Null
  Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart | Out-Null
  'Features enabled. Restart now.'; return
}

$rel = Invoke-RestMethod 'https://api.github.com/repos/microsoft/WSL/releases/latest'
$asset = $rel.assets | Where-Object name -like '*x64.msi' | Select-Object -First 1
$msi = Join-Path $env:TEMP $asset.name
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msi -UseBasicParsing
$sig = Get-AuthenticodeSignature $msi
if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Microsoft Corporation') { throw "Bad signature on $msi" }
$p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "msiexec exit $($p.ExitCode)" }
Remove-Item $msi

# The image URL and hash come from Microsoft's distro manifest.
$m = Invoke-RestMethod 'https://raw.githubusercontent.com/microsoft/WSL/master/distributions/DistributionInfo.json'
$d = $m.ModernDistributions.PSObject.Properties.Value | ForEach-Object { $_ } | Where-Object Name -eq $Distro | Select-Object -First 1
if (-not $d) { throw "$Distro not in the manifest" }
$img = Join-Path $env:TEMP (Split-Path $d.Amd64Url.Url -Leaf)
Invoke-WebRequest -Uri $d.Amd64Url.Url -OutFile $img -UseBasicParsing   # slow: releases.ubuntu.com gave ~0.5 MB/s
if ((Get-FileHash $img -Algorithm SHA256).Hash -ne $d.Amd64Url.Sha256) { throw 'Checksum mismatch' }
& wsl.exe --install --from-file $img --name $Distro --no-launch
Remove-Item $img
