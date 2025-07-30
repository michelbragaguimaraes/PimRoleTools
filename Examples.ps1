<#
.SYNOPSIS
    Example usage of PimRoleTools module
.DESCRIPTION
    This script demonstrates various use cases for the PimRoleTools module
.AUTHOR
    Mike Guimaraes
#>

# Import the module
Import-Module PimRoleTools -Force

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "     PimRoleTools Usage Examples        " -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan

# Example 1: Connect to Microsoft Graph
Write-Host "`n1. Connecting to Microsoft Graph..." -ForegroundColor Yellow
Connect-PimGraph

# Example 2: Get all PIM assignments summary
Write-Host "`n2. Getting complete PIM summary..." -ForegroundColor Yellow
Get-PimSummary -IncludeInactive

# Example 3: List Azure AD PIM roles
Write-Host "`n3. Listing Azure AD PIM roles..." -ForegroundColor Yellow
$aadRoles = Get-PimRole
$aadRoles | Format-Table RoleName, Status, TimeRemaining -AutoSize

# Example 4: Show detailed information for a specific role
Write-Host "`n4. Showing detailed role information..." -ForegroundColor Yellow
Show-PimRole -RoleName "Global Administrator"

# Example 5: Activate an eligible role (commented out to prevent accidental activation)
Write-Host "`n5. Example: Activating a role (commented out)..." -ForegroundColor Yellow
Write-Host @'
# Enable-PimRole -RoleName "User Administrator" `
#     -Duration "PT2H" `
#     -Justification "User management tasks" `
#     -TicketNumber "TICKET-12345" `
#     -TicketSystem "ServiceNow"
'@ -ForegroundColor Gray

# Example 6: List Azure Resource roles
Write-Host "`n6. Listing Azure Resource PIM roles..." -ForegroundColor Yellow
$resourceRoles = Get-PimResourceRole
if ($resourceRoles) {
    $resourceRoles | Format-Table ResourceName, RoleName, Status -AutoSize
} else {
    Write-Host "   No Azure Resource PIM roles found" -ForegroundColor Gray
}

# Example 7: List PIM group assignments
Write-Host "`n7. Listing PIM group assignments..." -ForegroundColor Yellow
$groupRoles = Get-PimGroupRole
if ($groupRoles) {
    $groupRoles | Format-Table GroupName, AccessLevel, Status -AutoSize
} else {
    Write-Host "   No PIM group assignments found" -ForegroundColor Gray
}

# Example 8: Find specific eligible roles
Write-Host "`n8. Finding eligible admin roles..." -ForegroundColor Yellow
$eligibleAdminRoles = Get-PimRole -Status Eligible -RoleName "*Admin*"
if ($eligibleAdminRoles) {
    Write-Host "   You are eligible for the following admin roles:" -ForegroundColor Green
    $eligibleAdminRoles | ForEach-Object {
        Write-Host "   - $($_.RoleName)" -ForegroundColor White
    }
} else {
    Write-Host "   No eligible admin roles found" -ForegroundColor Gray
}

# Example 9: Check for expiring roles
Write-Host "`n9. Checking for roles expiring soon..." -ForegroundColor Yellow
$activeRoles = Get-PimRole -Status Active
$expiringRoles = $activeRoles | Where-Object { 
    $_.TimeRemaining -and $_.TimeRemaining.TotalHours -lt 1 
}
if ($expiringRoles) {
    Write-Host "   ⚠️  The following roles expire within 1 hour:" -ForegroundColor Red
    $expiringRoles | ForEach-Object {
        Write-Host "   - $($_.RoleName): $(Format-TimeRemaining $_.TimeRemaining)" -ForegroundColor Yellow
    }
} else {
    Write-Host "   No roles expiring within the next hour" -ForegroundColor Green
}

# Example 10: Batch operations (commented out)
Write-Host "`n10. Example: Batch role activation (commented out)..." -ForegroundColor Yellow
Write-Host @'
# $rolesToActivate = @("Security Administrator", "Application Administrator")
# $rolesToActivate | ForEach-Object {
#     Enable-PimRole -RoleName $_ `
#         -Duration "PT4H" `
#         -Justification "Monthly security audit"
#     Start-Sleep -Seconds 5  # Avoid rate limiting
# }
'@ -ForegroundColor Gray

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "        Examples Completed              " -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nFor more information, see the README.md file or run:" -ForegroundColor Gray
Write-Host "Get-Help <CommandName> -Full" -ForegroundColor White