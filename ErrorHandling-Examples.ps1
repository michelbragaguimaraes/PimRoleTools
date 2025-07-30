<#
.SYNOPSIS
    Examples of enhanced error handling in PimRoleTools
.DESCRIPTION
    Demonstrates how the module now handles common error scenarios gracefully
.AUTHOR
    Mike Guimaraes
#>

Write-Host "🔧 PimRoleTools - Error Handling Examples" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`n📋 Scenario 1: User Interruption (Ctrl+C) Handling" -ForegroundColor Yellow
Write-Host "When activating a role, if you press Ctrl+C, the module will:" -ForegroundColor Gray
Write-Host "• Show a user-friendly message" -ForegroundColor Gray
Write-Host "• Explain that the role may still be activating" -ForegroundColor Gray
Write-Host "• Provide guidance on how to check status" -ForegroundColor Gray

Write-Host "`nExample:" -ForegroundColor White
Write-Host @'
Enable-PimRole -RoleName "Security Administrator"
# Press Ctrl+C during activation...
# Output:
# ⚠️  Activation monitoring interrupted by user
#    The role may still be activating in the background.
#    Use 'Get-PimRole -Status Active' to check status.
'@ -ForegroundColor Gray

Write-Host "`n📋 Scenario 2: 5-Minute Deactivation Rule" -ForegroundColor Yellow
Write-Host "Azure AD requires roles to be active for at least 5 minutes before deactivation." -ForegroundColor Gray

Write-Host "`nExample of early deactivation attempt:" -ForegroundColor White
Write-Host @'
Disable-PimRole -RoleName "Security Administrator"
# If activated less than 5 minutes ago:
# ⏳ Role must be active for at least 5 minutes before deactivation
#    Time remaining: 3m 45s
#    The role will auto-expire at: 7/30/2025 6:00:00 PM
'@ -ForegroundColor Gray

Write-Host "`n📋 Scenario 3: Proactive Duration Check" -ForegroundColor Yellow
Write-Host "The module now checks activation time before attempting deactivation." -ForegroundColor Gray

# Function to demonstrate the improved error handling
function Test-PimErrorHandling {
    param(
        [string]$RoleName = "Security Administrator"
    )
    
    Write-Host "`n🧪 Testing Error Handling for: $RoleName" -ForegroundColor Cyan
    
    # Check if role is active
    $activeRole = Get-PimRole -Status Active -RoleName $RoleName -ErrorAction SilentlyContinue
    
    if ($activeRole -and $activeRole.StartTime) {
        $activeDuration = (Get-Date) - $activeRole.StartTime
        $remainingTime = [TimeSpan]::FromMinutes(5) - $activeDuration
        
        if ($activeDuration.TotalMinutes -lt 5) {
            Write-Host "✅ Role is active but within 5-minute window" -ForegroundColor Green
            Write-Host "   Active for: $(Format-TimeRemaining $activeDuration)" -ForegroundColor Gray
            Write-Host "   Wait time remaining: $(Format-TimeRemaining $remainingTime)" -ForegroundColor Gray
            Write-Host "   Can deactivate after: $($activeRole.StartTime.AddMinutes(5))" -ForegroundColor Gray
        } else {
            Write-Host "✅ Role is active and can be deactivated" -ForegroundColor Green
            Write-Host "   Active for: $(Format-TimeRemaining $activeDuration)" -ForegroundColor Gray
        }
    } elseif ($activeRole) {
        Write-Host "⚠️  Role is active but start time unknown" -ForegroundColor Yellow
        Write-Host "   You can try deactivating, but it may fail if too recent" -ForegroundColor Gray
    } else {
        Write-Host "ℹ️  Role is not currently active" -ForegroundColor Cyan
    }
}

Write-Host "`n📋 Scenario 4: Smart Deactivation Check" -ForegroundColor Yellow
Test-PimErrorHandling -RoleName "Security Administrator"

Write-Host "`n📋 Scenario 5: Network or API Errors" -ForegroundColor Yellow
Write-Host "The module handles various API errors gracefully:" -ForegroundColor Gray
Write-Host "• Connection timeouts" -ForegroundColor Gray
Write-Host "• Rate limiting" -ForegroundColor Gray  
Write-Host "• Permission errors" -ForegroundColor Gray
Write-Host "• Service unavailable errors" -ForegroundColor Gray

Write-Host "`n💡 Best Practices:" -ForegroundColor Green
Write-Host "1. Always check role status before deactivation:" -ForegroundColor White
Write-Host "   Get-PimRole -Status Active -RoleName 'Role Name'" -ForegroundColor Gray

Write-Host "`n2. Use -NoWait for batch operations to avoid interruptions:" -ForegroundColor White
Write-Host "   Enable-PimRole -RoleName 'Security Administrator' -NoWait" -ForegroundColor Gray

Write-Host "`n3. If activation is interrupted, check status manually:" -ForegroundColor White
Write-Host "   Get-PimSummary" -ForegroundColor Gray

Write-Host "`n4. Wait at least 5 minutes before deactivating roles:" -ForegroundColor White
Write-Host "   Show-PimRole -RoleName 'Role Name'  # Check start time" -ForegroundColor Gray

Write-Host "`n🎯 The module now provides:" -ForegroundColor Cyan
Write-Host "✅ Graceful handling of user interruptions" -ForegroundColor Green
Write-Host "✅ Smart validation of Azure AD PIM rules" -ForegroundColor Green  
Write-Host "✅ Clear error messages with actionable guidance" -ForegroundColor Green
Write-Host "✅ Robust error recovery and status checking" -ForegroundColor Green

Write-Host "`n═══════════════════════════════════════════" -ForegroundColor Cyan