# ResizeVM-TempDisk-NonTempDisk

## What is this for?
Traditionally, Azure provide VM sizes (e.g. Standard_D2s_v3, Standard_E48_v3) that include a small local disk (i.e. a D: Drive). With the VM series such as Dsv4 and Dsv5 that small local disk no longer exists. However, customer can still attach Standard HDD, Premium SSD or Ultra SSD to use as remote storage. Local temporary disk is not persistent; to ensure the data is persistent, please use Standard HDD, Premium SSD or Ultra SSD options.

In order to resize a VM that has a local temp disk to a VM size with no local temp disk, you have to re-provision the VM.

## How to use?
1. Connect to your Virtual Machine that has a local temporary disk (for example, a D: Drive) as a admin.
2. Follow the guidelines on the [Move Page File to C Drive](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/change-drive-letter#temporarily-move-pagefilesys-to-c-drive) to move the page file from the local temporary disk (D: drive) to the C: drive. 
3. Modify variable of powershell script and run:

   *Sample*
```
#Enter details of target VM
$subscriptionId = 'xxxxxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
$resourceGroupName = 'resize-resourcegroup' 
$vmName = 'resize-tstvm'
$NewVMSize = "Standard_D2s_v4"

```

## What script do?
1. Retrive target VM information incuding: OS Disk, DataDisk, Network Interface Card, and Tags.
2. Shut down VM and take the snapshot of OS disk and all data disk
3. Detach all data disk
4. Detach NIC (As Azure require at least one Nic to be attached to VM, it is done through attaching a dummy NIC)
5. Remove original VM
6. Using OS snapshot to create a new VM, re-attached all data disk and original NIC
7. Purge all snapshots (hashed out, recommend run manually after verification)
