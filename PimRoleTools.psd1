@{
    RootModule = 'PimRoleTools.psm1'
    ModuleVersion = '2.0.0'
    GUID = 'b14b8395-fcc6-422b-8f21-d0c00a4d0e8b'
    Author = 'Mike Guimaraes'
    CompanyName = 'Independent'
    Copyright = '(c) Mike Guimaraes. All rights reserved.'
    Description = 'PowerShell module for managing Azure AD (Entra ID) and Group Privileged Identity Management (PIM) roles. Supports role activation, monitoring, and management with an enhanced user experience.'
    PowerShellVersion = '7.1'
    CompatiblePSEditions = @('Core')
    RequiredModules = @(
        @{ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0'}
        @{ModuleName = 'Microsoft.Graph.Identity.Governance'; ModuleVersion = '2.0.0'}
        @{ModuleName = 'Microsoft.Graph.Identity.SignIns'; ModuleVersion = '2.0.0'}
        @{ModuleName = 'Microsoft.Graph.Users'; ModuleVersion = '2.0.0'}
        @{ModuleName = 'Microsoft.Graph.Groups'; ModuleVersion = '2.0.0'}
    )
    FunctionsToExport = @(
        # Connection
        'Connect-PimGraph',
        
        # Azure AD/Entra ID
        'Get-PimRole',
        'Enable-PimRole',
        'Disable-PimRole',
        'Show-PimRole',
        
        
        # Groups
        'Get-PimGroupRole',
        'Enable-PimGroupRole',
        
        # Summary
        'Get-PimSummary'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('PIM', 'PrivilegedIdentityManagement', 'Azure', 'AzureAD', 'EntraID', 'Security', 'RBAC', 'Governance')
            ProjectUri = 'https://github.com/mguimaraes/PimRoleTools'
            LicenseUri = 'https://github.com/mguimaraes/PimRoleTools/blob/main/LICENSE'
            RequireLicenseAcceptance = $false
            ReleaseNotes = @'
# Version 2.0.0
## Major Features
- Complete rewrite with enhanced functionality and user experience
- Added support for PIM group memberships
- New comprehensive summary view with Get-PimSummary
- Enhanced error handling and visual feedback

## New Functions
- Connect-PimGraph: Dedicated connection management with automatic scope handling
- Get-PimGroupRole: List PIM group assignments (member/owner)
- Enable-PimGroupRole: Activate PIM group membership
- Disable-PimRole: Deactivate active Azure AD roles
- Get-PimSummary: Comprehensive overview of all PIM assignments

## Improvements
- Color-coded output with emoji indicators for better readability
- Support for wildcards in role name searches
- Real-time remaining duration calculations with smart formatting
- Animated spinner during role activation with timeout handling
- Enhanced error messages with actionable guidance
- Support for ticket systems and audit information
- Streamlined API calls with better performance

## Focus
- Concentrated on Azure AD/Entra ID and Group PIM for reliable functionality
- Removed Azure Resource PIM due to API limitations (use Azure Portal instead)
'@
        }
    }
}