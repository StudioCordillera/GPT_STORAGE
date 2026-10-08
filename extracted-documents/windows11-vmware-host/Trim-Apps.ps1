#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$profile = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'HostProfile.json') -Raw | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()
$results = [System.Collections.Generic.List[object]]::new()
if (@($profile.removeAppx | Where-Object { $_ -in $profile.protectedAppx }).Count) { throw 'Protected Appx in removal list.' }
$provisioned = @(Get-AppxProvisionedPackage -Online)
$registered = @(Get-AppxPackage -AllUsers)
foreach ($name in $profile.removeAppx) {
    foreach ($package in @($provisioned | Where-Object DisplayName -EQ $name)) {
        try {
            Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $package.PackageName | Out-Null
            $results.Add([ordered]@{ Kind = 'ProvisionedAppx'; Name = $name; Status = 'Removed' })
        } catch { $failures.Add("Provisioned $name : $($_.Exception.Message)") }
    }
    foreach ($package in @($registered | Where-Object Name -EQ $name)) {
        if ($package.IsFramework -or $package.NonRemovable) {
            $failures.Add("Protected/nonremovable package retained: $name"); continue
        }
        try {
            Remove-AppxPackage -Package $package.PackageFullName -AllUsers
            $results.Add([ordered]@{ Kind = 'RegisteredAppx'; Name = $name; Status = 'Removed' })
        } catch { $failures.Add("Registered $name : $($_.Exception.Message)") }
    }
}
foreach ($capability in @(Get-WindowsCapability -Online)) {
    $prefix = ($capability.Name -split '~')[0]
    if ($prefix -in $profile.removeCapabilityPrefixes -and $capability.State -eq 'Installed') {
        try {
            Remove-WindowsCapability -Online -Name $capability.Name | Out-Null
            $results.Add([ordered]@{ Kind = 'Capability'; Name = $capability.Name; Status = 'Removed' })
        } catch { $failures.Add("Capability $prefix : $($_.Exception.Message)") }
    }
}
# Uninstall via the Windows-supplied binary; do not delete installers or service files.
$oneDrivePaths = @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe")
$oneDrive = $oneDrivePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($oneDrive) {
    try {
        $p = Start-Process -FilePath $oneDrive -ArgumentList '/uninstall' -Wait -PassThru
        if ($p.ExitCode -ne 0) { throw "OneDrive uninstaller exit code $($p.ExitCode)." }
        $results.Add([ordered]@{ Kind = 'DesktopApp'; Name = 'OneDrive'; Status = 'UninstallRequested' })
    } catch { $failures.Add($_.Exception.Message) }
}
$root = Join-Path $env:ProgramData 'HostBase'
if (-not (Test-Path -LiteralPath $root)) {
    throw 'Run Apply-Base.ps1 first so the report directory has protected ACLs.'
}
[ordered]@{ Results = @($results.ToArray()); Failures = @($failures.ToArray()); FailureCount = $failures.Count } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'Trim-Apps.json') -Encoding UTF8
foreach ($failure in $failures) { Write-Warning $failure }
