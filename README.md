# Get-SwitchPort.ps1
## SYNOPSIS
Script to correlate hostnames in a text file to their switch port/VLAN for each. Script can also generate results for the local machine only.

## SYNTAX
```powershell
  ./Get-SwitchPort.ps1 [-local] [[-path] <String>] [[-name] <String>] [[-logSuffix] <String>] [<CommonParameters>]
```

## DESCRIPTION


## PARAMETERS
### -local &lt;SwitchParameter&gt;
OPTIONAL: Switch to denote whether script should run only on local machine
```
Required?                    false
Position?                    named
Default value                False
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -path &lt;String&gt;
REQUIRED: Location of file containing hostnames (one per line)
```
Required?                    false
Position?                    1
Default value                [Environment]::GetFolderPath("Desktop")
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -name &lt;String&gt;
REQUIRED: Name of the input file at above location
```
Required?                    false
Position?                    2
Default value                computers.txt
Accept pipeline input?       false
Accept wildcard characters?  false
```
 
### -logSuffix &lt;String&gt;
OPTIONAL: Can be used to add a suffix to the log file name
```
Required?                    false
Position?                    3
Default value
Accept pipeline input?       false
Accept wildcard characters?  false
```

## OUTPUTS
Log/output stored in C:\Windows\Temp\<name>.log

Purpose/Change: Add support for multiple NICs

## EXAMPLES
### EXAMPLE 1
```powershell
# Call script with hostname file stored on Bob's Desktop

PS C:\Users\Bob\Desktop\Scripts> ./Get-SwitchPort_1.3.23.ps1 -path ../ -name servers.txt -LogSuffix _servers
```

 
### EXAMPLE 2
```powershell
# Call script with local machine only

PS C:\Users\Bob\Desktop\Scripts> ./Get-SwitchPort_1.3.23.ps1 -local -LogSuffix _LocalTest
    

    Directory: C:\temp
    

    Mode                 LastWriteTime         Length Name                                    
    ----                 -------------         ------ ----                                    
    -a----          1/3/2023   2:02 PM              0 Get-SwitchPort.log
```


