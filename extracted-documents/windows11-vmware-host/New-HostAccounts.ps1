#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param([switch]$AddAcademicAndUsers)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell.' }
# No transcript, stored password, auto-logon, account overwrite, or automatic demotion.
$accounts = @([pscustomobject]@{ Name = 'HOST-ADMIN'; Admin = $true },
    [pscustomobject]@{ Name = 'WORK'; Admin = $false })
if ($AddAcademicAndUsers) {
    $accounts += @([pscustomobject]@{ Name = 'ACADEMIC'; Admin = $false },
        [pscustomobject]@{ Name = 'USERS'; Admin = $false })
}
foreach ($account in $accounts) {
    if (Get-LocalUser -Name $account.Name -ErrorAction SilentlyContinue) {
        throw "Account $($account.Name) already exists. Review it manually; this script will not replace accounts or passwords."
    }
}
$adminGroup = Get-LocalGroup -SID 'S-1-5-32-544'
$usersGroup = Get-LocalGroup -SID 'S-1-5-32-545'
foreach ($account in $accounts) {
    $password = Read-Host "Enter a unique password of at least 14 characters for $($account.Name)" -AsSecureString
    try {
        if ($password.Length -lt 14) { throw 'Password too short. No account was created for this prompt.' }
        $user = New-LocalUser -Name $account.Name -Password $password -PasswordNeverExpires `
            -Description 'Windows host account; created interactively without unattended credentials.'
        Add-LocalGroupMember -Group $usersGroup -Member $user
        if ($account.Admin) { Add-LocalGroupMember -Group $adminGroup -Member $user }
    } finally { $password.Dispose() }
}
Write-Host 'Test HOST-ADMIN sign-in and UAC elevation before removing administrator membership from your OOBE account. Use WORK for everyday VM work.'
