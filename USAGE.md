# PimRoleTools - Quick Start Guide

## 🚀 Getting Started

### 1. Import the Module
```powershell
Import-Module PimRoleTools
```

### 2. Connect to Microsoft Graph
```powershell
Connect-PimGraph
```

### 3. View Your PIM Status
```powershell
# Quick overview of all assignments
Get-PimSummary

# Detailed view including eligible roles
Get-PimSummary -IncludeInactive
```

## 📋 Common Tasks

### Check What Roles You Can Activate
```powershell
# Azure AD roles you're eligible for
Get-PimRole -Status Eligible

# Group memberships you're eligible for
Get-PimGroupRole -Status Eligible
```

### Activate a Role
```powershell
# Azure AD role (e.g., Global Administrator)
Enable-PimRole -RoleName "Global Administrator" -Duration "PT4H"

# Group membership
Enable-PimGroupRole -GroupName "IT Administrators" -AccessLevel Member
```

### Check Active Roles
```powershell
# See all your active assignments
Get-PimSummary

# Check specific Azure AD role
Get-PimRole -Status Active -RoleName "Global Administrator"

# Check specific group membership
Get-PimGroupRole -Status Active -GroupName "IT Administrators"
```

### Deactivate a Role
```powershell
# Deactivate Azure AD role when done
Disable-PimRole -RoleName "Global Administrator"
```

### Get Detailed Role Information
```powershell
# Show comprehensive role details
Show-PimRole -RoleName "Global Administrator"
```

## 💡 Pro Tips

1. **Use Tab Completion**: Most parameters support tab completion
   ```powershell
   Get-PimRole -Status <TAB>  # Cycles through: Active, Eligible, Permanent, All
   ```

2. **Wildcards Work**: Find roles using patterns
   ```powershell
   Get-PimRole -RoleName "*Admin*"
   Get-PimGroupRole -GroupName "*IT*"
   ```

3. **Check Expiring Roles**: See what's about to expire
   ```powershell
   Get-PimRole -Status Active | Where-Object { $_.TimeRemaining.TotalHours -lt 1 }
   ```

4. **Batch Activation**: Activate multiple roles
   ```powershell
   @("Security Administrator", "Application Administrator") | ForEach-Object {
       Enable-PimRole -RoleName $_ -Duration "PT2H"
   }
   ```

5. **Monitor All Active Assignments**: Keep track of what's active
   ```powershell
   # Show active assignments with time remaining
   Get-PimSummary | Format-Table -AutoSize
   ```

## 🕐 Duration Examples
- `PT30M` = 30 minutes
- `PT1H` = 1 hour
- `PT4H` = 4 hours
- `PT8H` = 8 hours (default)

## 🎯 Focus Areas
This module focuses on:
- ✅ **Azure AD/Entra ID PIM**: Fully supported with all features
- ✅ **Group PIM**: Complete member/owner role management
- ℹ️  **Azure Resource PIM**: Use Azure Portal (API limitations)

## ❓ Need Help?
```powershell
# Get detailed help for any command
Get-Help Enable-PimRole -Full
Get-Help Get-PimGroupRole -Examples

# List all available commands
Get-Command -Module PimRoleTools
```