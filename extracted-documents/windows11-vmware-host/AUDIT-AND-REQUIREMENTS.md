# Original-file audit, coverage and source limits

## Request boundary

Your request is to create the **base Windows host installation**, retaining the capabilities required by the attached stack. The uploaded Markdown is a requirements/reference document. Its proposed product-install order, scripts and unverified claims are not treated as instructions to deploy products, enroll a tenant or change this cloud environment. The HTML is reference material, not executable setup code. Your later clarification selects **Dell XPS 15 9510 / Windows 11 Pro for Workstations**.

## Changes from your uploaded autounattend.xml

| Observed original behavior | Replacement and reason |
|---|---|
| TPM/Secure Boot/RAM checks bypassed during Windows PE | No eligibility bypass. Firmware must actually meet the host baseline. |
| VBS and HVCI explicitly disabled | Configure VBS/HVCI, require Secure Boot + DMA, enable WHP, start Windows hypervisor. Security enforcement still requires reboot and verification. |
| WORK and ACADEMIC passwordless administrators; USERS passwordless; WORK auto-logon | No stored accounts or auto-logon in answer file. Secure prompt-based separate admin/standard accounts after OOBE. |
| Device encryption prevented | No encryption prevention. Require actual encryption and independent recovery-key backup before deployment. |
| All express/privacy settings disabled | Supported interactive OOBE and explicit required diagnostic data; retain DiagTrack and Defender cloud/EDR connectivity. |
| Windows Hello face capabilities removed | Retain Hello/biometric components for secure host authentication. |
| Edge made uninstallable by editing system region policy | Retain Edge/WebView with background activity suppressed. The provided website warns the region-policy edit can cause Windows Update problems. |
| System Restore disabled, junctions deleted, Windows.old cleanup attempted | Keep recovery/rollback capability and compatibility junctions; avoid destructive setup cleanup. |
| Machine-wide script execution relaxed; every setup script run with Unrestricted | No global execution-policy change. Only process-scoped execution for reviewed setup scripts. Execution policy is not an application-control security boundary. |
| Task periodically moved update active hours; indefinite reboot avoidance | No anti-reboot task. Keep updates serviceable and use deliberate patch/reboot windows. |
| Feature payloads removed using `-Remove` | Disable the selected unused features without removing their payloads. Appx/FoD removals remain explicit and can require official sources to restore. |
| Notepad removed while legacy txt associations were added | Keep a basic editor and Terminal for recovery and administration. |
| Hidden and protected files shown in default profile | Keep those hidden, but show file extensions. |
| Global root ACL rewrite | Preserve stock root ACLs; lock down the new report directory only. |
| Aggressive consumer-app removals | Retain equivalent consumer removals with explicit dependency exclusions; add Photos, Snipping Tool, Alarms and To Do to the local-only minimal host profile. |

The original custom product key is not copied into activation settings or audit output. The new setup key is a publicly listed generic **edition selector** in the matching generator source; it is not a new license. Actual Workstations activation/entitlement is a user prerequisite.

## Coverage of the attached requirements

