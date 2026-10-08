#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param([string]$SenseSource)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell.' }
$root = Join-Path $env:ProgramData 'HostBase'
if (-not (Test-Path -LiteralPath (Join-Path $root 'Apply-Base.json'))) { throw 'Base installation report missing.' }
$base = Get-Content (Join-Path $root 'Apply-Base.json') -Raw | ConvertFrom-Json
if (-not $base.Success) { throw 'Resolve the failed Apply-Base report first.' }
Start-Transcript -Path (Join-Path $root 'Initialize-Host.log') -Append | Out-Null
try {
    # Run before Bitdefender/Mullvad; do not override a third-party antivirus or firewall.
    $otherAv = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct |
        Where-Object { $_.displayName -notmatch '(?i)Microsoft Defender|Windows Defender' })
    if ($otherAv.Count) { throw 'Run Initialize-Host before third-party antivirus installation; do not overwrite the stack.' }
    Set-Service DiagTrack -StartupType Automatic
    Start-Service DiagTrack
    Start-Service WlanSvc
    $physical = @(Get-NetAdapter -Physical)
    foreach ($adapter in $physical) {
        foreach ($connection in @(Get-NetConnectionProfile -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue)) {
            if ($connection.NetworkCategory -ne 'DomainAuthenticated') {
                Set-NetConnectionProfile -InterfaceIndex $adapter.ifIndex -NetworkCategory Public
            }
        }
        # No host LAN file sharing; VMnet adapters are deliberately excluded.
        $sharing = Get-NetAdapterBinding -Name $adapter.Name -ComponentID ms_server -ErrorAction SilentlyContinue
        if ($sharing -and $sharing.Enabled) { Disable-NetAdapterBinding -Name $adapter.Name -ComponentID ms_server | Out-Null }
    }
    if (-not (Get-NetFirewallRule -Name HostBase-BlockOutboundSMB-TCP -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name HostBase-BlockOutboundSMB-TCP -DisplayName 'HostBase: block outbound SMB on Public networks' -Direction Outbound -Action Block -Protocol TCP -RemotePort 139,445 -Profile Public | Out-Null
    }
    if (-not (Get-NetFirewallRule -Name HostBase-BlockNetBIOS-UDP -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name HostBase-BlockNetBIOS-UDP -DisplayName 'HostBase: block outbound NetBIOS on Public networks' -Direction Outbound -Action Block -Protocol UDP -RemotePort 137,138 -Profile Public | Out-Null
    }
    # Defender remains the active AV until a registered third-party AV is installed.
    Set-MpPreference -PUAProtection Enabled -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false `
        -DisableIOAVProtection $false -DisableScriptScanning $false -DisableBlockAtFirstSeen $false `
        -MAPSReporting Advanced -SubmitSamplesConsent SendSafeSamples -EnableNetworkProtection Enabled
    # No AV exclusions, ASR enforcement, TLS-inspection exceptions, or passive-mode registry hacks.
    foreach ($guid in @('{0CCE922B-69AE-11D9-BED3-505054503030}',
        '{0CCE9215-69AE-11D9-BED3-505054503030}', '{0CCE921B-69AE-11D9-BED3-505054503030}',
        '{0CCE9235-69AE-11D9-BED3-505054503030}', '{0CCE923F-69AE-11D9-BED3-505054503030}')) {
        & auditpol.exe /set "/subcategory:$guid" /success:enable /failure:enable
        if ($LASTEXITCODE -ne 0) { throw 'Failed to enable an audit subcategory.' }
    }
    foreach ($spec in @(@('Security',134217728), @('System',67108864), @('Application',67108864))) {
        & wevtutil.exe sl $spec[0] "/ms:$($spec[1])"
        if ($LASTEXITCODE -ne 0) { throw "Failed to size event channel $($spec[0])." }
    }
    # Sense may be built in. Never assume that a universal FoD name or release exists.
    if (-not (Get-Service Sense -ErrorAction SilentlyContinue)) {
        $sense = @(Get-WindowsCapability -Online | Where-Object Name -Like 'Microsoft.Windows.Sense.Client*')
        if ($sense.Count -eq 1) {
            if ($SenseSource) {
                Add-WindowsCapability -Online -Name $sense[0].Name -Source $SenseSource -LimitAccess | Out-Null
            } else {
                Add-WindowsCapability -Online -Name $sense[0].Name | Out-Null
            }
        } else {
            throw 'Sense is missing and its capability is unavailable. Obtain the matching official Windows FoD/EDR package; do not onboard yet.'
        }
    }
    & (Join-Path $PSScriptRoot 'Trim-Apps.ps1')
    Write-Host 'Base initialization completed. Reboot, patch Windows, and run Test-Host.ps1. Third-party products are not installed or onboarded.'
} finally { Stop-Transcript | Out-Null }
