# Copying your Azure Functions' App Settings to another Function App.

```
"Usage: "
./CPAzureFunctionAppSettings -(single|multiple)
./CPAzureFunctionAppSettings -multiple [-separator `"<separator>`"] -subID `"<subscriptionid>`" -sourceRg `"<source_resource_group>`" -destRG `"<destination_resource_group>`"
./CPAzureFunctionAppSettings -single <--------- not implemented yet
```

In the event that you have to copy app settings from one Azure Function to another, you may want to look into doing this with automation. Especially if you want to do this on a large scale.

The first iteration of this Github project takes all appsettings in an Azure Function in a resource group with the Function App Name taking the form of: *"MyFunctionName-othertext"* and copies them to existing azure functions of the same form in a different resource group, given that the *"othertext"* is unknown in both of them, and it has a *"-"* separation in the name. If you want to override the separator you can use the optional argument *"-separator <separator>"*.


To use this script you either need the Azure CLI which can be found [here](https://github.com/Azure/azure-cli/releases), or you can use the cloud shell in your Azure Portal, which automatically had the Azure CLI installed.

QUICK NOTE:
The propertiesToRemove variable in the remove-Properties functions specifies all of the Azure generated appsettings so that we can make sure the copy doesn't actually change the behavior of the function app.

--------------

At this point this is all that I have implemented. But I will be working to implement other features into this script to allow other forms of copying including just copying a single function apps appsettings, as well as copying across subscriptions.
