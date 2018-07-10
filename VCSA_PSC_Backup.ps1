param (
        $SourceAppliance,
        [Parameter(ParameterSetName='FullBackup')]
        [switch]$FullBackup,
        [Parameter(ParameterSetName='CommonBackup')]
        [switch]$CommonBackup,
        [ValidateSet('FTPS', 'HTTP', 'SCP', 'HTTPS', 'FTP')]
        $LocationType = "FTP",
        $Location,
        $LocationUser,
        [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$LocationPassword,
        [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$BackupPassword,
        $Comment = "Backup job",
        [switch]$ShowProgress
    )

    Begin {
        if (!($global:DefaultCisServers)){ 
            Connect-CisServer $SourceAppliance
            $Connection = $global:DefaultCisServers
        } else {
            $Connection = $global:DefaultCisServers
        }
        if ($FullBackup) {$parts = @("common","seat")}
        if ($CommonBackup) {$parts = @("common")}
        $date = $((Get-Date).ToString('yyyy-MM-dd-hh-mm'))
    }

    Process{
        $BackupAPI = Get-CisService com.vmware.appliance.recovery.backup.job
        $CreateSpec = $BackupAPI.Help.create.piece.CreateExample()
        $CreateSpec.parts = $parts
        $CreateSpec.backup_password = $BackupPassword
        $CreateSpec.location_type = $LocationType
        $CreateSpec.location = $Location +"/"+ $SourceAppliance+"/"+$date
        $CreateSpec.location_user = $LocationUser
        $CreateSpec.location_password = $LocationPassword
        $CreateSpec.comment = $date
        try {
            $BackupJob = $BackupAPI.create($CreateSpec)
        }
        catch {
            throw $_.Exception.Message
        }
            

        If ($ShowProgress){
            do {
                $BackupAPI.get("$($BackupJob.ID)") | select id, progress, state
                $progress = ($BackupAPI.get("$($BackupJob.ID)").progress)
                Write-Progress -Activity "Backing up VCSA"  -Status $BackupAPI.get("$($BackupJob.ID)").state -PercentComplete ($BackupAPI.get("$($BackupJob.ID)").progress) -CurrentOperation "$progress% Complete"
                start-sleep -seconds 5
            } until ($BackupAPI.get("$($BackupJob.ID)").progress -eq 100 -or $BackupAPI.get("$($BackupJob.ID)").state -ne "INPROGRESS")

            Write-Progress -Activity "Backing up VCSA" -Completed
            $BackupAPI.get("$($BackupJob.ID)") | select id, progress, state
        } 
        Else {
            $BackupJob | select id, progress, state
        }
    }
    End {
        Disconnect-CisServer -server $Connection -Confirm:$false
    }