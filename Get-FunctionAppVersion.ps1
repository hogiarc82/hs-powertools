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
} catch {
    <#Do this if a terminating exception happens#>
}

# process the version info}mation for each function app
$appInfo = Get-AzFunctionApp | ForEach-Object -ThrottleLimit 2 -Parallel {

    # Query the web app for versions
    Write-Progress "Querying web app: "$_.Name
    #$appConfig = (az webapp show -n $app -g $group --query "{java:siteConfig.javaversion,netFramework:siteConfig.netFrameworkVersion,php:siteConfig.phpVersion,python:siteConfig.pythonVersion,linux:siteConfig.linuxFxVersion}") | ConvertFrom-Json
    try {
        $obj = [PSCustomObject]@{
            Subscription   = $using:context.Subscription.Name
            AppServicePlan = $_.AppServicePlan
            ResourceGroup  = $_.ResourceGroupName
            AppName        = $_.Name
            Status         = $_.Status
            OSType         = $_.OSType
            # Environment     = $_.ApplicationSettings['ASPNETCORE_ENVIRONMENT']
            Runtime        = $_.ApplicationSettings['FUNCTIONS_WORKER_RUNTIME']
            Version        = $_.ApplicationSettings['FUNCTIONS_EXTENSION_VERSION'].TrimStart("~")
        }
        if ($obj.OSType -eq "Linux") {
            if ($null -eq $obj.Runtime) {
                #$obj.Runtime = "dotnet-core"
                Write-Warning "OS type is Linux but failed to retrive runtime version"
            }
        }
        Write-Host "-Processed"$obj.AppName -ForegroundColor Cyan
        return $obj
    } catch {
        Write-Error "Fatal Error:"$_.Name
    }
}
# display the version information for each function app in a new window
$appInfo | Out-GridView