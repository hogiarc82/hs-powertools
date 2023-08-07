<#
##############################################################################
# NOTE: THIS SCRIPT WILL NOT CHANGE ANY SYSTEM PROPERTIES IN THE ENVIRONMENT #
##############################################################################
Last modified: 2023-05-31 by roman.castro
#
#>
Clear-Host
Write-Host "============= Executing Script - Press Ctrl+C anytime to abort =============" -ForegroundColor Green
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

$dblist = @()
## then loop through the list of databases and select the relevant properties
foreach ($database in $dbs) {
    if ("master" -eq $database.DatabaseName) {
        Write-Host "Skipping $($database.DatabaseName)..."
    }
    else {
        Write-Host "Processing $($database.DatabaseName)"
        try { 
            $dbTDE = $database | Get-AzSqlDatabaseTransparentDataEncryption
            $dbretention = $database | Get-AzSqlDatabaseBackupShortTermRetentionPolicy
        } catch {
            Write-Warning -Message "$($database.DatabaseName) could not provide extended properties"
        }
        $dbobj = [pscustomobject]@{
            Subscription    = $context.Subscription.Name
            ResourceGroup   = $database.ResourceGroupName
            ServerNAme      = $database.ServerName
            DatabaseName    = $database.DatabaseName
            ElasticPool     = $database.ElasticPoolName
            isZoneRedundant = $database.ZoneRedundant
            BackupRedudancy = $database.CurrentBackupStorageRedundancy
            RetentionDays   = $dbretention.RetentionDays
            DataEncryption  = $dbTDE.State
            ServerVersion   = $server.ServerVersion
            PublicNetAccess = $server.PublicNetworkAccess
            Location        = $database.Location
            Tags            = $database.Tags
        }
        $dblist += $dbobj
        Write-Host "- $($database.ServerName)/$($database.DatabaseName).. OK" -ForegroundColor Green
    }
}
$nonPooled = $dblist | Where-Object { $_.ElasticPool -eq $null }
Write-Output "Number of non-pooled SQL dbs: $($nonPooled.Count)"

$isZR = $dblist | Where-Object { $_.isZoneRedundant }
Write-Output "Number of zone-redundant SQL dbs: $($isZR.Count)"

$isGeo = $dblist | Where-Object { $_.BackupRedudancy -eq "Geo" }
Write-Output "Number of geo-redundant SQL dbs: $($isGeo.Count)"

$isTDE = $dblist | Where-Object { $_.DataEncryption -eq "Enabled" }
Write-Output "Number of TDE encrypted dbs: $($isTDE.Count)"

Write-Output "Total number of SQL dbs checked: $($dblist.Count)"

# Presents the user with a choice of saving the results to a file or display on screen
$key = Read-Host "- Save output to a file? Choose No to only show Gridview (Y/n)"
if ($key -eq "Y") {
        
    # Outputs table to a file (make sure to include filename and extension)
    $csvfile = "./PSOutputFiles/azsql_db_props.csv"

    try {
        Write-Host "Writing file to disk..." -ForegroundColor Cyan
        $dblist | Export-Csv -Path $csvfile -Delimiter ";"
        Write-Host "File Saved: Output can be found under $csvfile" -ForegroundColor Green
    } catch {
        Write-Error $_.Exception.GetType().FullName
        Write-Host -ForegroundColor Yellow "Possible reason: File already open? (locked)"
        $LASTEXITCODE = 1
    } finally {
        if ($LASTEXITCODE -eq 0) {
            Write-Host -ForegroundColor Green "Script completed successfully."
        } else {
            Write-Host -ForegroundColor Cyan "Script finished with exit code: $LASTEXITCODE"
        }
    }
} else {
    $dblist | Out-GridView -Title "SQLDbProperties"
}