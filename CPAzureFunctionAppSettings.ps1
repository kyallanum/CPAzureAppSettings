param(
    [string]$subID = "",
    [string]$sourceRG = "",
    [string]$destRG = ""
)

if ($subID -eq "" -or $sourceRG -eq "" -or $destRG -eq "")
{
    echo "Usage: "
    echo "./CPAzureFunctionAppSettings -subID `"<subscriptionid>`" -sourceRg `"<source_resource_group>`" -destRG `"<destination_resource_group>`""
    echo "`n"
    exit 1
}


az account set --subscription $subID

#Get the source Function App Names
$sfunctionappIDs = @($(az functionapp list -g $sourceRG --query "[?state=='Running'].{ID: id}" | ConvertFrom-Json).ID)
$sfunctionAppNames = @(foreach ($item in $sfunctionAppIDs) {$item.Split("/")[-1];})

#Get the destination Function App Names
$dfunctionappIDs = @($(az functionapp list -g $destRG --query "[?state=='Running'].{ID: id}" | ConvertFrom-Json).ID)
$dfunctionAppNames = @(foreach ($item in $dfunctionAppIDs) {$item.Split("/")[-1];})

#Loop through each source function app
foreach ($sfunctionapp in $sfunctionAppNames)
{
    #and through each destination app
    foreach ($dfunctionapp in $dfunctionAppNames)
    {
        #get what the function starts with so we can identify what destination app to send the settings
        $functionStart = $sfunctionapp.SubString(0, $sfunctionapp.IndexOf("-") -1);

        #find the matching destination function app
        if($dfunctionapp -like "$($functionStart)*")
        {
            #get the source function app settings
            $sresource = Invoke-AzResourceAction -ResourceGroupName $sourceRG -ResourceType Microsoft.Web/sites/config -ResourceName "$($sfunctionapp)/appsettings" -Action list -ApiVersion 2016-08-01 -Force
            $properties = $sresource.Properties;

            #remove all Azure generated settings
            $propertiesToRemove = @("AzureWebJobsStorage", "APPINSIGHTS_INSTRUMENTATIONKEY", "AzureWebJobsDashboard", "FUNCTIONS_EXTENSION_VERSION", `
            "FUNCTIONS_WORKER_RUNTIME", "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING", "WEBSITE_CONTENTSHARE", "WEBSITE_CONTENTSHARE", "WEBSITE_CONTENTSHARE", `
            "WEBSITE_ENABLE_SYNC_UPDATE_SITE", "WEBSITE_RUN_FROM_PACKAGE", "APPLICATIONINSIGHTS_CONNECTIONSTRING", "AZURE_FUNCTIONS_ENVIRONMENT", "AzureWebJobsDisableHomepage", `
            "AzureWebJobsFeatureFlags", "AzureWebJobsSecretStorageType", "AzureWebJobs_TypeScriptPath", "FUNCTION_APP_EDIT_MODE", "FUNCTIONS_V2_COMPATIBILITY_MODE", `
            "FUNCTIONS_WORKER_PROCESS_COUNT", "WEBSITE_MAX_DYNAMIC_APPLICATION_SCALE_OUT", "WEBSITE_NODE_DEFAULT_VERSION", "AZURE_FUNCTION_PROXY_DISABLE_LOCAL_CALL", `
            "AZURE_FUNCTION_PROXY_BACKEND_URL_DECODE_SLASHES")
            
            foreach ($rProperty in $propertiesToRemove)
            {
                $properties.PSObject.properties.remove($rProperty);
            }
            
            #get the destination function app appsettings
            $dresource = Invoke-AzResourceAction -ResourceGroupName $destRG -ResourceType Microsoft.Web/sites/config -ResourceName "$($dfunctionapp)/appsettings" -Action list -ApiVersion 2016-08-01 -Force
            
            #convert the remianing appsettings to a hashtable so we can insert it into destinations appsettings
            $properties = $properties | ConvertTo-Json | ConvertFrom-Json -AsHashTable
            
            #loop through the hash table and insert each key/value appropriately
            foreach ($p in $properties.keys)
            {
                $dresource.Properties | Add-Member -MemberType NoteProperty -Name $p -Value $properties.$p -Force
            }

            #insert all of the appsettings into the destination function
            New-AzResource -PropertyObject $dresource.Properties -ResourceGroupName $destRG -ResourceType Microsoft.Web/sites/config -ResourceName "$($dfunctionapp)/appsettings" -ApiVersion 2016-08-01 -Force
        }
    }
}
