<#
##############################################################################
# NOTE: THIS SCRIPT WILL NOT CHANGE ANY SYSTEM PROPERTIES IN THE ENVIRONMENT #
##############################################################################
Last modified: 2023-05-31 by roman.castro
#
#>
param(
    [switch]$Full
)
Import-Module Az.Storage
<# A user defined function prompting user for selection from a custom menu #>
function New-PromptSelection {
    param ()
    $i = 1; 
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
<# A user defined function for reading the StorageBlobServiceProperty as input #>
function New-ExtendedStorageProps {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [System.Object] $sa
    )
    $obj = Get-AzStorageBlobServiceProperty -StorageAccount $sa
    # calls the extended storage properties cmdlet and select which properties to read
    $extProperties = [ordered] @{
        AllowPermDelete     = $obj.DeleteRetentionPolicy.AllowPermanentDelete
        DeleteRetention     = $obj.DeleteRetentionPolicy.Enabled
        RetentionPolicyDays = $obj.DeleteRetentionPolicy.Days
        RestorePolicy       = $obj.RestorePolicy.Enabled
        RestorePolicyDays   = $obj.RestorePolicy.Days
        #MinRestoreTime         = $obj.RestorePolicy.MinRestoreTime
        #LoggingOperations      = $obj.Logging.LoggingOperations           
        #LogRetentionDays       = $obj.Logging.RetentionDays
        ChangedFeed         = $obj.ChangeFeed.Enabled
        Versioning          = $obj.IsVersioningEnabled
    }
    return (New-Object PSObject -Property $extProperties)
}
function Get-StorageProperties {
    # retrieve all storage accounts in the subscription
    $storageAccounts = Get-AzStorageAccount
    Write-Host "Retrieving and processing storage account properties..." -ForegroundColor Cyan
    # creates a master list for storing the storage account properties
    [System.Collections.ArrayList]$list = New-Object -TypeName System.Collections.ArrayList

    foreach ($sa in $storageAccounts) {
        # skips all storage accounts connected to cloud-shell, webjobs, etc.
        if ($sa.StorageAccountName -notlike "webjob*" -and $sa.ResourceGroupName -notlike "cloud-shell-storage*") {
            Write-Host "Loading"$sa.StorageAccountName -NoNewline

            # create new table row to store information about the storage account
            $row = New-Object PSObject
            #$row | Add-Member -MemberType NoteProperty -Name 'Subscription' -Value $context.Subscription.Name
            $row | Add-Member -MemberType NoteProperty -Name 'DateCreatedOn' -Value $sa.CreationTime
            $row | Add-Member -MemberType NoteProperty -Name 'ResourceGroupName' -Value $sa.ResourceGroupName
            $row | Add-Member -MemberType NoteProperty -Name 'StorageAccountName' -Value $sa.StorageAccountName
            
            # retrieves storage account tags and adds them as fields (columns)
            $tags = "company", "team"
            foreach ($key in $sa.Tags.Keys) {
                $value = $sa.Tags[$key]
                if ($key -in $tags) {
                    $row | Add-Member -MemberType NoteProperty -Name $key -Value $value
                }
            }
    
            Write-Host "..." -NoNewline
            $row | Add-Member -MemberType NoteProperty -Name 'Type' -Value $sa.Kind
            $row | Add-Member -MemberType NoteProperty -Name 'AccessTier' -Value $sa.AccessTier
            $row | Add-Member -MemberType NoteProperty -Name 'SKU' -Value $sa.Sku.Name
            $row | Add-Member -MemberType NoteProperty -Name 'Location' -Value $sa.PrimaryLocation

            # calls a custom defined function to retrieve extended storage properties (if switched)
            if ($Full) {
                $ext = New-ExtendedStorageProps($sa)
                $ext.PSObject.Properties | ForEach-Object {
                    $row | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
                }
            }
            $row | Add-Member -MemberType NoteProperty -Name 'AllowSharedKey' -Value $sa.AllowSharedKeyAccess
            $row | Add-Member -MemberType NoteProperty -Name 'AllowCrossTenant' -Value $sa.AllowCrossTenantReplication
            $row | Add-Member -MemberType NoteProperty -Name 'BlobPublicAccess' -Value $sa.AllowBlobPublicAccess
            $row | Add-Member -MemberType NoteProperty -Name 'EnableHttpsOnly' -Value $sa.EnableHttpsTrafficOnly

            # Extract the NetworkRuleSet properties for the storage account
            $netRules = @{
                Allowed = @()
                Denied  = @()
            }
            if ($sa.NetworkRuleSet.VirtualNetworkRules.Count -gt 0) {

                foreach ($rule in $sa.NetworkRuleSet.VirtualNetworkRules) {
                    $vnetResId = $rule.VirtualNetworkResourceId -split "/"
                    $vnet = $vnetResId[-3]+"/"+$vnetResId[-2]+"/"+$vnetResId[-1]+"/"+$vnetResId[0]

                    switch ($rule.Action) {
                        'Allow' {
                            $netRules['Allowed'] += $vnet
                        }
                        'Deny' {
                            $netRules['Denied'] += $vnet
                        }
                    }
                }
            }
            # Extract the IP address rules from the storage account NetworkRuleSet
            $ipRuleSet = @{
                Allowed = @()
                Denied  = @()
            }
            if ($sa.NetworkRuleSet.IpRules.Count -gt 0) {
                foreach ($rule in $sa.NetworkRuleSet.IpRules) {
                    $ruleAction = $rule.Action
                    switch ($ruleAction) {
                        'Allow' { 
                            $ipRuleSet['Allowed'] += $rule.IPAddressOrRange 
                        }
                        'Deny' { 
                            $ipRuleSet['Denied'] += $rule.IPAddressOrRange 
                        }
                    }
                }
            }

            # adding fields related to storage account network access properties and other security, etc.
            #$row | Add-Member -MemberType NoteProperty -Name 'ResourceAccess' -Value $sa.NetworkRuleSet.ResourceAccessRules
            #$row | Add-Member -MemberType NoteProperty -Name 'PublicNetAccess' -Value $sa.PublicNetworkAccess## DO NOT USE
            $row | Add-Member -MemberType NoteProperty -Name 'ByPassAllowed' -Value $sa.NetworkRuleSet.Bypass
            $row | Add-Member -MemberType NoteProperty -Name 'DefaultAction' -Value $sa.NetworkRuleSet.DefaultAction
            $row | Add-Member -MemberType NoteProperty -Name 'AllowedIPRules' -Value $ipRuleSet['Allowed']
            $row | Add-Member -MemberType NoteProperty -Name 'AllowedVNets' -Value $netRules['Allowed']
            #$row | Add-Member -MemberType NoteProperty -Name 'DeniedIPRules' -Value $ipRuleSet['Denied']
            #$row | Add-Member -MemberType NoteProperty -Name 'DeniedVNets' -Value $netRules['Denied']
            # adds the row and populates the master table
            $list.Add($row) | Out-Null
            Write-Host "OK"
        }
    }
    $skipCount = $storageAccounts.Count-$list.Count
    Write-Host $list.Count"storage accounts processed. ($skipCount skipped)" -ForegroundColor Yellow
    return $list
}
# Starts the main script process...
Write-Host "============= Executing Script - Press Ctrl+C anytime to abort =============" -ForegroundColor Green

