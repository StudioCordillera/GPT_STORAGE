"""Rebuild the self-contained answer file from the reviewed local payloads; no downloads."""
from pathlib import Path, PureWindowsPath
from lxml import etree as E

ROOT = Path(__file__).resolve().parent
U = 'urn:schemas-microsoft-com:unattend'
W = 'http://schemas.microsoft.com/WMIConfig/2002/State'
X = 'https://schneegans.de/windows/unattend-generator/'

def element(parent, tag, value=None, **attributes):
    node = E.SubElement(parent, '{%s}%s' % (U, tag), attributes)
    if value is not None:
        node.text = str(value)
    return node

def component(settings, name):
    return element(settings, 'component', name=name, processorArchitecture='amd64',
                   publicKeyToken='31bf3856ad364e35', language='neutral', versionScope='nonSxS')

root = E.Element('{%s}unattend' % U, nsmap={None: U, 'wcm': W})
root.append(E.Comment('Dell XPS 15 9510 / Windows 11 Pro for Workstations. Stock image, manual disk selection and interactive OOBE. No credentials or firmware-check bypasses.'))
pe = element(root, 'settings', **{'pass': 'windowsPE'})
international = component(pe, 'Microsoft-Windows-International-Core-WinPE')
setup_ui = element(international, 'SetupUILanguage')
element(setup_ui, 'UILanguage', 'en-US')
for key, value in [('InputLocale', '0409:00000409'), ('SystemLocale', 'en-US'), ('UILanguage', 'en-US'), ('UserLocale', 'en-US')]:
    element(international, key, value)
setup = component(pe, 'Microsoft-Windows-Setup')
userdata = element(setup, 'UserData')
product = element(userdata, 'ProductKey')
# Public edition-selection key from the matching Schneegans source, not an activation license.
element(product, 'Key', 'DXG7C-N36C4-C4HTG-X4T3X-2YV77')
element(product, 'WillShowUI', 'OnError')
element(userdata, 'AcceptEula', 'true')
element(setup, 'UseConfigurationSet', 'false')
# Deliberately omit DiskConfiguration, InstallTo, and InstallToAvailablePartition.
specialize = element(root, 'settings', **{'pass': 'specialize'})
shell = component(specialize, 'Microsoft-Windows-Shell-Setup')
element(shell, 'ComputerName', 'XPS-HOST')
deployment = component(specialize, 'Microsoft-Windows-Deployment')
commands = element(deployment, 'RunSynchronous')
extract_command = '''powershell.exe -NoProfile -Command "$ErrorActionPreference = 'Stop'; $xml = [xml]::new(); $xml.Load((Join-Path $env:windir 'Panther\\unattend.xml')); $sb = [scriptblock]::Create($xml.unattend.Extensions.ExtractScript.InnerText); Invoke-Command -ScriptBlock $sb -ArgumentList $xml;"'''
apply_command = '''powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; & (Join-Path $env:windir 'Setup\\Scripts\\HostBase\\Apply-Base.ps1'); if (-not $?) { exit 1 };"'''
for order, path, description in [(1, extract_command, 'Extract reviewed host payloads'), (2, apply_command, 'Configure serviceable minimal VMware security host')]:
    command = element(commands, 'RunSynchronousCommand', **{'{%s}action' % W: 'add'})
    element(command, 'Order', order)
    element(command, 'Description', description)
    element(command, 'Path', path)
    element(command, 'WillReboot', 'Never')
oobe = element(root, 'settings', **{'pass': 'oobeSystem'})
international = component(oobe, 'Microsoft-Windows-International-Core')
for key, value in [('InputLocale','0409:00000409'), ('SystemLocale','en-US'), ('UILanguage','en-US'), ('UserLocale','en-US')]:
    element(international, key, value)
shell = component(oobe, 'Microsoft-Windows-Shell-Setup')
oobe_settings = element(shell, 'OOBE')
element(oobe_settings, 'HideWirelessSetupInOOBE', 'false')
element(oobe_settings, 'HideOnlineAccountScreens', 'false')
# No UserAccounts, AutoLogon, OOBE bypass, global execution-policy change, or Wi-Fi password.
extensions = E.SubElement(root, '{%s}Extensions' % X, nsmap={None: X})
extract = E.SubElement(extensions, '{%s}ExtractScript' % X)
extract.text = E.CDATA('''
param([xml] $Document)
$ErrorActionPreference = 'Stop'
$destination = Join-Path $env:windir 'Setup\\Scripts\\HostBase'
New-Item -Path $destination -ItemType Directory -Force | Out-Null
foreach ($file in $Document.unattend.Extensions.File) {
    $name = $file.GetAttribute('name')
    if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]+\\.(ps1|json|xml)$') { throw 'Invalid embedded filename.' }
    $path = Join-Path $destination $name
    $encoding = [System.Text.UTF8Encoding]::new($true)
    [System.IO.File]::WriteAllText($path, $file.InnerText, $encoding)
}
''')
payload_names = ['Apply-Base.ps1', 'Initialize-Host.ps1', 'New-HostAccounts.ps1',
                 'Set-DefaultProfile.ps1', 'Test-Host.ps1', 'Trim-Apps.ps1',
                 'HostProfile.json', 'TaskbarLayoutModification.xml']
files = [ROOT / name for name in payload_names]
for path in files:
    embedded = E.SubElement(extensions, '{%s}File' % X, name=path.name,
                           path=str(PureWindowsPath('%WINDIR%', 'Setup', 'Scripts', 'HostBase', path.name)))
    embedded.text = E.CDATA(path.read_text(encoding='utf-8'))
E.ElementTree(root).write(str(ROOT / 'autounattend.xml'), encoding='utf-8', xml_declaration=True, pretty_print=True)
print('Built autounattend.xml with %d embedded payloads.' % len(files))
