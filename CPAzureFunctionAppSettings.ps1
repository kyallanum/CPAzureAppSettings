#Parameters to get when calling script
param(
    [string]$subID = "",
    [string]$destSubId = "",
    [string]$sourceRG = "",
    [string]$destRG = "",
    [string]$separator = "-",
    [string]$sourceFunc = "",
    [string]$destFunc = ""
)
#####################################################################
#Declare all of our functions to be used.


#Function: Output-Help
#Purpose: Print out to the user the syntax for the script
#Variables Taken: Nothing
#Returns: Nothing
Function Output-Help
{
    Write-Host "Usage: "
    Write-Host "./CPAzureFunctionAppSettings -(single|multiple)"
    Write-Host "./CPAzureFunctionAppSettings -single"
    Write-Host "                             -subID `"<source_sub_id>`""
    Write-Host "                             [-destSubID `"<dest_sub_id>`"]"
    Write-Host "                             -sourceRG `"<source_resource_group>`""
    Write-Host "                             [-destRG `"<destination_resource_group>`"]"
    Write-Host "                             -sourceFunc `"<source_function>`""
    Write-Host "                             -destfunc `"<dest_func`""
    Write-Host "`n"
    Write-Host "./CPAzureFunctionAppSettings -multiple "
    Write-Host "                             [-separator `"<separator>`"]"
    Write-Host "                             -subID `"<subscriptionid>`""
    Write-Host "                             [-destSubID `"<destination_subscription_id>`"]"
    Write-Host "                             -sourceRg `"<source_resource_group>`""
    Write-Host "                             -destRG `"<destination_resource_group>`""
    Write-Host "`n"
}

#Function: set-Subscription
#Purpose: Sets the Subscription that we are going to be working with
#Takes Variables: $subscriptionID [string]
#Returns: Nothing
Function set-Subscription
{
    param([string]$subscriptionID)
    
    az account set --subscription $subscriptionID 2> $null
    if(($(az account show --query "{ID: id}" | ConvertFrom-Json ).ID) -ne $subscriptionID)
    {
        Write-Host "Error: Could not connect to provided subscription" -ForegroundColor Yellow
        exit 1
    } 
}

#Function: get-MultipleFunctionAppNames
#Purpose: Gets the name of multiple function apps in a resource group and returns it in an array.
#Takes Variables: $resourceGroupName [string]
#Returns: $functionAppNames [array]
Function get-MultipleFunctionAppNames
{
    param([string]$resourceGroupName)
    
    #Get the source Function App Names
    if(!($functionappIDs = @($(az functionapp list -g $resourceGroupName --query "[].{ID: id}" | ConvertFrom-Json).ID)))
    {
        Write-Host "ERROR: No Azure Funcitons in this Resource Group" -ForegroundColor Yellow
        exit 1
    }
    $functionAppNames = @(foreach ($item in $functionAppIDs) {$item.Split("/")[-1];})
    , $functionAppNames
}

#Function: get-FunctionAppSettings
#Purpose: Takes a resource group name and a function app name, and gets its settings. Returns it as a Custom Powershell Object.
#Takes Variables: $resourceGroupName [string], $functionAppName [string]
#Returns: $functionapp [PSCustomObject]
Function get-FunctionAppSettings
{
    param( [string]$resourceGroupName,
           [string]$functionAppName)

    $functionapp = $(az functionapp config appsettings list --name $functionAppName --resource-group $resourceGroupName | ConvertFrom-Json)
    $functionapp | ForEach { $_.PSObject.Properties.Remove('slotSetting') }
    $myObject = [PSCustomObject]@{}
    foreach($property in $functionapp) { $myObject | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value }
    $functionapp = $myObject
    return [PSCustomObject]$functionapp
}

#Function: remove-Properties
#Purpose: Takes a Powershell Custom Object and removes all Azure Generated Settings, ensuring the Function Apps behavior does not change. Returns a Custom Powershell Object.
#Takes Variables: $properties [PSCustomObject]
#Returns: $properties [PSCustomObject]
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

