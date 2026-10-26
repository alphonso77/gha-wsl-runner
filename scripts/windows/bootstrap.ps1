#Requires -RunAsAdministrator
<#
Run once, at the keyboard, in an admin PowerShell on a fresh Windows 11 Pro box.
Afterwards everything else is done over SSH.

  .\bootstrap.ps1 -KeysUrl https://github.com/<you>.keys [-NewName GAR2] [-DisableWifi]

-KeysUrl  a text file of SSH public keys (one per line) that may log in as an admin.
          Every key on that GitHub account gets access; use a URL you control instead if that is too broad.
#>
param(
  [Parameter(Mandatory)][string]$KeysUrl,
  [string]$NewName,
  [switch]$DisableWifi
)
$ErrorActionPreference = 'Stop'

# Never sleep, hibernate, or fast-start (a half-hibernated box confuses WSL and SSH).
powercfg /change standby-timeout-ac 0
powercfg /hibernate off
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -Type DWord

# OpenSSH server. Its firewall rule only covers Private networks, so make the wired network Private.
Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null
Set-Service sshd -StartupType Automatic
Start-Service sshd
Get-NetConnectionProfile | Where-Object NetworkCategory -eq 'Public' | Set-NetConnectionProfile -NetworkCategory Private

# Admin accounts read keys from this file, not ~\.ssh\authorized_keys. Its ACL must be SYSTEM + Administrators only.
$f = 'C:\ProgramData\ssh\administrators_authorized_keys'
$keys = (Invoke-RestMethod -Uri $KeysUrl -UseBasicParsing).ToString().Trim()
[IO.File]::WriteAllText($f, $keys + "`r`n", [Text.Encoding]::ASCII)
icacls $f /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null

# Remote Desktop with Network Level Authentication, as a fallback when SSH is down.
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Set-ItemProperty 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -Value 1
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'

# Clock: an unsynced Windows clock makes the WSL clock jump and breaks timing tests (docs/gotchas.md).
sc.exe config w32time start= auto | Out-Null
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\NtpClient' -Name SpecialPollInterval -Value 3600 -Type DWord
w32tm /config /update /manualpeerlist:'time.windows.com,0x9' /syncfromflags:manual | Out-Null
Restart-Service w32time; Start-Sleep 3; w32tm /resync /force | Out-Null
$a = New-ScheduledTaskAction -Execute 'C:\Windows\System32\w32tm.exe' -Argument '/resync /force'
$t = New-ScheduledTaskTrigger -AtStartup; $t.Delay = 'PT1M'
$s = New-ScheduledTaskSettingsSet -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName 'Time resync at boot' -Action $a -Trigger $t -Settings $s -User 'SYSTEM' -RunLevel Highest -Force | Out-Null

# Updates: daytime active hours, no restart while someone is signed in, no Store app auto-updates.
$p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; New-Item $p -Force | Out-Null
Set-ItemProperty $p SetActiveHours 1 -Type DWord; Set-ItemProperty $p ActiveHoursStart 7 -Type DWord; Set-ItemProperty $p ActiveHoursEnd 23 -Type DWord
New-Item "$p\AU" -Force | Out-Null; Set-ItemProperty "$p\AU" NoAutoRebootWithLoggedOnUsers 1 -Type DWord
$st = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore'; New-Item $st -Force | Out-Null; Set-ItemProperty $st AutoDownload 2 -Type DWord

if ($DisableWifi) { Get-NetAdapter -Physical | Where-Object { $_.Name -match 'Wi-?Fi|Wireless' } | Disable-NetAdapter -Confirm:$false }
if ($NewName) { Rename-Computer -NewName $NewName }

Write-Host "Done. Restart if you renamed the PC. IPv4 address(es):"
Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -notlike '127.*' | Format-Table InterfaceAlias, IPAddress -AutoSize
