#Requires -Version 7.1
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Identity.Governance, Microsoft.Graph.Identity.SignIns

<#
.SYNOPSIS
    PimRoleTools - Enhanced PowerShell module for Azure AD and Azure Resource PIM management
.DESCRIPTION
    This module provides comprehensive tools for managing Privileged Identity Management (PIM) roles
    in both Azure AD (Entra ID) and Azure Resources. It simplifies role activation, monitoring,
    and management tasks.
.AUTHOR
    Mike Guimaraes
.VERSION
    2.0.0
#>

# Module-level variables
$script:ModuleName = 'PimRoleTools'
$script:RequiredScopes = @(
    'RoleManagement.ReadWrite.Directory',
    'PrivilegedAccess.ReadWrite.AzureAD',
    'PrivilegedAccess.ReadWrite.AzureResources',
    'PrivilegedAccess.ReadWrite.AzureADGroup',
    'Directory.Read.All',
    'User.Read'
)

#region Helper Functions

function Test-GraphConnection {
    <#
    .SYNOPSIS
        Verifies Microsoft Graph connection and required permissions
    #>
    [CmdletBinding()]
    param()
    
    $context = Get-MgContext
    if (-not $context) {
        Write-Verbose "No active Microsoft Graph connection found"
        return $false
    }
    
    # Check if we have the required scopes
    $missingScopes = $script:RequiredScopes | Where-Object { $_ -notin $context.Scopes }
    if ($missingScopes) {
        Write-Warning "Missing required scopes: $($missingScopes -join ', ')"
        return $false
    }
    
    return $true
}

function Connect-PimGraph {
    <#
    .SYNOPSIS
        Establishes connection to Microsoft Graph with required PIM scopes
    #>
    [CmdletBinding()]
    param(
        [switch]$ForceReconnect
    )
    
    if (-not $ForceReconnect -and (Test-GraphConnection)) {
        Write-Verbose "Already connected to Microsoft Graph with required permissions"
        return
    }
    
    try {
        Connect-MgGraph -Scopes $script:RequiredScopes -NoWelcome
        Write-Host "✅ Connected to Microsoft Graph successfully" -ForegroundColor Green
    }
    catch {
        throw "Failed to connect to Microsoft Graph: $_"
    }
}

function Format-Duration {
    <#
    .SYNOPSIS
        Formats ISO 8601 duration to human-readable format
    #>
    param(
        [string]$Duration
    )
    
    if ([string]::IsNullOrEmpty($Duration)) {
        return "N/A"
    }
    
    try {
        $timespan = [System.Xml.XmlConvert]::ToTimeSpan($Duration)
        $parts = @()
        
        if ($timespan.Days -gt 0) { $parts += "$($timespan.Days) day$(if($timespan.Days -ne 1){'s'})" }
        if ($timespan.Hours -gt 0) { $parts += "$($timespan.Hours) hour$(if($timespan.Hours -ne 1){'s'})" }
        if ($timespan.Minutes -gt 0) { $parts += "$($timespan.Minutes) minute$(if($timespan.Minutes -ne 1){'s'})" }
        
        return $parts -join ', '
    }
    catch {
        return $Duration
    }
}

function Format-TimeRemaining {
    <#
    .SYNOPSIS
        Formats remaining time in a human-readable format
    #>
    param(
        [nullable[TimeSpan]]$TimeSpan
    )
    
    if (-not $TimeSpan -or $TimeSpan.TotalSeconds -le 0) {
        return "Expired"
    }
    
    $parts = @()
    
    if ($TimeSpan.Days -gt 0) { 
        $parts += "$($TimeSpan.Days)d" 
    }
    if ($TimeSpan.Hours -gt 0) { 
        $parts += "$($TimeSpan.Hours)h" 
    }
    if ($TimeSpan.Minutes -gt 0) { 
        $parts += "$($TimeSpan.Minutes)m" 
    }
    
    if ($parts.Count -eq 0 -and $TimeSpan.Seconds -gt 0) {
        $parts += "$($TimeSpan.Seconds)s"
    }
    
    return $parts -join ' '
}

