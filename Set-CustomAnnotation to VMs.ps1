#params needed, input file, VM, vcenter and creds
#add in normal vcenter connection block
$attributeName = "Virtual Appliance"
$targetType = "Virtual Machine"
$inputList = $null
$VM =
$attributeValue = "True"

if ($inputList) {
    $VMs = $inputList
} elseif ($VM) {
    $VMs = $VM
}

$custA = Get-CustomAttribute -Name $attributeName -TargetType $targetType

if (!($custA)) {
    Write-Output $attributeName " attribute not found - creating.."
    New-CustomAttribute -Name $attributeName -TargetType $targetType
}
else {
    foreach ($v in $VMs) {
        get-vm -name $v | Set-Annotation -CustomAttribute $attributeName -Value $attributeValue
    }
}