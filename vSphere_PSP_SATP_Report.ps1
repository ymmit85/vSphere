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
foreach ($vmhost in get-vmhost) {
 
#foreach ($vmhost in get-cluster "SAP_DEV_TEST" | get-vmhost) {
$hostview= get-view $vmhost.id
$hostview.config.storagedevice.multipathinfo.lun | % { `
    $lunname=$_.id
    $lunpolicy=$_.policy.policy
    $lunsatp=$_.storagearraytypepolicy.policy
    $_.path | % {
        $pathstate=$_.pathstate
        $lunpathinfo += "" | select @{name="Hostname"; expression={$vmhost.name}},
                                    @{name="LunName"; expression={$lunname}},
                                    @{name="LunPolicy"; expression={$lunpolicy}},
                                    @{name="LunSATP"; expression={$lunsatp}},
                                    @{name="PathState"; expression={$pathstate}}
    }
}
}
$lunpathinfo | export-csv "$output\host_luns.csv"