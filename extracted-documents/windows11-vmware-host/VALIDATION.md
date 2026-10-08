# Validation performed on the deliverable

## Automatic completion update

The rebuilt answer file embeds Complete-Setup.ps1 and launches it at the first administrator sign-in. The latest run passed 66 static checks including the generic generator schema, parsed all nine PowerShell scripts, and extracted all nine embedded payloads with exact parity while rejecting four unsafe filenames. Existing answer-file settings (apart from the added launch hook), HostProfile.json and all eight original payloads were compared with the published commit and remained unchanged. Windows first-logon execution and installation on real hardware have not been tested in this Linux environment.

## Passed in this Linux workspace

* **66 static packaging/policy checks**: answer-file namespace/pass order; nine embedded payloads and exact source parity; constrained destination names; manual disk selection; no auto-logon/accounts/firmware-check bypasses; Workstations setup key and no activation key; protected packages/services/capabilities excluded from removals; no download-and-execute setup; expected WHP/VBS/HVCI/Credential Guard/telemetry settings; serialized setup commands and application error propagation.
* **Generic answer-file XSD validation passed**, using the schema in the matching Schneegans source commit. It validates the outer schema; the component settings are lax, so this is **not ISO-specific Windows System Image Manager validation**.
* **Nine PowerShell files parsed without syntax errors** using the official PowerShell 7.5.4 AST parser. Scripts target Windows PowerShell 5.1 and use its syntax. Parsing in PowerShell 7 is not a test of Windows 5.1 cmdlet availability or Windows runtime behavior.
* The answer file's **embedded extractor was actually executed** in a fresh scratch directory. All **nine payloads** were written with content exactly matching the embedded text. Four cases—relative traversal, absolute Windows path, executable suffix, and a path containing a child directory—were rejected. No Windows configuration payload was executed. This functional test found a CDATA/XML-adapter handling issue during development; the extractor invocation was corrected to use `InnerText`, and the rerun passed.
* The official PowerShell Linux archive's SHA-256 was checked against its official release checksum before execution. TLS/checksum verification stayed enabled. Its SHA-256 was `1fd7983fe56ca9e6233f126925edb24bf6b6b33e356b69996d925c4db94e2fef`. This validation tool is outside the deliverable and is not installed by the Windows answer file.
* A second answer-file build was compared byte-for-byte with the first to verify reproducible generation from unchanged payloads. The packaged files are listed in `SHA256SUMS.txt`; archive extraction/checksum verification also passed.
* The existing `/workspace/GPT_STORAGE` checkout and all original uploads were preserved. This deliverable is a separate folder; no cloud environment configuration was changed for this task.

The machine-readable results are in `static-validation.json`, `powershell-syntax-validation.json` and `payload-extraction-validation.json`.

## Not executed; required before using the host

1. Windows System Image Manager validation against the **exact non-N Windows 11 Pro for Workstations image/catalog**.
2. A real clean install from your chosen trusted media, including specialized scripts, setup logs, correct edition/activation, signed drivers and normal OOBE.
3. XPS 15 9510 BIOS/TPM/Secure Boot/IOMMU/Kernel DMA checks, VBS/HVCI/Credential Guard/LSA enforcement after reboot, and driver compatibility.
4. Windows Update, OEM/firmware updates, Sense availability and all services/Defender/firewall checks on Windows.
5. Actual BitLocker encryption, independent recovery-key escrow and administrator/standard-account sign-in tests.
6. Later licensed Bitdefender/Mullvad/Defender onboarding and cloud health; current VMware release support, a representative VM boot and network/credential smoke tests.

No claim of a ready-to-deploy secure host, vendor coexistence, measured memory/disk savings or working VMware guests is made by these Linux-side checks.

## Reproduce the local validation

The Python utilities require Python 3 and `lxml` on the review machine. They are optional developer tools, not installation dependencies of the host. Review any rebuilt output before installation.

```text
python3 build_answer_file.py
python3 validate_artifacts.py [path-to-matching-generator-autounattend.xsd]
pwsh -NoProfile -File Validate-Syntax.ps1
pwsh -NoProfile -File Validate-EmbeddedPayload.ps1 -ScratchDirectory <new-empty-scratch-path>
```

On a Windows review machine, the syntax check can also be run using `powershell.exe` 5.1. The extractor test runs only its local file-writing code; it does not apply the embedded host configuration. Use a fresh scratch directory for each extraction test. Rebuild `SHA256SUMS.txt` and the archive after any edit; old result files and checksums do not validate new content.
