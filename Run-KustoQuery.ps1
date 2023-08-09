param(
    [Parameter(Mandatory=$true)]
    [string]$Filename
)
Import-Module Az.ResourceGraph

# load the query from a file if no input was provided
if (!$filename) {
    $filename = Read-Host "Name of the file with the kusto query to load"    
}

$query = Get-Content $filename -Raw
if ($query) {
    #run the query (requires module 'Az.ResourceGraph')
    $result = Search-AzGraph -Query $query
    Get-AzContext
    $result.GetType()
} else {
    Write-Error $query": file content was invalid. Please try again"
}