$context = Get-AzContext
Write-Host -ForegroundColor Yellow "The current subscription is:"$context.Subscription.Name

# presents user with a choice to continue in current context or select another subscription
$key = Read-Host "- Do you want to continue to run the script in current context? (Y/n)"
if ($key -ne "Y") {
    Write-Host "Loading selection menu..." -ForegroundColor Cyan
    $selection = New-PromptSelection
    $context = Set-AzContext -Subscription $selection.Id
    Write-Host "You have selected a new context:" $selection.Name -ForegroundColor Yellow
}
# Main function runs here...
$table = Get-StorageProperties

# Presents the user with a choice of saving the results to a file or display on screen
$key = Read-Host "- Save output to a file? Choose No to only show Gridview (Y/n)"
if ($key -eq "Y") {
    $table | Out-GridView -Title "$($context.Subscription.Name) - StorageAccountProperties"

    # Outputs table to a file (make sure to include filename and extension)
    $csvfile = ".\PSOutputFiles\StorageAccProps.csv"
    $xlsfile = ".\PSOutputFiles\StorageAccProps.xlsx"

    try {
        Write-Host "Writing file to disk..." -ForegroundColor Cyan
        #$table | Export-Csv -Path $csvfile -Delimiter ";"
        #$table | Export-Excel -Path $xlsfile -WorksheetName "$($context.Subscription.Name)" -TableName "storageprops" -AutoSize
        #Write-Host "Success! Output can be found under $csvfile" -ForegroundColor Green
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
    $table | Out-GridView -Title "$($context.Subscription.Name) - StorageAccountProperties"
    Write-Host -ForegroundColor Green "Script completed successfully."
}