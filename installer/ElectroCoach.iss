; Installateur Windows de BTS Électro Coach (Inno Setup 6, gratuit).
; Compilé automatiquement par GitHub Actions : voir .github/workflows/build.yml
;
; - installation par utilisateur, sans droits administrateur ;
; - mise à jour : relancer un installateur plus récent (même AppId) ;
; - DÉSINSTALLEUR fourni : menu Démarrer > « Désinstaller BTS Électro Coach »,
;   ou Paramètres Windows > Applications ; il propose de garder ou d'effacer
;   la progression enregistrée sur ce PC.

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\app\build\windows\x64\runner\Release"
#endif

#define AppName "BTS Électro Coach"
#define AppExe "ElectroCoach.exe"
#define AppPublisher "BTS Électro Coach (logiciel libre)"
#define AppUrl "https://github.com/nabeiroriviereadriano-design/Electro-Coach"

[Setup]
AppId={{6C1D2A90-4E7B-4F0C-9A3E-2B8F5D7E1C44}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
DefaultDirName={localappdata}\Programs\Electro Coach
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=ElectroCoach-Setup-{#AppVersion}
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{group}\Désinstaller {#AppName}"; Filename: "{uninstallexe}"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; mise à jour lancée par l'application (/RELAUNCH=1) : la rouvrir à la fin
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: ShouldRelaunch

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
function ShouldRelaunch: Boolean;
begin
  Result := ExpandConstant('{param:RELAUNCH|0}') = '1';
end;

// À la désinstallation : proposer d'effacer aussi la progression stockée sur ce PC.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    DataDir := ExpandConstant('{userappdata}\ElectroCoach');
    if DirExists(DataDir) then
    begin
      if UninstallSilent then
        exit;
      if MsgBox('Supprimer aussi ta progression enregistrée sur ce PC ?' + #13#10 + #13#10 +
                'Choisis « Non » pour la conserver (utile pour une réinstallation).',
                mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      begin
        DelTree(DataDir, True, True, True);
      end;
    end;
  end;
end;
