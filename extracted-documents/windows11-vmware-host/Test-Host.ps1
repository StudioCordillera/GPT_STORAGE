#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [ValidateSet('Base','Deployment','FullStack')][string]$Stage = 'Base',
    [switch]$ScanWindowsUpdate,
    [string]$VmrunPath,
    [string]$ReportPath = (Join-Path $env:ProgramData 'HostBase\Host-Validation.json')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$checks = [System.Collections.Generic.List[object]]::new()
function Add-Check([string]$Name, [string]$Status, [string]$Detail) {
    $checks.Add([pscustomobject]@{ Name = $Name; Status = $Status; Detail = $Detail })
}
function Check([string]$Name, [scriptblock]$Test) {
    try {
        $result = & $Test
        if ($result -eq $true) { Add-Check $Name PASS 'Expected state observed.' }
        else { Add-Check $Name FAIL 'Expected state not observed.' }
    } catch { Add-Check $Name FAIL $_.Exception.Message }
}
if (-not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell.' }
$profile = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'HostProfile.json') -Raw | ConvertFrom-Json
Check 'Edition.Windows11Workstations' { ((Get-WindowsEdition -Online).Edition -eq 'ProfessionalWorkstation') -and ([int](Get-CimInstance Win32_OperatingSystem).BuildNumber -ge 22000) }
Check 'Firmware.TPM2Ready' {
    $tpm = Get-Tpm
    $version = (Get-CimInstance -Namespace root/CIMV2/Security/MicrosoftTpm -ClassName Win32_Tpm).SpecVersion
    $tpm.TpmPresent -and $tpm.TpmReady -and ($version -match '(^|,\s*)2\.0')
}
Check 'Firmware.SecureBoot' { Confirm-SecureBootUEFI }
Check 'Hypervisor.WHP' { (Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform).State -eq 'Enabled' }
Check 'Hypervisor.Running' { (Get-CimInstance Win32_ComputerSystem).HypervisorPresent }
Check 'Security.VBSRunning' { (Get-CimInstance -Namespace root/Microsoft/Windows/DeviceGuard -ClassName Win32_DeviceGuard).VirtualizationBasedSecurityStatus -eq 2 }
Check 'Security.HVCIRunning' { 2 -in (Get-CimInstance -Namespace root/Microsoft/Windows/DeviceGuard -ClassName Win32_DeviceGuard).SecurityServicesRunning }
Check 'Security.CredentialGuardRunning' { 1 -in (Get-CimInstance -Namespace root/Microsoft/Windows/DeviceGuard -ClassName Win32_DeviceGuard).SecurityServicesRunning }
Check 'Security.DMACapabilityAvailable' { 3 -in (Get-CimInstance -Namespace root/Microsoft/Windows/DeviceGuard -ClassName Win32_DeviceGuard).AvailableSecurityProperties }
Add-Check 'Firmware.KernelDMAProtection' MANUAL 'Confirm Kernel DMA Protection = On in msinfo32; an available DMA capability is not proof every peripheral is isolated. Confirm firmware IOMMU, SMM/WSMT and MOR support.'
Check 'Recovery.WinRE' {
    $output = & reagentc.exe /info
    if ($LASTEXITCODE -ne 0) { throw 'reagentc /info failed.' }
    # This answer file installs en-US. Validate English output; other locales need a localized check.
    ($output -join "`n") -match 'Windows RE status:\s+Enabled'
}
foreach ($name in $profile.requiredServices) {
    $serviceName = $name
    Check "Service.$name.PresentNotDisabled" {
        $service = Get-Service -Name $serviceName
        $service.StartType -ne 'Disabled'
    }
}
Check 'Service.DiagTrackRunning' { (Get-Service DiagTrack).Status -eq 'Running' }
Check 'Service.BFERunning' { (Get-Service BFE).Status -eq 'Running' }
Check 'Service.SecurityCenterRunning' { (Get-Service wscsvc).Status -eq 'Running' }
Check 'EDR.SensorAvailable' { [bool](Get-Service Sense -ErrorAction SilentlyContinue) }
Add-Check 'Services.TriggerStart' INFO 'VaultSvc, Windows Installer, update services and Sense before onboarding may be stopped normally. They must be present and usable; all-services-running is not a valid baseline.'
Check 'Servicing.ComponentStoreHealth' { (Repair-WindowsImage -Online -CheckHealth).ImageHealthState -eq 'Healthy' }
Check 'Network.IPv4Retained' {
    @((Get-NetAdapterBinding -ComponentID ms_tcpip) | Where-Object Enabled -EQ $true).Count -gt 0
}
Check 'Network.PhysicalProfilesPublic' {
    $found = $false
    foreach ($adapter in @(Get-NetAdapter -Physical)) {
        foreach ($connection in @(Get-NetConnectionProfile -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue)) {
            $found = $true
            if ($connection.NetworkCategory -ne 'Public') { return $false }
        }
    }
    $found
}
Check 'Security.NoAutomaticLogon' {
    $key = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $key.GetValue('AutoAdminLogon','0') -ne '1'
}
Check 'Security.UAC' {
    $uac = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $uac.EnableLUA -eq 1 -and $uac.PromptOnSecureDesktop -eq 1
}
Check 'Security.RemoteDesktopDenied' { (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server').fDenyTSConnections -eq 1 }
Check 'Security.SMB1Disabled' { -not (Get-SmbServerConfiguration).EnableSMB1Protocol }
Check 'Security.TrimCompleted' {
    $result = Get-Content -LiteralPath (Join-Path $env:ProgramData 'HostBase\Trim-Apps.json') -Raw | ConvertFrom-Json
    $result.FailureCount -eq 0
}
if ($Stage -ne 'FullStack') {
    Check 'Security.NativeFirewallBaseline' {
        $bad = @(Get-NetFirewallProfile | Where-Object { $_.Enabled -ne 'True' -or $_.DefaultInboundAction -ne 'Block' })
        $bad.Count -eq 0
    }
    Check 'Security.DefenderActive' {
        $av = Get-MpComputerStatus
        $av.AMRunningMode -eq 'Normal' -and $av.AntivirusEnabled -and $av.RealTimeProtectionEnabled
    }
}
if ($ScanWindowsUpdate) {
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $result = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")
        if ($result.ResultCode -ne 2) { throw "Windows Update scan result code $($result.ResultCode); not a complete success." }
        if ($result.Updates.Count -eq 0) { Add-Check 'Servicing.UpdateScan' PASS 'A current software-update scan completed; no pending software updates.' }
        else { Add-Check 'Servicing.UpdateScan' FAIL "$($result.Updates.Count) software updates pending. Install/reboot and scan again." }
    } catch { Add-Check 'Servicing.UpdateScan' FAIL $_.Exception.Message }
} else { Add-Check 'Servicing.UpdateScan' MANUAL 'Run again with -ScanWindowsUpdate after installing updates and rebooting. Updates have not been tested by this run.' }
if ($Stage -ne 'Base') {
    Check 'Encryption.BitLockerProtected' {
        $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive
        $volume.ProtectionStatus -eq 'On' -and $volume.VolumeStatus -eq 'FullyEncrypted'
    }
    Add-Check 'Encryption.RecoveryKeyEscrow' MANUAL 'Confirm the current recovery key is backed up off this laptop, accessible independently, and matches the protector ID. The script never reads or prints the recovery password.'
    Check 'Accounts.WORKIsStandard' {
        $user = Get-LocalUser WORK
        $admins = @(Get-LocalGroupMember -SID 'S-1-5-32-544')
        @($admins | Where-Object { $_.SID -eq $user.SID }).Count -eq 0 -and $user.Enabled
    }
    Check 'Accounts.HostAdminExists' {
        $user = Get-LocalUser HOST-ADMIN
        @((Get-LocalGroupMember -SID 'S-1-5-32-544') | Where-Object { $_.SID -eq $user.SID }).Count -eq 1 -and $user.Enabled
    }
    Add-Check 'Accounts.CredentialsVerified' MANUAL 'Test HOST-ADMIN sign-in/UAC and WORK sign-in; verify unique passwords/Hello, then demote or disable the original OOBE admin. Account presence alone does not prove password strength.'
} else { Add-Check 'Encryption.BitLocker' INFO 'Base stage preserves encryption capability. Encryption and recovery-key escrow are mandatory before hostile-network deployment.' }
if ($Stage -eq 'FullStack') {
    Check 'EDR.SenseRunning' { (Get-Service Sense).Status -eq 'Running' }
    Check 'EDR.OnboardedLocally' {
        (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status').OnboardingState -eq 1
    }
    Check 'AV.BitdefenderRegistered' {
        @((Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct) | Where-Object displayName -Match '(?i)Bitdefender').Count -gt 0
    }
    Check 'AV.DefenderPassiveOrEDRBlockMode' { (Get-MpComputerStatus).AMRunningMode -match '^(Passive|EDR Block Mode)' }
    foreach ($vmnet in @('VMnet1','VMnet8')) {
        $vmnetName = $vmnet
        Check "VMware.Adapter.$vmnet" { @((Get-NetAdapter -IncludeHidden) | Where-Object Name -Match "\b$vmnetName\b").Count -gt 0 }
    }
    foreach ($executable in @('vmnat.exe','vmnetdhcp.exe')) {
        $image = [regex]::Escape($executable)
        Check "VMware.Service.$executable" {
            @((Get-CimInstance Win32_Service) | Where-Object { $_.PathName -match "(?i)\b$image\b" -and $_.State -eq 'Running' }).Count -gt 0
        }
    }
    Check 'VMware.VmrunList' {
        $path = $VmrunPath
        if (-not $path) {
            $command = Get-Command vmrun.exe -ErrorAction SilentlyContinue
            if (-not $command) { throw 'Supply -VmrunPath for the installed signed VMware vmrun.exe.' }
            $path = $command.Source
        }
        if (-not (Test-Path -LiteralPath $path)) { throw 'vmrun.exe not found.' }
        $output = & $path -T ws list
        if ($LASTEXITCODE -ne 0) { throw "vmrun list failed: exit $LASTEXITCODE." }
        ($output -join "`n") -match 'Total running VMs:\s*\d+'
    }
    Add-Check 'EDR.CloudHealth' MANUAL 'Verify a recent device check-in in Defender portal; review SENSE errors and license entitlement. Local onboarding state alone cannot prove reporting.'
    Add-Check 'VPN.FirewallAndLeakTests' MANUAL 'Verify Mullvad lockdown, boot/disconnect behavior, IPv4/IPv6/DNS leak tests and Bitdefender health/firewall with VM NAT traffic. Test exceptions and recovery on a trusted staging network.'
    Add-Check 'VMware.GuestSmoke' MANUAL 'Boot a representative VM with VBS/HVCI still running. Verify guest DHCP/NAT/DNS, intended isolation, encrypted VM credentials and restart. vmrun list alone does not prove launch/networking.'
    Add-Check 'Tooling.BuildSmoke' MANUAL 'If host-side image automation is used, test Python/pywin32/keyring and a real Packer build over a temporary host-reachable VMnet. Remove build access before sandbox deployment.'
}
$failed = @($checks.ToArray() | Where-Object Status -EQ FAIL).Count
$manual = @($checks.ToArray() | Where-Object Status -EQ MANUAL).Count
$report = [ordered]@{
    Stage = $Stage; GeneratedUtc = [DateTime]::UtcNow.ToString('o'); Failed = $failed
    ManualChecksOutstanding = $manual; DeploymentReady = $false
    Note = 'Read-only checks and manual prerequisites. Never interpret exit 0 as approval to deploy.'
    Checks = @($checks.ToArray())
}
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
$checks.ToArray() | Format-Table Name,Status,Detail -Wrap
Write-Host "Failures: $failed; manual checks outstanding: $manual. Report: $ReportPath"
if ($failed) { exit 1 }
if ($manual) { exit 2 }
exit 0
