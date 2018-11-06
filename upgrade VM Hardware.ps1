$vm = "aaa"
$vmVersion = "v11"
#Stop-VM -VM $vm -Confirm:$false | Out-Null
#shutdown-vmguest -vm $vm -confirm:$false

Do {$vmStatus = get-vm -name $vm;  write-Host "Waiting for $vm to Shutdown... $(get-date -f HH:mm:ss)" -ForegroundColor Yellow; sleep -s 10}
            until ($vmStatus.PowerState -eq "PoweredOff")

write-host "$vm is off now.. upgrading hardware"

set-vm -vm (get-vm $vm) -Version $vmVersion -Confirm:$false
$x = get-vm $vm
write-host "Hardware on $vm upgraded to "$x.version"... Starting it back up"

start-vm -vm $vm -confirm:$false | Out-Null