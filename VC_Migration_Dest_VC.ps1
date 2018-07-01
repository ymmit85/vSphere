<#
.SYNOPSIS  
    Script to import folder, permissions and roles into new vCenter.
.DESCRIPTION
    Imports Folder structure, permissions and vCenter roles from XML file.
.NOTES
    Version:        1.0
    Author:         Tim Williams
    Credits:        http://vmwareinsight.com/Tips/2016/7/5798879/Powershell-Export-Import-Folders-and-Permissions-to-another-vCenter
                    https://www.blogger.com/profile/04755561443123954735
.LINK

.PARAMETER Directory
    Specifies the directory to import XML data from, if left blank current working directory will be used.

.PARAMETER Datacenter
    Specifies the Datacenter to import configuration to.

.EXAMPLE
    .\VC_Migration_Dest_VC.ps1 -Directory c:\temp -Datacenter Datacenter_1
    .\VC_Migration_Dest_VC.ps1 -Datacenter Datacenter_1

#>

param
(
    [Parameter(Position = 0, Mandatory = $false, HelpMessage = 'Enter path of input files from source vCenter')]
    [ValidateNotNullOrEmpty()]
    [String]$directory = "",
    [Parameter(Position = 0, Mandatory = $true, HelpMessage = 'Enter datacenter to import configuration to')]
    [ValidateNotNullOrEmpty()]
    [String]$datacenter = "",


        #$directory = $(read-host "Enter local input directory"),
        #$datacenter = $(read-host "Enter datacenter"),
        [switch]$roles,
        [switch]$permissions,
        [switch]$folders,
        [switch]$vms
)

function make-ParentFolder
{
        Param
        (
                $inFolderArray
        )
        $parentFolder = get-datacenter $datacenter | get-folder "VM"
        foreach ($thisSubFolder in $inFolderArray)
        {
                if (!($parentFolder | get-folder $thisSubFolder -noRecursion -erroraction silentlycontinue))
                {
                        $ParentFolder = $parentFolder | new-folder $thisSubFolder
                }
                else
                {
                        $ParentFolder = $ParentFolder | get-folder $thisSubFolder -noRecursion
                }
        }
        $ParentFolder
}
if (!($directory)) {$directory = (Get-Location).Path}

$directory = $directory.trim("\") #" fix the gistit syntax highlighting

#Rebuild Folder Structure
if ($folders)
{
        $folderArray = import-clixml $directory\$($datacenter)-folders.xml
        $i = 0
        foreach ($thisFolder in $folderArray)
        {
                write-progress -Activity "Creating Folders" -percentComplete ($i / $folderArray.count * 100)
                make-ParentFolder -inFolderArray $thisFolder.path
                $i++
        }
}

#Rebuild Roles
if ($roles)
{
        $allRoles = import-clixml $directory\$($datacenter)-roles.xml
        $i = 0
        foreach ($thisRole in $allRoles)
        {
                write-progress -Activity "Creating Roles" -percentComplete ($i / $allRoles.count * 100)
                if (!(get-virole $thisRole.name -erroraction silentlycontinue))
                {
                        new-virole -name $thisRole.name -privilege (get-viprivilege -id $thisRole.PrivilegeList) -erroraction silentlycontinue
                }
                $i++
        }
}

#Rebuild Permissions
if ($permissions)
{
        $allPermissions = import-clixml $directory\$($datacenter)-permissions.xml
        $i = 0
        foreach ($thisPermission in $allPermissions)
        {
                write-progress -Activity "Creating Permissions" -percentComplete ($i / $allPermissions.count * 100)
                $target = ""
                if ($thisPermission.type -eq "Folder")
                {
                        #permission is assigned to a folder, use make-folder to get the precise folder
                        $target = make-Parentfolder -inFolderArray $thisPermission.entity
                }
                elseif ($thisPermission.type -eq "VirtualMachine")
                {
                        #permission is assigned to VM
                        $target = get-datacenter $datacenter | get-vm $thisPermission.entity
                }
                elseif ($thisPermission.type -eq "Datacenter")
                {
                        #permission is assigned to Datacenter
                        $target = get-datacenter $thisPermission.entity
                }
                else
                {
                        write-error "Unexpected permission target, $($thisPermission.type)"
                }
                
                if ($target)
                {
                        $target | new-vipermission -role $thisPermission.role -principal $thisPermission.principal -propagate $thisPermission.propagate
                }
                else
                {
                        write-error "Unable to find permission object $($thisPermission.entity)"
                }
                $i++
        }
}

#Replace VMs
if ($VMs)
{
        $allVMs = import-clixml $directory\$($datacenter)-VMs.xml
        $allVApps = $NULL
        $i = 0
        if (test-path $directory\vApps.xml){$allVApps = import-clixml $directory\$($datacenter)-vApps.xml}
        foreach ($thisVM in $allVMs)
        {
                write-progress -Activity "Placing VMs" -percentComplete ($i / $allVMs.count * 100)
                if ($foundVM = get-vm $thisVM.name)
                {
                        $ParentFolder = make-ParentFolder -inFolderArray $thisVM.folderPath
                        $foundVM | move-vm -destination $ParentFolder   
                }
                $i++
        }
        foreach ($thisVApp in $allVApps)
        {
                echo "===$($thisVApp.name)==="
                $thisvApp.VMs
        }
        #Convert Template VMs back to Templates
}

if (!($VMs -or $folders -or $permissions -or $roles))
{
        echo "Please use one or more of the -VMs, -Folders, -Permissions, or -Roles switches to do something"
}