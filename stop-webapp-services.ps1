#############################################################################
# SCRIPT IS UNDER CONSTRUCTION !!! SCRIPT IS UNDER CONSTRUCTION !!! SCRIPT IS
#############################################################################
#
#
<# A user defined function prompting user for selection from a custom menu #>
function New-PromptSelection {
    param ()
    $i = 0; 
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
# calls Azure RM and returns information about current context
Write-Host -ForegroundColor Yellow "The current subscription is:"$context.Subscription.Name
Write-Host "NB! This script requires appropriate permissions to the env." -ForegroundColor Cyan

# presents user with a choice to either continue with current context or select a new
$key = Read-Host "- Do you want to continue to run the script in current context? (Y/n)"
if ($key -ne "Y") {
    Write-Host "Loading selection menu..." -ForegroundColor Cyan
    $selection = New-PromptSelection
    $context = Set-AzContext -Subscription $selection.Id
    Write-Host "You have selected a new context:" $selection.Name -ForegroundColor Yellow
}

##### Script to stop WebApps services starts here #####

#Params ++TODO: 
$resourceGroupName = "HS-SERVICEPLANS" #should be infered from the current context
$SPName = "SP01-INT" #should be selectable from a menu
$AppRGName = "HPTS-Orion" #should be selectable from a menu or infered

#Gets a list of all apps within a given App Service Plan
$plans = Get-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $SPName
$apps = Get-AzWebApp -AppServicePlan $plans | Where-Object ResourceGroup -eq $AppRGName

Write-Host "List of filtered Apps Complete" -ForegroundColor Cyan

#Stops all apps and slots in a specific resource group
$apps | ForEach-Object -ThrottleLimit 10 -Parallel {
    $slot = $_ | Get-AzWebAppSlot | Where-Object ResourceGroup -eq $AppRGName
    if ( $slot.State -eq "Running") {
        try {
            Write-Host "Stopping slot..." $slot.Name -ForegroundColor Yellow
            $slot | Stop-AzWebAppSlot | Out-Null    
        }
        catch {
            $Error[0]
        }
    }
    if ($slot.State -eq "Stopped" ) {
        Write-Host "Stopping..." $_.Name -ForegroundColor Green 
        $_ | Stop-AzWebApp | Out-Null
    }
}
#Stops all apps in a specific resource group
foreach ($app in $apps) {

    #Before stopping apps, stop all slots
    $slots | ForEach-Object -ThrottleLimit 10 -Parallel {
        Write-Host "Stopping" $slot.Name -ForegroundColor Yellow
        Stop-AzWebAppSlot -WebApp $slot | Out-Null
    }
    # Stop apps
    Write-host "Stopping" $app.Name -ForegroundColor Green 
    Stop-AzWebApp -WebApp $app | Out-Null

}
Write-Host "Job Complete"