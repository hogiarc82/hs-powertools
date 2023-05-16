$context = Get-AzContext
Write-Host "Your current AzContext is:"$context.Subscription.Name

$array = Read-Host "Enter a list of resource-types separated with commas"
$itemArray = $array.Split(",")

foreach ($item in $itemArray) {
    
    $item = $item.Trim("'","""")

    $resourceTypes += $item
    Write-Host "Adding "$item
}

Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

# $subscriptionId = Read-Host "Enter a valid Azure subscriptionId or press Enter to continue with current"
$subscriptionId = $context.Subscription.Id

$resourceTypes = @()
foreach ($type in $resourceTypes) {
    Write-Host "Getting resources that match the specified type:$type"
    $rsc = Get-AzResource -ResourceType $type | Where-Object { 
        $_.SubscriptionId -eq $subscriptionId 
    }
}
Write-Host "Resources in total:"$rsc.Count
$rsc | Select-Object Name, Kind, ResourceGroupName | Sort-Object -Property Kind, Name