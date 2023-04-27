## get a list of Azure subscriptions (that you have access to) and set AzContext
Get-AzSubscription

$subscriptionId = Read-Host -Prompt "Type in the SubscriptionID to execute this script in"
Set-AzContext -Subscription $subscriptionId

Get-AzAppServicePlan
Get-AzWebApp 
Set-AzWebApp -Name app-name -ResourceGroupName group-name -FtpsState Disabled