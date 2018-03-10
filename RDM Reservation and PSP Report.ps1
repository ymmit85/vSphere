<#
.DESCRIPTION
    Report on VMs with RDM disks and check if they have been perennially reserved and the current multipathing policy
	 RDMs that are in use by MSCS VM's will also have a SCSI lock on the physcal or virtual RDM. 
	 As a result ESXi hosts that have access to these LUNs will take a long time to reboot as it is unable to scan the datastore while rebooting.
	 This script sets the flag 'Perennially Reserved on VM's with these disks attached
        
.USAGE
    Manual - Ad-hoc
	
	RDM_Reservation_and_PSP_Report.ps1 -cluster <CLUSTER NAME>

	Change the $cluster value to the cvCentre cluster you wish to report on. "*" will scan all clusters.

	$filepath can be changed to set output file location.


.CHANGELOG
    Version 1.0   : 11/05/2015 Initial Build
    Version 1.1   : 23/06/2015 Added required parameter to specify cluster when running script eg: script.ps1 -Cluster "Cluster Name"
#>

Param(
	[CmdletBinding()]
	[Parameter(Mandatory=$True)]
	[string]$cluster
	)

#Configurable paramters 

$filepath = "c:\temp\"
$filedate = get-date -UFormat %d%m%Y
$filename = "RDM Report $cluster $filedate"

	#Get all hosts in cluster to be scanned
	Write-Host "Gathering Host info..."
	$hosts = get-cluster | where-object {$_.name -like $cluster} | Get-VMHost
	
	#Scan for all devices used by VMs that are in Physcal disk mode
	Write-Host "Finding RDM disks..."
	$RDM = get-cluster | where-object {$_.name -like $cluster} | Get-VM | Get-HardDisk -DiskType "RawPhysical" | Select ScsiCanonicalName
	$totalRDM = $RDM.count
	$RDMDisk = $RDM.ScsiCanonicalName | select -Unique
	$totalrdmdisks = $RDMDisk.count
	write-host "$totalrdmdisks out of $totalRDM unique..."

	$scsirpt = @()

	#Scan all hosts in specified cluster and get status of devices that are in physical mode
	Foreach ($h in $hosts) {
		Write-Host "Scanning RDMs on $h..."
			$esxcli = get-esxcli -VMHost $h
			$id = 0
				Foreach ($d in $RDMDisk) {
					$id++
						Write-Progress -Activity "Getting RDM Details" -PercentComplete (($id / $RDMDisk.length) * 100)
						$scsiinfo = "" | Select-Object VMHost, PerenniallyReserved, DeviceName, PSP
						$scsiinfo.VMHost = $h.name
						$scsiinfo.PerenniallyReserved = $esxcli.storage.core.device.list($d).IsPerenniallyReserved
						$scsiinfo.DeviceName = $esxcli.storage.core.device.list($d).Device
						$scsiinfo.PSP = $esxcli.storage.nmp.device.list($d).PathSelectionPolicy
						
						$scsirpt += $scsiinfo
					}
				}
				
			#Display output to screen
			#$scsirpt
			
			#Export results to CSV
			$scsirpt | Export-Csv -Path $filepath$filename.csv -NoTypeInformation
