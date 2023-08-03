<#
##############################################################################
# NOTE: THIS SCRIPT WILL NOT CHANGE ANY SYSTEM PROPERTIES IN THE ENVIRONMENT #
##############################################################################
Last modified: 2023-05-31 by roman.castro
#
#>

Write-Host "============= Executing Script - Press Ctrl+C anytime to abort =============" -ForegroundColor Green

Import-Module Az.Storage

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
<# A user defined function for reading the StorageBlobServiceProperty as input #>

$selection = New-PromptSelection
Write-Host $selection

Set-AzContext -Subscription $selection.Id

$serviceplans = Get-AzAppServicePlan
foreach ($asp in $serviceplans) {
    $apps = Get-AzWebApp -AppServicePlan $asp
    
    foreach ($app in $apps) {
    
    }
}
#Set-AzWebApp -Name app-name -ResourceGroupName group-name -FtpsState Disabled

