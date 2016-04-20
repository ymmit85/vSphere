<#
    .SYNOPSIS
            Generate report showing NMP & PSP for each LUN on all ESXi hosts
					 
    .DESCRIPTION
            Connect to required vCenter server, execute script.
            Output (.csv) will be saved in current PowerShell directoy.

#>


#Output directory for report
$output = "$pwd\Lun_Report_$(get-date -f yyyy-MM-dd).csv"

$lunpathinfo = @()

#Report on all LUNs on connected vCenter
foreach ($vmhost in get-vmhost) { 
$hostview= get-view $vmhost.id
$hostview.config.storagedevice.multipathinfo.lun | % { `
    $lunname=$_.id
    $lunpolicy=$_.policy.policy
    $lunsatp=$_.storagearraytypepolicy.policy
    $_.path | % {
        $pathstate=$_.pathstate
        
        #Gather data for each LUN
        $lunpathinfo += "" | select @{name="Hostname"; expression={$vmhost.name}},
                                    @{name="LunName"; expression={$lunname}},
                                    @{name="LunPolicy"; expression={$lunpolicy}},
                                    @{name="LunSATP"; expression={$lunsatp}},
                                    @{name="PathState"; expression={$pathstate}}
    }
}
}

#Output Report
$lunpathinfo | export-csv $output