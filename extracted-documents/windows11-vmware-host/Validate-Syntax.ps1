#requires -Version 5.1
[CmdletBinding()]
param([string]$Root = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
$results = @()
foreach ($file in @(Get-ChildItem -LiteralPath $Root -Filter '*.ps1' -File)) {
    $tokens = $null; $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    $results += [pscustomobject]@{ File = $file.Name; Errors = @($parseErrors).Count }
    foreach ($parseError in @($parseErrors)) {
        Write-Host "$($file.Name):$($parseError.Extent.StartLineNumber): $($parseError.Message)"
    }
}
$failed = @($results | Where-Object Errors -GT 0)
$results | Format-Table
if ($failed.Count) { throw "$($failed.Count) scripts failed syntax parsing." }
[pscustomobject]@{ Kind = 'Static PowerShell AST parsing'; ParserVersion = $PSVersionTable.PSVersion.ToString(); Results = $results } |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $Root 'powershell-syntax-validation.json') -Encoding UTF8
Write-Host 'All scripts parsed. Windows cmdlet availability, parameters, privileges, drivers and runtime behavior are not established by syntax parsing.'
