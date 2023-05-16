# Enable soft delete, change feed, and blob versioning
Update-AzStorageServiceProperty -ServiceType Blob -EnableChangeFeed $true -EnableVersioning $true -EnableSoftDelete $true -SoftDeleteRetentionInDays 7 -Context $storageAccount.Context

# Enable point-in-time restore
Update-AzStorageBlobServiceProperty -EnableRestorePolicy $true -RestoreDays 7 -Context $storageAccount.Context