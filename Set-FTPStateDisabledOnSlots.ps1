#Set ftpsState 'Disabled' on all app service slots in current subscription

Get-AzResource -ResourceType Microsoft.Web/sites/slots | ForEach-Object {
    $params = @{
        ApiVersion        = '2018-02-01'
        ResourceName      = '{0}/web' -f $_.Name
        ResourceGroupName = $_.ResourceGroupName
        PropertyObject    = @{ ftpsState = 'Disabled' }
        ResourceType      = 'Microsoft.Web/sites/slots/config'
    }
    Set-AzResource @params -Force
}