function Show-ActivationSpinner {
    <#
    .SYNOPSIS
        Shows a spinner animation while waiting for role activation
    #>
    param(
        [string]$RoleName,
        [scriptblock]$CheckActivation,
        [int]$MaxWaitSeconds = 300
    )
    
    $spinner = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
    $i = 0
    $startTime = Get-Date
    
    Write-Host -NoNewline "Waiting for activation of '$RoleName' "
    
    try {
        do {
            $elapsed = (Get-Date) - $startTime
            if ($elapsed.TotalSeconds -gt $MaxWaitSeconds) {
                Write-Host ("`r" + " " * 80)  # Clear the line
                Write-Host "`r❌ Activation timeout after $MaxWaitSeconds seconds" -ForegroundColor Red
                return $false
            }
            
            Write-Host -NoNewline ("`r" + $spinner[$i % $spinner.Length] + " Waiting... ($([int]$elapsed.TotalSeconds)s)")
            $i++
            
            Start-Sleep -Milliseconds 500
            
            $isActive = & $CheckActivation
        } while (-not $isActive)
        
        # Clear the spinner line completely and show success message
        Write-Host ("`r" + " " * 80)  # Clear the line
        Write-Host "`r✅ Role '$RoleName' is now active!" -ForegroundColor Green
        return $true
    }
    catch {
        # Handle Ctrl+C or other interruptions
        if ($_.Exception.Message -like "*interrupted*" -or $_.CategoryInfo.Category -eq 'OperationStopped') {
            Write-Host ("`r" + " " * 80)  # Clear the line
            Write-Host "`r⚠️  Activation monitoring interrupted by user" -ForegroundColor Yellow
            Write-Host "   The role may still be activating in the background." -ForegroundColor Gray
            Write-Host "   Use 'Get-PimRole -Status Active' to check status." -ForegroundColor Gray
            return $false
        }
        else {
            Write-Host ("`r" + " " * 80)  # Clear the line
            Write-Host "`r❌ Error during activation monitoring: $_" -ForegroundColor Red
            return $false
        }
    }
}

#endregion

#region Azure AD (Entra ID) PIM Functions