| Required capability | Base treatment | Later action/evidence |
|---|---|---|
| TPM 2.0, UEFI, Secure Boot, virtualization, SLAT, IOMMU, firmware protections | No bypasses; explicit VBS platform policy; firmware checks supplied | Enable/update in Dell firmware, verify actual hardware/SMM/MOR/Kernel DMA on the 9510. No software substitute. |
| Windows Pro or higher | Exact ProfessionalWorkstation edition guard, non-N x64 | Verify correct image/media/license and activate. |
| Windows hypervisor, VBS, HVCI and WHP | Configured/enabled; no full Hyper-V management/WSL/Sandbox roles added | Reboot and prove running security; trial ordinary VMs in WHP mode. |
| BitLocker and TPM | Retained; automatic device encryption not prevented | Encrypt host and VM-image volumes; independent recovery escrow and optional TPM+PIN. |
| WinRE, Hello, System Restore | Retained | Verify WinRE enabled on the selected disk layout; configure authentication/recovery. |
| Security Center, Defender AV/platform/UI | Preserved; native Defender hardened before third-party AV | Verify Bitdefender registration and supported Defender passive/EDR mode after licensed onboarding. |
| Sense client, DiagTrack and telemetry | Preserved; discovered Sense capability can be installed if missing | Actual FoD/source/network access and tenant onboarding; verify portal freshness and sensor errors. |
| Windows Update and component store | Preserved; no update blockers or ResetBase | Patch, restart, scan current updates; OEM updates are a separate check. |
| IPv4, default route, power notifications | Preserved; IPv6 also retained | Network connectivity/VPN route and suspend/resume tests. IPv4 alone is not a leak-prevention plan. |
| WFP, BFE, Windows Firewall infrastructure | Preserved; conservative native firewall baseline | Vendor coexistence, lockdown exceptions and full traffic tests; no blanket firewall-service deletion. |
| Credential Manager | Preserved; trigger-start behavior respected | Verify VMware encrypted-VM credential saving and optional keyring operations, without printing credentials. |
| Wi-Fi, DHCP, DNS, NLA, network drivers | Preserved; physical uplinks set Public | Dell-signed driver compatibility and actual uplink connection tests. |
| Windows Installer, Task Scheduler, Event Log/WMI, cryptography | Preserved; bounded auditing initialized | Install vendor products; collect actual logs and scheduled-tooling evidence. |
| Desktop/notification area | Explorer retained and visually simplified | Validate security tool notifications/alerts with standard-user sessions. |
| VMware VMnet1/VMnet8, NAT/DHCP services, vmrun | Windows dependencies retained; vendor binaries not included | Install supported release, create intended networks, verify actual service paths and functional guest networking. |
| Mullvad and Bitdefender drivers | No incompatible “add-back” shortcuts; HVCI retained | Verify current releases/licensing, signatures, drivers and shared WFP behavior. |
| Python, pywin32, keyring, Packer/plugin | Windows prerequisites retained; optional host tooling not installed | Install only if needed for host automation; run a real representative image build. |
| Optional Sysmon/LimaCharlie | Eventing/servicing infrastructure retained | Choose actual supported feature/distribution and configuration later. |
| Maximum future security configuration | Keep App Control/AppLocker/security-management infrastructure, servicing and identity stacks | Build a tested application/driver allowlist and security-product rules after actual installers/workloads are known. No untested enforced allowlist locks you out during base install. |

## Corrections and remaining uncertainties in the Markdown

* A baseline **64 GB storage device capacity** is different from 64 GB of required free disk space. Windows minimums do not size a VMware workload. No resource savings or VM capacity are measured by this bundle.
* All listed services need not run continuously. Sense can be absent until its supported capability exists and stopped until onboarding; VaultSvc, Windows Installer and servicing components can be demand/trigger-start. Protected service defaults should be preserved.
* Removing Defender, telemetry reporting or Security Center would undermine the intended EDR/AV combination. Keeping required diagnostic data is consistent with disabling consumer suggestions; a blanket telemetry blocklist is not applied.
* Keeping BitLocker available and allowing automatic device encryption do not prove that protection is on or that a usable independent recovery key exists.
* Exact `26H1u1` availability, its host/driver support, encrypted-VM credential behavior and its low-level/nested-virtualization limits were not verified from Broadcom live pages. The base targets ordinary VMs with VBS/WHP enabled; it does not promise nested virtualization.
* The exact 9510 firmware menu labels/version and SMM/MOR/DMA behavior remain hardware checks. The 9510 generation does not have the later Intel P/E hybrid layout referenced as a possibility in the supplied document.
* Security-product compatibility, ASR behavior in the final AV mode, native Sysmon feature availability, Defender cloud URLs/tenant connectivity, Bitdefender system requirements and vendor firewall coexistence remain release/tenant-specific checks.
* Official Mullvad source explicitly uses Windows WFP and describes DHCP/API/tunnel-control exceptions. A “no internet when disconnected” test must account for those intended exceptions. Do not interpret lockdown as no packets at all, or assume guest NAT routing from host-only VPN tests.
* A sealed VMware LAN segment has no host communication path. Packer build access needs a deliberately temporary host-reachable path; isolate it afterwards. A host-only VMware network itself includes the host and is not a sealed boundary.

