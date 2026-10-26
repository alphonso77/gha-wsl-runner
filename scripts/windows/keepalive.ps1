<#
Starts the distro at boot with nobody logged in, and keeps it running (WSL stops an idle distro, which would stop
Docker and the runner). S4U logon = no stored password. Run over SSH after wsl-install.ps1 and setup-ubuntu.sh.
#>
param([string]$Distro = 'Ubuntu-24.04')
$a = New-ScheduledTaskAction -Execute 'C:\Windows\System32\wsl.exe' -Argument "-d $Distro -u root -- sleep infinity"
$t = New-ScheduledTaskTrigger -AtStartup
$p = New-ScheduledTaskPrincipal -UserId "$env:COMPUTERNAME\$env:USERNAME" -LogonType S4U -RunLevel Highest
$s = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'WSL keep-alive' -Description "Keeps $Distro (and the runner) running without a login" -Action $a -Trigger $t -Principal $p -Settings $s -Force | Out-Null
Start-ScheduledTask -TaskName 'WSL keep-alive'
