<#
##############################################################################
# NOTE: THIS SCRIPT WILL NOT CHANGE ANY SYSTEM PROPERTIES IN THE ENVIRONMENT #
##############################################################################
Last modified: 2023-05-31 by roman.castro
(Co-authored with ChatGPT & Co-pilot)
#>
#Run if needed 

Write-Host "============= Executing Script - Press Ctrl+C anytime to abort =============" -ForegroundColor Green
Import-Module Az.Storage

<# A user defined function for prompting the user for a choice from a menu #>
function New-PromptSelection {
    param ()
    $i = 0; 
    # Create an array list and populate with subscription titles 
    $subscriptions = New-Object System.Collections.ArrayList
    foreach ($line in Get-AzSubscription | Select-Object Name, Id) {
        $line | Add-Member NoteProperty -Name Index -Value $i
        $subscriptions.Add($line) | Out-Null
        $i++
    }

    # Create options for the user to select from
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($subscriptions | ForEach-Object {
            $label = "&$($_.Index) $($_.Name) | "
            New-Object System.Management.Automation.Host.ChoiceDescription $label, $_.Name
        })

    # Display verbose output for debugging
    # Write-Verbose "Options:"
    # foreach ($option in $options) {
    #     Write-Verbose "Label: $($option.Label)"
    #     Write-Verbose "HelpMessage: $($option.HelpMessage)"
    # }

    # Draw the menu and prompt user for a selection input
    $title = "=========== USER INPUT REQUIRED ==========="
    $message = "Please select a subscription from the list:"
    $selectedSubscriptionIndex = $host.ui.PromptForChoice($title, $message, $options, -1)

    # Return the user selected subscription
    return $subscriptions[$selectedSubscriptionIndex]
}
<# A user defined function that takes a StorageBlobServiceProperty as input #>
function New-ExtendedStorageProps {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [System.Object] $obj
    )

    # read input object from the extended storage properties data and list properties 
    $saProperties = [ordered] @{
        AllowPermDelete       = $obj.DeleteRetentionPolicy.AllowPermanentDelete
        DeleteRetentionPolicy = $obj.DeleteRetentionPolicy.Enabled
        RetentionPolicyDays   = $obj.DeleteRetentionPolicy.Days
        RestorePolicy         = $obj.RestorePolicy.Enabled
        RestorePolicyDays     = $obj.RestorePolicy.Days
        ChangedFeedEnabled    = $obj.ChangeFeed.Enabled
        VersioningEnabled     = $obj.IsVersioningEnabled
        #MinRestoreTime        = $obj.RestorePolicy.MinRestoreTime
        #LoggingOperations     = $obj.Logging.LoggingOperations           
        #LogRetentionDays      = $obj.Logging.RetentionDays
    }
    Write-Host "." -NoNewline
    return (New-Object PSObject -Property $saProperties)
}
# create a master list (table) for storing all of the storage account properties
[System.Collections.ArrayList]$list = New-Object -TypeName System.Collections.ArrayList

$context = Get-AzContext
# call Azure RM and return information about current context to operate
Write-Host -ForegroundColor Yellow "The current subscription selected is:"$context.Subscription.Name
Write-Host "This script requires the appropriate permissions within the environment" -ForegroundColor Cyan

# present user a choice to either continue with current context or select a new
$key = Read-Host "- Do you want to continue to run the script in current context? (Y/n)"
if ($key -ne "Y") {
    Write-Host "Loading selection menu..." -ForegroundColor Yellow
    $selection = New-PromptSelection
    $context = Set-AzContext -Subscription $selection.Id
}

# return all available storage accounts in the selected subscription
$storageAccounts = Get-AzStorageAccount
Write-Host "Retrieving and processing storage account properties..."
foreach ($sa in $storageAccounts) {
    # skip all storage accounts that belong to webjobs
    if ($sa.StorageAccountName -notlike "webjob*") {
        Write-Host "Loading"$sa.StorageAccountName -NoNewline
        
        $row = New-Object PSObject
        # populate basic storage information in the fields as row columns
        $row | Add-Member -MemberType NoteProperty -Name 'Subscription' -Value $context.Subscription.Name
        $row | Add-Member -MemberType NoteProperty -Name 'StorageAccount' -Value $sa.StorageAccountName
        $row | Add-Member -MemberType NoteProperty -Name 'ResouceGroup' -Value $sa.ResourceGroupName
        Write-Host "." -NoNewline

        #retrieve storage account tags (relevant ones)
        $acceptKeys = "company", "team"
        foreach ($key in $sa.Tags.Keys) {
            $value = $sa.Tags[$key]
            if ($key -in $acceptKeys) {
                $row | Add-Member -MemberType NoteProperty -Name $key -Value $value
            }
        }
        #add additional storage account properties per row (change as needed)
        $row | Add-Member -MemberType NoteProperty -Name 'Type' -Value $sa.Kind
        $row | Add-Member -MemberType NoteProperty -Name 'AccessTier' -Value $sa.AccessTier
        $row | Add-Member -MemberType NoteProperty -Name 'SKU' -Value $sa.Sku.Name
        $row | Add-Member -MemberType NoteProperty -Name 'Location' -Value $sa.PrimaryLocation
        ##$row | Add-Member -MemberType NoteProperty -Name 'GeoReplicatedIn' -Value $sa.SecondaryLocation
        Write-Host "." -NoNewline

        #call custom defined function to retrieve extended properties for each account
        $ext = New-ExtendedStorageProps(Get-AzStorageBlobServiceProperty -StorageAccount $sa)
        $ext.PSObject.Properties | ForEach-Object {
            $row | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
        }
 
        # add property field related to network access and security boundaries
        $row | Add-Member -MemberType NoteProperty -Name 'PublicNetAccess' -Value $sa.PublicNetworkAccess
        $row | Add-Member -MemberType NoteProperty -Name 'BlobPublicAccess' -Value $sa.AllowBlobPublicAccess
        $row | Add-Member -MemberType NoteProperty -Name 'AllowSharedKey' -Value $sa.AllowSharedKeyAccess
        $row | Add-Member -MemberType NoteProperty -Name 'AllowCrossTenant' -Value $sa.AllowCrossTenantReplication

        # add row to the master list (table)
        $list.Add($row) | Out-Null
        Write-Host " OK "
    }
}
# Count how many storage accounts where skipped
$skipCount = $storageAccounts.Count-$list.Count
Write-Host $list.Count"storage accounts processed. ($skipCount skipped)" -ForegroundColor Yellow

# Ensure that all the PSObjects in the ArrayList have the same set of properties (this is experimental and might not work)
#$properties = $list | ForEach-Object { $_.PSObject.Properties.Name } | Select-Object -Unique
#$arrayList = $arrayList | Select-Object $properties

$key = Read-Host "- Save output to a file? Choose No to only show Gridview (Y/n)"
if ($key -eq "Y") {
        
    # Output table to excel file and display grid-view (make sure to include file-path and extension)
    $path = ".\PSOutputFiles\StorageAccProps.xlsx"

    try {
        $list | Export-Excel -Path $path -WorksheetName "ExtendedProperties" -TableName "storageprops" -AutoSize
    } catch {
        Write-Error $_.Exception.GetType().FullName
        Write-Host -ForegroundColor Yellow "Possible reason: Excel file already open? (locked)"
        return
    } finally {
        Write-Host "Script finished successfully. Output can be found under the \PSOutputFiles folder" -ForegroundColor Green
    }

} else {
    $list | Out-GridView -Title "StorageAccountProperties"
}
