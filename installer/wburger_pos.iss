#define MyAppName "W-Burger POS"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "W-Burger"
#define MyAppExeName "wburger_pos.exe"

[Setup]
AppId={{9A18F6BB-76AE-4F20-9BB5-WBURGERPOS001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\W-Burger POS
DefaultGroupName=W-Burger POS
DisableProgramGroupPage=yes
OutputDir=..\installer-output
OutputBaseFilename=W-Burger-POS-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\W-Burger POS"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\W-Burger POS"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch W-Burger POS"; Flags: nowait postinstall skipifsilent
