<#
# TODO: update this description to include general information about the script and what it does
#>

$context = Get-AzContext
## TODO: Add support for multiple subscriptions and different SQL server pools
## TODO: Add support for caching - optionally ask user for refresh to avoid repopulating list
$server = Get-AzSqlServer

## get a list of all databases on a server by specifying ResourceGroupName and ServerName
$dbs = Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName

$dblist = @()
## then loop through the list of databases and select the relevant properties
foreach ($database in $dbs) {
    Write-Host "Processing $($database.DatabaseName)"
    try { 
        if ("master" -ne $database.DatabaseName) {
            $dbTDE = $database | Get-AzSqlDatabaseTransparentDataEncryption
            $dbretention = $database | Get-AzSqlDatabaseBackupShortTermRetentionPolicy
        }
    } catch {
        Write-Warning -Message "$($database.DatabaseName) could not provide some extended properties"
    }
    $dbobj = [pscustomobject]@{
        Subscription    = $context.Subscription.Name
        ResourceGroup   = $database.ResourceGroupName
        DatabaseName    = $database.DatabaseName
        Location        = $database.Location
        ElasticPool     = $database.ElasticPoolName
        isZoneRedundant = $database.ZoneRedundant
        BackupRedudancy = $database.CurrentBackupStorageRedundancy
        RetentionDays   = $dbretention.RetentionDays
        DataEncryption  = $dbTDE.State
        ServerVersion   = $server.ServerVersion
        PublicNetAccess = $server.PublicNetworkAccess
        Tags            = $database.Tags
    }
    $dblist += $dbobj
    Write-Host "+$($database.DatabaseName).. OK" -ForegroundColor Green
}

$dblist | Out-GridView
## NB! Set the correct path to get the resulting output as an Excel file
# $mytable | Export-Excel -Path "./azsql_db_list.xls" -WorksheetName $context.Name

$nonPooled = $dblist | Where-Object { $_.ElasticPool -eq $null }
Write-Output "Number of non-pooled (single) SQL dbs: $($nonPooled.Count)"

$isZR = $dblist | Where-Object { $_.isZoneRedundant }
Write-Output "Number of zone-redundant SQL dbs: $($isZR.Count)"

$isGeo = $dblist | Where-Object { $_.BackupRedudancy -eq "Geo" }
Write-Output "Number of geo-redundant SQL dbs: $($isGeo.Count)"

$isTDE = $dblist | Where-Object { $_.DataEncryption -eq "Enabled" }
Write-Output "Number of TDE encrypted dbs: $($isTDE.Count)"

Write-Output "Total number of SQL dbs checked: $($dblist.Count)"