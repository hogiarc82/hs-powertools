<#
.SYNOPSIS
    This PS function creates a user prompt for selecting an Azure Subscription
.DESCRIPTION
    New-PromptSelection is used to create an interactive user selection menu for providing
    PSscripts a proper Set-AzContext to operate on with specific Az cmdlets. The menu presents
    the user with a selection of subscriptions to choose from and returns the subscript ID.
.PARAMETER Name
    This function does not require any parameters.
.EXAMPLE
    $selection = New-PromptSelection
    $context = Set-AzContext -Subscription $selection.Id
#>

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