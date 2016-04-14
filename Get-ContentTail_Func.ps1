function Get-ContentTail {
<#
 .SYNOPSIS
 Get the last x lines of a text file

 .DESCRIPTION
 Get the last x lines of a text file

 .PARAMETER Path
 Path to the text file

.PARAMETER Lines
 Number of lines to retrieve

.INPUTS
 IO.FileInfo
 System.Int

.OUTPUTS
 System.String

.EXAMPLE
 PS> Get-ContentTail -Path c:\server.log -Lines 10

.EXAMPLE
 PS> Get-ContentTail -Path c:\server.log -Lines 10 -Follow

#>
[CmdletBinding()][OutputType('System.String')]

Param
 (

[parameter(Mandatory=$true,Position=0)]
 [ValidateNotNullOrEmpty()]
 [IO.FileInfo]$Path,

 [parameter(Mandatory=$true,Position=1)]
 [ValidateNotNullOrEmpty()]
 [Int]$Lines,

[parameter(Mandatory=$false,Position=2)]
 [Switch]$Follow
 )
 try {

if ($PSBoundParameters.ContainsKey('Follow')){

Get-Content -Path $Path -Tail $Lines -Wait

}
 else {

Get-Content -Path $Path -Tail $Lines
 }

}
 catch [Exception]{

 throw "Unable to get the last x lines of a text file....."
 }
 }


