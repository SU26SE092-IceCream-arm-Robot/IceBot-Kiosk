[Setup]
AppName=IceBot Kiosk Demo
AppVersion=1.0.0
DefaultDirName={pf}\IceBot Kiosk Demo
DefaultGroupName=IceBot Kiosk Demo
OutputDir=installer_output
OutputBaseFilename=IceBot_Kiosk_Demo_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\IceBot Kiosk Demo"; Filename: "{app}\icebot_kiosk.exe"
Name: "{commondesktop}\IceBot Kiosk Demo"; Filename: "{app}\icebot_kiosk.exe"; Tasks: desktopicon
