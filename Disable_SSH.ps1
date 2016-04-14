#version 1
Get-VMHost | Foreach {Stop-VMHostService -HostService ($_ | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} ) -Confirm:$False} | Out-Null
Get-VMHost | Get-VMHostService | Where { $_.Key -eq "TSM-SSH" } |select VMHost, Label, Running, Policy | FT -AutoSize