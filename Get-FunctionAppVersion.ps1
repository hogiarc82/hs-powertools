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
#Execution of script starts here
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
# getting a list of available function apps
Write-Host "Getting available function apps... This may take a while" -ForegroundColor Yellow

try {
    $FunctionApps = Get-AzFunctionApp -SubscriptionId $context.Subscription.Id
} catch {
    <#Do this if a terminating exception happens#>
}

$appInfo = @{}
# process the version info}mation for each function app
foreach ($app in $FunctionApps) {

    # Query the web app for versions
    Write-Progress "Querying web app: "$app.Name
    #$appConfig = (az webapp show -n $app -g $group --query "{java:siteConfig.javaversion,netFramework:siteConfig.netFrameworkVersion,php:siteConfig.phpVersion,python:siteConfig.pythonVersion,linux:siteConfig.linuxFxVersion}") | ConvertFrom-Json
    try {
        $obj = [PSCustomObject]@{
            Subscription   = $context.Subscription.Name
            AppServicePlan = $app.AppServicePlan
            ResourceGroup  = $app.ResourceGroupName
            AppName        = $app.Name
            Status         = $app.Status
            OSType         = $app.OSType
            # Environment     = $app.ApplicationSettings['ASPNETCORE_ENVIRONMENT']
            Runtime        = $app.ApplicationSettings['FUNCTIONS_WORKER_RUNTIME']
            Version        = $app.ApplicationSettings['FUNCTIONS_EXTENSION_VERSION'].TrimStart("~")
        }
        $appInfo.Add($obj) | Out-Null
    } catch {
        <#Do this if a terminating exception happens#>
    }
    Write-Host "- Processed "$obj.AppName -ForegroundColor Cyan
}

# display the version information for each function app in a new window
$appInfo | Out-GridView