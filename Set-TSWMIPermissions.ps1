##
#  Purpose: Set Terminal Services permissions across multiple RDS Session Hosts (servers.txt)
#    to allow Shadowing (Screen Control), with full interaction capabilities
#    Can support:
#        RDS Session Manager.exe  <automatically connects to all machines inside servers.txt>
#        msra.exe /offerra <servername>
#        
#  Author: Simon Jackson (admin@jacksonfamily.me)
#  Created: 2017/05/11
#  Reading:
#    http://msdn.microsoft.com/en-us/library/aa383815%28v=vs.85%29.aspx
#    https://technet.microsoft.com/en-us/library/cc753032.aspx
##

Import-Module ActiveDirectory

#Reset to factory defaults
$reset = $false

#This filename and it's conntents (RDS Session Hosts) are required to be managed by an administrator
$filepath = 'C:\Program Files\Remote Desktop Services Manager 2012 R2\servers.txt'

#What type of Terminal Services protols are we using?
#$protocols = "ICA-CGP","ICA-CGP-1","ICA-CGP-2","ICA-CGP-3","ICA-TCP","ICA-SSL","RDP-Tcp"
$protocols = "RDP-Tcp"

#What is the AD Group/Username we are going to grant Remote Shadowing/Control to?
$groupname = 'Screen Control - Solicited RDS'
$groupmembers = (Get-ADGroupMember $groupname -Recursive) | % { Get-ADUser $_.samaccountname | Select Name,userPrincipalName }
#Note the -Recursive flag here helps find nested group members - very useful!

#Get the static list of servers
$servers = Get-Content -path $filepath

#Loop through the list
$servers | % {
    write-host Connecting to: $_ -ForegroundColor Cyan
    #Get the WMI Namespace for the Terminal Services RDP-Tcp Object
    $ts = Get-WmiObject -ComputerName $_ -Namespace "Root/CimV2/TerminalServices" -Class Win32_TSPermissionsSetting
    #loop through protocols
    ForEach($protocol in $protocols){
        Write-Host $protocol -ForegroundColor DarkCyan
        $tsprotocol = $ts | where-Object {$_.TerminalName -eq $protocol}
        #Exclude any non-specified protocol
        If ($tsprotocol -ne $null) {
            # RESET IF YOU LOSE ANY GROUP MEMBERS        
            If ($reset) { 
                Write-Host Resetting permisisons to factory defaults -ForegroundColor DarkCyan
                $tsprotocol.RestoreDefaults | Out-Null
            }
            #ADD each user to the list of approved users:
            ForEach($samaccountname in $groupmembers) {
                Write-Host Adding a new TS Operator: $samaccountname.Name -ForegroundColor DarkCyan
                $tsprotocol.AddAccount($samaccountname.userPrincipalName,2) | Out-Null
            }
        }
        Write-Host #blank line
    }
}
