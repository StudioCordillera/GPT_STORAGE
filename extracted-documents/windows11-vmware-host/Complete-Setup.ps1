#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:ProgramData 'HostBase'
$statusPath = Join-Path $root 'Setup-Completion.json'
$status = [ordered]@{ Initialization = 'Pending'; Accounts = 'Pending'; Validation = 'Pending'; ScriptStepsCompleted = $false; DeploymentReady = $false; Error = $null }
try {
    Write-Host 'Windows host setup is completing automatically. Keep this window open.'
    & (Join-Path $PSScriptRoot 'Initialize-Host.ps1')
    $status.Initialization = 'Completed'
    $status | ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding UTF8
    # Preserve the configured secure password prompts and HOST-ADMIN/WORK roles.
    # Never transcript passwords, invent credentials, or enable automatic sign-in.
    & (Join-Path $PSScriptRoot 'New-HostAccounts.ps1')
    $status.Accounts = 'Completed'
    $status | ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding UTF8
    # Use a child process because Test-Host exits with its result code.
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-Host.ps1') -Stage Base -ScanWindowsUpdate
    $validationExit = $LASTEXITCODE
    if ($validationExit -notin @(0, 1, 2)) { throw "Validation process failed: $validationExit" }
    $reportPath = Join-Path $root 'Host-Validation.json'
    if (-not (Test-Path -LiteralPath $reportPath)) { throw 'Validation report missing.' }
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    $status.Validation = if ($validationExit -eq 1) { 'FailedChecks' } elseif ($validationExit -eq 2) { 'ManualChecksOutstanding' } else { 'Completed' }
    $status.ScriptStepsCompleted = $true
    Write-Host "Setup scripts finished. Validation failures: $($report.Failed); manual checks: $($report.ManualChecksOutstanding)."
    Write-Host 'Review the reports before deployment. Hardware, updates, encryption and third-party installation are not certified by this workflow.'
} catch {
    $status.Error = $_.Exception.Message
    Write-Host "Setup did not finish: $($status.Error)" -ForegroundColor Red
} finally {
    $status | ConvertTo-Json | Set-Content -LiteralPath $statusPath -Encoding UTF8
    Write-Host "Setup report: $statusPath"
    Read-Host 'Press Enter to close this setup window' | Out-Null
}
if (-not $status.ScriptStepsCompleted) { exit 1 }
