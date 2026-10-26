<#
Windows Update's COM API is denied in an SSH session, so install updates as SYSTEM through a one-shot scheduled task.
Run over SSH, then poll C:\ProgramData\gar\wu.log until it ends with "done", delete the task, and restart if the log says to.
#>
New-Item -ItemType Directory -Force C:\ProgramData\gar | Out-Null
$job = @'
$log = "C:\ProgramData\gar\wu.log"
"start $(Get-Date -f s)" | Out-File $log
try {
  $s = New-Object -ComObject Microsoft.Update.Session
  $r = $s.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0")
  $c = New-Object -ComObject Microsoft.Update.UpdateColl
  foreach ($u in $r.Updates) { if (-not $u.EulaAccepted) { $u.AcceptEula() }; [void]$c.Add($u) }
  "found $($c.Count)" | Out-File $log -Append
  if ($c.Count -gt 0) {
    $d = $s.CreateUpdateDownloader(); $d.Updates = $c; [void]$d.Download()
    $i = $s.CreateUpdateInstaller(); $i.Updates = $c; $ir = $i.Install()
    for ($k = 0; $k -lt $c.Count; $k++) { "$($c.Item($k).Title): $($ir.GetUpdateResult($k).ResultCode)" | Out-File $log -Append }
    "reboot required $($ir.RebootRequired)" | Out-File $log -Append
  }
} catch { "error $($_.Exception.Message)" | Out-File $log -Append }
"done $(Get-Date -f s)" | Out-File $log -Append
'@
Set-Content C:\ProgramData\gar\wu.ps1 $job
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\ProgramData\gar\wu.ps1'
Register-ScheduledTask -TaskName 'gar install updates' -Action $a -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName 'gar install updates'
