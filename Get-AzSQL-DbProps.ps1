<#
.SYNOPSIS List all of the properties of a database resource in a given subscription and displays results as a Grid-view object or optionally outputs results to a file.
.DESCRIPTION The script lists all of the properties of a database resource including general information about the configuration of the database along with optional information.
.INPUTS The script requires a single input - a subscription ID that is provided through an interactive console menu.
.PARAMETER Output
Optional string that specifies the filename of the resulting output file. This parameter must contain the file extension, which can be either `.csv` or `.xls`.
.PARAMETER UseCache
Optional string that specifies if the script should use a cached list of databases or not.
#
#>
param (
    [Parameter()]
    [string]$Output,
 
    [Parameter()]
    [bool]$UseCache = $false   
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
function Get-SQLServerList {
<# TODO: RG names needs cleanup to prevent errors with the match pattern across subscriptions #>
    #$server = Get-AzResourceGroup | where ResourceGroupName -match "HS-SQL" | Get-AzSqlServer
    $server = Get-AzSqlServer | Where-Object SqlAdministratorLogin -Match "hogiadba"


    # get a list of all current Azure SQL databases (unless the UseCache switch is passed by user)
    if (!$UseCache) {
        $dbs = Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $server.ResourceGroupName
    } else {
        if (!$dbs) {
            Write-Error "There was no cached databases available!"
            $UseCache = $false
            Get-SQLServerList
        }
        Write-Host -ForegroundColor Yellow "Using cached database information"
    }
    return $dbs
}
function ProcessDatabases {
<# loop through the list of databases and select the relevant properties #>
    $dbs | ForEach-Object -ThrottleLimit 10 -Parallel {
        $database = $_
        if ("master" -eq $database.DatabaseName) {
            Write-Host "Skipping $($database.DatabaseName)..." -ForegroundColor Red
        } else {
            Write-Host "Processing $($database.DatabaseName)"
            try { 
                $dbDMS = $database | Get-AzSqlDatabaseDataMaskingPolicy
                $dbTDE = $database | Get-AzSqlDatabaseTransparentDataEncryption
                $dbSTR = $database | Get-AzSqlDatabaseBackupShortTermRetentionPolicy
            } catch {
                Write-Warning -Message "$($database.DatabaseName) could not provide extended properties"
            }
            
            # retrieves the relevant tags from the object
            $tags = @{}
            foreach ($key in $database.Tags.Keys) {
                switch ($key) {
                    "company" {
                        $value = $database.Tags[$key]
                        $tags.Add($key, $value)
                    }
                    "team" {
                        $value = $database.Tags[$key]
                        $tags.Add($key, $value)
                    }
                }
            }
            $dbobj = [pscustomobject]@{
                Subscription    = $using:context.Subscription.Name
                ResourceGroup   = $database.ResourceGroupName
                Company         = $tags['company']
                Team            = $tags['team']
                ServerName      = $database.ServerName
                DatabaseName    = $database.DatabaseName
                ElasticPool     = $database.ElasticPoolName
                MaxSizeBytesGB  = $database.MaxSizeBytes / (1024 * 1024 * 1024)
                isZoneRedundant = $database.ZoneRedundant
                BackupReplica   = $database.CurrentBackupStorageRedundancy
                RetentionDays   = $dbSTR.RetentionDays
                DataEncryption  = $dbTDE.State
                DataMasking     = $dbDMS.DataMaskingState
                Location        = $database.Location
                PublicNetAccess = $using:server.PublicNetworkAccess
                Tags            = $database.Tags
            }
            Write-Host "- $($database.ServerName)/$($database.DatabaseName).. OK" -ForegroundColor Green
            return $dbobj
        }
    }
}
function Set-FileName {
    # Parameter help description
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("csv", "xls", "xlsx")]
        [string]$ext,
        
        [Parameter(Mandatory=$true)]
        [string]$filename,
        [string]$folder
    )
    switch ($ext) {
        'csv' {
            return $folder+$filename+".csv"
        }
        'xls' {
            return $folder+$filename+".xls" 
        }
        'xlsx' {
            return $folder+$filename+".xlsx" 
        }
        default {
            return $false
        }
    }
}
function StartPSScript {
    Clear-Host
    Write-Host "============= Executing Script - Press Ctrl+C anytime to abort =============" -ForegroundColor Green
    $context = Get-AzContext
    # calls Azure RM and returns information about current context
    Write-Host -ForegroundColor Yellow "The current subscription is:"$context.Subscription.Name
    Write-Host "NB! This script requires appropriate permissions to the env." -ForegroundColor Cyan
}
function SelectionPrompt {
    # presents user with a choice to either continue with current context or select a new
    $key = Read-Host "- Do you want to continue to run the script in current context? (Y/n)"
    if ($key -ne "Y") {
        Write-Host "Loading selection menu..." -ForegroundColor Cyan
        $selection = New-PromptSelection
        $context = Set-AzContext -Subscription $selection.Id
        Write-Host "You have selected a new context:" $selection.Name -ForegroundColor Yellow
    }
}
function SaveToFile {
    try {
        Write-Host "Writing file to disk..." -ForegroundColor Yellow
        if ($filename -match ".csv") {
            $list | Export-Csv -Path $filename -Delimiter ";" 
        }
        if ($filename -match ".xlsx") {
            $list | Export-Excel -Path $filename -WorksheetName "$($context.Subscription.Name)" -TableName "storageprops" -AutoSize 
        } else {
            Write-Error "Fatal error: Something went wrong while writing to $filename"
        }
        Write-Host "Success! Output can be found under: "$filepath -ForegroundColor Green
    } catch {
        Write-Error $_.Exception.GetType().FullName
        Write-Host -ForegroundColor Yellow "Possible reason: File already open? (=locked)"
        $LASTEXITCODE = 1
    }
}
function EndPSScript {
    if ($LASTEXITCODE -eq 0) {
        Write-Host -ForegroundColor Green "Script completed successfully." 
    } else {
        Write-Host -ForegroundColor Cyan "Script finished with exit code: $LASTEXITCODE"
    }
}
Get-SQLServerList
ProcessDatabases

$nonPooled = $list | Where-Object { $_.ElasticPool -eq $null }
Write-Output "Number of non-pooled SQL dbs: $($nonPooled.Count)"
$isTDE = $list | Where-Object { $_.DataEncryption -eq "Enabled" }
Write-Output "Number of TDE encrypted SQL dbs: $($isTDE.Count)"
$isZR = $list | Where-Object { $_.isZoneRedundant }
Write-Output "Number of Zone-redundant SQL dbs: $($isZR.Count)"
$isGeo = $list | Where-Object { $_.BackupReplica -eq "Geo" }
Write-Output "Geo-backup enabled replicas: $($isGeo.Count)"
Write-Output "Total number of DBs processed: $($list.Count)"
Write-Output "-------------------------------------------------)"

<# Presents the user with a choice of saving the results to a file or display on screen #>
$key = Read-Host "- Save output to a file? (Press Y or any key to continue)"
    
    if ($key -eq "Y") {
        # if the Output param was not specified at runtime then present user with option to specify now
        if (!$Output) {
            Write-Error "File extension type was NOT defined at runtime. Please use [-Output]"
            EndPSScript
        } else {

            $ext = $Output
            $folder = ".\PSOutputFiles\"
            $filename = "List-AzSqlDbProps"

            $file = Set-FileName($folder, $filename, $ext)
        $list | Out-GridView -Title "$($context.Subscription.Name) - SqlDbProperties"