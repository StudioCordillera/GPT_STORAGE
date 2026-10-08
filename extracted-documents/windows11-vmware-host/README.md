# Minimal Windows 11 VMware host — Dell XPS 15 9510

This is a **stock Windows 11 Pro for Workstations x64 installation with a minimal desktop**, designed to support the security stack in your attached requirements. It removes consumer applications, sync clients and unused remote/discovery/printing features while keeping the Windows components that patching, protection, vendor installers and VMware need. It is not a rebuilt Windows ISO, a Server Core image, or a claim that a smaller supported image is impossible.

The delivered `autounattend.xml` is self-contained. Its embedded scripts run during the specialize phase, before OOBE. Disk selection, sign-in and passwords remain interactive. At the first administrator sign-in, the embedded completion workflow automatically runs initialization, opens the existing HOST-ADMIN/WORK password prompts, and runs base validation. No manual PowerShell commands are needed for these steps. No host installation, firmware change, encryption, third-party installation or Windows runtime test has been performed from this Linux workspace.

## What the install configures

| Area | Result |
|---|---|
| Edition | Windows 11 **Pro for Workstations**, non-N, x64. A public generic setup key from the matching generator source selects the edition; it does not supply a license or activate Windows. A valid Workstations entitlement is still required. |
| Desktop | Explorer, desktop, Start, taskbar, notification area and Settings retained. Taskbar defaults to an Explorer pin. Search box, Widgets, Task View, transparency and most animation removed/hidden. Font smoothing stays on. Remaining Start pins can be unpinned manually; no unsupported database edits or permanent layout-lock task. |
| Consumer software | Exact-name removal list for 47 consumer Appx packages, plus optional handwriting/speech/OCR, legacy apps and unused SSH capabilities. The actual count removed depends on the ISO. Missing apps are normal; removal failures are reported, not hidden. |
| Recovery and servicing | WinSxS/CBS/DISM, Windows Update, servicing services, WinRE, BitLocker, TPM plumbing and System Restore capability retained. No `/ResetBase`, component-file deletion, disabled update tasks or forced removal of security packages. |
| Security | WHP enabled; Windows hypervisor set to launch; VBS/HVCI configured with Secure Boot + DMA requirement. Credential Guard and LSA protection configured **without UEFI locks**, so driver recovery remains possible. Vulnerable-driver blocklist and SmartScreen enabled; Smart App Control default state preserved. Actual enforcement is verified after reboot. |
| Credentials | No passwordless accounts, automatic logon, stored passwords or Wi-Fi credentials. UAC and secure desktop enabled; 14-character password minimum, lockout after 10 attempts for 15 minutes, 10-minute inactivity lock. No forced periodic password expiry. |
| Networking | Windows Firewall enabled with default inbound block/outbound allow; IPv4 **and IPv6**, DHCP, DNS, WLAN and WFP retained. Initialization sets physical uplinks to Public and disables their host file-sharing binding; VMnet adapters are excluded. Public-network outbound SMB/NetBIOS rules and LLMNR suppression reduce unsolicited LAN authentication. These are not a complete outbound allowlist. |
| Privacy | Required diagnostic data remains enabled and `DiagTrack` is retained. Consumer suggestions, OneDrive sync and Recall are suppressed. Defender/EDR endpoints are not blocked. |
| Idle overhead | No alternative shell, no added resident agent, no indefinite update-reboot prevention, no global PowerShell execution-policy relaxation, no blanket service shutdown. Indexing, printing, remote registry/WinRM and UPnP/SSDP services are disabled for this dedicated local-VM host. |

Security capabilities, updateability and application compatibility determine the minimum. Defender, Event Log, EDR telemetry and recovery have unavoidable costs. VMware VM disks and workload RAM will dominate host footprint; no RAM/disk/boot-time savings have been measured here.

## 1. Prepare trusted installation media and firmware

1. Back up the target laptop and obtain official Microsoft installation media that contains the non-N **Pro for Workstations** edition and matches `en-US`. A Home OEM entitlement or ordinary Pro license is not a Workstations license. If your ISO lacks that edition, use the correct media/entitlement; the script deliberately rejects a different edition instead of silently deploying Home/Pro. Do not use tiny11 core, Nano11 or an unknown premodified ISO.
2. On the **XPS 15 9510**, use Dell's Service Tag support page to update BIOS and obtain signed 9510 storage, chipset, Wi-Fi, GPU and other required drivers. Verify installer signatures and provenance on a trusted machine. The 9510 has 11th-generation Intel CPUs; the document's possible hybrid P/E-core concern applies to other generations. Exact BIOS menu names and firmware version are not independently verified here.
3. In firmware: use native UEFI, enable TPM 2.0, Secure Boot, CPU virtualization and VT-d/IOMMU. Keep Legacy/CSM off. Check the actual firmware's SMM/WSMT/MOR support; an answer file cannot add missing hardware features. Do not switch storage controller/RST mode casually. If Setup cannot see the SSD, load the correct Dell signed storage driver rather than bypassing hardware checks. Use the generator's referenced `$WinPEDriver$` method or Windows Setup's Load driver.
4. Copy **this bundle's** `autounattend.xml` to the installation USB root. Other files are included for inspection/reuse; no `$OEM$` copy is required because they are embedded. Do not combine it with your old answer file, old first-logon scripts, or Rufus TPM/Secure Boot/account bypass settings.
5. Boot the USB in UEFI mode. Select the intended disk/partition interactively. **No disk is automatically wiped by this file**, but Windows Setup can erase the partitions you select. For a clean install use the intended unallocated target and allow Setup to create EFI/MSR/Windows/recovery partitions. Disconnect unrelated disks if practical.
6. Complete normal OOBE on a trusted staging connection. This file does not rely on `BypassNRO`, `SkipMachineOOBE`, blank credentials, or build-specific Microsoft-account workarounds. Use the account flow supported by the exact Windows build. Secure local host accounts are created in step 3 below.

