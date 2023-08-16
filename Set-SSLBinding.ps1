$OLDthumbprint = "CF5EC359BB0B3EE07EC45829F9CCCE02462C66FE"
$thumbprint = 'BB577D58609F0BEFD931EBCB59E2220FC6C1885F'
$TagCompany = 'HISS'

#Otaggade
#Get-AzResource | Where-Object {$_.ResourceType -like 'Microsoft.Web/sites/slots' -and $_.Tags.Keys -notcontains "company"} | foreach-object {

Get-azresource -TagName 'Company' -TagValue "$TagCompany" | where-object { $_.ResourceType -like 'Microsoft.Web/sites*' } | foreach-object {
    
    if ($_.ResourceType -eq 'Microsoft.Web/sites/slots') {

        $siteName = $_.Name.replace("/staging", "")
        
        $webAppSSLSlotBinding = Get-AzWebAppSSLBinding -ResourceGroupName $_.ResourceGroupName -WebAppName $siteName -Slot Staging -ErrorAction SilentlyContinue

        if ($webAppSSLSlotBinding) {

            Write-Host "Will bind new ssl on SLOT Staging: [$siteName] In ResourceGroup: [$($_.ResourceGroupName)]" -ForegroundColor Green
            write-Host ''

            New-AzWebAppSSLBinding -ResourceGroupName $_.ResourceGroupName `
                -WebAppName $siteName `
                -Name $webAppSSLSlotBinding.Name `
                -Slot Staging `
                -Thumbprint $thumbprint `
                -SslState SniEnabled
            
        }
        else { Write-Host "No SSL Binding found on Staging Slot: [$siteName] Continuing without applying new..." -ForegroundColor Yellow }
    }
    else {

        $webAppSSLBinding = Get-AzWebAppSSLBinding -ResourceGroupName $_.ResourceGroupName -WebAppName $_.Name -ErrorAction SilentlyContinue
        
        if ($webAppSSLBinding) {

            Write-Host "Will bind new ssl on SLOT Production: [$($_.Name)] In ResourceGroup: [$($_.ResourceGroupName)]" -ForegroundColor Green
            Write-Host ''

            New-AzWebAppSSLBinding -ResourceGroupName $_.ResourceGroupName `
                -WebAppName $_.Name `
                -Name $webAppSSLBinding.Name `
                -Thumbprint $thumbprint `
                -SslState SniEnabled
            
        }
        else { Write-Host "No SSL Binding found on Production Slot: [$($_.Name)] Continuing without applying new..." -ForegroundColor Yellow }
    } 
}


#Verifiera
#$allstarwebapps = get-azwebapp | Get-AzWebAppSSLBinding | Where-Object {$_.Thumbprint -eq 'BB577D58609F0BEFD931EBCB59E2220FC6C1885F'}
#$allstarwebapps.count
#$allstarslots = Get-AzWebApp | Get-AzWebAppSlot
#$allstarslots.count
#$allslots = $allstarslots | Get-AzWebAppSSLBinding | Where-Object {$_.Thumbprint -eq 'BB577D58609F0BEFD931EBCB59E2220FC6C1885F'} 
#$allslots.count