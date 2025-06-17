function Show-PimRole {
<#!
.SYNOPSIS
Shows a human-friendly summary of a specific PIM role assignment for the current user.
.DESCRIPTION
Displays the status, start/end time, and time remaining for a given Azure AD PIM role. Uses Get-PimRole internally.
.PARAMETER RoleName
The name of the role to show the status for. Defaults to 'Helpdesk Administrator'.
.EXAMPLE
Show-PimRole -RoleName "Global Administrator"
#>
    [CmdletBinding()]
    param (
        [string]$RoleName = "Helpdesk Administrator"
    )

    $role = Get-PimRole -RoleName $RoleName
    if (-not $role) {
        Write-Host "ℹ️ You do not currently have any assignment for '$RoleName'."
        return
    }

    $r = $role | Select-Object -First 1
    Write-Host "🛡️ Role: $($r.RoleName)"
    Write-Host "Status        : $($r.Status)"
    if ($r.Status -eq 'Active') {
        Write-Host "Start Time    : $($r.StartTime)"
        Write-Host "End Time      : $($r.EndTime)"
        Write-Host "Time Remaining: $($r.TimeRemaining)"
    } elseif ($r.Status -eq 'Permanent') {
        Write-Host "Assignment is permanent or direct, not time-limited."
    } elseif ($r.Status -eq 'Eligible') {
        Write-Host "You are eligible for this role, but it is not currently active."
    }
}

function Enable-PimRole {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$RoleName,

        [string]$Justification = "Enable $RoleName for administrative task",

        [string]$Duration = "PT8H"
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
        # Spinner animation while waiting for activation
        $spinner = @('|','/','-','\')
        $i = 0
        Write-Host -NoNewline "Waiting for activation "
        do {
            Start-Sleep -Seconds 2
            $active = Get-PimRole -Status Active -RoleName $RoleName
            Write-Host -NoNewline ("`b" + $spinner[$i % $spinner.Length])
            $i++
        } while (-not $active)
        Write-Host "`b✔️ Activated!"
    } catch {
        Write-Host "❌ Failed to activate PIM role: $_" -ForegroundColor Red
    }
}

function Get-PimRole {
<#!
.SYNOPSIS
Gets all PIM role assignments for the current user, with status and timing details.
.DESCRIPTION
Lists all Azure AD PIM roles (active, eligible, permanent) for the current user. Can filter by role name and status. Outputs objects for scripting.
.PARAMETER RoleName
Filter by role name.
.PARAMETER Status
Filter by status: Active, Eligible, Permanent, or All (default).
.EXAMPLE
Get-PimRole
.EXAMPLE
Get-PimRole -Status Active
.EXAMPLE
Get-PimRole -RoleName "Global Administrator"
#>
    [CmdletBinding()]
    param (
        [string]$RoleName,
        [ValidateSet('Active','Eligible','Permanent','All')]
        [string]$Status = 'All'
    )

    if (-not (Get-MgContext)) {
        Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "PrivilegedAccess.Read.AzureAD", "Directory.Read.All"
    }

    $currentUserId = (Get-MgUser -UserId (Get-MgContext).Account).Id

    $assignments = Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty RoleDefinition `
        -Filter "principalId eq '$currentUserId'"

    $scheduleInstances = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -All -ExpandProperty RoleDefinition,ActivatedUsing `
        -Filter "principalId eq '$currentUserId'"

    $results = @()
    # Add all active assignments from schedule instances
    foreach ($schedule in $scheduleInstances) {
        $roleName = $schedule.RoleDefinition.DisplayName
        $startTime = $schedule.StartDateTime
        $endTime = $schedule.EndDateTime
        $remaining = $null
        if ($endTime) {
            $remaining = [DateTime]::Parse($endTime).ToLocalTime() - (Get-Date)
        }
        if ($startTime -or $endTime) {
            $results += [PSCustomObject]@{
                RoleName = $roleName
                Status = 'Active'
                StartTime = if ($startTime) { [DateTime]::Parse($startTime).ToLocalTime() } else { $null }
                EndTime = if ($endTime) { [DateTime]::Parse($endTime).ToLocalTime() } else { $null }
                TimeRemaining = $remaining
            }
        } else {
            $results += [PSCustomObject]@{
                RoleName = $roleName
                Status = 'Permanent'
                StartTime = $null
                EndTime = $null
                TimeRemaining = $null
            }
        }
    }
    # Add all assignments (permanent or eligible)
    foreach ($assignment in $assignments) {
        $roleName = $assignment.RoleDefinition.DisplayName
        # Skip if already added as active
        $alreadyActive = $results | Where-Object { $_.RoleName -eq $roleName -and $_.Status -eq 'Active' }
        if ($assignment.ActivatedUsing) {
            if (-not $alreadyActive) {
                $startTime = $assignment.ActivatedUsing.StartDateTime
                $duration = $assignment.ActivatedUsing.Expiration.Duration
                $endTime = $null
                $remaining = $null
                if ($duration) {
                    try {
                        $durationTimespan = [System.Xml.XmlConvert]::ToTimeSpan($duration)
                        $endTime = $startTime.Add($durationTimespan)
                        $remaining = $endTime.ToLocalTime() - (Get-Date)
                    } catch {}
                }
                if ($startTime -or $endTime) {
                    $results += [PSCustomObject]@{
                        RoleName = $roleName
                        Status = 'Active'
                        StartTime = if ($startTime) { [DateTime]::Parse($startTime).ToLocalTime() } else { $null }
                        EndTime = if ($endTime) { [DateTime]::Parse($endTime).ToLocalTime() } else { $null }
                        TimeRemaining = $remaining
                    }
                } else {
                    $results += [PSCustomObject]@{
                        RoleName = $roleName
                        Status = 'Permanent'
                        StartTime = $null
                        EndTime = $null
                        TimeRemaining = $null
                    }
                }
            }
        } elseif ($assignment.AdditionalProperties.Count -eq 0) {
            $results += [PSCustomObject]@{
                RoleName = $roleName
                Status = 'Permanent'
                StartTime = $null
                EndTime = $null
                TimeRemaining = $null
            }
        } else {
            # Only add eligible if not already active or permanent
            $alreadyPermanent = $results | Where-Object { $_.RoleName -eq $roleName -and $_.Status -eq 'Permanent' }
            if (-not $alreadyActive -and -not $alreadyPermanent) {
                $results += [PSCustomObject]@{
                    RoleName = $roleName
                    Status = 'Eligible'
                    StartTime = $null
                    EndTime = $null
                    TimeRemaining = $null
                }
            }
        }
    }
    if ($RoleName) {
        $results = $results | Where-Object { $_.RoleName -eq $RoleName }
    }
    if ($Status -ne 'All') {
        $results = $results | Where-Object { $_.Status -eq $Status }
    }
    $results
}

Export-ModuleMember -Function Show-PimRole, Enable-PimRole, Get-PimRole
