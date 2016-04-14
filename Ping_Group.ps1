<#
.SYNOPSIS
    Ping list of devices

.DESCRIPTION
Imports list of devices from CSV and reports if up or down. 
        
.USAGE
    Manual - Ad-hoc

    Source CSV file to be in following format;

    Name
    computer1
    computer2
    192.168.1.2

.NOTES
    File Name     : Ping_Group_v1.0.ps1
    Author        : Tim Williams
    Prerequisite  : .Net FrameWork 4.5.x
                  : Windows Management FrameWork 4.0
                  

.CHANGELOG
    Version 1.0   : 02/07/2014 Initial Build

#>

$PingResultsOff = @()
$PingResultsOn = @()

# Open CSV file
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $gSourceCsv = New-Object system.windows.forms.openfiledialog
    $gSourceCsv.InitialDirectory = 'c:\scripts'
    $gSourceCsv.Filter = "csv files (*.csv)|*.csv|All files (*.*)|*.*"
    $gSourceCsv.MultiSelect = $false
    $gSourceCsv.showdialog()
    $gSourceCsv.filenames 

$gObjSrc = import-csv -Path $gSourceCsv.fileName

$gObjSrc  | ForEach-Object {
    $names = $_.VMName

        foreach ($name in $names) {
            if ( Test-Connection -ComputerName $name -Count 1 -ErrorAction SilentlyContinue ) {
                Write-Host "$name is up" -ForegroundColor Green
                $PingGroupOn = "" | Select Name
                $PingGroupOn.Name = $name
                $PingResultsOn += $PingGroupOn
                }
                else {
                    Write-Host "$name is down" -ForegroundColor Red
                $PingGroupOff = "" | Select Name
                $PingGroupOff.Name = $name
                $PingResultsOff += $PingGroupOff
                    }
                }
            }
$PingResultsOn 
$PingResultsOff 