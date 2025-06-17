# PimRoleTools

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/PimRoleTools?color=blue)](https://www.powershellgallery.com/packages/PimRoleTools)

## Overview
PimRoleTools is a PowerShell module for Azure AD Privileged Identity Management (PIM) automation. It allows you to:
- List all your PIM roles (active, eligible, permanent)
- Activate eligible PIM roles
- See activation status and timing
- Script and automate PIM operations

## Installation

### From PowerShell Gallery (Recommended)
```powershell
Install-Module -Name PimRoleTools
```

### Manual Installation
1. Clone or download this repository.
2. Import the module in your PowerShell session:
   ```powershell
   Import-Module ./PimRoleTools.psm1
   ```
3. (Optional) Copy to your PowerShell modules directory for auto-loading:
   ```powershell
   Copy-Item -Path ./PimRoleTools -Destination $env:USERPROFILE\Documents\WindowsPowerShell\Modules\ -Recurse
   ```

## Prerequisites
- **PowerShell 5.1 or 7+** (Windows PowerShell or PowerShell Core)
- **Microsoft.Graph PowerShell module**
  - Install with: `Install-Module Microsoft.Graph -Scope CurrentUser`
- **Azure AD PIM enabled** in your tenant
- **Sufficient permissions** to activate roles (must be eligible for PIM roles)
- **Internet access** (to connect to Microsoft Graph)

## Authentication
The module uses Microsoft Graph authentication. The first time you run a command, you will be prompted to log in:
```powershell
Connect-MgGraph
```
Or, the module will prompt you automatically if not already connected.

## Usage
### List all your PIM roles
```powershell
Get-PimRole
```

### List only eligible roles
```powershell
Get-PimRole -Status Eligible
```

### List only active roles
```powershell
Get-PimRole -Status Active
```

### List only permanent (direct) assignments
```powershell
Get-PimRole -Status Permanent
```

### Filter by role name
```powershell
Get-PimRole -RoleName "Global Administrator"
```

### Show a summary for a specific role
```powershell
Show-PimRole -RoleName "Global Administrator"
```

### Activate a PIM role
```powershell
Enable-PimRole -RoleName "Global Administrator"
```

#### With custom duration and justification
```powershell
Enable-PimRole -RoleName "Global Administrator" -Duration "PT2H" -Justification "Emergency access"
```

#### Activation spinner
After submitting an activation, the module will show a spinner animation and wait until your role is active. When activation is detected, you'll see a checkmark and confirmation.

## Command Reference
### Get-PimRole
- Lists all PIM roles for the current user.
- Parameters:
  - `-RoleName <string>`: Filter by role name
  - `-Status <Active|Eligible|Permanent|All>`: Filter by status
- Output: `[PSCustomObject]` with `RoleName`, `Status`, `StartTime`, `EndTime`, `TimeRemaining`

### Show-PimRole
- Shows a human-friendly summary for a specific role.
- Parameters:
  - `-RoleName <string>`: The role to summarize

### Enable-PimRole
- Activates an eligible PIM role for the current user.
- Parameters:
  - `-RoleName <string>`: The role to activate (required)
  - `-Duration <string>`: ISO8601 duration (default: PT8H)
  - `-Justification <string>`: Reason for activation
- After activation, waits and shows a spinner until the role is active.

## Troubleshooting
- **No eligible roles?**
  - You may already have activated all eligible roles, or you may not be eligible for any roles. Check in the Azure portal.
- **No active roles after activation?**
  - It may take a few seconds for the activation to be processed. The spinner will wait until the role is active.
- **Permanent and active for the same role?**
  - This is possible if you have both a direct assignment and a PIM activation for the same role.
- **Authentication issues?**
  - Run `Connect-MgGraph` manually to re-authenticate.
- **Module not found?**
  - Make sure you imported the module with the correct path, or copied it to your modules directory.

## Examples
```powershell
# List all roles
Get-PimRole

# List only eligible roles
Get-PimRole -Status Eligible

# Activate a role
Enable-PimRole -RoleName "Global Administrator"

# Show a summary for a role
Show-PimRole -RoleName "Global Administrator"
```

## Uninstallation
To remove the module, simply run:
```powershell
Uninstall-Module -Name PimRoleTools
```
Or delete the `PimRoleTools` folder from your modules directory.

## License
MIT

## Author
Michel Braga Guimaraes

## PowerShell Gallery
[PimRoleTools on PowerShell Gallery](https://www.powershellgallery.com/packages/PimRoleTools) 