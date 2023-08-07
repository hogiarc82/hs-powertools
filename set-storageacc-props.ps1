<#
##############################################################################
# !!!!!! THIS SCRIPT WILL CHANGE SYSTEM PROPERTIES IN THE ENVIRONMENT !!!!!! #
##############################################################################
Last modified: 2023-05-31 by roman.castro
#
#>
Clear-Host
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

$context = Get-AzContext
Write-Host -ForegroundColor Yellow "The current subscription is:"$context.Subscription.Name

# presents user with a choice to run in the current context
$key = Read-Host "- Press Y to run in current context or N to select a new subscription"
if ($key -ne "Y") {
    Write-Host "Loading selection menu..." -ForegroundColor Cyan
    $selection = New-PromptSelection
    $context = Set-AzContext -Subscription $selection.Id
    Write-Host "You have selected a new context:" $selection.Name -ForegroundColor Yellow
}

[System.Collections.ArrayList]$list = New-Object -TypeName System.Collections.ArrayList
$storageAccounts = Get-AzStorageAccount

# TODO: work out a way to get a list of options matching the following actions
switch ($x) {
    condition {  }
    Default {}
}

# keep it here for safety
$storageAccount = $null

# Enable soft delete, change feed, and blob versioning
Update-AzStorageServiceProperty -ServiceType Blob -EnableChangeFeed $true -EnableVersioning $true -EnableSoftDelete $true -SoftDeleteRetentionInDays 7 -Context $storageAccount.Context

# Disable soft delete, change feed, and blob versioning
Update-AzStorageServiceProperty -ServiceType Blob -EnableChangeFeed $false -EnableVersioning $false -EnableSoftDelete $false -SoftDeleteRetentionInDays 0 -Context $storageAccount.Context

# Enable point-in-time restore
Update-AzStorageBlobServiceProperty -EnableRestorePolicy $true -RestoreDays 7 -Context $storageAccount.Context -EnableChangeFeed $true -IsVersioningEnabled $true

# Disable point-in-time restore
Update-AzStorageBlobServiceProperty -EnableRestorePolicy $true -RestoreDays 7 -Context $storageAccount.Context -EnableChangeFeed $true -IsVersioningEnabled $true
