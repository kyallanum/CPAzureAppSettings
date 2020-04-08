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
            $properties.PSObject.properties.remove("AzureWebJobsStorage");
            $properties.PSObject.properties.remove("APPINSIGHTS_INSTRUMENTATIONKEY");
            $properties.PSObject.properties.remove("AzureWebJobsDashboard");
            $properties.PSObject.properties.remove("FUNCTIONS_EXTENSION_VERSION");
            $properties.PSObject.properties.remove("FUNCTIONS_WORKER_RUNTIME");
            $properties.PSObject.properties.remove("WEBSITE_CONTENTAZUREFILECONNECTIONSTRING");
            $properties.PSObject.properties.remove("WEBSITE_CONTENTSHARE");
            $properties.PSObject.properties.remove("WEBSITE_ENABLE_SYNC_UPDATE_SITE");
            $properties.PSObject.properties.remove("WEBSITE_RUN_FROM_PACKAGE");
            $properties.PSObject.properties.remove("APPLICATIONINSIGHTS_CONNECTIONSTRING");
            $properties.PSObject.properties.remove("AZURE_FUNCTIONS_ENVIRONMENT");
            $properties.PSObject.properties.remove("AzureWebJobsDisableHomepage");
            $properties.PSObject.properties.remove("AzureWebJobsFeatureFlags");
            $properties.PSObject.properties.remove("AzureWebJobsSecretStorageType");
            $properties.PSObject.properties.remove("AzureWebJobs_TypeScriptPath");
            $properties.PSObject.properties.remove("FUNCTION_APP_EDIT_MODE");
            $properties.PSObject.properties.remove("FUNCTIONS_V2_COMPATIBILITY_MODE");
            $properties.PSObject.properties.remove("FUNCTIONS_WORKER_PROCESS_COUNT");
            $properties.PSObject.properties.remove("WEBSITE_MAX_DYNAMIC_APPLICATION_SCALE_OUT");
            $properties.PSObject.properties.remove("WEBSITE_NODE_DEFAULT_VERSION");
            $properties.PSObject.properties.remove("AZURE_FUNCTION_PROXY_DISABLE_LOCAL_CALL");
            $properties.PSObject.properties.remove("AZURE_FUNCTION_PROXY_BACKEND_URL_DECODE_SLASHES");
            
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
