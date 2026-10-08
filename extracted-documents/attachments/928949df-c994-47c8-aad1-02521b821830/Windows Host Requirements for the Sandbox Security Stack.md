# Windows Host Requirements for the Sandbox Security Stack

Oct 8, 2026 · @StudioC

## 1. Summary

The host must be Windows 11 Pro or higher on hardware with a TPM 2.0, Secure Boot, CPU virtualization and an IOMMU, and a debloat must leave seven Windows pieces intact. Those seven are the hypervisor stack, BitLocker, Windows Security Center, the Defender Antivirus platform, the telemetry service (`DiagTrack`), the update stack and the Windows Filtering Platform. Sections 2 to 4 list what is needed, section 6 gives the add-back order, and section 7 gives the checks.

Two traps matter most:

- **Telemetry blocking breaks Defender for Business.** Microsoft's event codes show onboarding and reporting failing when `DiagTrack` can't start, and the debloat kit we found disables telemetry services by default.
- **Removing Windows Security Center breaks Bitdefender.** Defender then stays active beside it, which Microsoft calls unsupported.

Each table row says whether it rests on a page I opened or on my own reasoning. Section 8 lists nine points still unconfirmed, including one gap in the earlier build spec: Packer can't reach a golden image that sits only on the sealed LAN segment.

## 2. Hardware and firmware prerequisites

