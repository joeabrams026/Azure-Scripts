﻿#Add-PSSnapin WAPPSCmdlets
# Load our variables
. .\Variables.ps1
#$thumb
#$subid
#$serviceName
#$slot - Staging or production

$cert = get-item cert:\CurrentUser\My\$thumb

$did = (Get-Deployment -ServiceName $serviceName -Certificate $cert -SubscriptionId $subid -Slot $slot).DeploymentId
$roles = (Get-Deployment -ServiceName $serviceName -Certificate $cert -SubscriptionId $subid -Slot $slot).RoleInstanceList

$roles | foreach {
    write-host $_.RoleName $_.InstanceName $_.InstanceStatus
    
    if ($_.InstanceStatus -ne "Ready")
    {
        write-host "Instance status not ready - aborting." 
        exit
    }
    else
    {
        write-host "Rebooting " -NoNewline
        $resetOperation = Reset-RoleInstance -ServiceName $serviceName -DeploymentSlot $slot -SubscriptionId $subid -InstanceName $_.InstanceName -Certificate $cert -Reboot -ErrorAction Stop
        $resetOperation | Get-OperationStatus -WaitToComplete -OperationId $resetOperation.RoleInstances[0].OperationId
        
        # For some reason, instances are not always in the 'ready' state after a reboot.
        # We'll wait a little longer
        $role = (Get-RoleInstanceStatus -Certificate $cert -SubscriptionId $subid -Slot $slot -ServiceName $serviceName -InstanceName $_.InstanceName).RoleInstances[0]
        while ($role.InstanceStatus -ne "Ready")
        {
            $role = (Get-RoleInstanceStatus -Certificate $cert -SubscriptionId $subid -Slot $slot -ServiceName $serviceName -InstanceName $_.InstanceName).RoleInstances[0]
            write-host "." -NoNewline
            sleep 10
        }
        write-host #newline
    }
}
