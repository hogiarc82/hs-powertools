## get a list of Azure subscriptions (that you have access to) and set AzContext
Get-AzSubscription

$subscriptionId = Read-Host -Prompt "Type in the SubscriptionID to execute this script in"
Set-AzContext -Subscription $subscriptionId

## get a list of all databases on a server by specifying ResourceGroupName and ServerName
$databases = Get-AzSqlDatabase -ServerName 'hs-sql01' -ResourceGroupName 'hs-sql'

$mytable = @()
# then loop through the list of databases and check the ElasticPoolName property
foreach ($database in $databases) {
    
    $obj = [pscustomobject]@{
        Database = $database.DatabaseName
        ElasticPool = $database.ElasticPoolName
        isZoneRedundant = $database.ZoneRedundant
    }
    $mytable += $obj

    # $row = "" | Select-Object Database,ElasticPool,isZoneRedundant
    # $row.Database = $($database.DatabaseName)

    # if ($database.ElasticPoolName) {    
    #     $row.ElasticPool = ($database.ElasticPoolName)
    # }
    # if ($database.ZoneRedundant) {
    #     $row.isZoneRedundant = "TRUE"
    # }
    # else {
    #     $row.isZoneRedundant = "FALSE"
    # }

    # # add the row to the table object
    # $mytable += $row
}

# NB! Set the correct path to get the resulting output as an Excel file
$mytable | Export-Excel -Path "./azsql_db_list.xls" -WorksheetName "SQL Databaser" -TableName "Tabell0"

$nonPooledDb = $databases | Where-Object { -not $_.ElasticPoolName }
Write-Output "Number of non-elastic SQL dbs: $($nonPooledDb.Count)"

$isZR = $databases | Where-Object { $_.ZoneRedundant }
Write-Output "Number of zone-redundant SQL dbs: $($isZR.Count)"