function Get-PimRole {
    <#
    .SYNOPSIS
        Gets all PIM role assignments for the current user (Azure AD/Entra ID)
    .DESCRIPTION
        Lists all Azure AD PIM roles (active, eligible, permanent) for the current user with detailed status information
    .PARAMETER RoleName
        Filter by specific role name
    .PARAMETER Status
        Filter by status: Active, Eligible, Permanent, or All (default)
    .PARAMETER IncludeDetails
        Include additional details like role description and permissions
    .EXAMPLE
        Get-PimRole
        Lists all PIM roles for the current user
    .EXAMPLE
        Get-PimRole -Status Active
        Lists only currently active PIM roles
    .EXAMPLE
        Get-PimRole -RoleName "Global Administrator" -IncludeDetails
        Shows detailed information for the Global Administrator role
    #>
    [CmdletBinding()]
    param(
        [string]$RoleName,
        
        [ValidateSet('Active', 'Eligible', 'Permanent', 'All')]
        [string]$Status = 'All',
        
        [switch]$IncludeDetails
    )
    
    Connect-PimGraph
    
    try {
        $currentUser = Get-MgUser -UserId (Get-MgContext).Account
        $userId = $currentUser.Id
        
        $results = @()
        
        # Get eligible roles
        if ($Status -in 'All', 'Eligible') {
            $eligibleSchedules = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All `
                -Filter "principalId eq '$userId'" -ExpandProperty RoleDefinition
            
            foreach ($schedule in $eligibleSchedules) {
                $results += [PSCustomObject]@{
                    RoleName = $schedule.RoleDefinition.DisplayName
                    RoleId = $schedule.RoleDefinition.Id
                    Status = 'Eligible'
                    StartTime = $null
                    EndTime = $null
                    TimeRemaining = $null
                    DirectoryScopeId = $schedule.DirectoryScopeId
                    MemberType = $schedule.MemberType
                }
            }
        }
        
        # Get active roles
        if ($Status -in 'All', 'Active') {
            $activeSchedules = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -All `
                -Filter "principalId eq '$userId'" -ExpandProperty RoleDefinition,ActivatedUsing
            
            foreach ($schedule in $activeSchedules) {
                $endTime = if ($schedule.EndDateTime) { [DateTime]::Parse($schedule.EndDateTime).ToLocalTime() } else { $null }
                $timeRemaining = if ($endTime) { $endTime - (Get-Date) } else { $null }
                
                $results += [PSCustomObject]@{
                    RoleName = $schedule.RoleDefinition.DisplayName
                    RoleId = $schedule.RoleDefinition.Id
                    Status = 'Active'
                    StartTime = if ($schedule.StartDateTime) { [DateTime]::Parse($schedule.StartDateTime).ToLocalTime() } else { $null }
                    EndTime = $endTime
                    TimeRemaining = $timeRemaining
                    DirectoryScopeId = $schedule.DirectoryScopeId
                    MemberType = $schedule.MemberType
                }
            }
        }
        
        # Get permanent assignments
        if ($Status -in 'All', 'Permanent') {
            $permanentAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All `
                -Filter "principalId eq '$userId'" -ExpandProperty RoleDefinition
            
            foreach ($assignment in $permanentAssignments) {
                # Check if this is not already in active (to avoid duplicates)
                $isDuplicate = $results | Where-Object { 
                    $_.RoleId -eq $assignment.RoleDefinition.Id -and 
                    $_.Status -eq 'Active' 
                }
                
                if (-not $isDuplicate) {
                    $results += [PSCustomObject]@{
                        RoleName = $assignment.RoleDefinition.DisplayName
                        RoleId = $assignment.RoleDefinition.Id
                        Status = 'Permanent'
                        StartTime = $null
                        EndTime = $null
                        TimeRemaining = $null
                        DirectoryScopeId = $assignment.DirectoryScopeId
                        MemberType = 'Direct'
                    }
                }
            }
        }
        
        # Filter by role name if specified
        if ($RoleName) {
            $results = $results | Where-Object { $_.RoleName -like "*$RoleName*" }
        }
        
        # Add details if requested
        if ($IncludeDetails -and $results) {
            foreach ($result in $results) {
                $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $result.RoleId
                $result | Add-Member -NotePropertyName Description -NotePropertyValue $roleDefinition.Description
                $result | Add-Member -NotePropertyName IsBuiltIn -NotePropertyValue $roleDefinition.IsBuiltIn
            }
        }
        
        # Sort results
        $results | Sort-Object Status, RoleName
    }
    catch {
        Write-Error "Failed to retrieve PIM roles: $_"
    }
}

function Enable-PimRole {
    <#
    .SYNOPSIS
        Activates an eligible PIM role for the current user (Azure AD/Entra ID)
    .DESCRIPTION
        Activates an eligible Azure AD PIM role with optional duration, justification, and ticket information
    .PARAMETER RoleName
        The name of the role to activate (supports wildcards)
    .PARAMETER Duration
        ISO 8601 duration (default: PT8H). Examples: PT4H (4 hours), PT30M (30 minutes)
    .PARAMETER Justification
        Reason for activation
    .PARAMETER TicketNumber
        Optional ticket number for auditing
    .PARAMETER TicketSystem
        Optional ticket system name
    .PARAMETER NoWait
        Don't wait for activation to complete
    .EXAMPLE
        Enable-PimRole -RoleName "Global Administrator"
        Activates the Global Administrator role for 8 hours
    .EXAMPLE
        Enable-PimRole -RoleName "User Admin*" -Duration PT4H -Justification "User management tasks"
        Activates a role matching "User Admin*" for 4 hours
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$RoleName,
        
        [string]$Duration = "PT8H",
        
        [string]$Justification,
        
        [string]$TicketNumber,
        
        [string]$TicketSystem,
        
        [switch]$NoWait
    )
    
    Connect-PimGraph
    
    # Find eligible role
    $eligibleRoles = Get-PimRole -Status Eligible -RoleName $RoleName
    
    if (-not $eligibleRoles) {
        Write-Error "No eligible roles found matching '$RoleName'"
        return
    }
    
    if ($eligibleRoles.Count -gt 1) {
        Write-Host "Multiple eligible roles found matching '$RoleName':" -ForegroundColor Yellow
        $eligibleRoles | Format-Table RoleName, DirectoryScopeId -AutoSize
        Write-Error "Please specify a more specific role name"
        return
    }
    
    $role = $eligibleRoles[0]
    
    # Set default justification if not provided
    if (-not $Justification) {
        $Justification = "Activating $($role.RoleName) for administrative tasks"
    }
    
    if ($PSCmdlet.ShouldProcess($role.RoleName, "Activate PIM Role")) {
        try {
            $params = @{
                Action = "selfActivate"
                PrincipalId = (Get-MgUser -UserId (Get-MgContext).Account).Id
                RoleDefinitionId = $role.RoleId
                DirectoryScopeId = $role.DirectoryScopeId
                Justification = $Justification
                ScheduleInfo = @{
                    StartDateTime = (Get-Date).ToUniversalTime()
                    Expiration = @{
                        Type = "AfterDuration"
                        Duration = $Duration
                    }
                }
            }
            
            # Add ticket info if provided
            if ($TicketNumber -or $TicketSystem) {
                $params.TicketInfo = @{}
                if ($TicketNumber) { $params.TicketInfo.TicketNumber = $TicketNumber }
                if ($TicketSystem) { $params.TicketInfo.TicketSystem = $TicketSystem }
            }
            
            # Submit activation request
            $request = New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
            
            Write-Host "✅ PIM activation request submitted for '$($role.RoleName)'" -ForegroundColor Green
            Write-Host "   Duration: $(Format-Duration $Duration)" -ForegroundColor Gray
            Write-Host "   Justification: $Justification" -ForegroundColor Gray
            
            # Wait for activation unless -NoWait is specified
            if (-not $NoWait) {
                $checkScript = {
                    try {
                        $activeRoles = Get-PimRole -Status Active -RoleName $role.RoleName
                        $result = ($activeRoles | Where-Object { $_.RoleId -eq $role.RoleId })
                        return [bool]$result
                    }
                    catch {
                        # Return false on error to keep trying
                        return $false
                    }
                }
                
                try {
                    $spinnerResult = Show-ActivationSpinner -RoleName $role.RoleName -CheckActivation $checkScript
                    # Clear any remaining output
                    if (-not $spinnerResult) {
                        Write-Host ""  # Add newline if spinner was interrupted
                    }
                }
                catch {
                    # Handle any interruptions during spinner
                    Write-Host "`n⚠️  Activation monitoring stopped" -ForegroundColor Yellow
                    Write-Host "   Check activation status with: Get-PimRole -Status Active -RoleName '$($role.RoleName)'" -ForegroundColor Gray
                }
            }
        }
        catch {
            Write-Error "Failed to activate role: $_"
        }
    }
}

