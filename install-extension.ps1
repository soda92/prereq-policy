$VMs = Import-Csv "AzureVirtualMachines.csv"
foreach ($vm in $VMs) {
    $rgName = $vm."RESOURCE GROUP"
    $vmName = $vm."NAME"
    $location = $vm."LOCATION"
    # checking if the VM has a system-assigned identity
    $vm = Get-AzVM -ResourceGroupName $rgName -VMName $vmName
    if ($vm.Identity.Type -eq "SystemAssigned") {
    }
    else {
        # "assigning a system-assigned identity"
        Update-AzVM -ResourceGroupName $rgName -VM $vm -IdentityType SystemAssigned
    }

    $isExtensionInstalled = $false
    foreach ($ext in $vm.Extensions) {
        if ($ext.Name -Contains "AzurePolicy") {
            $isExtensionInstalled = $true
            break
        }
    }

    if ($isExtensionInstalled) {
        continue
    }

    # checking power state
    $vmState = Get-AzVM -ResourceGroupName $rgName -VMName $vmName -Status
    $isOn = $vmState.Statuses[1].Code -Contains "running"
    $needTurnOff = $false

    if ($isOn -eq $false) {
        Start-AzVM -ResourceGroupName $rgName -Name $vmName
        $needTurnOff = $true
    }

    if (!$isExtensionInstalled) {
        # installing extension
        if ($vm.OSProfile.WindowsConfiguration -ne $null) {
            Set-AzVMExtension -Publisher 'Microsoft.GuestConfiguration' -ExtensionType 'ConfigurationforWindows' -Name 'AzurePolicyforWindows' -TypeHandlerVersion 1.0 -ResourceGroupName $rgName -Location $location -VMName $vmName
        }
        else {
            Set-AzVMExtension -Publisher 'Microsoft.GuestConfiguration' -ExtensionType 'ConfigurationForLinux' -Name 'AzurePolicyforLinux' -TypeHandlerVersion 1.0 -ResourceGroupName $rgName -Location $location -VMName $vmName -EnableAutomaticUpgrade $true
        }

    }

    if ($needTurnOff) {
        Stop-AzVM -ResourceGroupName $rgName -Name $vmName -Force
    }
}