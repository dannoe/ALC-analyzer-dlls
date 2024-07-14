This packages provides some assemblies from the AL compiler extension for VS Code.

The extension is available in the Visual Studio Marketplace under [AL Language extension for Microsoft Dynamics 365 Business Central](https://marketplace.visualstudio.com/items?itemName=ms-dynamics-smb.al)

# Why
This package allows developers to more easily consume the assemblies from the AL compiler extension.

# How are the assemblies packaged?

- Downloading the [AL Language extension for Microsoft Dynamics 365 Business Central](https://marketplace.visualstudio.com/items?itemName=ms-dynamics-smb.al)
- Extracting the DLLs 
- Building a empty class library project, which includes some of the assemblies
- Packing the class library project
- Pushing it to nuget.org

# Alternative

If you don't want to use the nuget package, you can also follow these steps:

- Download and Install Visual Studio Code
- Install the [AL Language extension for Microsoft Dynamics 365 Business Central](https://marketplace.visualstudio.com/items?itemName=ms-dynamics-smb.al)
- Search the extension folder on your pc (e.g. ``C:\Users\user\.vscode\extensions\ms-dynamics-smb.al-<version>\bin\Analyzers``)
- Manually copy the required DLLs into your project