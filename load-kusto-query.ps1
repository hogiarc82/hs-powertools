# load the query from a kusto query file
$file = Read-Host "Name of the file with the kusto query to load"
$kustoQuery = Get-Content .\AzResourceGraphQueries\$file -Raw

#run the query (requires module 'Az.ResourceGraph' to be installed)
Search-AzGraph -Query $kustoQuery