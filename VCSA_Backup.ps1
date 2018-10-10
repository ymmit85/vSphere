<#
.SYNOPSIS  
    
.DESCRIPTION

.NOTES
    Version:        
    Author:         
    Twitter:        
    Github:         
    Credits:        
.LINK

.PARAMETER param1
    
.PARAMETER param2
    Specifies the type of report that will generated.
    This parameter is mandatory.

.EXAMPLE
    .\script.ps1 -param1 -param2
    
#>

param (
        $Debug,
        $SourceAppliance,
        $username,
        [ValidateSet("FTP","FTPS","HTTP","HTTPS","SCP")][string]$LocationType,
        [ValidateSet("Full","Common")][string]$BackupType,
        $Location,
        $LocationUser,
        [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$LocationPassword,
        [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$BackupPassword,
        $Comment = "Scheduled Backup Task"
    )

    if (!($SourceAppliance)){$SourceAppliance = "vc652.minilab.local"}
    if (!($username)){$username = "administrator@vsphere.local"}
    if (!($BackupType)){$BackupType = "Full"}
    if (!($LocationType)){$LocationType = "FTP"}
    if (!($Location)){$Location = "192.168.15.156"}
    if (!($LocationUser)){$LocationUser = "vmware"}
    if (!($LocationPassword)){[VMware.VimAutomation.Cis.Core.Types.V1.Secret]$LocationPassword = "vmware"}
    if (!($BackupPassword)){[VMware.VimAutomation.Cis.Core.Types.V1.Secret]$BackupPassword = ""}
    if (!($Comment)){$Comment = "Scheduled Backup Task"}

    $password = Read-Host -AsSecureString -Prompt "Enter password for $sourceAppliance"
function Write-Log {
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $Message,
        #[ValidateScript({Test-Path $_})]
        [string]
        [AllowNull()]
        $LogOutputPath  = (Get-Location).Path,
        $LogFilename = "log.log"
    )
    function TS {Get-Date -Format 'hh:mm:ss'}
    "[$(TS)]$Message" | Tee-Object -FilePath (join-path -Path $LogOutputPath -ChildPath $LogFilename) -Append | Write-Verbose
}

#Disconenct from any current connected servers
if ($global:DefaultCisServers -ne $null) {Disconnect-CisServer -Server * -Force -Confirm:$false | Out-Null}

    write-host "connecting to "$SourceAppliance
    try {
        $CisServer = Connect-CisServer -Server $SourceAppliance -User $username -Password $password -ErrorAction Stop
    }
    catch {
        $_.Exception.Message
        if ($Debug) {Write-Log -Message $_.Exception.Message}
        continue
    }
    if ($Debug) {$msg = "connected to $SourceAppliance"; Write-Log -Message $msg}

    #Determnine deployment type
    $vami = @()
    $vami = (Get-CisService -Name 'com.vmware.appliance.system.version').get()

    if ( ($vami.type -eq "VMware Platform Services Controller")) {
        $vcsaType = "PSC"
    } elseIf ($vami.type -eq "vCenter Server with an embedded Platform Services Controller") {
        $vcsaType = "VCE"
    } elseIf ( ($vami.type -eq "vCenter Server with an external Platform Services Controller")) {
        $vcsaType = "VC"
    }
    if ($Debug) {Write-Log -Message $vcsaType}

    $parts = @()
    $CreateSpec = @()

    if ($vcsaType -eq "PSC") {
        $parts = @("common")}

    elseif ($vcsaType -eq "VCE" -or "VC") {
        if ($BackupType -eq "Common") {$parts = @("common")}
        else {$parts = @("common","seat")}
    }
    if ($Debug) {$msg = "Parts = $parts"; Write-Log -Message $msg}

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
        if ($Debug) {$msg = $backupPartSizes +" "+ $partId + " data is " + $partSize + " MB`n"; Write-Log -Message $msg}

    }

    Write-Host "Estimated Backup Size: $estimateBackupSize MB"
    Write-Host $backupPartSizes

    #main backup section
    $date = $((Get-Date).ToString('dd-MM-yyyy-HH-mm'))
    $BackupAPI = Get-CisService com.vmware.appliance.recovery.backup.job
    $CreateSpec = $BackupAPI.Help.create.piece.Create()
    $CreateSpec.parts = $parts
    $CreateSpec.backup_password = $BackupPassword
    $CreateSpec.location_type = $LocationType
    $CreateSpec.location = $Location +"/"+$SourceAppliance+"/"+$date
    $CreateSpec.location_user = $LocationUser
    $CreateSpec.location_password = $LocationPassword
    $CreateSpec.comment = $comment + " " + $date

    if ($Debug) {Write-Log -Message $CreateSpec}

    try {
        $BackupJob = $BackupAPI.create($CreateSpec)
        if ($Debug) {Write-Log -Message $BackupJob}
    }
    catch {
        $_.Exception.Message
        if ($Debug) {Write-Log -Message $_.Exception.Message}

    }

    If (!($BackupJob.id -eq $null)){
        do {
            #$BackupAPI.get("$($BackupJob.ID)") | select id, progress, state
            $progress = ($BackupAPI.get("$($BackupJob.ID)").progress)
            if ($Debug) {$msg = $progress; Write-Log -Message $msg}

            Write-Progress -Activity "Backing up $SourceAppliance - vcsaType = $vcsaType - backupType = $parts"  -Status $BackupAPI.get("$($BackupJob.ID)").state -PercentComplete ($BackupAPI.get("$($BackupJob.ID)").progress) -CurrentOperation "$progress% Complete"
            start-sleep -seconds 1
        } until ($BackupAPI.get("$($BackupJob.ID)").progress -eq 100 -or $BackupAPI.get("$($BackupJob.ID)").state -ne "INPROGRESS")

        Write-Progress -Activity "Backing up $SourceAppliance" -Completed
        if ($Debug) {Write-Log -Message "Backing up $SourceAppliance -Completed"}
        $BackupAPI.get("$($BackupJob.ID)") | select ID, Progress, State
    }

    Disconnect-CisServer -server $SourceAppliance -Confirm:$false