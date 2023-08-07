## TODO: Create a script that moves a SQL database from one resource group to another

# Creates a empty list to store objects
$sites = @()

# Creates a list of objects from Azure Resources and adds them in sites if succeded
foreach ($i in $testdb) {
    $rgname = $i.DatabaseName+"qa"
    try {
        $app = Get-AzResource -Name $rgname -ResourceType "Microsoft.Web/sites"
        $sites += $app
    } catch {
    }
}
# Displays information from retrieved databases and simulating a move for each database
foreach ($s in $sites) {
    $dbname = $s.Name.Substring(0, $s.Name.Length-2)
    try {
        $db = Get-AzResource -Name $dbname -ResourceType "Microsoft.Sql/servers/databases"
        $db | Format-Table
        Write-Host "Found a database matching the site: $($db.Name)"
        # Remove 'whatIf' switch to run the script in vivo
        Move-AzResource -DestinationResourceGroupName $s.ResourceGroupName -ResourceId $db.ResourceId -WhatIf
    } catch {
    }
}
# Checks if varable is empty. If not, a table is displayed with number of matches and actions taken place
if ($null -ne $sites) {
    $sites | Format-Table
    Write-Host "Found $($sites.Count) matches and moved them to another resourcegroup" -ForegroundColor Red
}