## Sources actually inspected

| Source | Access/evidence | Used for |
|---|---|---|
| Your three uploads | Read in full as local references; all embedded original scripts extracted for review | Original settings, generator options/links, requirements and stated uncertainties. |
| [Schneegans generator source at the exact commit](https://github.com/cschneegans/unattend-generator/tree/97c1141d51a9cdae6831107cb3311c2f9eb8121b) | Read-only clone succeeded; HEAD matched the HTML/answer file commit | Embedded extraction technique, exact package/capability selectors, generic edition key, feature-removal behavior and schema. No project scripts were executed. |
| [Microsoft driver documentation: memory integrity and VBS](https://github.com/MicrosoftDocs/windows-driver-docs/blob/staging/windows-driver-docs-pr/bringup/device-guard-and-credential-guard.md) | Official source fetched successfully | VBS/HVCI's purpose and driver-compatibility constraints. It links the hardware and readiness documentation; those linked pages were not retrieved here. |
| [Mullvad security architecture](https://github.com/mullvad/mullvadvpn-app/blob/main/docs/security.md) | Official upstream source fetched successfully | WFP, traffic exceptions and lockdown-state behavior. |
| [Mullvad split-tunnel driver](https://github.com/mullvad/win-split-tunnel/blob/master/README.md) | Official upstream source fetched successfully | Windows driver/WFP interface and host prerequisites. |
| [tiny11builder README](https://github.com/ntdevlabs/tiny11builder/blob/main/README.md) | Upstream source fetched successfully | Explicit serviceability/WinSxS/Update/WinRE limitations of tiny11 core. Neither builder was run. |
| [PowerShell 7.5.4 release](https://github.com/PowerShell/PowerShell/releases/tag/v7.5.4) | Official Linux archive downloaded; SHA-256 verified against the release's checksum file before execution | Static PowerShell AST parsing only. This runtime is not bundled or required on Windows; scripts target inbox 64-bit Windows PowerShell 5.1. |

### Linked sources that could not be independently retrieved

The environment's HTTPS egress proxy returned `403 Forbidden` for Schneegans live usage/samples, Microsoft Learn, Broadcom/VMware blogs and KB pages, Bitdefender support and Dell support. No TLS/checksum verification was disabled and no unknown credential was requested. Microsoft document-source URLs tried as an alternative returned 404 for several moved/unavailable repositories; those are not used as verified evidence.

These links remain useful verification targets on your trusted staging machine:

* [Schneegans usage and driver/OEM media conventions](https://schneegans.de/windows/unattend-generator/usage/) and [sample scripts](https://schneegans.de/windows/unattend-generator/samples/).
* [Microsoft VBS hardware requirements](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-vbs), [memory-integrity enablement](https://learn.microsoft.com/en-us/windows/security/hardware-security/enable-virtualization-based-protection-of-code-integrity), and [unattend component reference](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/components-b-unattend).
* [Defender endpoint requirements](https://learn.microsoft.com/en-us/defender-endpoint/minimum-requirements), [AV coexistence](https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-antivirus-compatibility), [sensor event codes](https://learn.microsoft.com/en-us/defender-endpoint/event-error-codes), and [cloud connectivity](https://learn.microsoft.com/en-us/defender-endpoint/configure-proxy-internet).
* [BitLocker documentation](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/) and [Windows RE configuration](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/reagentc-command-line-options?view=windows-11).
* [Broadcom Workstation host OS support KB 315653](https://knowledge.broadcom.com/external/article/315653). Consult the installed release's current VBS/WHP and nested-virtualization limitations; do not treat an unverified article ID as authoritative for those limits.
* [Bitdefender firewall documentation](https://www.bitdefender.com/consumer/support/answer/89030) and your licensed product's current system requirements.
* [Dell XPS 15 9510 support](https://www.dell.com/support/home/en-us/product-support/product/xps-15-9510-laptop/docs) using the actual laptop Service Tag for drivers/BIOS.

Source-access restrictions limit independent confirmation of all vendor details. The delivered base settings are reviewable implementation choices, not a claim that every statement in the uploaded report was verified.
