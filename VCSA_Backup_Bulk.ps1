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
        $ConfigPath,
        $Debug
    )

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

$config = import-csv -Path $configpath
#Disconenct from any current connected servers

if ($global:DefaultCisServers -ne $null) {Disconnect-CisServer -Server * -Force -Confirm:$false | Out-Null}

Foreach ($item in $config) {
#import password for VCSA
$spass = ConvertTo-SecureString(Get-Content $item.VCSAPassword)

    write-host "connecting to "$item.hostname
    try {
        $CisServer = Connect-CisServer -Server $item.Hostname -User $item.VCSAUser -Password $spass -ErrorAction Stop
    }
    catch {
        $_.Exception.Message
        if ($Debug) {Write-Log -Message $_.Exception.Message}
        continue
    }
    if ($Debug) {$msg = "connected to $CisServer.name"; Write-Log -Message $msg}

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
        if ($item.BackupType -eq "Common") {$parts = @("common")}
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
    [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$BackupPassword = $item.backuppassword
    [VMware.VimAutomation.Cis.Core.Types.V1.Secret]$locationpassword = $item.locationpassword

    #main backup section
    $date = $((Get-Date).ToString('dd-MM-yyyy-HH-mm'))
    $BackupAPI = Get-CisService com.vmware.appliance.recovery.backup.job
    $CreateSpec = $BackupAPI.Help.create.piece.Create()
    $CreateSpec.parts = $parts
    $CreateSpec.backup_password = $BackupPassword
    $CreateSpec.location_type = $item.LocationType
    $CreateSpec.location = $item.Location +"/"+$item.Hostname+"/"+$date
    $CreateSpec.location_user = $item.LocationUser
    $CreateSpec.location_password = $locationpassword
    $CreateSpec.comment = $item.comment + " " + $date

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

            Write-Progress -Activity "Backing up $source - vcsaType = $vcsaType - backupType = $parts"  -Status $BackupAPI.get("$($BackupJob.ID)").state -PercentComplete ($BackupAPI.get("$($BackupJob.ID)").progress) -CurrentOperation "$progress% Complete"
            start-sleep -seconds 1
        } until ($BackupAPI.get("$($BackupJob.ID)").progress -eq 100 -or $BackupAPI.get("$($BackupJob.ID)").state -ne "INPROGRESS")

        Write-Progress -Activity "Backing up $source" -Completed
        if ($Debug) {Write-Log -Message "Backing up $source -Completed"}
        $BackupAPI.get("$($BackupJob.ID)") | select ID, Progress, State
    }

    Disconnect-CisServer -server $item.Hostname -Confirm:$false
}