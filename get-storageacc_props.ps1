Import-Module Az.Storage
$context = Get-AzContext

Write-Host -ForegroundColor Yellow "Your current subscription is"$context.Subscription.Name
Write-Host "Depending on your current role the access levels will vary."
$key = Read-Host "- Do you want to run the script in this context? (Y/n)"
if ($key -ne "Y") {
    return
}

Write-Host "OK.. Executing script." -ForegroundColor Green
#define a function to build the table from specified input objects
function New-StorageAccountDetails {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [System.Object] $obj
    )
    # construct each row with the SA properties (data fields)
    $saProperties = [ordered] @{
        SubscriptionName      = $context.Subscription.Name
        StorageAccount        = $obj.StorageAccountName
        ResourceGroup         = $obj.ResourceGroupName
        RestorePolicy         = $obj.RestorePolicy.Enabled
        RestorePolicyDays     = $obj.RestorePolicy.Days
        MinRestoreTime        = $obj.RestorePolicy.MinRestoreTime
        RetentionPolicyDays   = $obj.DeleteRetentionPolicy.Days
        DeleteRetentionPolicy = $obj.DeleteRetentionPolicy.Enabled
        DeleteRetentionInDays = $obj.DeleteRetentionPolicy.RetentionDays
        AllowPermDelete       = $obj.DeleteRetentionPolicy.AllowPermanentDelete
        ChangedFeedEnabled    = $obj.ChangeFeed.Enabled
        ChangeFeedRetention   = $obj.ChangeFeed.RetentionInDays
        VersioningEnabled     = $obj.IsVersioningEnabled
        LoggingOperations     = $obj.Logging.LoggingOperations           
        LogRetentionDays      = $obj.Logging.RetentionDays
    }
    return (New-Object PSObject -Property $saProperties)
}

# step 1: retrive all the storage accounts in the current subscription
## $storageAccounts = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts'
$storageAccounts = Get-AzStorageAccount
# create an array to store the extended storage account property details
[System.Collections.ArrayList]$list = New-Object -TypeName System.Collections.ArrayList

# step 2: retrive the storage account properties and add fields to each row
Write-Host "Processing storage accounts..." -ForegroundColor Yellow
foreach ($sa in $storageAccounts) {
    # skip storage accounts that belong to a webjob or function
    if ($sa.StorageAccountName -notlike "webjob*") {
        Write-Host "Loading"$sa.StorageAccountName -NoNewline
        $props = New-StorageAccountDetails(Get-AzStorageBlobServiceProperty -StorageAccount $sa)
        $props | Add-Member -MemberType NoteProperty -Name 'Version' -Value $sa.Kind
        $props | Add-Member -MemberType NoteProperty -Name 'AccessTier' -Value $sa.AccessTier
        $props | Add-Member -MemberType NoteProperty -Name 'Location' -Value $sa.PrimaryLocation
        $props | Add-Member -MemberType NoteProperty -Name 'ReplicaType' -Value $sa.SkuName
        $props | Add-Member -MemberType NoteProperty -Name 'ReplicatedTo' -Value $sa.SecondaryLocation 
        $props | Add-Member -MemberType NoteProperty -Name 'PublicNetwork' -Value $sa.PublicNetworkAccess
        $props | Add-Member -MemberType NoteProperty -Name 'PublicAccess' -Value $sa.AllowBlobPublicAccess
        $props | Add-Member -MemberType NoteProperty -Name 'AllowSharedKey' -Value $sa.AllowSharedKeyAccess
        $props | Add-Member -MemberType NoteProperty -Name 'AllowCrossTenant' -Value $sa.AllowCrossTenantReplication
        
        ## TODO: Fix some additional properties, like tags and other useful info
        #$t = $storageAccounts | Where-Object -Property Name -EQ $i.StorageAccountName | Select-Object Tags
        #$props | Add-Member -MemberType NoteProperty -Name 'Tags' -Value $t.Tags.ToString()
        $list.Add($props) | Out-Null
        Write-Host " ...OK!" -ForegroundColor White
    }
}
$skipped = $storageAccounts.Count-$list.Count
$totals = $storageAccounts.Count-$skipped
Write-Host "Total number of storage accounts processed:"$totals
Write-Host "(Skipped:"$skipped")"

# Output the entire table to an excel file (include full filepath and extension)
$path = ".\PSOutputFiles\StorageAccProps.xlsx"
try {
    $list | Export-Excel -Path $path -WorksheetName "ExtendedProperties" -TableName "storageprops" -AutoSize
} catch {
    Write-Error $_.Exception.GetType().FullName
    Write-Error "Possible reason: Do you have the Excel file open?"
    return
} finally {
    Write-Host "Script finished successfully!" -ForegroundColor Green
}