The file uses the generator's embedded-payload technique, but is a reviewed custom answer file. Regenerating it on the website can discard custom scripts. Change the source payloads and rebuild deliberately; see `GENERATOR-SETTINGS.md`.

## 2. Automatic completion after OOBE

Complete the configured normal OOBE and sign in with its initial administrator account. Windows automatically opens `Complete-Setup.ps1` through a single elevated FirstLogonCommands entry. It runs `Initialize-Host.ps1`, then `New-HostAccounts.ps1`, then `Test-Host.ps1 -Stage Base -ScanWindowsUpdate` in order. You do not need to open PowerShell or run those scripts yourself.

Enter unique passwords of at least 14 characters when the existing HOST-ADMIN and WORK prompts appear. These interactive prompts are intentional: no passwords are embedded, no accounts are passwordless, and automatic logon stays off. The optional ACADEMIC/USERS switch remains off. Keep the completion window open until it finishes, then press Enter to close it.

Reports are under `%ProgramData%\HostBase`: `Setup-Completion.json`, `Apply-Base.json`, `Initialize-Host.log` and `Host-Validation.json`. Failed initialization or account creation stops subsequent steps and is shown in the window/report. Failed validation checks and outstanding manual checks are reported separately from script execution completion. The workflow does not silently retry partial account creation or mark a machine deployment-ready.

This automates execution of the existing base scripts. It does not add automatic disk wiping, change the computer name/edition/security policy, install drivers/vendor software, apply Windows updates, encrypt disks or remove the initial OOBE administrator. The update scan reports applicable updates; it does not install them. Install Windows/OEM updates and reboot as needed; later verification may need repeating after hardware or software changes.

## 3. Account verification

The automatic completion workflow creates the configured HOST-ADMIN administrator and WORK standard user using secure password prompts. Test HOST-ADMIN sign-in and UAC elevation before demoting or disabling the initial OOBE administrator. This verification remains a human action and is not silently performed by the installer.

## 4. Encrypt before hostile-network deployment

Use **Manage BitLocker** for the Windows volume and every volume containing VM images or secrets. Automatic device encryption is allowed but is not accepted as proof of protection. Verify `manage-bde -status` shows protection on and encryption complete.

Choose TPM + startup PIN if physical theft/tampering is in your threat model and the operational cost is acceptable; the native BitLocker policy/editor is retained. Back up the recovery key **off this laptop**, to a location accessible independently, and verify it corresponds to the current protector. Do not store the only recovery key in a host file, a VM on the same SSD, this answer file, or a local report. For centrally managed machines, use your supported Entra/AD escrow policy. Follow recovery-key and firmware-update procedures before later BIOS/TPM changes.

