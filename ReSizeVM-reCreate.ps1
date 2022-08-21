#reset variable
Remove-Variable * -ErrorAction SilentlyContinue



#Enter details of target VM
$subscriptionId = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx'
$resourceGroupName = 'test-resource-group' 
$vmName = 'tstvm'
$NewVMSize = "Standard_D2s_v4"




### Retrive VM Info ###
$location = 'australiaeast' 
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
#1. OS DiskName
$original_OS_DiskName = $vm.StorageProfile.OsDisk.Name

#2. Nic details
$original_nic = Get-AzNetworkInterface -ResourceId $vm.NetworkProfile.NetworkInterfaces.id

#3. Tag details
$sourceTags = $vm | Select -ExpandProperty Tags
$OSTags = Get-AzDisk -DiskName $original_OS_DiskName -ResourceGroupName $resourceGroupName | Select -ExpandProperty Tags

#4. Data Disk details
$original_DataDisk = $vm.StorageProfile.DataDisks
$DiskCount = $original_DataDisk.Count

### Shutdown VM and take snapshot on VM OS disk ##
Stop-AzVM -id $vm.id -Force

$snapshotName = $vmName+'-OS-snapshot'
$snapshot =  New-AzSnapshotConfig -SourceUri $vm.StorageProfile.OsDisk.ManagedDisk.Id -Location $location -CreateOption copy
New-AzSnapshot -Snapshot $snapshot -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName
Get-AzSnapshot -ResourceGroupName $resourceGroupName

### take snapshot on all data disk ###
foreach ($disk in $original_DataDisk) 
    {
        $snapshotDataDiskName = $disk.Name+'-Data-snapshot'
        $snapshotDataDisk =  New-AzSnapshotConfig -SourceUri $disk.ManagedDisk.Id -Location $location -CreateOption copy
        New-AzSnapshot -Snapshot $snapshotDataDisk -SnapshotName $snapshotDataDiskName -ResourceGroupName $resourceGroupName
    }


### Detach all Data Disks ###
foreach ($disk in $original_DataDisk) 
    {
        Remove-AzVMDataDisk $vm -Name $disk.Name
    }
Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm


### Detach original Nic ###
# 1. Create and attach dummy nic
$dummynic = New-AzNetworkInterface -Name ($original_nic.Name+'-dummy') -ResourceGroupName $original_nic.ResourceGroupName -Location $original_nic.Location -SubnetId $original_nic.IpConfigurations.Subnet.Id 
Add-AzVMNetworkInterface -VM $vm -Id $dummynic.Id -Primary

# 2. detach original nic and update
Remove-AzVMNetworkInterface -VM $vm -Id $original_nic.id
Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm


### Remove VM ###
Remove-AzVM -id $vm.id -Force 

sleep 20


### Create new VM from snapshot ###
# 1. Create new OS disk from snapshot
$osDiskName = $original_OS_DiskName + "_NEW"
$snapshot = Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName
$diskConfig = New-AzDiskConfig -Location $snapshot.Location -SourceResourceId $snapshot.Id -CreateOption Copy
$disk = New-AzDisk -Disk $diskConfig -ResourceGroupName $resourceGroupName -DiskName $osDiskName

# 2. Initialize VM configuration
$NewVMConfig = New-AzVMConfig -VMName $vmName -VMSize $NewVMSize

# 3. Use the Managed Disk Resource Id to attach it to the virtual machine. 
$NewVMConfig = Set-AzVMOSDisk -VM $NewVMConfig -ManagedDiskId $disk.Id -CreateOption Attach -Windows

# 4. Configure TEMP vNet where virtual machine will be hosted
#$vnet = Get-AzVirtualNetwork -Name $tempVNET -ResourceGroupName $tempVNETRG

# 5. Attach original NIC to new VM
$NewVMConfig = Add-AzVMNetworkInterface -VM $NewVMConfig -Id $original_nic.Id

# 6. Attach Data Disk to new VM
foreach ($disk in $original_DataDisk)
    {
        $NewVMConfig = Add-AzVMDataDisk -VM $NewVMConfig -Name $Disk.Name -CreateOption Attach -ManagedDiskId (Get-AzDisk -DiskName $disk.Name).id -Lun $disk.Lun 
    }

# 7. Create the virtual machine with Managed Disk
$NewVM = New-AzVM -VM $NewVMConfig -ResourceGroupName $resourceGroupName -Location $snapshot.Location

# 8. Assign tag to VM
Set-AzResource -ResourceGroupName $resourceGroupName -Name $vm.Name -ResourceType "Microsoft.Compute/VirtualMachines" -Tag $sourceTags -Force

# 9. Assign tag to OS Disk
Set-AzResource -ResourceGroupName $resourceGroupName -Name $osDiskName -ResourceType "Microsoft.Compute/Disks" -Tag $OSTags -Force



### CLEAN UP ###
# 1. remove dummy nic
Remove-AzNetworkInterface -Name $dummynic.Name -ResourceGroupName $resourceGroupName -Force

# 2. remove OS Disk snapshot
#Remove-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName -Force

# 3. remove Data Disk snapshot
#foreach ($disk in $original_DataDisk) 
#    {
#        $snapshotDataDiskName = $disk.Name+'-Data-snapshot'
#        Remove-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotDataDiskName -Force
#    }
