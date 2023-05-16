Import-Module Az.Storage

$context = Get-AzContext
# get the current Azure context scope then ask user to confirm
Write-Host "Your current subscription is:"$context.Subscription.Name
Read-Host "Press any key to run the script in this context (Ctrl+C to abort)"

# retrive all the storage accounts in the subscription
$storageAccounts = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts'

# create an array to store all the storage accounts
[System.Collections.ArrayList]$saUsage = New-Object -TypeName System.Collections.ArrayList

# do the following for each storage account in the array (collection)
foreach ($storageAccount in $storageAccounts) {
    
    # Try to fetch the storage account key (extracts the primary key)
    try {
        $saKey = Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.Name
    } 
    catch {
        Write-Error "Not able to retrive the Storage Account key at this time."
        break;
    }

    # Create a new storage context using the primary SA key
    $saContext = New-AzStorageContext -StorageAccountName $storageAccount.Name -StorageAccountKey $saKey[0].value

    # Read all of the storage account properties and structure them into objects
    $saProp = Get-AzStorageServiceProperty -ServiceType Blob -Context $saContext

    $StorageAccountDetails = [ordered]@{
        SubscriptionName      = $context.Subscription.Name
        # SubscrpitionID        = $context.Subscription.Id
        StorageAccountName    = $storageAccount.Name
        ResourceGroup         = $storageAccount.ResourceGroupName
        Location              = $storageAccount.Location
        AllowPermDelete       = $saProp.DeleteRetentionPolicy.AllowPermanentDelete 
        DeleteRetentionPolicy = $saProp.DeleteRetentionPolicy.Enabled       
        DeleteRetentionInDays = $saProp.DeleteRetentionPolicy.RetentionDays
        # DeleteRetentionPolicy = $saProp.DeleteRetentionPolicy.Enabled
        # RetentionPolicyDays   = $saProp.DeleteRetentionPolicy.Days
        # MinRestoreTime        = $saProp.RestorePolicy.MinRestoreTime
        ChangedFeedEnabled    = $saProp.ChangeFeed.Enabled
        ChangeFeedRetention   = $saProp.ChangeFeed.RetentionInDays
        VersioningEnabled     = $saProp.IsVersioningEnabled
        LoggingOperations     = $saProp.Logging.LoggingOperations           
        LogRetentionDays      = $saProp.Logging.RetentionDays               
    }
    
    # Add each object as a row into the new PSObject serving as the table to output
    $saUsage.add((New-Object psobject -Property $StorageAccountDetails)) | Out-Null
}

# Write the final table to a formated xls-file
$saUsage | Export-Excel -Path ".\PSOutputFiles\ListStorageAccProps.xlsx" -WorksheetName "$StorageAccountDetails.SubscriptionName" -TableName "ExportedTable"