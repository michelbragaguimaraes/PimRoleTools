@{
    RootModule = 'PimRoleTools.psm1'
    ModuleVersion = '1.0.2'
    GUID = 'b14b8395-fcc6-422b-8f21-d0c00a4d0e8b'
    Author = 'Michel Braga Guimaraes'
    CompanyName = 'Independent'
    Description = 'PowerShell module to activate and monitor PIM role assignments using Microsoft Graph.'
    PowerShellVersion = '7.1'
    CompatiblePSEditions = @('Core')
    RequiredModules = @('Microsoft.Graph')
    FunctionsToExport = @('Show-PimRole', 'Enable-PimRole', 'Get-PimRole')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{}
  }