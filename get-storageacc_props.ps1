<# 
Script created by Román Castro for use with the Azure CLI (or PowerShell ver 5+)
################################################################################
# THIS SCRIPT DOES NOT CHANGE ANY PROPERTIES NOR PARAMETERS IN THE ENVIRONMENT #
################################################################################
Last modified: 2023-05-31 by roman.castro
(Co-authored with ChatGPT and Bing Chat)

#>

Import-Module Az.Storage
$context = Get-AzContext

Write-Host -ForegroundColor Yellow "Your current subscription is"$context.Subscription.Name
Write-Host "You need to run this script with the appropriate environment read-access!" -ForegroundColor Cyan
$key = Read-Host "- Do you want to continue to run the script in this context? (Y/n)"
if ($key -ne "Y") {
    return
}
Write-Host "============ COMMAND ACCEPTED - Executing Script ============" -ForegroundColor Green

#user defined function that takes a StorageBlobServiceProperty as input
function New-ExtendedStorageProps {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [System.Object] $obj
    )
    Write-Host "." -NoNewline

    # create new fields with the input from the extended storage properties data
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
    return (New-Object PSObject -Property $saProperties)
}
# create a list to store the final storage account properties as a "table"
[System.Collections.ArrayList]$list = New-Object -TypeName System.Collections.ArrayList

Write-Host "Retrieving and processing storage account properties..."
$storageAccounts = Get-AzStorageAccount

foreach ($sa in $storageAccounts) {
    # skip storage accounts that belong to webjobs
    if ($sa.StorageAccountName -notlike "webjob*") {
        Write-Host "Loading"$sa.StorageAccountName -NoNewline
        
        # create like a "table row"
        $row = New-Object PSObject
        
        # add basic primary fields as new columns
        $row | Add-Member -MemberType NoteProperty -Name 'Subscription' -Value $context.Subscription.Name
        $row | Add-Member -MemberType NoteProperty -Name 'StorageAccount' -Value $sa.StorageAccountName
        $row | Add-Member -MemberType NoteProperty -Name 'ResouceGroup' -Value $sa.ResourceGroupName

        #retrieve the storage account tags (only relevant ones)
        $acceptKeys = "company", "team"
        foreach ($key in $sa.Tags.Keys) {
            $value = $sa.Tags[$key]
            if ($key -in $acceptKeys) {
                $row | Add-Member -MemberType NoteProperty -Name $key -Value $value
            }
        }

        #add additional storage account properties (as many as you like)
        $row | Add-Member -MemberType NoteProperty -Name 'Type' -Value $sa.Kind
        $row | Add-Member -MemberType NoteProperty -Name 'AccessTier' -Value $sa.AccessTier
        $row | Add-Member -MemberType NoteProperty -Name 'SKU' -Value $sa.Sku.Name
        $row | Add-Member -MemberType NoteProperty -Name 'Location' -Value $sa.PrimaryLocation
        $row | Add-Member -MemberType NoteProperty -Name 'ReplicatedIn' -Value $sa.SecondaryLocation

        #call custom defined function to retrieve the extended properties
        $ext = New-ExtendedStorageProps(Get-AzStorageBlobServiceProperty -StorageAccount $sa)
        $ext.PSObject.Properties | ForEach-Object {
            $row | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
        }
 
        # add property field related to network access and security boundaries
        $row | Add-Member -MemberType NoteProperty -Name 'PublicNetAccess' -Value $sa.PublicNetworkAccess
        $row | Add-Member -MemberType NoteProperty -Name 'BlobPublicAccess' -Value $sa.AllowBlobPublicAccess
        $row | Add-Member -MemberType NoteProperty -Name 'AllowSharedKey' -Value $sa.AllowSharedKeyAccess
        $row | Add-Member -MemberType NoteProperty -Name 'AllowCrossTenant' -Value $sa.AllowCrossTenantReplication

        # join all fields into a table row
        $list.Add($row) | Out-Null
        Write-Host ".. OK"
    }
}
# tally how many storage accounts where skipped
$skipCount = $storageAccounts.Count-$list.Count
Write-Host $list.Count"storage accounts processed. ($skipCount skipped)" -ForegroundColor Yellow

# Ensure that all the PSObjects in the ArrayList have the same set of properties (this is experimental and might not work)
#$properties = $list | ForEach-Object { $_.PSObject.Properties.Name } | Select-Object -Unique
#$arrayList = $arrayList | Select-Object $properties

# Output table to excel file and display grid-view (make sure to include file-path and extension)
$path = ".\PSOutputFiles\StorageAccProps.xlsx"

try {
    $list | Export-Excel -Path $path -WorksheetName "ExtendedProperties" -TableName "storageprops" -AutoSize
} catch {
    Write-Error $_.Exception.GetType().FullName
    Write-Error "Possible reason: Do you have the Excel file open?"
    return
} finally {
    $list | Out-GridView -Title "StorageAccountProperties"
    Write-Host "Script finished successfully! Excel-file can be found in the .\PSOutputFiles folder" -ForegroundColor Green
}