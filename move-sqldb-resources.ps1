## TODO: Create a script that moves a SQL database from one resource group to another
$sites = @()
foreach ($i in $testdb) {
    $rgname = $i.DatabaseName+"qa"
    try {
        $app = Get-AzResource -Name $rgname -ResourceType "Microsoft.Web/sites"
        $sites += $app
    } catch {
    }
}
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

if ($null -ne $sites) {
    $sites | Format-Table
    Write-Host "Found $($sites.Count) matches and moved them to another resourcegroup" -ForegroundColor Red
}