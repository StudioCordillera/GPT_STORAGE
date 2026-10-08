#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$hive = 'HKU\HostBaseDefault'
& reg.exe load $hive "$env:SystemDrive\Users\Default\NTUSER.DAT" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not load the default-user hive.' }
function Set-DefaultValue([string]$Subkey, [string]$Name, $Value, [string]$Type = 'DWord') {
    # Registry provider keys are not held across hive unload.
    $path = "Registry::HKEY_USERS\HostBaseDefault\$Subkey"
    New-Item -Path $path -Force | Out-Null
    New-ItemProperty -Path $path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}
try {
    $shell = Join-Path $env:SystemDrive 'Users\Default\AppData\Local\Microsoft\Windows\Shell'
    New-Item -Path $shell -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'TaskbarLayoutModification.xml') -Destination (Join-Path $shell 'LayoutModification.xml') -Force
    $advanced = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-DefaultValue $advanced HideFileExt 0
    Set-DefaultValue $advanced ShowSuperHidden 0
    Set-DefaultValue $advanced Hidden 2
    Set-DefaultValue $advanced TaskbarAl 0
    Set-DefaultValue $advanced ShowTaskViewButton 0
    Set-DefaultValue $advanced TaskbarDa 0
    Set-DefaultValue $advanced LaunchTo 1
    Set-DefaultValue $advanced TaskbarAnimations 0
    Set-DefaultValue 'Software\Microsoft\Windows\CurrentVersion\Search' SearchboxTaskbarMode 0
    Set-DefaultValue 'Software\Policies\Microsoft\Windows\Explorer' DisableSearchBoxSuggestions 1
    Set-DefaultValue 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' EnableTransparency 0
    Set-DefaultValue 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme 0
    Set-DefaultValue 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' SystemUsesLightTheme 0
    Set-DefaultValue 'Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' VisualFXSetting 2
    # Keep font smoothing; avoid removing the taskbar or security notifications.
    Set-DefaultValue 'Control Panel\Desktop' FontSmoothing '2' String
    Set-DefaultValue 'Control Panel\Desktop\WindowMetrics' MinAnimate '0' String
    Set-DefaultValue 'Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' Enabled 0
    foreach ($name in @('SilentInstalledAppsEnabled','PreInstalledAppsEnabled','OemPreInstalledAppsEnabled',
        'SoftLandingEnabled','SystemPaneSuggestionsEnabled','SubscribedContent-338388Enabled',
        'SubscribedContent-338389Enabled','SubscribedContent-353698Enabled')) {
        Set-DefaultValue 'Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' $name 0
    }
    Remove-ItemProperty -Path 'Registry::HKEY_USERS\HostBaseDefault\Software\Microsoft\Windows\CurrentVersion\Run' -Name OneDriveSetup -ErrorAction SilentlyContinue
} finally {
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    & reg.exe unload $hive | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not unload the default-user hive. Reboot before using this profile.' }
}