The host needs a 64-bit CPU with virtualization extensions, a TPM 2.0 and UEFI Secure Boot. These are firmware and silicon features, so no software add-back can supply them. Requirement names below are quoted from [Microsoft's VBS requirements page](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-vbs).

| Requirement | What it must provide | Needed by |
| --- | --- | --- |
| 64-bit CPU with virtualization extensions | Intel VT-x or AMD-V; the Windows hypervisor runs only on these | VBS, memory integrity, VMware Workstation |
| Second Level Address Translation (SLAT) | Intel VT-x2 with Extended Page Tables (EPT), or AMD-V with RVI | VBS, memory integrity |
| IOMMU | Intel VT-d or AMD-Vi; all DMA-capable devices must sit behind it | VBS (DMA protection) |
| Trusted Platform Module (TPM) 2.0 | Listed as required for VBS; also holds the BitLocker key | VBS, BitLocker, Windows 11 |
| Secure Boot | "Secure Boot must be enabled on devices leveraging VBS" | VBS, memory integrity, Windows 11 |
| UEFI memory reporting | UEFI v2.6 Memory Attributes Table; executable memory read-only | VBS (firmware side) |
| SMM protection support | Firmware follows the Windows SMM Security Mitigations Table (WSMT) | VBS (firmware side) |
| Secure Memory Overwrite Request (MOR) v2 | Secure MOR v2 protects the MOR lock setting | VBS (firmware side) |
| Memory-integrity-compatible drivers | Every kernel driver must pass Code Integrity compatibility tests | Memory integrity |

The last row matters for this build. Any kernel driver the stack installs (VMware's network drivers, Mullvad's tunnel driver, Bitdefender's filter drivers) must be HVCI-compatible, or Windows will refuse to enable memory integrity or will block the driver.

**Firmware settings to confirm in the Dell BIOS:** virtualization technology on, VT for Direct I/O on, Secure Boot on, TPM on, UEFI boot mode. I haven't checked Dell's menu names for this model, so the agent should look them up for the exact XPS 15 generation.

## 3. Windows edition, features and services that must exist

Use Windows 11 Pro, Enterprise or Education; Home is not enough. Everything else below must survive the strip or be added back. The last column says how well each row is backed: **Docs** means a Microsoft or vendor page I opened this session, **Inference** means my reasoning, not yet confirmed on a real machine.

| Component | Why the stack needs it | Basis |
| --- | --- | --- |
| Windows 11 Pro, Enterprise or Education | Defender for Endpoint lists Pro, Enterprise, Education and Pro Education, not Home. BitLocker enablement lists Pro, Enterprise and Education editions, not Home ([MDE requirements](https://learn.microsoft.com/en-us/defender-endpoint/minimum-requirements), [BitLocker](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/)) | Docs |
| Windows 11 baseline | 64 GB free disk, 4 GB RAM, DirectX 12 and WDDM 2.0 graphics driver, 720p display, internet for updates ([Windows 11 requirements](https://learn.microsoft.com/en-us/windows/whats-new/windows-11-requirements)) | Docs |
| Windows hypervisor, VBS and memory integrity | The host security baseline; they also force VMware into its Windows Hypervisor Platform mode | Docs (VBS); earlier report (VMware mode) |
| Windows Hypervisor Platform optional feature | Lets Workstation 26H1u1 run while the Windows hypervisor is active | Earlier report; verify on the host |
| BitLocker feature and TPM | Encrypts the host disk. TPM 2.0 needs native UEFI, with Legacy and CSM modes off ([BitLocker](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/)) | Docs |
| Windows Security Center service (`wscsvc`) | Required for Defender to detect Bitdefender and go passive. If disabled, Defender "will stay **Active**" and conflicts with Bitdefender, "not supported" ([AV compatibility](https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-antivirus-compatibility)) | Docs |
| Microsoft Defender Antivirus platform (`WinDefend`) | "The Defender for Endpoint agent depends on Microsoft Defender Antivirus to scan files"; it runs passive beside Bitdefender ([MDE requirements](https://learn.microsoft.com/en-us/defender-endpoint/minimum-requirements)) | Docs |
| Sense client (`Microsoft.Windows.Sense.Client` capability) | The EDR sensor. Upgraded Home devices may need `DISM /online /Add-Capability /CapabilityName:Microsoft.Windows.Sense.Client~~~~` before onboarding | Docs |
| Connected User Experiences and Telemetry service (`DiagTrack`) | The EDR sensor registers as a dependent of it. Events 62, 17, 28 and 34 report onboarding or telemetry failure when it can't start; the fix is "Ensure the diagnostic data service is enabled" ([event codes](https://learn.microsoft.com/defender-endpoint/event-error-codes)) | Docs |
| IPv4 stack and internet access | "IPv4 stack must be enabled" for the Defender cloud service ([MDE requirements](https://learn.microsoft.com/en-us/defender-endpoint/minimum-requirements)) | Docs |
| Default route and power notifications | Mullvad infers connectivity from the default route and suspend state ([Mullvad architecture](https://github.com/mullvad/mullvadvpn-app/blob/main/docs/architecture.md)) | Docs |
| Windows Filtering Platform and Base Filtering Engine (`BFE`) | Mullvad's split-tunnel driver docs say its firewall subsystem "integrates with WFP" ([win-split-tunnel](https://github.com/mullvad/win-split-tunnel)); Bitdefender's firewall presumably does too | Docs for Mullvad driver; Inference for the rest |
| Credential Manager (`VaultSvc`) | Workstation 26H1 saves encrypted-VM credentials in the host's credential manager ([26H1 announcement](https://blogs.vmware.com/cloud-foundation/2026/05/14/announcing-vmware-workstation-and-fusion-26h1/)); Python `keyring` uses it too | Docs (VMware); Inference (keyring) |
| Windows Update stack and component store | Patching the host, since Workstation patches arrive separately but Windows and Defender platform patches do not | Inference |
| Wi-Fi: WLAN AutoConfig, DHCP Client, DNS Client, Network Location Awareness, and the Intel Wi-Fi driver | The laptop's only uplink; NLA profiles drive the Public-network rules | Inference |
| Windows Installer, Task Scheduler, Event Log services | Installing Workstation and Mullvad updates, scheduled rebuilds, reading Defender and Sysmon events | Inference |
| Desktop session with a notification area | Workstation, Mullvad and Bitdefender are GUI apps; Bitdefender's Alert-mode prompts and Mullvad's status icon appear there | Inference |

## 4. What each security product adds to the host

Five products put code on the host. Each row lists what the agent must install and what it needs from Windows.

| Product | Host-side pieces | Needs from Windows | Basis |
| --- | --- | --- | --- |
| VMware Workstation Pro 26H1u1 | Virtual network adapters for VMnet1 (host-only) and VMnet8 (NAT), the NAT service (`vmnat.exe`), the DHCP service (`vmnetdhcp.exe`), the `vmrun` command-line tool. It is a 64-bit app from 26H1. Free for commercial use; the download needs a Broadcom account | Windows 10 20H1 or later, or Windows 11, 64-bit ([host OS list](https://knowledge.broadcom.com/external/article/315653)); Windows Hypervisor Platform when VBS is on; Credential Manager | Docs (host OS, 26H1); Inference (service names) |
| Mullvad VPN | A background service, a WireGuard tunnel, and a kernel-mode split-tunnel driver (KMDF) ([win-split-tunnel](https://github.com/mullvad/win-split-tunnel)). Settings the design needs: Lockdown mode on, Local network sharing off, malware DNS blocker on | A default route; the Windows Filtering Platform. Its firewall allows DHCP in every state ([Mullvad security docs](https://github.com/mullvad/mullvadvpn-app/blob/main/docs/security.md)) | Docs; Inference (BFE) |
| Bitdefender Total Security | Its own antivirus, firewall (Stealth mode, Alert mode, rules list) and filter drivers. I[n this design it replaces Windows Firewall (my earlier guidance; Bitdefender's firewall overview page covers Stealth mode, Alert mode and rules, not that replacement](https://www.bitdefender.com/consumer/support/answer/89030)) | Windows Security Center to register as the primary antivirus; internet access to activate the licence; allow rules for `vmnat.exe` and `vmnetdhcp.exe` | Docs (firewall); Inference (activation) |
| Defender for Business sensor | Onboarding package from the Microsoft 365 admin center. Defender Antivirus runs in passive mode beside Bitdefender; the EDR sensor keeps reporting. Attack surface reduction rules do not work in passive mode ([AV compatibility](https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-antivirus-compatibility)) | Pro or higher, `DiagTrack`, `Sense`, `WinDefend`, `wscsvc`, IPv4, internet to the Defender cloud service. I did not open Microsoft's list of required URLs | Docs |
| Python glue and image tooling | Python 3 with `pywin32` and `keyring`; Packer with the HashiCorp VMware plugin | Credential Manager, Task Scheduler, Event Log | Earlier report |

**Passive mode is a documented outcome here.** Microsoft's table lists a non-Microsoft antivirus with Smart App Control on Evaluation or On as passive for Defender, whether or not the device is onboarded. That table covers the combination, but it does not say whether Smart App Control itself keeps working beside Bitdefender, so treat Smart App Control as optional.

## 5. Where aggressive debloating breaks the stack

The common debloat tools remove several of the components in section 3. This table pairs each action with what it breaks, so the agent can skip or reverse it. The host is a security boundary, so it should be stripped far less than the sandbox guests.

| Debloat action | What it breaks | Basis |
| --- | --- | --- |
| Disabling telemetry services or `DiagTrack` (the [windows-debloat-automated](https://github.com/lotusflowr/windows-debloat-automated) `SystemSetup.ps1` "disabling telemetry services"; telemetry-blocking tools generally) | Defender for Business onboarding and reporting: events 62, 17, 28 and 34 | Docs (both sides) |
| Telemetry blocklists and firewall rules (`WindowsSpyBlocker.ps1`) | May block the Defender cloud connection; adds a second rule set beside Bitdefender's firewall | Inference |
| Disabling or removing Windows Security Center | Defender stays active beside Bitdefender; Microsoft calls that "not supported" | Docs |
| Removing or disabling Defender (the Unattend Generator's **Disable Windows Defender** option, tiny11 core) | The Defender for Endpoint agent depends on Defender Antivirus to scan files, so EDR reporting is impaired | Docs |
| Removing the component store and Windows Update (tiny11 core, Nano11) | The host can't be patched; tiny11 core says Windows Update "would put the system in a state of failure" ([tiny11builder](https://github.com/ntdevlabs/tiny11builder)) | Docs |
| Nano11 removing BitLocker, Windows Hello and WinRE, and bypassing TPM and Secure Boot checks ([Nano11 article](https://kelexine.is-a.dev/blog/nano11-builder-development)) | The disk-encryption and Secure Boot requirements in sections 2 and 3 | Docs |
| Unattend Generator options **Disable Windows Update**, **Prevent device encryption**, **Disable Smart App Control** ([generator](https://schneegans.de/windows/unattend-generator/)) | Host patching and BitLocker. Leave all three unticked on the host | Docs |
| Removing optional features (`SysPrep_Debloater.ps1`) | Could remove Windows Hypervisor Platform, the Sense capability or BitLocker. I did not read which features it removes | Inference; read the script |
| Replacing Explorer with a minimal shell | May lose the notification area that Bitdefender prompts and the Mullvad icon use | Inference |

## 6. Ordered add-back checklist

The order matters: firmware first, patching before security software, and Bitdefender before Defender onboarding so Defender settles into passive mode correctly. Run the section 7 check after each step.

1. **Firmware.** Turn on virtualization and VT-d, Secure Boot and the TPM; set native UEFI with Legacy and CSM off. Update the Dell BIOS.
2. **Windows.** Install Windows 11 Pro or higher from a stock ISO. Keep the component store, and don't use the options listed in section 5.
3. **Patch.** Run Windows Update until nothing remains. Confirm the update path works before any trimming.
4. **BitLocker.** Turn it on and store the recovery key off the laptop.
5. **Memory integrity.** Confirm VBS and memory integrity are running (Windows Security ‣ Device security ‣ Core isolation).
6. **Windows Hypervisor Platform.** Enable it under Turn Windows features on or off, then reboot.
7. **Bitdefender Total Security.** Install, activate, and confirm Windows Security Center lists it as the antivirus. Set the Wi-Fi adapter to Public and Stealth mode on.
8. **Defender for Business.** Onboard from the Microsoft 365 admin center. Confirm Defender Antivirus is passive and the `Sense` and `DiagTrack` services run.
9. **Mullvad.** Install, turn on Lockdown mode and the malware DNS blocker, leave Local network sharing off, and disable Bitdefender's built-in VPN. If Bitdefender fails to load at boot, turn off Mullvad auto-connect.
10. **VMware Workstation Pro 26H1u1.** Install, then configure VMnet1 and VMnet8 as in section 3.3 of the build spec. Add Bitdefender allow rules for `vmnat.exe` and `vmnetdhcp.exe`.
11. **Tooling.** Install Python 3 with `pywin32` and `keyring`, Packer with the VMware plugin, and put `vmrun` on the path.
12. **Optional telemetry.** Enable native Sysmon (`Dism /Online /Enable-Feature /FeatureName:Sysmon`) and LimaCharlie. Defender for Business already gives EDR.
13. **Trim last.** Only now remove anything else, one change at a time, re-running section 7 after each.

## 7. Checks that prove each feature is present

These are the commands and screens the agent can use after each step. I have not run any of them on your laptop, so treat the expected results as what the feature should show.

| Feature | Check | Expected |
| --- | --- | --- |
| TPM and Secure Boot | PowerShell: `Get-Tpm`, `Confirm-SecureBootUEFI` | TPM present and ready; `True` |
| Hypervisor, VBS and memory integrity | `msinfo32` System Summary, or `systeminfo` | Virtualization-based security **Running**; "A hypervisor has been detected" |
| BitLocker | `manage-bde -status` | Protection **On** for the system drive |
| Core services | `Get-Service wscsvc, WinDefend, Sense, DiagTrack, BFE, VaultSvc` | All **Running** |
| Defender passive | `Get-MpComputerStatus`, property `AMRunningMode` | Passive mode while Bitdefender is the antivirus |
| Defender for Business | Defender portal device list; Event Viewer `Microsoft-Windows-SENSE/Operational` | Device shows as onboarded; no event 62, 17, 28 or 34 |
| Windows Update | Settings ‣ Windows Update ‣ Check for updates | Completes with no error |
| Mullvad | Mullvad app status and the Mullvad connection check page | Connected; lockdown on; with the tunnel dropped, the host has no internet |
| Bitdefender firewall | Firewall ‣ Settings ‣ Application access with Mullvad connected | New entries keep appearing |
| VMware networking | Workstation Virtual Network Editor; `vmrun -T ws list` | VMnet1 and VMnet8 present; `vmrun` runs |
| Credential storage | `cmdkey /list` after saving a VM encryption password | Entry listed |

## 8. Unverified items

These are the points I could not confirm from an official page this session. The agent should settle each on the real machine.

1. **Driver compatibility.** Whether VMware's network drivers, Mullvad's drivers and Bitdefender's filter drivers are all compatible with memory integrity. Microsoft requires every kernel driver to be compatible; I have not seen it confirmed for these products.
2. **Windows service names.** The VMware service names (`vmnat.exe`, `vmnetdhcp.exe` and the authorization service) come from my earlier spec, not a page I opened this session.
3. **Mullvad's firewall dependency.** Only the split-tunnel driver docs mention WFP. I did not confirm that Mullvad needs the Base Filtering Engine or the Windows Firewall service to stay on.
4. **Defender events.** The planned alert hook reads Defender events 1116 and 1117. With Defender passive beside Bitdefender, those events may not fire. Test before relying on them.
5. **Debloat script contents.** I did not read which optional features `SysPrep_Debloater.ps1` removes, or what the other scripts in that kit change.
6. **Defender connection URLs.** I did not open Microsoft's list of URLs the sensor must reach, so the agent should check it against Bitdefender and Mullvad rules.
7. **Dell details.** I don't know the XPS 15 generation. If it has a hybrid performance and efficiency core CPU, William Lam has a post on Workstation performance with those CPUs, which I did not open. Dell's BIOS menu names and firmware update path on a stripped OS are also unchecked.
8. **Packer reachability (a gap in the build spec).** The golden image sits on SANDBOX-NET, which has no host adapter, so Packer on the host can't reach it over WinRM or SSH. Packer needs a host-reachable network (VMnet1 or VMnet8) during the build, with the adapter switched to SANDBOX-NET afterwards. This is my reasoning, not tested.
9. **Bitdefender requirements.** I opened only its firewall pages, not its system requirements.

## 9. Sources

Pages opened for this report, as of Oct 8, 2026.

**Microsoft**

- [Defender for Endpoint minimum requirements](https://learn.microsoft.com/en-us/defender-endpoint/minimum-requirements)
- [Defender Antivirus compatibility with other security products](https://learn.microsoft.com/en-us/defender-endpoint/microsoft-defender-antivirus-compatibility)
- [Defender for Endpoint events and error codes](https://learn.microsoft.com/defender-endpoint/event-error-codes) (the last 4,000 characters were not read)
- [Defender for Endpoint proxy and internet connectivity](https://learn.microsoft.com/en-us/defender-endpoint/configure-proxy-internet)
- [VBS hardware requirements](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-vbs)
- [BitLocker overview and requirements](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/)
- [Windows 11 requirements](https://learn.microsoft.com/en-us/windows/whats-new/windows-11-requirements)

**VMware and Broadcom**

- [Host operating systems for Workstation (KB 315653)](https://knowledge.broadcom.com/external/article/315653)
- [Workstation and Fusion 26H1 announcement](https://blogs.vmware.com/cloud-foundation/2026/05/14/announcing-vmware-workstation-and-fusion-26h1/)

**Mullvad**

- [Architecture](https://github.com/mullvad/mullvadvpn-app/blob/main/docs/architecture.md)
- [Security and firewall behavior](https://github.com/mullvad/mullvadvpn-app/blob/main/docs/security.md)
- [Split-tunnel driver](https://github.com/mullvad/win-split-tunnel)

**Debloat tools**

- [tiny11builder](https://github.com/ntdevlabs/tiny11builder)
- [Nano11 Builder article](https://kelexine.is-a.dev/blog/nano11-builder-development)
- [windows-debloat-automated](https://github.com/lotusflowr/windows-debloat-automated)
- [Unattend Generator](https://schneegans.de/windows/unattend-generator/) (about 2,700 characters at the end were not read)

**Not opened:** Bitdefender's firewall overview appeared in search results only. The Workstation Hyper-V mode blog is cited by the earlier research report, not re-read here.
