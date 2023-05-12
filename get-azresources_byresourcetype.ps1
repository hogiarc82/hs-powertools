$resourceTypes = @()

$array = Read-Host "Enter a comma-separated list of resource-itemtypes"
$itemArray = $array.Split(",")
foreach ($item in $itemArray) {
    
    $resourceTypes += $item
    Write-Host "Added: "$item
}

$subscriptionId = Read-Host "Enter a valid Azure subscriptionId"
$subscription = Get-AzSubscription -SubscriptionId $subscriptionId
Write-Host "Accepted: "$subscription.Name

foreach ($type in $resourceTypes) {
    Write-Host "Getting resources that match the specified type: " $type
    $result = Get-AzResource -ResourceType $type | Where-Object { 
        $_.SubscriptionId -eq $subscriptionId 
    } | Select-Object Name, Location, ResourceGroupName
	if ($result.Count -eq 0) {
	    Write-Host "Object returned empty..."
	else
            $result.Count
	}
}
