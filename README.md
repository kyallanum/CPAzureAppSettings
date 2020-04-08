# Copying your Azure Functions' App Settings to another Function App.

```
Usage: ./CPAzureFunctionAppSettings -subID "<subscriptionid>" -sourceRg "<source_resource_group>" -destRG "<destination_resource_group>"
```

In the event that you have to copy app settings from one Azure Function to another, you may want to look into doing this with automation. Especially if you want to do this on a large scale.

The first iteration of this Github project takes all appsettings in an Azure Function in a resource group with the Function App Name taking the form of: *"MyFunctionName-othertext"* and copies them to existing azure functions of the same form in a different resource group, given that the *"othertext"* is unknown in both of them, and it has a *"-"* separation in the name. 

A few quick comments if you want to change anything in the code for yourself:
```
21: $functionStart = $sfunctionapp.SubString(0, $sfunctionapp.IndexOf("-") -1);
```
Is where we specify the separator in the name. If you want this changed just change the *$sfunctionapp.IndexOf("-")* to whichever character you want to separate by.

Lines 31 - 52 removes all of the Azure generated appsettings so that we can make sure the copy doesn't actually change the behavior of the function app.

--------------

At this point this is all that I have implemented. But I will be working to implement other features into this script to allow other forms of copying including just copying a single function apps appsettings.