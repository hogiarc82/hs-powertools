<#
##############################################################################
# NOTE: THIS SCRIPT WILL NOT CHANGE ANY SYSTEM PROPERTIES IN THE ENVIRONMENT #
##############################################################################
Last modified: 2023-05-31 by roman.castro
(Co-authored with ChatGPT & Co-pilot)
#
#>

Write-Host "============= Executing Script - Press Ctrl+C anytime to abort =============" -ForegroundColor Green
Import-Module Az.Storage

<# A user defined function prompting user for selection from a custom menu #>
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
<# A user defined function for reading the StorageBlobServiceProperty as input #>
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
        #MinRestoreTime        = $obj.RestorePolicy.MinRestoreTime
        #LoggingOperations     = $obj.Logging.LoggingOperations           
        #LogRetentionDays      = $obj.Logging.RetentionDays
        ChangedFeedEnabled    = $obj.ChangeFeed.Enabled
        VersioningEnabled     = $obj.IsVersioningEnabled
    }
    Write-Host "..." -NoNewline
    return (New-Object PSObject -Property $saProperties)
}
# create a master list (table) for storing all of the storage account properties
[System.Collections.ArrayList]$list = New-Object -TypeName System.Collections.ArrayList

$context = Get-AzContext
# call Azure RM and return information about current context to operate
Write-Host -ForegroundColor Yellow "The current subscription is:"$context.Subscription.Name
Write-Host "NB! This script requires the appropriate permissions" -ForegroundColor Cyan

# present user a choice to either continue with current context or select a new
$key = Read-Host "- Do you want to continue to run the script in current context? (Y/n)"
if ($key -ne "Y") {
    Write-Host "Loading selection menu..." -ForegroundColor Yellow
    $selection = New-PromptSelection
    $context = Set-AzContext -Subscription $selection.Id
    Write-Host "You have selected a new context:" $selection.Name -ForegroundColor Yellow
}

# return all available storage accounts in the selected subscription
$storageAccounts = Get-AzStorageAccount
Write-Host "Retrieving and processing storage account properties..."
foreach ($sa in $storageAccounts) {
    # skip all storage accounts that belong to the cloud-shell, webjobs, etc.
    if ($sa.StorageAccountName -notlike "webjob*" -and $sa.ResourceGroupName -notlike "cloud-shell-storage*") {
        Write-Host "Loading"$sa.StorageAccountName -NoNewline
        
        $row = New-Object PSObject
        # populate basic storage information in the fields as row columns
        $row | Add-Member -MemberType NoteProperty -Name 'Subscription' -Value $context.Subscription.Name
        $row | Add-Member -MemberType NoteProperty -Name 'StorageAccount' -Value $sa.StorageAccountName
        $row | Add-Member -MemberType NoteProperty -Name 'ResouceGroup' -Value $sa.ResourceGroupName


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
        Write-Host "OK"
    }
}
# Count how many storage accounts where skipped
$skipCount = $storageAccounts.Count-$list.Count
Write-Host $list.Count"storage accounts processed. ($skipCount skipped)" -ForegroundColor Yellow

$key = Read-Host "- Save output to a file? Choose No to only show Gridview (Y/n)"
if ($key -eq "Y") {
        
    # Output table to excel file and display grid-view (make sure to include file-path and extension)
    $csvfile = ".\PSOutputFiles\StorageAccProps.csv"
    #$xlsfile = ".\PSOutputFiles\StorageAccProps.xlsx"

    try {
        Write-Host "Writing file to disk..."
        $list | Export-Csv -Path $csvfile -Delimiter ";"
        #$list | Export-Excel -Path $xlsfile -WorksheetName "ExtendedProperties" -TableName "storageprops" -AutoSize
        Write-Host "Success! Output can be found under the \PSOutputFiles folder" -ForegroundColor Green
    } catch {
        Write-Error $_.Exception.GetType().FullName
        Write-Host -ForegroundColor Yellow "Possible reason: File already open? (locked)"
        break
    } finally {
        if ($LASTEXITCODE -eq 0) {
            Write-Host -ForegroundColor Cyan "Script completed successfully."
        } else {
            Write-Host -ForegroundColor Blue "Script finished with exit code: $LASTEXITCODE"
        }
    }

} else {
    if ($LASTEXITCODE -eq 0) {
        $list | Out-GridView -Title "StorageAccountProperties"
        Write-Host -ForegroundColor Cyan "Script completed successfully."
    } else {
        Write-Host -ForegroundColor Blue "Script finished with exit code: $LASTEXITCODE"
    }  
}