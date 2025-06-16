@{
    RootModule = 'PimRoleTools.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'b14b8395-fcc6-422b-8f21-d0c00a4d0e8b'
    Author = 'Michel Braga Guimaraes'
    CompanyName = 'Independent'
    Description = 'PowerShell module to activate and monitor PIM role assignments using Microsoft Graph.'
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    RequiredModules = @('Microsoft.Graph')
    FunctionsToExport = @('Get-PimRoleStatus', 'Enable-PimRole', 'Show-PimEligibleRoles', 'Get-PimRoleAssignment')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{}
}