This bundle deliberately does not silently initiate encryption or invent an escrow destination. Retaining the BitLocker feature is different from having a protected disk. WinRE and system restore capability remain available; configure a bounded restore allocation/checkpoint if useful, and maintain an independent backup. A restore point is not a backup.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$scripts\Test-Host.ps1" -Stage Deployment -ScanWindowsUpdate
```

The manual recovery, firmware and sign-in checks still need real-machine evidence. Do not attach the host to the hostile network merely because the base script completed.

## 5. Add the security/workspace stack later

This delivery stops at the **base host installation**. It preserves prerequisites for the following products; it does not download unverified vendor binaries or embed license keys/onboarding secrets.

1. Install a current, signed, supported **VMware Workstation Pro** release that supports the exact Windows build and VBS/WHP. The specific `26H1u1` claim in your document is **not independently verified**. Leave the Windows hypervisor and HVCI on. Full Hyper-V management, Virtual Machine Platform, WSL, Docker and Windows Sandbox are not installed by this profile because ordinary Workstation use does not require them.
2. Install/activate **Bitdefender** using your licensed vendor package. Verify active, healthy registration in Windows Security Center and its firewall UI. Keep `BFE`, `mpssvc` and `wscsvc`; do not manually rip out Windows Firewall because Bitdefender provides its own controls. Do not blindly enable competing firewall policy. Confirm the vendor's actual requirements, supported Windows build and HVCI-compatible drivers.
3. Onboard **Defender for Business/Endpoint** using the official tenant package and correct entitlement. Keep `WinDefend`, the Sense sensor, DiagTrack and IPv4. Verify the supported Defender passive/EDR-block mode for that precise combination and a recent portal check-in. Do not assume ASR or AV event 1116/1117 will provide the intended enforcement/detections in passive mode. Check the Microsoft URL list appropriate to your tenant and standard/streamlined connectivity; no speculative hosts-file/privacy blacklist is applied.
4. Install **Mullvad**. Configure lockdown, local network sharing off and your intended DNS blockers. Verify boot, connect, disconnect, suspend/resume, DNS/IPv4/IPv6 behavior and Windows/Bitdefender coexistence. Lockdown has deliberate exceptions (for example DHCP and VPN control traffic); it is not a literal zero-packet state. Test **VM NAT traffic** as well as host browser traffic. Host VPN connectivity alone does not prove that all VMware guest traffic follows the desired route.
5. Configure **VMnet1** host-only and **VMnet8** NAT; keep guest bridging to the hostile LAN off. Obtain actual VMware service executable paths from the installation before authorizing them in Bitdefender; scope rules to the needed direction/interface/ports and signed program. Do not create blanket inbound host permissions. A host-only network permits guest-to-host contact and is not sealed isolation. For an isolated sandbox, use the intended LAN segment with no host adapter; assess VMware shared folders, clipboard, drag/drop, USB passthrough and virtual devices separately.
6. Install host Python/pywin32/keyring and Packer/VMware plugin **only if host-side automation is needed**. They are not Windows base requirements and add footprint. Packer may need temporary host-reachable VMnet networking during an image build; move the guest to the sealed segment and remove build access afterwards. Disablement of the host WinRM server does not prohibit a Packer client connecting to a guest WinRM server.
7. Treat Sysmon/LimaCharlie as optional later additions. The suggested `Sysmon` DISM feature name is build-dependent and unverified here. Enumerate actual features or use a verified signed Sysinternals distribution and an intentional configuration; do not assume that command is available on every Windows 11 ISO.

**VMware tradeoff:** VBS/WHP can reduce performance and restrict nested virtualization, virtual performance counters or other low-level VMware features. Ordinary Windows/Linux VMs are the target. Do not promise nested Hyper-V/WSL2/ESXi/KVM inside those guests with the host security baseline enabled. Verify the installed vendor release and an actual representative VM. If nested virtualization is a requirement, it needs a separately assessed hardware/workflow choice rather than silently disabling host protections.

Full-stack read-only checks, after the later products are installed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$scripts\Test-Host.ps1" -Stage FullStack -ScanWindowsUpdate -VmrunPath 'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe'
```

Use the actual installed vmrun path; this path is an example, not a version assumption. The check lists VMs without starting any. It distinguishes local registration/onboarding/service checks from required guest-launch/network/credential and cloud/VPN tests. None of these Windows-only checks were executed here.

## Maintenance and controlled customization

Keep the profile removal lists exact; do not replace them with `*Microsoft*` or wildcard framework removals. Updates can reintroduce apps; rerun `Trim-Apps.ps1` as administrator and inspect its report rather than disabling updates. It must run after `Apply-Base.ps1` has created the protected report directory. Scripts outside the installation are review copies; use the installed protected copies for normal work. Edit/rebuild the answer file **before** a future installation to change the base.

Do not rerun `Apply-Base.ps1` or `Initialize-Host.ps1` after replacing the native firewall/AV policy: their baseline is the newly installed Windows host. Do not modify `IntegratedServicesRegionPolicySet.json`, remove compatibility junctions, delete WinSxS/WinRE, globally disable certificate/TLS verification, suppress security notifications, grant writable script directories, or add unreviewed VM-disk exclusions.

If you later need printing, Windows indexing, SSH client, RDP client or host-side network sharing, re-enable the specific retained feature/service through supported Windows commands and reassess firewall exposure. Removing speech/OCR reduces accessibility/recognition options; install the matching language FoD if you need them. Media Foundation, .NET, VC/UCRT, graphics, audio/Bluetooth drivers, browser/WebView and the Windows installation/update infrastructure remain for vendor compatibility. The non-N edition avoids introducing a Media Feature Pack dependency.

CompactOS is serviceable but trades storage for CPU/decompression overhead. Leave Windows' default choice for this VM host; `compact.exe /CompactOS:query` can report it. Whole-OS compression, hibernation removal, paging-file removal and speculative SysMain/timer tweaks are not defaults. They require measured benefit and compatibility testing, not a smaller-looking process list.

## Delivered evidence and limits

See `AUDIT-AND-REQUIREMENTS.md` for the original-file audit, requirement coverage and source-access limits, `GENERATOR-SETTINGS.md` for the website mapping, and `VALIDATION.md` for the checks actually run here. `SHA256SUMS.txt` identifies this local bundle's artifacts; it is a consistency manifest, not a Microsoft/vender signature or an independent attestation.

Before using this on hardware, validate `autounattend.xml` in Windows System Image Manager against the **exact ISO's** catalog, then run a trial install from your media and the real XPS staging checks. The generator's generic XSD validates outer answer-file structure only; it cannot prove every setting/cmdlet/driver works on your exact Windows release. No live Windows machine or VMware hypervisor was available for those tests.
