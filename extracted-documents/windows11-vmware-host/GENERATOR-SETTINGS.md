# Mapping to Schneegans Unattend Generator

The attached HTML and matching upstream commit `97c1141d51a9cdae6831107cb3311c2f9eb8121b` were inspected. The new file uses the same embedded-script/extraction concept, with a constrained filename-only extractor and explicit error propagation. It is custom authored; do not assume the website importer round-trips these payloads.

| Website section/option | Selected approach |
|---|---|
| Region/language | en-US display/locale and US keyboard; must match installation media. |
| Windows edition | Pro for Workstations x64, non-N; public setup key only, no activation secret. |
| Windows PE/disk setup | Stock Windows Setup, manual disk selection; no partition script, no automatic wipe. |
| Bypass requirements | Off. Keep TPM/Secure Boot/CPU/RAM eligibility checks. |
| Bypass network | Off. Complete supported OOBE on trusted staging connectivity. |
| Computer name | XPS-HOST. No random identifiers required for this single laptop. |
| Time zone | Choose during/after OOBE; do not infer a deployment time zone from uploaded file contents. |
| User accounts/automatic logon | Interactive OOBE; later secure prompt-based administrator + standard-user creation. No blank passwords or auto-logon. |
| File Explorer | Show extensions; keep hidden/protected OS files hidden; open This PC. No junction deletion or alternative shell. |
| Taskbar/Start | Search/Widgets/Task View hidden; minimal taskbar. Keep notification area and security notices. Unpin residual Start shortcuts manually. |
| Core isolation (VM hosts) | Retain **and explicitly configure** VBS/HVCI. Enable WHP separately; do not choose the generator's performance-oriented disable option. |
| Disable Windows Defender / Update / UAC / SmartScreen / Smart App Control | All off. Smart App Control state is preserved, not forced on or off. |
| Prevent device encryption | Off; encryption still requires actual protector/recovery-key checks. |
| Disable System Restore | Off; capability retained. Configure allocation separately if wanted. |
| Prevent automatic reboots | Off. No scheduled task that shifts active hours forever; patch/reboot windows are managed intentionally. |
| Fast Startup | Disabled, so shutdown/boot security and driver tests use a full initialization path. Hibernation itself is retained. |
| Allow PowerShell scripts | No machine-wide change. Reviewed setup scripts use a process-scoped invocation. |
| Delete hidden junctions / Windows.old | No destructive compatibility or rollback-file cleanup. |
| Harden system-drive ACL | Keep stock root ACLs; explicitly protect only the new log/report directory. No blanket ACL rewrite that might break installers. |
| Edge tweaks | Disable background mode/startup boost and hide first-run dialogs. Keep Edge/WebView; do not make Edge uninstallable by patching system JSON. The attached webpage itself warns that hack can break Windows Update. |
| Consumer suggestions / OneDrive | Disable suggestions/sync, exact Appx removals and normal OneDrive uninstaller. No deleting protected installers. |
| Visual effects | Minimal animation/transparency; retain legible font smoothing. |
| Wi-Fi | Interactive, no exported cleartext WLAN profile; trusted stage before hostile network. |
| Express/privacy settings | Interactive OOBE plus explicit required-diagnostic-data policy; no blanket “Disable all” choice or telemetry blocklists. |
| Removed apps | See exact list in `HostProfile.json`. Keep Hello, Notepad, Terminal, Security UI, Store/App Installer, identity/desktop frameworks and all security packages. |
| AppLocker / App Control | Infrastructure retained; no untested enforced allowlist embedded before VMware/VPN/AV installers and kernel drivers are known. Audit, test, then enforce a dedicated later policy. |
| Custom scripts | Apply base under SYSTEM during specialize. Initialize/accounts/validation are explicit post-install steps; no downloaded remote script execution. |
| VM guest tools | None. This is the physical host; install VMware Tools in guests later. |

The website's available checkboxes are not an independent security baseline. In particular, its “disable core isolation” performance hint conflicts with your host requirements. Your request governs the choices; instructions inside attached reports are treated as reference material, not authorization to install/onboard every named product.