function Disable-PimRole {
    <#
    .SYNOPSIS
        Deactivates an active PIM role (Azure AD/Entra ID)
    .DESCRIPTION
        Deactivates a currently active Azure AD PIM role assignment
        Note: Azure AD requires roles to be active for at least 5 minutes before deactivation
    .PARAMETER RoleName
        The name of the role to deactivate
    .PARAMETER Force
        Skip confirmation prompt
    .EXAMPLE
        Disable-PimRole -RoleName "Global Administrator"
        Deactivates the Global Administrator role
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$RoleName,
        
        [switch]$Force
    )
    
    Connect-PimGraph
    
    # Find active role
    $activeRoles = Get-PimRole -Status Active -RoleName $RoleName
    
    if (-not $activeRoles) {
        Write-Error "No active roles found matching '$RoleName'"
        return
    }
    
    if ($activeRoles.Count -gt 1) {
        Write-Host "Multiple active roles found matching '$RoleName':" -ForegroundColor Yellow
        $activeRoles | Format-Table RoleName, DirectoryScopeId, TimeRemaining -AutoSize
        Write-Error "Please specify a more specific role name"
        return
    }
    
    $role = $activeRoles[0]
    
    # Check if role has been active for at least 5 minutes
    if ($role.StartTime) {
        $activeDuration = (Get-Date) - $role.StartTime
        if ($activeDuration.TotalMinutes -lt 5) {
            $remainingWait = [TimeSpan]::FromMinutes(5) - $activeDuration
            Write-Host "⏳ Role must be active for at least 5 minutes before deactivation" -ForegroundColor Yellow
            Write-Host "   Time remaining: $(Format-TimeRemaining $remainingWait)" -ForegroundColor Gray
            Write-Host "   The role will auto-expire at: $($role.EndTime)" -ForegroundColor Gray
            return
        }
    }
    
    if ($Force -or $PSCmdlet.ShouldProcess($role.RoleName, "Deactivate PIM Role")) {
        try {
            $params = @{
                Action = "selfDeactivate"
                PrincipalId = (Get-MgUser -UserId (Get-MgContext).Account).Id
                RoleDefinitionId = $role.RoleId
                DirectoryScopeId = $role.DirectoryScopeId
                Justification = "Deactivating role - task completed"
            }
            
            New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
            
            Write-Host "✅ Successfully deactivated '$($role.RoleName)'" -ForegroundColor Green
        }
        catch {
            # Handle specific error cases
            if ($_.Exception.Message -like "*ActiveDurationTooShort*" -or $_.Exception.Message -like "*Miniumum Required is 5 minutes*") {
                Write-Host "⏳ Cannot deactivate: Role must be active for at least 5 minutes" -ForegroundColor Yellow
                Write-Host "   This is an Azure AD PIM requirement for security" -ForegroundColor Gray
                if ($role.EndTime) {
                    Write-Host "   Role will auto-expire at: $($role.EndTime)" -ForegroundColor Gray
                }
            }
            else {
                Write-Error "Failed to deactivate role: $_"
            }
        }
    }
}

