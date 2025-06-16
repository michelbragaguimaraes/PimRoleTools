function Get-PimRoleStatus {
    [CmdletBinding()]
    param (
        [string]$RoleName = "Global Administrator"
    )

    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "PrivilegedAccess.Read.AzureAD", "Directory.Read.All"
    }

    $currentUserId = (Get-MgUser -UserId (Get-MgContext).Account).Id

    $activeAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty RoleDefinition `
        -Filter "principalId eq '$currentUserId'"

    $targetRole = $activeAssignments | Where-Object {
        $_.RoleDefinition.DisplayName -eq $RoleName
    }

    if ($targetRole) {
        $startTime = $targetRole.ActivatedUsing.StartDateTime
        $duration = $targetRole.ActivatedUsing.Expiration.Duration

        $durationTimespan = [System.Xml.XmlConvert]::ToTimeSpan($duration)
        $endTime = $startTime.Add($durationTimespan)
        $remaining = $endTime - (Get-Date)

        Write-Host "`n🛡️ Role '$RoleName' is Active"
        Write-Host "Start Time     : $startTime UTC"
        Write-Host "End Time       : $endTime UTC"
        Write-Host "Time Remaining : $($remaining.ToString())`n"
    } else {
        Write-Host "ℹ️ You do not currently have an active PIM assignment for '$RoleName'."
    }
}

function Enable-PimRole {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$RoleName,

        [string]$Justification = "Enable $RoleName for administrative task",

        [string]$Duration = "PT4H"
    )

    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory", "PrivilegedAccess.ReadWrite.AzureAD", "Directory.Read.All"
    }

    $currentUserId = (Get-MgUser -UserId (Get-MgContext).Account).Id

    $eligibleRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All -ExpandProperty RoleDefinition `
        -Filter "principalId eq '$currentUserId'"

    $myRole = $eligibleRoles | Where-Object { $_.RoleDefinition.DisplayName -eq $RoleName }

    if (-not $myRole) {
        Write-Host "❌ No eligible PIM assignment found for '$RoleName'." -ForegroundColor Red
        return
    }

    $params = @{
        Action           = "selfActivate"
        PrincipalId      = $myRole.PrincipalId
        RoleDefinitionId = $myRole.RoleDefinitionId
        DirectoryScopeId = $myRole.DirectoryScopeId
        Justification    = $Justification
        ScheduleInfo     = @{
            StartDateTime = (Get-Date).ToUniversalTime()
            Expiration    = @{
                Type     = "AfterDuration"
                Duration = $Duration
            }
        }
    }

    try {
        New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
        Write-Host "✅ PIM activation request submitted for '$RoleName'." -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to activate PIM role: $_" -ForegroundColor Red
    }
}

function Show-PimEligibleRoles {
    [CmdletBinding()]
    param ()

    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "PrivilegedAccess.Read.AzureAD", "Directory.Read.All"
    }

    $currentUserId = (Get-MgUser -UserId (Get-MgContext).Account).Id

    $eligibleRoles = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All -ExpandProperty RoleDefinition `
        -Filter "principalId eq '$currentUserId'"

    if ($eligibleRoles) {
        Write-Host "`n🎯 Eligible PIM Roles:`n" -ForegroundColor Cyan
        $eligibleRoles | Sort-Object { $_.RoleDefinition.DisplayName } | ForEach-Object {
            Write-Host "- $($_.RoleDefinition.DisplayName)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "ℹ️ No eligible PIM roles found for your account." -ForegroundColor Gray
    }
}

Export-ModuleMember -Function Get-PimRoleStatus, Enable-PimRole, Show-PimEligibleRoles
