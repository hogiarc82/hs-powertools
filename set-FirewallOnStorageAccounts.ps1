function New-PromptSelection {
    param ()
    $i = 1; 
    # Creates a list with all accessible Azure subscriptions 
    $subscriptions = New-Object System.Collections.ArrayList
    foreach ($line in Get-AzSubscription | Select-Object Name, Id) {
        $line | Add-Member NoteProperty -Name Index -Value $i
        $subscriptions.Add($line) | Out-Null
        $i++
    }

    # Creates the option list for the user to select a subscription from
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($subscriptions | ForEach-Object {
            $label = "&$($_.Index) $($_.Name) |"
            New-Object System.Management.Automation.Host.ChoiceDescription $label, $_.Name
        })

    # Draws the console menu and prompts user for a selection
    $title =   "Please select a subscription from the list"
    $message = "=========================================="
    $selectedSubscriptionIndex = $host.ui.PromptForChoice($title, $message, $options, -1)

    # Returns the selected subscription
    return $subscriptions[$selectedSubscriptionIndex]
}

$context = Get-AzContext
Write-Host -ForegroundColor Yellow "The current subscription is:"$context.Subscription.Name

# presents user with a choice to continue in current context or select another subscription
$key = Read-Host "- Do you want to continue to run the script in current context? (Y/n)"
if ($key -ne "Y") {
    Write-Host "Loading selection menu..." -ForegroundColor Cyan
    $selection = New-PromptSelection
    $context = Set-AzContext -Subscription $selection.Id
    Write-Host "You have selected a new context:" $selection.Name -ForegroundColor Yellow
}

$vNet = switch ( $context.subscription.Name )
{
    'Hogia Star - Test Environment' 	  { 'HogiaStarTest-VNET' }
    'Hogia Star - QA Environment' 		  { 'HogiaStarQa-VNET'   }
    'Hogia Star - Production Environment' { 'HogiaStarProd-VNET' }
}

#Fetch all storageaccounts except signit
$storageAccounts = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts' | where {$_.Name -notmatch "Signitstorage"}

#Allow Selected subnet
$INT1 = Get-AzVirtualNetwork -ResourceGroupName "HS-NETWORK" -Name $vNet | Get-AzVirtualNetworkSubnetConfig -Name "ASE-INT1"
$ADM = Get-AzVirtualNetwork -ResourceGroupName "HS-NETWORK" -Name $vNet | Get-AzVirtualNetworkSubnetConfig -Name "ASE-ADM"

Foreach ($storage in $storageAccounts) {

    Write-Host "Running on: $($storage.Name)"
    $switch = (Get-AzStorageAccountNetworkRuleSet -ResourceGroupName $($storage.ResourceGroupName) -AccountName $($storage.Name)).DefaultAction
    
    if ("Allow" -eq $switch) {

        #Set NetworkRuleSet to Deny
        Write-Host "Updating Rule Set to Deny for: [$($storage.Name)]"
        Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $($storage.ResourceGroupName) -Name $($storage.Name) -DefaultAction Deny

        Write-Host "Adding Network Rule for: [$($storage.Name)] "
        Add-AzStorageAccountNetworkRule -ResourceGroupName $($storage.ResourceGroupName) -Name $($storage.Name) -VirtualNetworkResourceId $ADM.Id
        Add-AzStorageAccountNetworkRule -ResourceGroupName $($storage.ResourceGroupName) -Name $($storage.Name) -VirtualNetworkResourceId $INT1.Id
    } else {

        Write-Host "NetWork Rule Set is already: '$switch'"
        Write-Host ""
    }
    
}