function Show-PimRole {
    <#
    .SYNOPSIS
        Shows a detailed summary of a specific PIM role (Azure AD/Entra ID)
    .DESCRIPTION
        Displays comprehensive information about a PIM role assignment including status, timing, and permissions
    .PARAMETER RoleName
        The name of the role to display
    .EXAMPLE
        Show-PimRole -RoleName "Global Administrator"
        Shows detailed information about the Global Administrator role
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RoleName
    )
    
    $roles = Get-PimRole -RoleName $RoleName -IncludeDetails
    
    if (-not $roles) {
        Write-Host "ℹ️  No PIM roles found matching '$RoleName'" -ForegroundColor Yellow
        return
    }
    
    foreach ($role in $roles) {
        Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host "🛡️  Role: $($role.RoleName)" -ForegroundColor White
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        
        # Status with color coding
        $statusColor = switch ($role.Status) {
            'Active' { 'Green' }
            'Eligible' { 'Yellow' }
            'Permanent' { 'Cyan' }
            default { 'White' }
        }
        
        Write-Host "Status        : " -NoNewline
        Write-Host $role.Status -ForegroundColor $statusColor
        
        if ($role.Status -eq 'Active') {
            Write-Host "Start Time    : $($role.StartTime)" -ForegroundColor Gray
            Write-Host "End Time      : $($role.EndTime)" -ForegroundColor Gray
            Write-Host "Time Remaining: " -NoNewline
            
            if ($role.TimeRemaining -and $role.TimeRemaining.TotalMinutes -gt 0) {
                $remainingFormatted = Format-TimeRemaining $role.TimeRemaining
                $warningColor = if ($role.TimeRemaining.TotalMinutes -lt 30) { 'Red' } 
                                elseif ($role.TimeRemaining.TotalHours -lt 1) { 'Yellow' } 
                                else { 'Green' }
                Write-Host $remainingFormatted -ForegroundColor $warningColor
            }
            else {
                Write-Host "Expired" -ForegroundColor Red
            }
        }
        elseif ($role.Status -eq 'Eligible') {
            Write-Host "You are eligible to activate this role" -ForegroundColor Yellow
            Write-Host "Use: Enable-PimRole -RoleName `"$($role.RoleName)`"" -ForegroundColor Gray
        }
        elseif ($role.Status -eq 'Permanent') {
            Write-Host "This is a permanent assignment (always active)" -ForegroundColor Cyan
        }
        
        Write-Host "Directory Scope: $($role.DirectoryScopeId)" -ForegroundColor Gray
        Write-Host "Member Type    : $($role.MemberType)" -ForegroundColor Gray
        
        if ($role.Description) {
            Write-Host "`nDescription:" -ForegroundColor White
            Write-Host $role.Description -ForegroundColor Gray
        }
    }
}

#endregion


#region Group PIM Functions

