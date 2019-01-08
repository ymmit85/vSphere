<#
.SYNOPSIS
Generates report detailing ESXi Host NUMA configuration and shows VMs that are exceeding NUMA node size.

.DESCRIPTION
Basic usage:
Connect to vCenter and execute Numa_Report_v1.ps1
#>

Param	(
    [parameter(Mandatory=$false)]$Cluster
)
#Get list of all clusters in vCentre
if ($Cluster) {
    $Clusters = Get-Cluster -Name $Cluster
} else {
    $Clusters = Get-Cluster
}

if (!$Clusters) {
    Write-Host "No Clusters found"
    Break
}

ForEach ($c in $Clusters){  
    For($e = 1; $e -le $Clusters.count; $e++) {
    Write-Progress -Activity "Processing Clusters" -status "Working on cluster - $c" ` -percentComplete ($e / $Clusters.count*100)
}

#Process each host in cluster
    $NUMAStats = @()
    $NUMAMaximums = @()
    $largeMemVM = @()
    $largeCPUVM = @()
    $largeCPUVM2 = @()
    $largeCPUVM3 = @()
    $largeCPUVMSockets = @()

    $hosts = Get-VMHost -Location $c    

ForEach ($h in $Hosts) {
    $HostView = $h | Get-View
    $HostSummary = “” | Select HostName, MemorySizeGB, CPUSockets, CPUCoresSocket, CPUCoresTotal, CPUThreads, NumNUMANodes, NUMANodeSize

#Get Host CPU, Memory & NUMA info
    $HostSummary.HostName = $h.Name
    $HostSummary.MemorySizeGB =([Math]::Round($HostView.hardware.memorysize / 1GB))
    $HostSummary.CPUSockets = $HostView.hardware.cpuinfo.numCpuPackages
    $HostSummary.CPUCoresSocket = ($HostView.hardware.cpuinfo.numCpuCores / $HostSummary.CPUSockets)
    $HostSummary.CPUCoresTotal = $HostView.hardware.cpuinfo.numCpuCores
    $HostSummary.CPUThreads = $HostView.hardware.cpuinfo.numCpuThreads
    $HostSummary.NumNUMANodes = $HostView.hardware.numainfo.NumNodes
    $HostSummary.NUMANodeSize =([Math]::Round($HostSummary.MemorySizeGB / $HostSummary.NumNUMANodes))
    $NUMAStats += $HostSummary
}

#Find the smallest NUMA Node (CPU & Mem) to use for comparison
    $v = $NUMAStats.CPUCoresTotal | measure -Maximum
    $w =  $NUMAStats.CPUSockets | measure -Minimum
    $x =  $NUMAStats.NUMANodeSize | measure -Minimum
    $y =  $NUMAStats.CPUCoresSocket | measure -Minimum

#Get list of all VMs in cluster that are oversized
    $VMDeatils = @()

#$VMDeatils = Get-VM -Location $c | where {$_.NumCpu -gt $v.Minimum -or $_.MemoryGB -gt $y.Minimum}
    $VMDeatils = Get-VM -Location $c | where {$_.NumCpu -gt $x.Minimum -or $_.MemoryGB -gt $y.Minimum}

For($i = 1; $i -le $VMDeatils.count; $i++) {
    Write-Progress -Activity "Processing VMs" ` -percentComplete ($i / $VMDeatils.count*100)
}

# VM Calculations
#Large MEM VM - VMs that Exceed NUMA Node Memory size..
    $largeMemVM += $VMDeatils | Where-Object {$_.MemoryGB -gt $x.Minimum}

#Large CPU VM - VMs that Exceed Host CPU Sockets.
    $largeCPUVMSockets += $VMDeatils | Where-Object {($_.ExtensionData.Config.Hardware.NumCPU / $_.ExtensionData.Config.Hardware.NumCoresPerSocket) -gt $w.Minimum}

#Large CPU VM - VMs that Exceed Cores per NUMA Node.
    $largeCPUVM += $VMDeatils | Where-Object {$_.NumCPU -gt $y.Minimum}                

#Large CPU VM - VMs that Exceed Cores per NUMA Node and only have single socket configured.
    $largeCPUVM2 += $VMDeatils | Where-Object {(($_.ExtensionData.Config.Hardware.NumCPU / $_.ExtensionData.Config.Hardware.NumCoresPerSocket) -eq 1) -and ($_.NumCPU -gt $y.Minimum) -and ($_.ExtensionData.Config.CpuHotAddEnabled -contains 'True')}

#Large CPU VM - VMs that have more cores then available on host
    $largeCPUVM3 += $VMDeatils | Where-Object {$_.NumCPU -gt $v.Maximum} 

#Display report for current cluster
if ($largeMemVM -or $largeCPUVM -or $largeCPUVM2 -or $largeCPUVM3 -or $largeCPUVMSockets) {
        Write-Host "NUMA Node Specs for Cluster - $c." -ForegroundColor Green
        $NUMAStats | ft

        #Disaply Smallest NUMA Size within cluster
        Write-Host "Recommended VM Maximum Sizing within - $c." -ForegroundColor Green
        Write-host $w.Minimum " CPU Sockets. " $y.Minimum " Cores per Socket. " $x.Minimum " GB RAM."
        write-host

        if ($largeCPUVM) {
            Write-host $largeCPUVM.Count "VMs that Exceed Cores per NUMA Node." -ForegroundColor Yellow
            $largeCPUVM | select name, @{N='Memory GB';E={$_.MemoryGB}}, @{N='Num CPU';E={$_.ExtensionData.Config.Hardware.NumCPU}}, @{N='Num Sockets';E={($_.ExtensionData.Config.Hardware.NumCPU / $_.ExtensionData.Config.Hardware.NumCoresPerSocket)}}, @{N='Cores Per Socket';E={$_.ExtensionData.Config.Hardware.NumCoresPerSocket}}, @{N='CPU Hot Plug Status';E={$_.ExtensionData.Config.CpuHotAddEnabled}} | ft
        }
        if ($largeCPUVM2) {
            Write-host $largeCPUVM2.Count "VMs that Exceed Cores per NUMA Node and only have single socket configured." -ForegroundColor Yellow
            $largeCPUVM2 | select name, @{N='Memory GB';E={$_.MemoryGB}}, @{N='Num CPU';E={$_.ExtensionData.Config.Hardware.NumCPU}}, @{N='Num Sockets';E={($_.ExtensionData.Config.Hardware.NumCPU / $_.ExtensionData.Config.Hardware.NumCoresPerSocket)}}, @{N='Cores Per Socket';E={$_.ExtensionData.Config.Hardware.NumCoresPerSocket}}, @{N='CPU Hot Plug Status';E={$_.ExtensionData.Config.CpuHotAddEnabled}} | ft
        } 
        if ($largeCPUVMSockets) {
            Write-host $largeCPUVMSockets.Count "VMs that Exceed Host CPU Sockets." -ForegroundColor Yellow
            $largeCPUVMSockets | select name, @{N='Memory GB';E={$_.MemoryGB}}, @{N='Num CPU';E={$_.ExtensionData.Config.Hardware.NumCPU}}, @{N='Num Sockets';E={($_.ExtensionData.Config.Hardware.NumCPU / $_.ExtensionData.Config.Hardware.NumCoresPerSocket)}}, @{N='Cores Per Socket';E={$_.ExtensionData.Config.Hardware.NumCoresPerSocket}}, @{N='CPU Hot Plug Status';E={$_.ExtensionData.Config.CpuHotAddEnabled}} | ft
        }
        if ($largeMemVM) {
            Write-host $largeMemVM.Count "VMs that Exceed NUMA Node Memory size." -ForegroundColor Yellow
            $largeMemVM | select name, @{N='Memory GB';E={$_.MemoryGB}}, @{N='Num CPU';E={$_.ExtensionData.Config.Hardware.NumCPU}}, @{N='Num Sockets';E={($_.ExtensionData.Config.Hardware.NumCPU / $_.ExtensionData.Config.Hardware.NumCoresPerSocket)}}, @{N='Cores Per Socket';E={$_.ExtensionData.Config.Hardware.NumCoresPerSocket}}, @{N='CPU Hot Plug Status';E={$_.ExtensionData.Config.CpuHotAddEnabled}} | ft
        }
        if ($largeCPUVM3) {
            Write-host $largeCPUVM3.Count "VMs that have more cores allocated then available on host." -ForegroundColor Red
            $largeCPUVM3 | select name, @{N='Memory GB';E={$_.MemoryGB}}, @{N='Num CPU';E={$_.ExtensionData.Config.Hardware.NumCPU}}, @{N='Num Sockets';E={($_.ExtensionData.Config.Hardware.NumCPU / $_.ExtensionData.Config.Hardware.NumCoresPerSocket)}}, @{N='Cores Per Socket';E={$_.ExtensionData.Config.Hardware.NumCoresPerSocket}}, @{N='CPU Hot Plug Status';E={$_.ExtensionData.Config.CpuHotAddEnabled}} | ft
        }  
    }
}
