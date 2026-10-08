"""Static packaging/policy checks. Does not validate Windows runtime or an ISO catalog."""
from pathlib import Path
from lxml import etree as E
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent
U = 'urn:schemas-microsoft-com:unattend'
X = 'https://schneegans.de/windows/unattend-generator/'
ns = {'u': U, 'x': X}
tree = E.parse(str(ROOT / 'autounattend.xml'), E.XMLParser(resolve_entities=False))
profile = json.loads((ROOT / 'HostProfile.json').read_text())
checks = []

def check(name, condition):
    checks.append({'name': name, 'pass': bool(condition)})
    if not condition:
        raise AssertionError(name)

check('XML root/pass order', tree.getroot().tag == '{%s}unattend' % U and
      [s.get('pass') for s in tree.findall('u:settings', ns)] == ['windowsPE', 'specialize', 'oobeSystem'])
embedded = tree.findall('x:Extensions/x:File', ns)
check('Eight expected embedded payloads', len(embedded) == 8)
for node in embedded:
    name = node.get('name')
    check('Safe embedded filename ' + name, re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]+\.(ps1|json|xml)', name) is not None)
    check('Embedded parity ' + name, node.text == (ROOT / name).read_text())
    check('Embedded destination ' + name, node.get('path') == '%WINDIR%\\Setup\\Scripts\\HostBase\\' + name)
for tag in ['AutoLogon', 'UserAccounts', 'DiskConfiguration', 'InstallTo', 'InstallToAvailablePartition']:
    check('Absent ' + tag, not tree.findall('.//u:' + tag, ns))
payload = (ROOT / 'autounattend.xml').read_text()
for unsafe in ['BypassTPMCheck', 'BypassSecureBootCheck', 'BypassRAMCheck', 'BypassNRO',
               'SkipMachineOOBE', 'SkipUserOOBE', 'Unrestricted', 'Set-ExecutionPolicy',
               'IntegratedServicesRegionPolicySet.json', 'Disable-ComputerRestore']:
    check('Absent unsafe setting ' + unsafe, unsafe not in payload)
check('Workstations setup key', tree.find('.//u:UserData/u:ProductKey/u:Key', ns).text == 'DXG7C-N36C4-C4HTG-X4T3X-2YV77')
check('No specialize activation key', not tree.findall("u:settings[@pass='specialize']/u:component/u:ProductKey", ns))
check('No wildcard Appx removal', all('*' not in name and '?' not in name for name in profile['removeAppx']))
check('Protected apps preserved', not set(profile['removeAppx']) & set(profile['protectedAppx']))
check('Required services preserved', not set(profile['disabledServices']) & set(profile['requiredServices']))
check('No protected capability removal', all(not any(x.lower() in name.lower() for x in ['sense','bitlocker','hello']) for name in profile['removeCapabilityPrefixes']))
check('WHP and security feature retention', not set(profile['disableFeatures']) & {'HypervisorPlatform','VirtualMachinePlatform','Microsoft-Hyper-V','Windows-Defender','BitLocker','NetFx4-AdvSrvs'})
base = (ROOT / 'Apply-Base.ps1').read_text()
for name, snippet in {
    'WHP enabled': 'Enable-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -All -NoRestart',
    'Hypervisor autostart': "@('/set', 'hypervisorlaunchtype', 'auto')",
    'VBS enabled': "'EnableVirtualizationBasedSecurity' 1",
    'HVCI enabled': "HypervisorEnforcedCodeIntegrity\" 'Enabled' 1",
    'Secure Boot and DMA required': "'RequirePlatformSecurityFeatures' 3",
    'No HVCI firmware lock': "HypervisorEnforcedCodeIntegrity\" 'Locked' 0",
    'Credential Guard without firmware lock': "'LsaCfgFlags' 2",
    'Required telemetry retained': "'AllowTelemetry' 1",
    'No feature payload destruction': 'Disable-WindowsOptionalFeature -Online -FeatureName $name -NoRestart',
}.items():
    check(name, snippet in base)
commands = tree.findall("u:settings[@pass='specialize']//u:RunSynchronousCommand", ns)
check('Ordered extract/apply with exit propagation', [c.find('u:Order', ns).text for c in commands] == ['1','2'] and "if (-not $?) { exit 1 }" in commands[1].find('u:Path', ns).text)
check('No download-and-execute in install payload', all(x.lower() not in payload.lower() for x in ['Invoke-WebRequest','DownloadString','Start-BitsTransfer','curl.exe','Invoke-Expression']))
taskbar = E.parse(str(ROOT / 'TaskbarLayoutModification.xml'))
check('Taskbar retains a functional Explorer pin', 'File Explorer.lnk' in E.tostring(taskbar).decode())
# The optional schema argument is the matching generator's generic structure schema.
import sys
if len(sys.argv) > 1:
    schema = E.XMLSchema(E.parse(sys.argv[1]))
    check('Generator generic answer-file XSD', schema.validate(tree))
    if not schema.validate(tree):
        print(schema.error_log)
report = {'kind': 'static-only', 'passed': len(checks), 'checks': checks,
          'xml_sha256': hashlib.sha256((ROOT / 'autounattend.xml').read_bytes()).hexdigest()}
(ROOT / 'static-validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS: %d static packaging/policy checks. Windows runtime and ISO-specific WSIM validation remain unrun.' % len(checks))
