$VMs = Import-Csv "AzureVirtualMachines.csv"
foreach ($vm in $VMs) {
    if ($vm.NAME -eq $null) {
        continue
    }
    $rgName = $vm."RESOURCE GROUP"
    $vmName = $vm."NAME"
    $location = $vm."LOCATION"
    # check if the VM has a system-assigned identity
    $vm = Get-AzVM -ResourceGroupName $rgName -VMName $vmName
    if ($vm.Identity.Type -eq "SystemAssigned") {
        # remove system-assigned identity
        Update-AzVM -ResourceGroupName $rgName -VM $vm -IdentityType None
    }
    else {
    }


    $isExtensionInstalled = $false
    foreach ($ext in $vm.Extensions) {
        if ($ext.Name -Contains "AzurePolicy") {
            $isExtensionInstalled = $true
            break
        }
    }

    if (!$isExtensionInstalled) {
        continue
    }

    # check power state
    $vmState = Get-AzVM -ResourceGroupName $rgName -VMName $vmName -Status
    $isOn = $vmState.Statuses[1].Code -Contains "running"
    $needTurnOff = $false

    if ($isOn -eq $false) {
        Start-AzVM -ResourceGroupName $rgName -Name $vmName
        $needTurnOff = $true
    }

    if ($isExtensionInstalled) {
        # uninstall extension
        if ($vm.OSProfile.WindowsConfiguration -ne $null) {
            Remove-AzVMExtension -ResourceGroupName $rgName -VMName $vmName -Name 'AzurePolicyforWindows'
        }
        else {
            Remove-AzVMExtension -ResourceGroupName $rgName -VMName $vmName -Name 'AzurePolicyforLinux'
        }
        Update-AzVM -ResourceGroupName $rgName -VM $vm
    }

    if ($needTurnOff) {
        Stop-AzVM -ResourceGroupName $rgName -Name $vmName -Force
    }
}