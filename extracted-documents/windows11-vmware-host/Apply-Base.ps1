#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:ProgramData 'HostBase'
New-Item -Path $root -ItemType Directory -Force | Out-Null
# Logs and reports must not be writable by a standard host user.
& icacls.exe $root /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not protect HostBase log directory.' }
Start-Transcript -Path (Join-Path $root 'Apply-Base.log') -Append | Out-Null
$warnings = [System.Collections.Generic.List[string]]::new()
$changes = [System.Collections.Generic.List[string]]::new()
$restartNeeded = $false
function Set-Dword([string]$Path, [string]$Name, [int]$Value) {
    New-Item -Path $Path -Force | Out-Null
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
}
function Invoke-CheckedNative([string]$File, [string[]]$Arguments) {
    & $File @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$File failed with exit code $LASTEXITCODE." }
}
try {
    if (-not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        throw 'Run using 64-bit Windows PowerShell on the x64 target.'
    }
    $edition = (Get-WindowsEdition -Online).Edition
    $profile = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'HostProfile.json') -Raw | ConvertFrom-Json
    if ($edition -ne $profile.targetEdition) {
        throw "Expected Windows 11 Pro for Workstations (ProfessionalWorkstation); found $edition. Use the matching stock ISO image."
    }
    $os = Get-CimInstance Win32_OperatingSystem
    if ([int]$os.BuildNumber -lt 22000) { throw 'This profile requires Windows 11.' }
    if (@($profile.removeAppx | Where-Object { $_ -in $profile.protectedAppx }).Count -gt 0) {
        throw 'The Appx removal list overlaps protected host dependencies.'
    }
    if (@($profile.disabledServices | Where-Object { $_ -in $profile.requiredServices }).Count -gt 0) {
        throw 'The disabled-service list overlaps a required host dependency.'
    }

    # Preserve stock protected/trigger-start service settings. Never force all services to Automatic.
    foreach ($name in $profile.requiredServices) {
        $service = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $service) { throw "Required stock service missing: $name" }
        if ($service.StartType -eq 'Disabled') { throw "Required service disabled: $name. Repair the stock image before proceeding." }
    }
    Set-Service -Name DiagTrack -StartupType Automatic
    # Start after OOBE if not yet runnable during specialize; do not suppress telemetry endpoints.
    try { Start-Service DiagTrack } catch { $warnings.Add("DiagTrack startup deferred: $($_.Exception.Message)") }

    # The WHP API, not the full Hyper-V management role, is the required VMware interface.
    $whp = Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform
    if ($whp.State -ne 'Enabled') {
        $result = Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart
        $restartNeeded = $restartNeeded -or $result.RestartNeeded
    }
    Invoke-CheckedNative bcdedit.exe @('/set', 'hypervisorlaunchtype', 'auto')
    $dg = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
    Set-Dword $dg 'EnableVirtualizationBasedSecurity' 1
    # Require Secure Boot + DMA protection; unsupported firmware must fail host validation.
    Set-Dword $dg 'RequirePlatformSecurityFeatures' 3
    Set-Dword "$dg\Scenarios\HypervisorEnforcedCodeIntegrity" 'Enabled' 1
    Set-Dword "$dg\Scenarios\HypervisorEnforcedCodeIntegrity" 'Locked' 0
    Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags' 2
    Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'RunAsPPL' 2
    Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config' 'VulnerableDriverBlocklistEnable' 1
    $restartNeeded = $true
    $changes.Add('WHP, VBS/HVCI, Credential Guard and LSA protection configured; runtime validation after reboot is mandatory.')

    # Keep encryption automatic when eligible. Never enroll encryption keys in this file.
    Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker' -Name PreventDeviceEncryption -ErrorAction SilentlyContinue
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 1
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 1
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' -Name ShellSmartScreenLevel -Value 'Block' -PropertyType String -Force | Out-Null
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableCloudOptimizedContent' 1
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'HideFirstRunExperience' 1
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
    Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0
    Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1
    Set-Dword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'EnableLUA' 1
    Set-Dword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'PromptOnSecureDesktop' 1
    Set-Dword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorAdmin' 2
    Set-Dword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'ConsentPromptBehaviorUser' 1
    Set-Dword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'InactivityTimeoutSecs' 600
    Set-Dword 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'DisableAutomaticRestartSignOn' 1
    Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 1
    Set-Dword 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient' 'EnableMulticast' 0
    Invoke-CheckedNative net.exe @('accounts', '/minpwlen:14', '/maxpwage:unlimited', '/lockoutthreshold:10', '/lockoutduration:15', '/lockoutwindow:15')
    Invoke-CheckedNative net.exe @('user', 'Guest', '/active:no')
    # Applies to this new stock installation. Do not rerun after third-party firewall deployment.
    Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow
    # Leave IPv4/IPv6, BFE, mpssvc, SharedAccess, cryptography and servicing intact.
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -EnableSMB2Protocol $true -RequireSecuritySignature $true -Force
    Set-SmbClientConfiguration -RequireSecuritySignature $true -EnableInsecureGuestLogons $false -Force

    $features = @(Get-WindowsOptionalFeature -Online)
    foreach ($name in $profile.disableFeatures) {
        $feature = $features | Where-Object FeatureName -EQ $name
        if ($feature -and $feature.State -eq 'Enabled') {
            try {
                # No -Remove: preserve feature payloads and Windows component servicing.
                $result = Disable-WindowsOptionalFeature -Online -FeatureName $name -NoRestart
                $restartNeeded = $restartNeeded -or $result.RestartNeeded
                $changes.Add("Disabled optional feature: $name")
            } catch { $warnings.Add("Feature $name not disabled: $($_.Exception.Message)") }
        }
    }
    foreach ($name in $profile.disabledServices) {
        $service = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($service) {
            try {
                if ($service.Status -ne 'Stopped') { Stop-Service -Name $name -Force }
                Set-Service -Name $name -StartupType Disabled
                $changes.Add("Disabled optional service: $name")
            } catch { $warnings.Add("Service $name not disabled: $($_.Exception.Message)") }
        }
    }
    & (Join-Path $PSScriptRoot 'Trim-Apps.ps1')
    & (Join-Path $PSScriptRoot 'Set-DefaultProfile.ps1')
    [ordered]@{
        Version = $profile.profileVersion; Success = $true; RestartRequired = $restartNeeded
        WarningCount = $warnings.Count; Warnings = @($warnings.ToArray()); Changes = @($changes.ToArray())
        Note = 'Configuration applied, not proof of runtime security. Run Test-Host.ps1 after reboot.'
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'Apply-Base.json') -Encoding UTF8
    foreach ($warning in $warnings) { Write-Warning $warning }
} catch {
    [ordered]@{ Success = $false; Error = $_.Exception.Message } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'Apply-Base.json') -Encoding UTF8
    throw
} finally { Stop-Transcript | Out-Null }
