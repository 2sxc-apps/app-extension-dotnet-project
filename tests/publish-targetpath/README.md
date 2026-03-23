# Publish TargetPath Regression Fixture

This folder contains publish-time fixtures for regressions in Web SDK content target path handling.

The file below intentionally contains commas in its name to reproduce the .NET SDK 10 publish fallback issue that `extensions/dotnet-project/8-final/publish-targetpath.props` works around:

- `fixtures/Data/Data-Dynamic/Dynamic - Owner, Created, Modified.cshtml`

Useful manual checks:

```powershell
dotnet msbuild .\app.csproj -nologo -getItem:Content
dotnet publish .\app.csproj -nologo -o .\obj\publish-targetpath-test
```
