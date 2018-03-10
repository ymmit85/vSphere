<#
.DESCRIPTION
	Perennially reserves RDM's used by MSCS VM's
	RDMs that are in use by MSCS VM's will also have a SCSI lock on the physcal or virtual RDM. 
	As a result ESXi hosts that have access to these LUNs will take a long time to reboot as it is unable to scan the datastore while rebooting.
	This script sets the flag 'Perennially Reserved on VM's with these disks attached and sets the multipathing policy to MRU.
	If it is not required for your environment to set the multipathing policy then lines 49-54 can be removed.
        
.USAGE
    Manual - Ad-hoc

    Source CSV file to be in following format (RDM report script outputs in this format)

	VMHost	PerenniallyReserved	DeviceName	PSP
	VMNAME	TRUE	naa.600601609ba0010d11d1d0d1d0d1d0	VMW_PSP_RR


.CHANGELOG
    Version 1.0   : 11/05/2015 Initial Build
    Version 1.1   : 23/06/2015 Updated status outputs

#>

# Open CSV file
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
$gSourceCsv = New-Object system.windows.forms.openfiledialog
$gSourceCsv.InitialDirectory = 'c:\scripts'
$gSourceCsv.Filter = "csv files (*.csv)|*.csv|All files (*.*)|*.*"
$gSourceCsv.MultiSelect = $false
$gSourceCsv.showdialog()
$gSourceCsv.filenames 
$gObjSrc = import-csv -Path $gSourceCsv.fileName

	#Import data from CSV        
	$gObjSrc | ForEach-Object {
		$hosts = $_.VMHost
		$PerenniallyReserved = $_.PerenniallyReserved
		$DeviceName = $_.DeviceName
		$PSP = $_.PSP
		
		#For each host in CSV, perennially reserve the device and set the multipathing policy
		foreach ($h in $hosts) {
		$esxcli = get-vmhost -name $h | Get-EsxCli
			
			foreach($d in $DeviceName | Where-Object {$PerenniallyReserved -eq "false"}) {
				# Set the configuration to "PereniallyReserved".
				# setconfig method: void setconfig(boolean detached, string device, boolean perenniallyreserved)  
				write-host "Reserving $d on $h..."    
				$esxcli.storage.core.device.setconfig($false, ($d), $true)
			}
			
			#This section can be remvoed if multipathing policy is not required to be changed
			foreach($d in $DeviceName | Where-Object {$PSP -eq "VMW_PSP_RR"}) {
				# Set the configuration to "PereniallyReserved".
				# setconfig method: void setconfig(boolean detached, string device, boolean perenniallyreserved)  
				write-host "Setting $d to VMW_PSP_MRU on $h..."    
				$esxcli.storage.nmp.device.set($false, ($d), "VMW_PSP_MRU")
			}
		}
	}
