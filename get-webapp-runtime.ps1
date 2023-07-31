
# https://stackoverflow.com/questions/67107064/how-to-list-app-services-webapp-runtimes

# Define a collection to hold the output
$runtimes = [System.Collections.Generic.List[object]]@()

# Get subscription id
Write-Progress "Fetching subscription id"
$subscription = (az account show --query id -o tsv)

# Get all resource groups in the subscription
Write-Progress "Searching for resource groups"
$groups = (az group list --query "[].name" -o tsv)

# Set counter for group progress
$groupCounter = 1;

# Loop through each resource group to find all the web apps in it
foreach($group in $groups) {

    # Find web apps in the specified group
    Write-Progress "Searching for web apps in resource group $group" -PercentComplete (($groupCounter / $groups.Count) * 100)
    $apps =(az webapp list -g $group --query "[?kind=='app' || kind=='app,linux'].name" -o tsv)

    # Iterate the web apps
    foreach($app in $apps) {

        # Query the web app for versions
        Write-Progress "Querying web app $app"
        $appConfig = (az webapp show -n $app -g $group --query "{java:siteConfig.javaversion,netFramework:siteConfig.netFrameworkVersion,php:siteConfig.phpVersion,python:siteConfig.pythonVersion,linux:siteConfig.linuxFxVersion}") | ConvertFrom-Json

        # Define an output object
        $output = [PSCustomObject]@{
            resourcegroup = $group
            name = $app
            host = $null
            runtime = $null
            version = $null
        }

        # Determine which type of app service it is and get the values accordingly
        if($appConfig.linux -eq "") {

            # Windows platform
            $output.host = "windows"

            # Query the app config to get the metadata for the current stack
            $uri = "https://management.azure.com/subscriptions/$subscription/resourceGroups/$group/providers/Microsoft.Web/sites/$app/config/metadata/list?api-version=2020-10-01"
            $output.runtime = (az rest --method post --uri $uri --query "properties.CURRENT_STACK" -o tsv)

            # Determine the version of the relevant stack
            $output.version = switch($output.runtime) {
                "dotnet" {$appConfig.netFramework}
                "dotnetcore" {$null}
                "python" {$appConfig.python}
                "php" {$appConfig.php}
                "java" {$appConfig.java}
                default {$null}    
            }        

        } else {

            # Linux platform
            $output.host = "linux"

            # Split out the stack from the version
            $output.runtime = $appConfig.linux.split("|")[0]
            $output.version = $appConfig.linux.split("|")[1]

        }

        $runtimes.Add($output)
    }

    $groupCounter = $groupCounter + 1
}

# Convert the collection to JSON and write it out to a file
Write-Output $runtimes  | ConvertTo-Json > "webapp-runtimes-$subscription.json"