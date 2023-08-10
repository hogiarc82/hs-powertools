<#
##############################################################################
# NOTE: THIS SCRIPT WILL NOT CHANGE ANY SYSTEM PROPERTIES IN THE ENVIRONMENT #
##############################################################################
Last modified: 2023-05-31 by roman.castro
#
#>
param (
    [Parameter()]
    [ValidateSet("csv", "xls")]
    [string]$Output
)
Import-Module Az.Storage

<# A user defined function prompting user for selection from a custom menu #>
function New-PromptSelection {
    param ()
    $i = 0; 
    # Creates a list with all accessible Azure subscriptions 
    $subscriptions = New-Object System.Collections.ArrayList
    foreach ($line in Get-AzSubscription | Select-Object Name, Id) {
        $line | Add-Member NoteProperty -Name Index -Value $i
        $subscriptions.Add($line) | Out-Null
        $i++
    }

    # Creates the option list for the user to select a subscription from
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($subscriptions | ForEach-Object {
            $label = "&$($_.Index) $($_.Name) |"
            New-Object System.Management.Automation.Host.ChoiceDescription $label, $_.Name
        })

    # Draws the console menu and prompts user for a selection
    $title =   "Please select a subscription from the list"
    $message = "=========================================="
    $selectedSubscriptionIndex = $host.ui.PromptForChoice($title, $message, $options, -1)

    # Returns the selected subscription
    return $subscriptions[$selectedSubscriptionIndex]
}
Clear-Host
Write-Host "============= Executing Script - Press Ctrl+C anytime to abort =============" -ForegroundColor Green
$context = Get-AzContext
# calls Azure RM and returns information about current context
Write-Host -ForegroundColor Yellow "The current subscription is:"$context.Subscription.Name
Write-Host "NB! This script requires appropriate permissions to the env." -ForegroundColor Cyan

# presents user with a choice to either continue with current context or select a new
$key = Read-Host "- Do you want to continue to run the script in current context? (Y/n)"
if ($key -ne "Y") {
    Write-Host "Loading selection menu..." -ForegroundColor Cyan
    $selection = New-PromptSelection
    $context = Set-AzContext -Subscription $selection.Id
    Write-Host "You have selected a new context:" $selection.Name -ForegroundColor Yellow
}
$server = Get-AzSqlServer | Where-Object SqlAdministratorLogin -Match "hogiadba"
#$server = Get-AzResourceGroup | where ResourceGroupName -match "HS-SQL" | Get-AzSqlServer ##TODO: fix bad RG names

## get a list of all databases on a server by specifying ResourceGroupName and ServerName
$dbs = Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName

$list = @()
## then loop through the list of databases and select the relevant properties
foreach ($database in $dbs) {
    if ("master" -eq $database.DatabaseName) {
        Write-Host "Skipping $($database.DatabaseName)..."
    }
    else {
        Write-Host "Processing $($database.DatabaseName)"
        try { 
            $dbDMS = $database | Get-AzSqlDatabaseDataMaskingPolicy
            $dbTDE = $database | Get-AzSqlDatabaseTransparentDataEncryption
            $dbSTR = $database | Get-AzSqlDatabaseBackupShortTermRetentionPolicy
        } catch {
            Write-Warning -Message "$($database.DatabaseName) could not provide extended properties"
        }
        $dbobj = [pscustomobject]@{
            Subscription     = $context.Subscription.Name
            ResourceGroup    = $database.ResourceGroupName
            ServerName       = $database.ServerName
            Location         = $database.Location
            DatabaseName     = $database.DatabaseName
            ElasticPool      = $database.ElasticPoolName
            MaxSizeBytesGB   = $database.MaxSizeBytes / (1024 * 1024 * 1024)
            isZoneRedundant  = $database.ZoneRedundant
            BackupRedundancy = $database.CurrentBackupStorageRedundancy
            RetentionDays    = $dbSTR.RetentionDays
            DataEncryption   = $dbTDE.State
            DataMasking      = $dbDMS.DataMaskingState
            PublicNetAccess  = $server.PublicNetworkAccess
            Tags             = $database.Tags
        }
        $list += $dbobj
        Write-Host "- $($database.ServerName)/$($database.DatabaseName).. OK" -ForegroundColor Green
    }
}
$nonPooled = $list | Where-Object { $_.ElasticPool -eq $null }
Write-Output "Number of non-pooled SQL dbs: $($nonPooled.Count)"

$isTDE = $list | Where-Object { $_.DataEncryption -eq "Enabled" }
Write-Output "Number of TDE encrypted dbs: $($isTDE.Count)"

$isZR = $list | Where-Object { $_.isZoneRedundant }
Write-Output "Number of zone-redundant SQL dbs: $($isZR.Count)"

$isGeo = $list | Where-Object { $_.BackupRedudancy -eq "Geo" }
Write-Output "Number of geo-backuped SQL dbs: $($isGeo.Count)"

Write-Output "Total number of SQL dbs checked: $($list.Count)"
Write-Output "-------------------------------------------------)"

# Presents the user with a choice of saving the results to a file or display on screen
$key = Read-Host "- Save output to a file? Choose No to only show Gridview (Y/n)"
if ($key -eq "Y") {
    $list | Out-GridView -Title "$($context.Subscription.Name) - SqlDbProperties"

    $filepath = ".\PSOutputFiles\"
    # Outputs table to a file (depending on output param)
    switch ($Output) {
        'csv' { $filename = $filepath + "StorageAccProps.csv" }
        'xls' { $filename = $filepath + "StorageAccProps.xlsx" }
        default { $filename = $null}
    }
    if (!$Output && !$filename) {
        Write-Host "No file file extension type defined at runtime. Please use the [-Output] switch!"
    }
    elseif ($filename -match ".csv") {
        $list | Export-Csv -Path $filename -Delimiter ";"
    }
    elseif ($filename -match ".xlsx") {
        $list | Export-Excel -Path $filename -WorksheetName "$($context.Subscription.Name)" -TableName "storageprops" -AutoSize
    }
}