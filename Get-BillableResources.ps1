Import-Module Az.ResourceGraph

$filename = ".\ADXKustoQueries\helium_billable_resources.graph"
# load the query from a file if no input was provided
if (!$filename) {
    $filename = Read-Host "Input the full path of the kusto query to run"
}

$query = Get-Content $filename -Raw
if ($query) {
    $total = 0;
    #run the query (requires module 'Az.ResourceGraph')
    $result = Search-AzGraph -Query $query
    foreach ($i in $result.Data.toArray()) {
        $total += $i.ResourceCount 
    }
    $result.Data; Start-Sleep -Milliseconds 1000
    Write-Host "Total billable resources: "$total -ForegroundColor DarkRed
} else {
    Write-Error "Malformed query - exiting.."
}