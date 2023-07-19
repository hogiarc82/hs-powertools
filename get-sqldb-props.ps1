$context = Get-AzContext
## TODO: Add support for multiple subscriptions and SQL server pools
$server = Get-AzSqlServer
## get a list of all databases on a server by specifying ResourceGroupName and ServerName
$dbs = Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName

$dblist = @()
## then loop through the list of databases and select the relevant properties
foreach ($database in $dbs) {
    
    $dbobj = [pscustomobject]@{
        Database        = $database.DatabaseName
        ElasticPool     = $database.ElasticPoolName
        isZoneRedundant = $database.ZoneRedundant
        # TODO: make this line work
        #isEncrypted           = $database.TransparentDataEncryption[0].Status
    }
    $dblist += $dbobj
}

$dblist | Out-GridView
## NB! Set the correct path to get the resulting output as an Excel file
# $mytable | Export-Excel -Path "./azsql_db_list.xls" -WorksheetName $context.Name

$nonPooled = $dblist | Where-Object { -not $_.ElasticPool }
Write-Output "Number of non-elastic SQL dbs: $($nonPooled.Count)"

$ZR = $dblist | Where-Object { $_.isZoneRedundant }
Write-Output "Number of zone-redundant SQL dbs: $($ZR.Count)"

$TDE = $dblist | Where-Object { $_.isEncrypted -eq "Enabled" }
Write-Output "Number of non-isTDE dbs: $($TDE.Count)"