<#
.SYNOPSIS  
    PowerShell script to export list of VMs in folders.
.DESCRIPTION
    Exports lists of VMs in vCenter Inventory VM folders. Will output a file for each folder from a input list or a 
    single folder along with a single file with all VMs from specified foolders.
.NOTES
    Version: 1.0
    Author: Tim Williams
    MD5: 0E7BD700F05552B0B69E60EB9E7E64A7

.PARAMETER InputFile
    Txt file with a list of folders to list VMs from.
.PARAMETER SourceFolder
    Single Folder that VMs will be listed from.
.PARAMETER OutputPath
    Directory to output txt files to. Script will validate path exists.

.EXAMPLE
    .\VMs in Folder.ps1 -SourceFolder "My VMs" -OutputPath c:\temp
.EXAMPLE
    .\VMs in Folder.ps1 -InputFile c:\temp\input.txt -OutputPath c:\temp
#>

param (
    [Parameter(Mandatory=$false)]
    $InputFile,
    [Parameter(Mandatory=$false)]
    $SourceFolder,
    [ValidateScript({Test-Path $_ -PathType 'Container'})]
    [Parameter(Mandatory=$true)]
    [String]
    $OutputPath
)

$VMs = @()
$date = $((Get-Date).ToString('yyyy-MM-dd-hh-mm'))

#If OutputPath is not provided then the below path will be used.
if (!($OutputPath)) {$OutputPath = "C:\temp"}
if ($InputFile -and !($SourceFolder)) {
    $input = Get-Content $InputFile
} elseif ($SourceFolder -and !($InputFile)) {
    $input = $SourceFolder
}

foreach ($i in $input) {
    write-host $i
    $VMList = Get-Folder -Type VM -Name $i | get-vm
    
    #output single folder VM list to file
    $ifilename = "$OutputPath\$date $i.txt"
    Out-File -InputObject $VMList.name -FilePath $ifilename

    #Add all VMs to single list
    $VMs += $VMList
}

#Output full list of VMs from specified folders
$gfilename = "$OutputPath\$date All VMs.txt"
Out-File -InputObject $VMs.name -FilePath $gfilename