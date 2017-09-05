#Get list of all clusters in vCentre
$Clusters = Get-Cluster
    ForEach ($c in $Clusters){  
            For($e = 1; $e -le $Clusters.count; $e++) {
                Write-Progress -Activity "Processing Clusters" -status "Working on cluster - $c" ` -percentComplete ($e / $Clusters.count*100)
            }
    
            #Process each host in cluster
            $NUMAStats = @()
            $largeMemVM = @()
            $largeCPUVM = @()
    
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
                    $x =  $HostSummary.NUMANodeSize | measure -Minimum
                    $y =  $HostSummary.CPUCoresSocket | measure -Minimum
    
                    #Get list of all VMs in cluster that are oversized
                    $VMDeatils = @()
                    $VMDeatils = Get-VM -Location $c | where {$_.NumCpu -gt $v.Minimum -or $_.MemoryGB -gt $y.Minimum}
    
                    For($i = 1; $i -le $VMDeatils.count; $i++) {
                        Write-Progress -Activity "Processing VMs" ` -percentComplete ($i / $VMDeatils.count*100)
                    }
    
                    # VM Calculations
                    #Large MEM VM - Any VM with more memory allocated then the NUMA node.
                    $largeMemVM += $VMDeatils | Where-Object {$_.MemoryGB -gt $x.Minimum}
    
                    #Large CPU VM - Any VM with more CPU then cores per Proc on a host
                    $largeCPUVM += $VMDeatils | Where-Object {$_.NumCPU -gt $y.Minimum}
            
                    #Display report for current cluster
                    if ($largeMemVM -or $largeCPUVM) {
                            Write-Host "Numa Node Specs for Cluster - $c." -ForegroundColor Green
                            $NUMAStats | ft
                
                        if ($largeCPUVM) {
                            Write-host $largeCPUVM.Count "VMs that Exceed CPUCoresSocket." -ForegroundColor Green
                            $largeCPUVM | select name, @{N='Memory GB';E={$_.MemoryGB}}, @{N='Num CPU';E={$_.ExtensionData.Config.Hardware.NumCPU}}, @{N='Cores Per Socket';E={$_.ExtensionData.Config.Hardware.NumCoresPerSocket}}, @{N='CPU Hot Add Status';E={$_.ExtensionData.Config.CpuHotAddEnabled}} | ft
                        }
    
                        if ($largeMemVM) {
                            Write-host $largeMemVM.Count "VMs that Exceed NUMA Node Memory size." -ForegroundColor Green
                            $largeMemVM | select name, @{N='Memory GB';E={$_.MemoryGB}}, @{N='Num CPU';E={$_.ExtensionData.Config.Hardware.NumCPU}}, @{N='Cores Per Socket';E={$_.ExtensionData.Config.Hardware.NumCoresPerSocket}}, @{N='CPU Hot Add Status';E={$_.ExtensionData.Config.CpuHotAddEnabled}} | ft
                        }
                    }
    }