function Get-PimGroupRole {
    <#
    .SYNOPSIS
        Gets PIM assignments for Azure AD groups
    .DESCRIPTION
        Lists all PIM group memberships (owner/member) for the current user
    .PARAMETER GroupName
        Filter by group name
    .PARAMETER Status
        Filter by status: Active, Eligible, or All (default)
    .PARAMETER AccessLevel
        Filter by access level: Member, Owner, or All (default)
    .EXAMPLE
        Get-PimGroupRole
        Lists all PIM group assignments
    #>
    [CmdletBinding()]
    param(
        [string]$GroupName,
        
        [ValidateSet('Active', 'Eligible', 'All')]
        [string]$Status = 'All',
        
        [ValidateSet('Member', 'Owner', 'All')]
        [string]$AccessLevel = 'All'
    )
    
    Connect-PimGraph
    
    try {
        $currentUser = Get-MgUser -UserId (Get-MgContext).Account
        $results = @()
        
        # Get eligible assignments
        if ($Status -in 'All', 'Eligible') {
            $filter = "principalId eq '$($currentUser.Id)'"
            $eligibleSchedules = Get-MgIdentityGovernancePrivilegedAccessGroupEligibilitySchedule -All -Filter $filter
            
            foreach ($schedule in $eligibleSchedules) {
                if ($AccessLevel -ne 'All' -and $schedule.AccessId -ne $AccessLevel.ToLower()) {
                    continue
                }
                
                # Get group details
                $group = Get-MgGroup -GroupId $schedule.GroupId -ErrorAction SilentlyContinue
                
                if ($GroupName -and $group.DisplayName -notlike "*$GroupName*") {
                    continue
                }
                
                $results += [PSCustomObject]@{
                    GroupName = $group.DisplayName
                    GroupId = $schedule.GroupId
                    AccessLevel = $schedule.AccessId
                    Status = 'Eligible'
                    StartTime = $null
                    EndTime = $null
                    TimeRemaining = $null
                }
            }
        }
        
        # Get active assignments
        if ($Status -in 'All', 'Active') {
            $filter = "principalId eq '$($currentUser.Id)'"
            $activeSchedules = Get-MgIdentityGovernancePrivilegedAccessGroupAssignmentScheduleInstance -All -Filter $filter
            
            foreach ($schedule in $activeSchedules) {
                if ($AccessLevel -ne 'All' -and $schedule.AccessId -ne $AccessLevel.ToLower()) {
                    continue
                }
                
                # Get group details
                $group = Get-MgGroup -GroupId $schedule.GroupId -ErrorAction SilentlyContinue
                
                if ($GroupName -and $group.DisplayName -notlike "*$GroupName*") {
                    continue
                }
                
                $endTime = if ($schedule.EndDateTime) { [DateTime]::Parse($schedule.EndDateTime).ToLocalTime() } else { $null }
                $timeRemaining = if ($endTime) { $endTime - (Get-Date) } else { $null }
                
                $results += [PSCustomObject]@{
                    GroupName = $group.DisplayName
                    GroupId = $schedule.GroupId
                    AccessLevel = $schedule.AccessId
                    Status = 'Active'
                    StartTime = if ($schedule.StartDateTime) { [DateTime]::Parse($schedule.StartDateTime).ToLocalTime() } else { $null }
                    EndTime = $endTime
                    TimeRemaining = $timeRemaining
                }
            }
        }
        
        $results | Sort-Object Status, GroupName, AccessLevel
    }
    catch {
        Write-Error "Failed to retrieve PIM group assignments: $_"
    }
}

