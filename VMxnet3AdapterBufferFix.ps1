#Logging Function
## $LogFile.WriteLogFile('Message, 'Error')
    $scriptName = $MyInvocation.MyCommand
    $timer = (Get-Date -Format hh-mm-dd-MM-yyyy)
    $LogFilePath = $env:USERPROFILE
    $LogFileName =  "$scriptName $timer.txt"
    try {
    # Create a new log-file
    $global:LogFile = New-Item -Name $LogFileName -Path $LogFilePath -ItemType File -Force
} catch {
    # If log-file creation fails, throw the error to terminate script execution
    throw $Error[0]
}

# Write the CSV field-titles to the log-file
Out-File -InputObject '"DateTime","Level","Message"' -FilePath $LogFile -Encoding UTF8 -Append

# Add a ScriptMethod member to the $LogFile object for writing messages to the log-file
Add-Member -InputObject $global:LogFile -MemberType ScriptMethod -Name WriteLogFile -Value {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Message,
        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Critical')]
        [String]$Level = 'Info'
    )

    # Create the local UTC offset string to append to the ISO 8601 combined date and time string
    $LocalUtcOffset = "$([System.TimeZoneInfo]::Local.BaseUtcOffset.Hours.ToString('00')):$([System.TimeZoneInfo]::Local.BaseUtcOffset.Minutes.ToString('00'))"

    # Check whether the local UTC offset is positive
    if ([System.TimeZoneInfo]::Local.BaseUtcOffset.Hours -ge 0) {
        # Prefix the local UTC offset string with a "+" sign
        $LocalUtcOffset = "+$LocalUtcOffset"
    }

    $timeStamp = (Get-Date).ToString('s')
    # Write an entry to the log-file
        Switch ($Level) {
            "Error" {write-host "$($Level.ToUpper()), $Message, $timeStamp" -ForegroundColor Red} 
            "Critical" {write-host "$($Level.ToUpper()), $Message, $timeStamp" -ForegroundColor Red} 
            "Warning" {write-host "$($Level.ToUpper()), $Message, $timeStamp" -ForegroundColor Yellow}
            "Info" {Write-Host "$Message, $timeStamp" -ForegroundColor White }
            }
    Out-File -InputObject ("`"$((Get-Date).ToString('s'))$LocalUtcOffset`",`"$($Level.ToUpper())`",`"$Message`"") -FilePath $this -Encoding UTF8 -Append
}

$vmxnet3Adapters = Get-NetAdapter | where {$_.DriverDescription -like "vmxnet3 Ethernet Adapter"} 
$values = @()
$values = "Rx Ring #1 Size", "Small Rx Buffers"
$valuesX = "128", "256"

foreach ($vmx in $vmxnet3Adapters) {
    $ifName = $vmx.Name 
    $ifDesc = $vmx.InterfaceDescription
    $ifIndex = $vmx.ifIndex
    $ifstatus = $vmx.status
    $LogFile.WriteLogFile("Updating $ifName - $ifDesc - $ifIndex - $ifstatus", "Info")

    foreach ($v in $values) {
        
        $vmxSRx = $vmx | Get-NetAdapterAdvancedProperty -DisplayName $v | select DisplayValue
        $x = $vmxSRx.DisplayValue
        if (!$x) {$x = 0} 
        $vIndex = $values.IndexOf($v)
        $z = $valuesX[$vIndex]
        $LogFile.WriteLogFile(" Setting $v from $x to $z", "Info")
        $vmx | Set-NetAdapterAdvancedProperty -DisplayName $v -DisplayValue $z -Confirm:$false
        }
}

