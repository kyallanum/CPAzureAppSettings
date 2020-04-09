param(
    [string]$subID = "",
    [string]$sourceRG = "",
    [string]$destRG = "",
    [string]$separator = "-"
)

if ($args[0] -eq "/?" -or $args[0] -eq "-help" -or $args[0] -eq "--help")
{
    echo "Usage: "
    echo "./CPAzureFunctionAppSettings -(single|multiple)"
    echo "./CPAzureFunctionAppSettings -multiple [-separator `"<separator>`"] -subID `"<subscriptionid>`" -sourceRg `"<source_resource_group>`" -destRG `"<destination_resource_group>`""
    echo "./CPAzureFunctionAppSettings -single <--------- not implemented yet"
    echo "`n"
    exit 1
}

if ($args[0] -ne "-single" -and $args[0] -ne "-multiple")
{
    echo "Usage: "
    echo "./CPAzureFunctionAppSettings -(single|multiple)"
    echo "./CPAzureFunctionAppSettings -multiple [-separator `"<separator>`"] -subID `"<subscriptionid>`" -sourceRg `"<source_resource_group>`" -destRG `"<destination_resource_group>`""
    echo "./CPAzureFunctionAppSettings -single <--------- not implemented yet"
    echo "`n"
    exit 1
}

if ($subID -eq "")
{
    $subID = Read-Host -Prompt "Subscription ID"
}
if ($sourceRG -eq "")
{
    $sourceRG = Read-Host -Prompt "Source Resource Group Name"
}
if ($destRG -eq "")
{
    $destRG = Read-Host -Prompt "Destination Resource Group Name"
}

Function set-Subscription
{
    param([string]$subscriptionID)
    az account set --subscription $subscriptionID
}

Function get-MultipleFunctionAppNames
{
    param([string]$resourceGroupName)
    
    #Get the source Function App Names
    $functionappIDs = @($(az functionapp list -g $resourceGroupName --query "[?state=='Running'].{ID: id}" | ConvertFrom-Json).ID)
    $functionAppNames = @(foreach ($item in $sfunctionAppIDs) {$item.Split("/")[-1];})
    , $functionAppNames
}

Function get-FunctionAppSettings
{
    param( [string]$resourceGroupName,
           [string]$functionAppName)

    $functionapp = Invoke-AzResourceAction -ResourceGroupName $resourceGroupName -ResourceType Microsoft.Web/sites/config -ResourceName "$($functionAppName)/appsettings" -Action list -ApiVersion 2016-08-01 -Force
    return [PSCustomObject]$functionapp
}

Function remove-Properties
{
    param([PsCustomObject]$properties)

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

    return [PSCustomObject]$properties
}

Function add-PropertiesToFunctionApp
{
    param( [PSCustomObject]$destFunction,
           [PSCustomObject]$propertiestoAdd )
           
    $propertiestoAdd = $propertiestoAdd | ConvertTo-Json | ConvertFrom-Json -AsHashTable 
    foreach ($p in $propertiestoAdd.keys)
    {
        $destFunction.Properties | Add-Member -MemberType NoteProperty -Name $p -Value $propertiestoAdd.$p -Force
    }

    return [PSCustomObject]$destFunction
}

Function update-FunctionAppSettings
{
    param(  [string]$destinationRG,
            [string]$functionAppName,
            [PSCustomObject]$updatedSettings )
    
    return New-AzResource -PropertyObject $updatedSettings -ResourceGroupName $destinationRG -ResourceType Microsoft.Web/sites/config -ResourceName "$($functionAppName)/appsettings" -ApiVersion 2016-08-01 -Force
}
            

Function copy-MultipleFunctionAppsWithSeparator
{
    param(  [string]$separator,
            [string[]]$sfunctionAppNames,
            [string[]]$dfunctionAppNames,
            [string]$sourceResourceGroup,
            [string]$destinationResourceGroup )

    #Loop through each source function app
    foreach ($sfunctionapp in $sfunctionAppNames)
    {
        #and through each destination app
        foreach ($dfunctionapp in $dfunctionAppNames)
        {
            #get what the function starts with so we can identify what destination app to send the settings
            $functionStart = $sfunctionapp.SubString(0, $sfunctionapp.IndexOf($separator) -1);

            #find the matching destination function app
            if($dfunctionapp -like "$($functionStart)*")
            {
                #get the source function app settings
                $sresource = get-FunctionAppSettings -resourceGroupName $sourceResourceGroup -functionAppName $sfunctionapp
                $properties = $sresource.Properties;

                #remove all Azure generated settings
                $properties = remove-Properties -properties $properties
            
                #get the destination function app appsettings
                $dresource = get-FunctionAppSettings -resourceGroupName $destinationResourceGroup -functionAppName $dfunctionapp
            
                $dresource = add-PropertiesToFunctionApp -destFunction $dresource -propertiestoAdd $properties

                #insert all of the appsettings into the destination function
                update-FunctionAppSettings -destinationRG $destRG -functionAppName $dfunctionapp -updatedSettings $dresource.Properties
            }
        }
    }
}

## Function App Start

set-Subscription -subscriptionID $subID;

if(args[0] -eq "-multiple")
{
    $sourceFunctionAppNames = get-MultipleFunctionAppNames -resourceGroupName $sourceRG;
    $destFunctionAppNames = get-MultipleFunctionAppNames -resourceGroupName $destRG;

    $appsettings = copy-MultipleFunctionAppsWithSeparator -sfunctionAppNames $sourceFunctionAppNames -dfunctionAppNames $destFunctionAppNames
}
else if(args[0] -eq "-single")
{
    echo "Currently copying one single function has not been implemented yet."
    echo "Usage: "
    echo "./CPAzureFunctionAppSettings -(single|multiple)"
    echo "./CPAzureFunctionAppSettings -multiple [-separator `"<separator>`"] -subID `"<subscriptionid>`" -sourceRg `"<source_resource_group>`" -destRG `"<destination_resource_group>`""
    echo "./CPAzureFunctionAppSettings -single <--------- not implemented yet"
    echo "`n"
    exit 1
}