#Function: add-PropertiesToFunctionApp
#Purpose: Adds properties from one Powershell Custom Object to another by converting the first into a Hash Table, and then adding each key and value to the end of the other. Returns a Powershell Custom Object.
#Takes Variables: $destFunction [PSCustomObject], $propertiestoAdd [PSCustomObject]
#Returns: $destFunction [PSCustomObject]
Function add-PropertiesToFunctionApp
{
    param( [PSCustomObject]$destFunction,
           [PSCustomObject]$propertiestoAdd )
           
    $propertiestoAdd = $propertiestoAdd | ConvertTo-Json | ConvertFrom-Json -AsHashTable 
    foreach ($p in $propertiestoAdd.keys)
    {
        $destFunction | Add-Member -MemberType NoteProperty -Name $p -Value $propertiestoAdd.$p -Force
    }

    return [PSCustomObject]$destFunction
}

#Function: update-FunctionAppSettings
#Purpose: Updates a function app settings by taking a Custom Powershell Object, the Destination Resource Group, and the Function App Name, and putting the appsettings in there.
#Takes Variables: $destinationRG [string], $functionAppName[string], $updatedSettings [PSCustomObject]
#Returns: [PSCustomObject]
Function update-FunctionAppSettings
{
    param(  [string]$destinationRG,
            [string]$functionAppName,
            [PSCustomObject]$updatedSettings )
    
    $settingsarray = @()
    for($i=0; $i -lt $updatedSettings.PSObject.Properties.Name.length; $i++)
    {
	    $settingsarray += $("`"" + $updatedSettings.PSObject.properties.name[$i] + "=" + $updatedSettings.PSObject.properties.value[$i] + "`"");
    }
    az functionapp config appsettings set --name $functionAppName --resource-group $destinationRG --settings $(foreach($setting in $settingsarray) { $setting }) | Out-Null

}
            
#Function: copy-MultipleFunctionAppsWithSeparator
#Purpose: Takes multiple resource groups and takes all Azure Functions App Settings and copies them to Azure Functions in a different resource group as long as they have the same prefix. 
#         Prefix is, by default denoted by "-" or the $separator variable.
#Takes Variables: $sep [string], $sfunctionAppNames [string[]], $dfunctionAppNames [string[]], $sourceResourceGroup [string], $destinationResourceGroup [string]
#Returns: Nothing
Function copy-MultipleFunctionAppsWithSeparator
{
    param(  [string]$sep = $separator,
            [string[]]$sfunctionAppNames,
            [string[]]$dfunctionAppNames,
            [string]$sourceResourceGroup,
            [string]$destinationResourceGroup )


    #Loop through each source function app
    foreach ($sfunctionapp in $sfunctionAppNames)
    {
        #get the source function app settings
        $sproperties = get-FunctionAppSettings -resourceGroupName $sourceResourceGroup -functionAppName $sfunctionapp
        
        #get what the function starts with so we can identify what destination app to send the settings
        $functionStart = $sfunctionapp.SubString(0, $sfunctionapp.IndexOf($sep));

        #remove all Azure generated settings
        $sproperties = remove-Properties -properties $sproperties

        #and loop through each destination app
        foreach ($dfunctionapp in $dfunctionAppNames)
        {

            #find the matching destination function app
            if($dfunctionapp -like "$($functionStart)*")
            {            
                if($destSubId -ne "")
                {
                    set-Subscription -subscriptionID $destSubId
                }
                #get the destination function app appsettings
                $dproperties= get-FunctionAppSettings -resourceGroupName $destinationResourceGroup -functionAppName $dfunctionapp
                $dproperties = add-PropertiesToFunctionApp -destFunction $dproperties -propertiestoAdd $sproperties

                #insert all of the appsettings into the destination function
                

                if($destSubId -ne "")
                {
                    set-Subscription -subscriptionID $subID
                }
            }
        }
    }
}

Function copyMultiple
{
    Write-Host "Setting Subscription: $($subID)"
    set-Subscription -subscriptionID $subID

    if($destSubId -ne "")
    {
        Write-Host "Destination Subscription: $($destSubId)"
    }
    Write-Host "Copying Multiple Function Apps appsettings."
    Write-Host "Source: $($sourceRG)"
    Write-Host "Destination: $($destRG)"
    $sourceFunctionAppNames = get-MultipleFunctionAppNames -resourceGroupName $sourceRG;
    Write-Host "Source Function App Names: $($sourceFunctionAppNames)"

    if($destSubId -ne "")
    {
        set-Subscription -subscriptionID $destSubId
    }

    $destFunctionAppNames = get-MultipleFunctionAppNames -resourceGroupName $destRG;
    Write-Host "Destination Function App Names: $($destFunctionAppNames)"

    if($destSubId -ne "")
    {
        set-Subscription -subscriptionID $subID
    }

    copy-MultipleFunctionAppsWithSeparator -sfunctionAppNames $sourceFunctionAppNames -dfunctionAppNames $destFunctionAppNames -sourceResourceGroup $sourceRG -destinationResourceGroup $destRG
    
    Write-Host "Copy Complete!"
}

Function copySingle
{
    #Validate Information. Throw errors if source Subscription, Resource Groups, or Functions dont exist.
    Write-Host "Source Subscription ID: $($subID)"
    set-Subscription -subscriptionID $subID

    if($destSubId -ne "")
    {
        Write-Host "Destination Subscription ID: $($destSubId)"
    }

    Write-Host "Source Resource Group: $($sourceRG)"
    if(!([System.Convert]::ToBoolean($(az group exists -n $sourceRG 2> $null))))
    {
        Write-Host "ERROR: The source resource group does not exist" -ForegroundColor Yellow
        exit 1
    }

    $destRG = if($destRG -eq "") { $sourceRG } else { $destRG }
    if($destRG -ne "")
    {
        Write-Host "Destination Resource Group: $($destRG)"
    }

    Write-Host "Source Function App: $($sourceFunc)"
    if(!(($(az functionapp list -g $sourceRG --query "[].{Name: name}" | ConvertFrom-Json ).Name ) -eq $sourceFunc))
    {
        Write-Host "ERROR: The source function app does not exist" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Destination Function App: $($destFunc)"

    Write-Host "--------------------------------------"
    Write-Host "Getting Source App Settings"
    $sAppSettings = get-FunctionAppSettings -resourceGroupName $sourceRG -functionAppName $sourceFunc
    $sAppSettings = remove-Properties -properties $sAppSettings

    Write-Host "--------------------------------------"
    Write-Host "Getting Destination App Settings"

    #Run Checks on whether destination resources exist.
    if($destSubId -ne "")
    {
        set-Subscription -subscriptionID $destSubId
    }


    if(!([System.Convert]::ToBoolean($(az group exists -n $destRG 2> $null))))
    {
        Write-Host "ERROR: The destination resource group does not exist" -ForegroundColor Yellow
        exit 1
    }
    if(!(($(az functionapp list -g $destRG --query "[].{Name: name}" | ConvertFrom-Json ).Name ) -eq $destFunc))
    {
        Write-Host "ERROR: The destination function app does not exist" -ForegroundColor Yellow
        exit 1
    }

    $dAppSettings = get-FunctionAppSettings -resourceGroupName $destRG -functionAppName $destFunc
    $dAppSettings = add-PropertiesToFunctionApp -destFunction $dAppSettings -propertiestoAdd $sAppSettings

    update-FunctionAppSettings -destinationRG $destRG -functionAppName $destFunc -updatedSettings $dAppSettings

    Write-Host "Copy Complete!"
}



########################################################################
#Script Execution Start

#Handle All Arguments
#If the user needs help with syntax show them here
if ($args[0] -eq "/?" -or $args[0] -eq "-help" -or $args[0] -eq "--help")
{
    Output-Help
    exit 1
}

switch ( $args[0] )
{
    "-single"
    {
        if($subID -eq "")
        {
            Read-Host -Prompt "Source Subscription"
        }
        if($sourceRG -eq "")
        {
            Read-Host -Prompt "Source Resource Group"
        }
        if($sourceFunc -eq "")
        {
            Read-Host -Prompt "Source Function App"
        }
        if($destFunc -eq "")
        {
            Read-Host -Prompt "Destination Function App"
        }
        copySingle

        break
    }
    "-multiple"
    {
        if($subID -eq "")
        {
            Read-Host -Prompt "Source Subscription"
        }
        if($sourceRG -eq "")
        {
            Read-Host -Prompt "Source Resource Group"
        }
        if($destRG -eq "")
        {
            Read-Host -Prompt "Destination Resource Group"
        }

        copyMultiple

        break
    }
    {($_ -eq "/?") -or ($_ -eq "-help") -or ($_ -eq "--help")}
    {
        Output-Help
        exit -1
    }
    default
    {
        Output-Help
        exit 1
    }
}