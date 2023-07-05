<#
##############################################################################
# NOTE: THIS SCRIPT WILL NOT CHANGE ANY SYSTEM PROPERTIES IN THE ENVIRONMENT #
##############################################################################
Last modified: 2023-05-31 by roman.castro
(Co-authored with ChatGPT & Co-pilot)
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
<# A user defined function for reading the StorageBlobServiceProperty as input #>
function New-ExtendedStorageProps {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [System.Object] $obj
    )
    Write-Host "..." -NoNewline
    # reads the input from the extended storage properties and selects specific properties 
    $saProperties = [ordered] @{
        AllowPermDelete       = $obj.DeleteRetentionPolicy.AllowPermanentDelete
        DeleteRetentionPolicy = $obj.DeleteRetentionPolicy.Enabled
        RetentionPolicyDays   = $obj.DeleteRetentionPolicy.Days
        RestorePolicy         = $obj.RestorePolicy.Enabled
        RestorePolicyDays     = $obj.RestorePolicy.Days
        #MinRestoreTime        = $obj.RestorePolicy.MinRestoreTime
        #LoggingOperations     = $obj.Logging.LoggingOperations           
        #LogRetentionDays      = $obj.Logging.RetentionDays
        ChangedFeedEnabled    = $obj.ChangeFeed.Enabled
        VersioningEnabled     = $obj.IsVersioningEnabled
    }
    return (New-Object PSObject -Property $saProperties)
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
# creates a master list (table) for storing all of the storage account properties
[System.Collections.ArrayList]$list = New-Object -TypeName System.Collections.ArrayList

# calls Azure RM and returns all storage accounts in the selected subscription
$storageAccounts = Get-AzStorageAccount
Write-Host "Retrieving and processing storage account properties..." -ForegroundColor Cyan
foreach ($sa in $storageAccounts) {
    # skips all storage accounts connected to cloud-shell, webjobs, etc.
    if ($sa.StorageAccountName -notlike "webjob*" -and $sa.ResourceGroupName -notlike "cloud-shell-storage*") {
        Write-Host "Loading"$sa.StorageAccountName -NoNewline
        
        $row = New-Object PSObject
        # adding fields to a table row with basic storage account properties
        $row | Add-Member -MemberType NoteProperty -Name 'Subscription' -Value $context.Subscription.Name
        $row | Add-Member -MemberType NoteProperty -Name 'StorageAccount' -Value $sa.StorageAccountName
        $row | Add-Member -MemberType NoteProperty -Name 'ResouceGroup' -Value $sa.ResourceGroupName

        # retrieves storage account tags and adds them as fields (columns)
        $acceptKeys = "company", "team"
        foreach ($key in $sa.Tags.Keys) {
            $value = $sa.Tags[$key]
            if ($key -in $acceptKeys) {
                $row | Add-Member -MemberType NoteProperty -Name $key -Value $value
            }
        }
        # adding additional storage account properties as new fields (columns)
        $row | Add-Member -MemberType NoteProperty -Name 'Type' -Value $sa.Kind
        $row | Add-Member -MemberType NoteProperty -Name 'AccessTier' -Value $sa.AccessTier
        $row | Add-Member -MemberType NoteProperty -Name 'SKU' -Value $sa.Sku.Name
        $row | Add-Member -MemberType NoteProperty -Name 'Location' -Value $sa.PrimaryLocation
        

        # calls a custom defined function to retrieve extended storage properties
        $ext = New-ExtendedStorageProps(Get-AzStorageBlobServiceProperty -StorageAccount $sa)
        $ext.PSObject.Properties | ForEach-Object {
            $row | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
        }

        # adding fields related to network access and perimater security, etc.
        $row | Add-Member -MemberType NoteProperty -Name 'PublicNetAccess' -Value $sa.PublicNetworkAccess
        $row | Add-Member -MemberType NoteProperty -Name 'BlobPublicAccess' -Value $sa.AllowBlobPublicAccess
        $row | Add-Member -MemberType NoteProperty -Name 'AllowSharedKey' -Value $sa.AllowSharedKeyAccess
        $row | Add-Member -MemberType NoteProperty -Name 'AllowCrossTenant' -Value $sa.AllowCrossTenantReplication

        # adds the entire row to the master list (table)
        $list.Add($row) | Out-Null
        Write-Host "OK"
    }
}
$skipCount = $storageAccounts.Count-$list.Count
Write-Host $list.Count"storage accounts processed. ($skipCount skipped)" -ForegroundColor Yellow

# Presents the user with a choice of saving the results to a file or display on screen
$key = Read-Host "- Save output to a file? Choose No to only show Gridview (Y/n)"
if ($key -eq "Y") {
        
    # Outputs table to a file (make sure to include filename and extension)
    $csvfile = ".\PSOutputFiles\StorageAccProps.csv"
    #$xlsfile = ".\PSOutputFiles\StorageAccProps.xlsx"

    try {
        Write-Host "Writing file to disk..." -ForegroundColor Cyan
        $list | Export-Csv -Path $csvfile -Delimiter ";"
        #$list | Export-Excel -Path $xlsfile -WorksheetName "ExtendedProperties" -TableName "storageprops" -AutoSize
        Write-Host "Success! Output can be found under $csvfile" -ForegroundColor Green
    } catch {
        Write-Error $_.Exception.GetType().FullName
        Write-Host -ForegroundColor Yellow "Possible reason: File already open? (locked)"
        $LASTEXITCODE = 1
    } finally {
        if ($LASTEXITCODE -eq 0) {
            Write-Host -ForegroundColor Green "Script completed successfully."
        } else {
            Write-Host -ForegroundColor Cyan "Script finished with exit code: $LASTEXITCODE"
        }
    }
} else {
    $list | Out-GridView -Title "StorageAccountProperties"
    Write-Host -ForegroundColor Green "Script completed successfully."
}