function Enable-PimGroupRole {
    <#
    .SYNOPSIS
        Activates eligible PIM group membership
    .DESCRIPTION
        Activates an eligible PIM group membership (owner or member role)
    .PARAMETER GroupName
        The name of the group
    .PARAMETER AccessLevel
        The access level to activate: Member or Owner
    .PARAMETER Duration
        ISO 8601 duration (default: PT8H)
    .PARAMETER Justification
        Reason for activation
    .EXAMPLE
        Enable-PimGroupRole -GroupName "IT Admins" -AccessLevel Member
        Activates member access to the IT Admins group
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$GroupName,
        
        [Parameter(Mandatory)]
        [ValidateSet('Member', 'Owner')]
        [string]$AccessLevel,
        
        [string]$Duration = "PT8H",
        
        [string]$Justification
    )
    
    Connect-PimGraph
    
    # Find the eligible group assignment
    $eligibleGroups = Get-PimGroupRole -GroupName $GroupName -Status Eligible -AccessLevel $AccessLevel
    
    if (-not $eligibleGroups) {
        Write-Error "No eligible $AccessLevel assignment found for group '$GroupName'"
        return
    }
    
    $group = $eligibleGroups[0]
    
    if (-not $Justification) {
        $Justification = "Activating $AccessLevel access to $($group.GroupName)"
    }
    
    if ($PSCmdlet.ShouldProcess("$AccessLevel access to $($group.GroupName)", "Activate PIM Group Assignment")) {
        try {
            $params = @{
                AccessId = $AccessLevel.ToLower()
                PrincipalId = (Get-MgUser -UserId (Get-MgContext).Account).Id
                GroupId = $group.GroupId
                Action = "selfActivate"
                ScheduleInfo = @{
                    StartDateTime = (Get-Date).ToUniversalTime()
                    Expiration = @{
                        Type = "afterDuration"
                        Duration = $Duration
                    }
                }
                Justification = $Justification
            }
            
            $request = New-MgIdentityGovernancePrivilegedAccessGroupAssignmentScheduleRequest -BodyParameter $params
            
            Write-Host "✅ PIM group activation request submitted" -ForegroundColor Green
            Write-Host "   Group: $($group.GroupName)" -ForegroundColor Gray
            Write-Host "   Access Level: $AccessLevel" -ForegroundColor Gray
            Write-Host "   Duration: $(Format-Duration $Duration)" -ForegroundColor Gray
        }
        catch {
            Write-Error "Failed to activate group membership: $_"
        }
    }
}

#endregion

#region Summary Functions

function Get-PimSummary {
    <#
    .SYNOPSIS
        Gets a comprehensive summary of all PIM assignments
    .DESCRIPTION
        Shows a consolidated view of all PIM assignments across Azure AD roles, Azure resources, and groups
    .PARAMETER IncludeInactive
        Include eligible and permanent assignments in addition to active ones
    .EXAMPLE
        Get-PimSummary
        Shows all active PIM assignments
    .EXAMPLE
        Get-PimSummary -IncludeInactive
        Shows all PIM assignments including eligible ones
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeInactive
    )
    
    Connect-PimGraph
    
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                    PIM ASSIGNMENT SUMMARY                      " -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    # Azure AD Roles
    Write-Host "`n▶ Azure AD (Entra ID) Roles:" -ForegroundColor Yellow
    $aadRoles = if ($IncludeInactive) { 
        Get-PimRole 
    } else { 
        Get-PimRole -Status Active 
    }
    
    if ($aadRoles) {
        $aadRoles | Format-Table -Property @(
            @{Label="Role"; Expression={$_.RoleName}; Width=40}
            @{Label="Status"; Expression={$_.Status}; Width=12}
            @{Label="Time Remaining"; Expression={
                if ($_.Status -eq 'Active' -and $_.TimeRemaining) {
                    Format-TimeRemaining $_.TimeRemaining
                } else { '-' }
            }; Width=15}
        ) -AutoSize
    } else {
        Write-Host "   No assignments found" -ForegroundColor Gray
    }
    
    
    # Group Memberships
    Write-Host "`n▶ Group Memberships:" -ForegroundColor Yellow
    $groupRoles = if ($IncludeInactive) { 
        Get-PimGroupRole 
    } else { 
        Get-PimGroupRole -Status Active 
    }
    
    if ($groupRoles) {
        $groupRoles | Format-Table -Property @(
            @{Label="Group"; Expression={$_.GroupName}; Width=40}
            @{Label="Access"; Expression={$_.AccessLevel}; Width=10}
            @{Label="Status"; Expression={$_.Status}; Width=12}
            @{Label="Time Remaining"; Expression={
                if ($_.Status -eq 'Active' -and $_.TimeRemaining) {
                    Format-TimeRemaining $_.TimeRemaining
                } else { '-' }
            }; Width=15}
        ) -AutoSize
    } else {
        Write-Host "   No assignments found" -ForegroundColor Gray
    }
    
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    # Connection
    'Connect-PimGraph'
    
    # Azure AD/Entra ID
    'Get-PimRole'
    'Enable-PimRole'
    'Disable-PimRole'
    'Show-PimRole'
    
    # Groups
    'Get-PimGroupRole'
    'Enable-PimGroupRole'
    
    # Summary
    'Get-PimSummary'
)