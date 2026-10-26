#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6F0C2E7A-3B1D-4C8E-9A52-7D4E1B9C0A31}
AppName=Barcode Labeler
AppVersion={#AppVersion}
AppPublisher=Barcode Labeler
DefaultDirName={autopf}\Barcode Labeler
DefaultGroupName=Barcode Labeler
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=Output
OutputBaseFilename=BarcodeLabelerSetup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\barcode_labeler.exe
ChangesAssociations=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Barcode Labeler"; Filename: "{app}\barcode_labeler.exe"
Name: "{autodesktop}\Barcode Labeler"; Filename: "{app}\barcode_labeler.exe"; Tasks: desktopicon

[Registry]
Root: HKA; Subkey: "Software\Classes\.labeldesign"; ValueType: string; ValueName: ""; ValueData: "BarcodeLabeler.Design"; Flags: uninsdeletevalue
Root: HKA; Subkey: "Software\Classes\BarcodeLabeler.Design"; ValueType: string; ValueName: ""; ValueData: "Barcode label design"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\BarcodeLabeler.Design\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\barcode_labeler.exe,0"
Root: HKA; Subkey: "Software\Classes\BarcodeLabeler.Design\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\barcode_labeler.exe"" ""%1"""

[Run]
Filename: "{app}\barcode_labeler.exe"; Description: "{cm:LaunchProgram,Barcode Labeler}"; Flags: nowait postinstall skipifsilent
