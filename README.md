# PimRoleTools

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/PimRoleTools?color=blue)](https://www.powershellgallery.com/packages/PimRoleTools)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/PimRoleTools?color=green)](https://www.powershellgallery.com/packages/PimRoleTools)

## Overview
PimRoleTools is a focused PowerShell module for managing Privileged Identity Management (PIM) across Azure AD (Entra ID) and Groups. It provides a clean, reliable interface to:

- 🛡️ **Azure AD/Entra ID Roles**: List, activate, deactivate, and manage directory roles
- 👥 **Group Memberships**: Handle PIM-enabled group assignments (member/owner)
- 📊 **Unified Summary**: Get a complete overview of all PIM assignments
- 🎨 **Enhanced UX**: Color-coded output, progress indicators, and smart formatting

## 🚀 Key Features
- **Focused & Reliable**: Azure AD and Group PIM support with consistent API availability
- **Smart Activation**: Animated progress indicators and automatic status checking
- **Enhanced UX**: Color-coded output, emoji indicators, and formatted tables
- **Flexible Filtering**: Search by name, status, type with wildcard support
- **Time Tracking**: Real-time remaining duration calculations with smart formatting
- **Ticket Integration**: Support for ticket systems and audit trails
- **Robust Error Handling**: Clear error messages with actionable guidance

## 📋 Prerequisites
- **PowerShell 7.1 or higher** (Windows, macOS, or Linux)
- **Microsoft Graph PowerShell SDK v2.0+**
  ```powershell
  Install-Module Microsoft.Graph -Scope CurrentUser
  ```
- **Azure AD PIM** enabled in your tenant
- **Appropriate permissions** to manage PIM roles

## 📦 Installation

### From PowerShell Gallery (Recommended)
```powershell
Install-Module -Name PimRoleTools -Scope CurrentUser
```

### Manual Installation
```powershell
# Clone the repository
git clone https://github.com/michelbragaguimaraes/PimRoleTools.git

# Import the module
Import-Module ./PimRoleTools/PimRoleTools.psm1
```

## 🔐 Authentication
The module handles authentication automatically. On first use, you'll be prompted to sign in:

```powershell
# Connect with all required permissions
Connect-PimGraph

# Force reconnection if needed
Connect-PimGraph -ForceReconnect
```

## 📖 Usage Guide

### Azure AD/Entra ID Roles

#### List all your PIM roles
```powershell
# All roles
Get-PimRole

# Only eligible roles
Get-PimRole -Status Eligible

# Only active roles with details
Get-PimRole -Status Active -IncludeDetails

# Filter by name (supports wildcards)
Get-PimRole -RoleName "*Admin*"
```

#### Activate an eligible role
```powershell
# Basic activation (8 hours default)
Enable-PimRole -RoleName "Global Administrator"

# Custom duration and justification
Enable-PimRole -RoleName "User Administrator" -Duration "PT4H" -Justification "User onboarding tasks"

# With ticket information
Enable-PimRole -RoleName "Security Administrator" `
    -Duration "PT2H" `
    -Justification "Security incident response" `
    -TicketNumber "INC001234" `
    -TicketSystem "ServiceNow"

# Activate without waiting
Enable-PimRole -RoleName "Application Administrator" -NoWait
```

#### Deactivate an active role
```powershell
# Interactive deactivation
Disable-PimRole -RoleName "Global Administrator"

# Force deactivation without confirmation
Disable-PimRole -RoleName "Global Administrator" -Force
```

#### Show detailed role information
```powershell
Show-PimRole -RoleName "Global Administrator"
```


### Group Memberships

#### List PIM group assignments
```powershell
# All group assignments
Get-PimGroupRole

# Filter by status
Get-PimGroupRole -Status Eligible

# Filter by access level
Get-PimGroupRole -AccessLevel Owner

# Search by group name
Get-PimGroupRole -GroupName "*Admins*"
```

#### Activate group membership
```powershell
# Activate as member
Enable-PimGroupRole -GroupName "IT Administrators" -AccessLevel Member

# Activate as owner with custom duration
Enable-PimGroupRole `
    -GroupName "Security Team" `
    -AccessLevel Owner `
    -Duration "PT6H" `
    -Justification "Security review meeting"
```

### Comprehensive Summary

#### Get complete PIM overview
```powershell
# Show all active assignments
Get-PimSummary

# Include eligible assignments
Get-PimSummary -IncludeInactive
```

## 📊 Output Examples

### Get-PimRole Output
```
RoleName                    Status    StartTime           EndTime             TimeRemaining
--------                    ------    ---------           -------             -------------
Global Administrator        Active    12/1/2023 9:00 AM   12/1/2023 5:00 PM  4h 32m
User Administrator          Eligible  -                   -                   -
Application Administrator   Permanent -                   -                   -
```

### Get-PimSummary Output
```
═══════════════════════════════════════════════════════════════
                    PIM ASSIGNMENT SUMMARY
═══════════════════════════════════════════════════════════════

▶ Azure AD (Entra ID) Roles:
Role                         Status      Time Remaining
----                         ------      --------------
Global Administrator         Active      4h 32m
Security Administrator       Active      2h 15m


▶ Group Memberships:
Group                  Access    Status    Time Remaining
-----                  ------    ------    --------------
IT Administrators      member    Active    3h 20m
Security Team          owner     Eligible  -
```

## 🕒 Duration Formats
Duration must be in ISO 8601 format:
- `PT30M` - 30 minutes
- `PT1H` - 1 hour
- `PT4H30M` - 4 hours 30 minutes
- `PT8H` - 8 hours (default)

## 🔧 Advanced Usage

### Batch Operations
```powershell
# Activate multiple roles
@("Global Administrator", "Security Administrator") | ForEach-Object {
    Enable-PimRole -RoleName $_ -Duration "PT2H" -Justification "Monthly security review"
}

# Check all eligible roles
Get-PimRole -Status Eligible | ForEach-Object {
    Write-Host "Eligible for: $($_.RoleName)"
}
```

### Scheduled Activation
```powershell
# Create a scheduled task for role activation
$action = {
    Import-Module PimRoleTools
    Enable-PimRole -RoleName "Global Administrator" -Duration "PT1H" -Justification "Automated maintenance"
}

# Register scheduled job (example)
Register-ScheduledJob -Name "PIMActivation" -ScriptBlock $action -Trigger (New-JobTrigger -At 3am -Daily)
```

## 🐛 Troubleshooting

### Module Import Issues
```powershell
# Check module is installed
Get-Module -ListAvailable PimRoleTools

# Force reload
Remove-Module PimRoleTools -Force -ErrorAction SilentlyContinue
Import-Module PimRoleTools -Force

# Verify requirements
Get-Module Microsoft.Graph* -ListAvailable
```

### Authentication Problems
```powershell
# Clear existing sessions
Disconnect-MgGraph
Connect-PimGraph -ForceReconnect

# Check current context
Get-MgContext | Format-List
```

### Common Issues
- **"No eligible roles found"**: Verify you have PIM assignments in Azure Portal
- **"Failed to activate role"**: Check if role requires approval or has additional policies
- **Missing permissions**: Ensure your account has the necessary Graph API permissions
- **Module not found**: Install from PowerShell Gallery or check installation path

## 🤝 Contributing
Contributions are welcome! Please feel free to submit issues or pull requests on [GitHub](https://github.com/michelbragaguimaraes/PimRoleTools).

## 📜 License
MIT License - see LICENSE file for details

## ✍️ Author
Mike Guimaraes

## 🔗 Links
- [PowerShell Gallery](https://www.powershellgallery.com/packages/PimRoleTools)
- [GitHub Repository](https://github.com/michelbragaguimaraes/PimRoleTools)
- [Report Issues](https://github.com/michelbragaguimaraes/PimRoleTools/issues)

## 📝 Change Log

### Version 2.0.0
- Complete rewrite with enhanced functionality and user experience
- Added Group PIM support for member/owner role activation
- New unified summary view with Get-PimSummary
- Enhanced visual feedback with colors, emojis, and progress indicators
- Improved error handling with actionable guidance
- Support for ticket systems and audit trails
- Focused approach on reliable Azure AD and Group PIM functionality

### Version 1.0.2
- Initial release
- Basic Azure AD PIM support
