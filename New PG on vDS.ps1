<#
.DESCRIPTION
	Adds one or more portgroups to vDS.
	
.USAGE
    Manual - Ad-hoc
    The following Parameters are required;
    -vDS < Name of vDS to add portgroup to.
    -vDSPort <Name of portgroup to create
    -vDSPortVLAN <VLAN ID of porrtgroup

    Source CSV file to be in following format;

    vDS
    vDSPort
    vDSPortVLAN
	
	New portgroups will inherit security & load balancing settings from parent vDS.
	Script will also work if connected to multiple vCentre servers which each have vDS with different names.
	
.CHANGELOG
    Version 1.0   : 23/06/2015 Initial Build

#>

# Open CSV file
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $gSourceCsv = New-Object system.windows.forms.openfiledialog
    $gSourceCsv.InitialDirectory = 'c:\temp'
    $gSourceCsv.Filter = "csv files (*.csv)|*.csv|All files (*.*)|*.*"
    $gSourceCsv.MultiSelect = $false
    $gSourceCsv.showdialog()
    $gSourceCsv.filenames 
	
	#Import data 
	$gObjSrc = import-csv -Path $gSourceCsv.fileName

	$gObjSrc | ForEach-Object {
		$vDS = $_.vDS
		$vDSPort = $_.vDSPort
		$vDSPortVLAN = $_.vDSPortVLAN
		
		#Process imported data, add portgroups to vDS
		ForEach ($NewvDSPortGroup in $vDSPort) {
		New-VDPortgroup -VDSwitch $vDS -Name $NewvDSPortGroup -NumPorts "128" -VlanId $vDSPortVLAN -Confirm:$false | Out-Null
		}
	   }
