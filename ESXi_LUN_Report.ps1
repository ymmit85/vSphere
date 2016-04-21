<#
    .SYNOPSIS
            Generate report showing NMP & PSP for each LUN on all ESXi hosts
					 
    .DESCRIPTION
            Connect to required vCenter server, execute script.
            Output (.csv) will be saved in current PowerShell directoy.

#>

Param
(
	[CmdletBinding()]
	[Parameter(Mandatory=$false)]
	[string]$path
)

if ($path) {
    $output = $path
    } else { 
    $output = $PWD
    }

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
$lunpathinfo | export-csv "$output\Lun_Report_$(get-date -f yyyy-MM-dd).csv"