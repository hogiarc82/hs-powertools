$context = Get-AzContext
$storageAccounts = Get-AzResource -ResourceType 'Microsoft.Storage/storageAccounts'
[System.Collections.ArrayList]$saUsage = New-Object -TypeName System.Collections.ArrayList

foreach ($storageAccount in $storageAccounts) {
    
    # Get the storage account key (extracts the primary key)
    ##$saKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccount.ResourceGroupName -Name $storageAccount.Name).Value[0]
    # Create a storage context (service-principal object)
    ##$saContext = New-AzStorageContext -StorageAccountName $storageAccount.Name -StorageAccountKey $saKey

    # Get the storage service properties for blobs
    ##$saProp = Get-AzStorageServiceProperty -ServiceType Blob -Context $saContext

    # Get the extended storage service properties
    $saPropEx = Get-AzStorageBlobServiceProperty -ResourceGroupName $storageAccount.ResourceGroupName -AccountName $storageAccount.Name

    $StorageAccountDetails = [ordered]@{
        SubscriptionName = $context.Subscription.Name
        SubscrpitionID = $context.Subscription.Id
        StorageAccountName = $storageAccount.Name
        ResourceGroup = $storageAccount.ResourceGroupName
        Location = $storageAccount.Location
        DeleteRetentionPolicy = $saPropEx.DeleteRetentionPolicy.Enabled
        RetentionPolicyDays = $saPropEx.DeleteRetentionPolicy.Days
        AllowPermDelete = $saPropEx.DeleteRetentionPolicy.AllowPermanentDelete
        RestorePolicyEnabled = $saPropEx.RestorePolicy.Enabled
        RestorePolicyDays= $saPropEx.RestorePolicy.Days
        MinRestoreTime = $saPropEx.RestorePolicy.MinRestoreTime
        ChangedFeedEnabled = $saPropEx.ChangeFeed.Enabled
        ChangeFeedRetention = $saPropEx.ChangeFeed.RetentionInDays
        VersioningEnabled = $saPropEx.IsVersioningEnabled

    }
    $saUsage.add((New-Object psobject -Property $StorageAccountDetails)) | Out-Null
}
$saUsage | Export-Excel -Path ".\PSOutputFiles\ListStorageAccProps.xlsx" -WorksheetName "PropertyDetails" -TableName "Table1"