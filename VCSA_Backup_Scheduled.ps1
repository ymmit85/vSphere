param (
    [Parameter()]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf})]
    [ValidatePattern( '\.json$' )]
    [string]$ConfigPath
    )

    $config = Get-Content -Path $ConfigPath | ConvertFrom-Json
    $SourceAppliance = $config.SourceAppliance
    $FullBackup = $config.FullBackup
    $CommonBackup = $config.CommonBackup
    $LocationType = $config.LocationType
    $Location = $config.Location
    $LocationUser = $config.LocationUser
    [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$LocationPassword = $config.LocationPassword
    [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$BackupPassword = $config.BackupPassword
    $Comment = $config.Comment
    $Username = $config.Username
    $Password = $config.Password

#Disconenct from any current connected servers
try {Disconnect-CisServer * -Force -Confirm:$false -ErrorAction Continue }
catch { $ErrorMessage = $_.Exception.Message}

#Import unsername and password into $creds variable
if ($Username -and $Password) {
        # Convert specified Password to secure string
        $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $Creds = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)
}

#Prompt for creds if not supplied 
if (!($Creds)) {
    $Creds = Get-Credential -Message "Enter Credentails to invoke backups.."
}

Foreach ($Source in $SourceAppliance) {
    start-job
    Connect-CisServer -Server $Source -Credential $Creds

    #Determnine deployment type
    $vami = (Get-CisService -Name 'com.vmware.appliance.system.version').get()

    if ( ($vami.type -eq "VMware Platform Services Controller")) {
        $vcsaType = "PSC"
    } elseIf ($vami.type -eq "vCenter Server with an embedded Platform Services Controller") {
        $vcsaType = "VCE"
    } elseIf ( ($vami.type -eq "vCenter Server with an external Platform Services Controller")) {
        $vcsaType = "VC"
    }
    $parts = @()
    $CreateSpec = @()

    if ($vcsaType -eq "PSC") {
        $parts = @("common")}

    elseif ($vcsaType -eq "VCE" -or "VC") {
        if ($FullBackup) {$parts = @("common","seat")}
        if ($CommonBackup) {$parts = @("common")}
    }

    #show size of backups
    $recoveryAPI = Get-CisService 'com.vmware.appliance.recovery.backup.parts'
    $backupParts = $recoveryAPI.list() | select id

    $estimateBackupSize = 0
    $backupPartSizes = ""
    foreach ($backupPart in $backupParts) {
        $partId = $backupPart.id.value
        $partSize = $recoveryAPI.get($partId)
        $estimateBackupSize += $partSize
        $backupPartSizes += $partId + " data is " + $partSize + " MB`n"
    }

    Write-Host "Estimated Backup Size: $estimateBackupSize MB"
    Write-Host $backupPartSizes

    #main backup section
    $date = $((Get-Date).ToString('yyyy-MM-dd-hh-mm'))
    $BackupAPI = Get-CisService com.vmware.appliance.recovery.backup.job
    $CreateSpec = $BackupAPI.Help.create.piece.CreateExample()
    $CreateSpec.parts = $parts
    $CreateSpec.backup_password = $BackupPassword
    $CreateSpec.location_type = $LocationType
    $CreateSpec.location = $Location +"/"+ $Source+"/"+$date
    $CreateSpec.location_user = $LocationUser
    $CreateSpec.location_password = $LocationPassword
    $CreateSpec.comment = $date
    try {
        $BackupJob = $BackupAPI.create($CreateSpec)
    }
    catch {
        $_.Exception.Message
    }

    If (!($BackupJob.id -eq $null)){
        do {
            #$BackupAPI.get("$($BackupJob.ID)") | select id, progress, state
            $progress = ($BackupAPI.get("$($BackupJob.ID)").progress)
            Write-Progress -Activity "Backing up $source - vcsaType = $vcsaType - backupType = $parts"  -Status $BackupAPI.get("$($BackupJob.ID)").state -PercentComplete ($BackupAPI.get("$($BackupJob.ID)").progress) -CurrentOperation "$progress% Complete"
            start-sleep -seconds 5
        } 
        until ($BackupAPI.get("$($BackupJob.ID)").progress -eq 100 -or $BackupAPI.get("$($BackupJob.ID)").state -ne "INPROGRESS")

        Write-Progress -Activity "Backing up $source" -Completed
        $BackupAPI.get("$($BackupJob.ID)") | select ID, Progress, State
    }

    Disconnect-CisServer -server $Source -Confirm:$false
    
    #Wait for all jobs
    Get-Job | Wait-Job
 
    #Get all job results
    Get-Job | Receive-Job | Out-GridView
}