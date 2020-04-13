# Copying your Azure Functions' App Settings to another Function App.

```
Usage: 
./CPAzureFunctionAppSettings -(single|multiple)
./CPAzureFunctionAppSettings -single
                             -subID "<source_sub_id>"
                             [-destSubID "<dest_sub_id>"]
                             -sourceRG "<source_resource_group>"
                             [-destRG "<destination_resource_group>"]
                             -sourceFunc "<source_function>"
                             -destfunc "<dest_func>"

./CPAzureFunctionAppSettings -multiple
                             [-separator "<separator>"]
                             -subID "<subscriptionid>"
                             [-destSubID "<destination_subscription_id>"]
                             -sourceRg "<source_resource_group>"
                             -destRG "<destination_resource_group>"
```

In the event that you have to copy app settings from one Azure Function to another, you may want to look into doing this with automation. Especially if you want to do this on a large scale.

### REQUIREMENTS
[PowerShell Version 7.0](https://github.com/PowerShell/PowerShell/releases/tag/v7.0.0-preview.6) 

The [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)


### V1.0.0
The first iteration of this Github project takes all appsettings in an Azure Function in a resource group with the Function App Name taking the form of: *"MyFunctionName-othertext"* and copies them to existing azure functions of the same form in a different resource group, given that the *"othertext"* is unknown in both of them, and it has a *"-"* separation in the name. If you want to override the separator you can use the optional argument *"-separator <separator>"*.

### V1.1.0
The second iteration of this script included the ability to copy between subscriptions. To do this, the optional argument was implemented called -destSubID which is used the same way as -subID

To use this script you either need the Azure CLI which can be found [here](https://github.com/Azure/azure-cli/releases), or you can use the cloud shell in your Azure Portal, which automatically has the Azure CLI installed.

### BUG FIX:
Previously a combination of both the AzureRM Module was used as well as the Azure CLI. this caused some issues when attempting to change subscriptions and get information from both sides. To fix this I removed all AzureRM Module references and am just sticking with the Azure CLI. I knew that I was mixing the two, and planned on fixing everything, this just forced me to fix it earlier than normal.

### QUICK NOTE:
The propertiesToRemove variable in the remove-Properties functions specifies all of the Azure generated appsettings so that we can make sure the copy doesn't actually change the behavior of the function app.

--------------

At this point this is all that I have implemented. But I will be working to implement other features into this script to allow other forms of copying including just copying a single function apps appsettings.
