#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ScratchDirectory)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $ScratchDirectory) { throw 'Use a fresh scratch directory; do not overwrite existing files.' }
New-Item -Path $ScratchDirectory -ItemType Directory | Out-Null
# Execute only the constrained local extractor, never any Windows configuration payload.
$savedWindowsDirectory = $env:windir
try {
    $env:windir = $ScratchDirectory
    $document = [xml]::new()
    $document.Load((Join-Path $PSScriptRoot 'autounattend.xml'))
    $extractor = [scriptblock]::Create($document.unattend.Extensions.ExtractScript.InnerText)
    Invoke-Command -ScriptBlock $extractor -ArgumentList $document
    $destination = Join-Path $ScratchDirectory 'Setup\Scripts\HostBase'
    $verified = 0
    foreach ($payload in $document.unattend.Extensions.File) {
        $path = Join-Path $destination $payload.GetAttribute('name')
        $actual = [IO.File]::ReadAllText($path)
        if ($actual -cne $payload.InnerText) { throw "Embedded extraction changed $path." }
        $verified++
    }
    $rejected = 0
    foreach ($name in @('../escape.ps1', 'C:\escape.ps1', 'payload.exe', 'script.ps1/child.ps1')) {
        $probe = $document.Clone()
        $probe.unattend.Extensions.File[0].SetAttribute('name', $name)
        $didReject = $false
        try { Invoke-Command -ScriptBlock $extractor -ArgumentList $probe }
        catch {
            if ($_.Exception.Message -notmatch 'Invalid embedded filename') { throw }
            $didReject = $true
        }
        if (-not $didReject) { throw "Extractor accepted unsafe filename: $name" }
        $rejected++
    }
    [ordered]@{ Kind = 'Local extractor functional checks'; VerifiedPayloads = $verified; RejectedUnsafeNames = $rejected; WindowsConfigurationPayloadsExecuted = 0 } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'payload-extraction-validation.json') -Encoding UTF8
    Write-Host "PASS: $verified embedded payloads extracted exactly; $rejected unsafe filename cases rejected. No host configuration payload executed."
} finally { $env:windir = $savedWindowsDirectory }
