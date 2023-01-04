
<#
.SYNOPSIS
    Script will grab a list of hostnames in a text file and find the switch port/VLAN for each.

.PARAMETER local
    OPTIONAL: Switch to denote whether script should run only on local machine

.PARAMETER path
    REQUIRED: Location of file containing hostnames (one per line)

.PARAMETER name
    REQUIRED: Name of the input file at above location

.PARAMETER logSuffix
    OPTIONAL: Can be used to add a suffix to the log file name

.OUTPUTS
    Log/output stored in C:\Windows\Temp\<name>.log

.NOTES
    Version:        1.2
    Author:         Andrew Seamon
    Date:           1/3/23
    Purpose/Change: Add support for multiple NICs
  
.EXAMPLE
Call script with hostname file stored on Bob's Desktop
    
    
    PS C:\Users\USER\Desktop\Scripts> ./Get-SwitchPort_1.3.23.ps1 -path ../ -name servers.txt -LogSuffix _servers

.EXAMPLE
Call script with local machine only
    
    
    PS C:\Users\USER\Desktop\Scripts> ./Get-SwitchPort_1.3.23.ps1 -local -LogSuffix _LocalTest
    

    Directory: C:\temp
    

    Mode                 LastWriteTime         Length Name                                    
    ----                 -------------         ------ ----                                    
    -a----          1/3/2023   2:02 PM              0 Get-SwitchPort.log                      


#>

#-----------------------------------------------------------[Parameters]-----------------------------------------------------------

param(
    [switch]$local,                                            # If $local = $true, run only with local machine as host.
    [string]$path='[Environment]::GetFolderPath("Desktop")',   # Allow for custom input file directory. Assume Desktop.
    [string]$name='computers.txt',                              # Allow for custom input file name. Assume 'computers.txt'.
    [string]$logSuffix=''
)

if('local path name'.Split().Where{$PSBoundParameters.ContainsKey($_)}.Count -eq 0) {
    $local = $true
    Write-Host "Default to local only"
}

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"

Import-Module PSLogging

Clear-Variable hostnameFile -ErrorAction SilentlyContinue

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.2"

#Log File Info
$global:sLogPath = "C:\temp"
$global:sLogName = "Get-SwitchPort$LogSuffix.log"
$global:sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#Input File Info
if($local) {                                                         # If running with -local
    $file = New-TemporaryFile                                        # Create a temporary file
    Add-Content -Path $file -Value $env:COMPUTERNAME                 # Add the local host to it
    $hostnameFile = $file.FullName                                   # Point $hostnameFile to it
}
else{                                                                # If running without -local
    $hostnameFile = Join-Path -Path $path -ChildPath $name           # Grab path and filename normally
}

#Credential
$username = '' # ELEVATED USERNAME HERE
$password = '' # PASSWORD HERE
$secpw = ConvertTo-SecureString $password -AsPlainText -Force
$global:cred  = New-Object Management.Automation.PSCredential ($username, $secpw)

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Toggle-WinRM {
    param(
        $computerName
    )
   
    if (Test-Connection $computerName) {

        Write-Host "Successfully pinged $computerName"
        $status = Get-Service -Name 'WinRM' -ComputerName $computerName | Select Status -ExpandProperty Status
        if($status -eq 'Running'){
            Invoke-WmiMethod -Path "Win32_Service.Name='WinRM'" -Name StopService -Computername $computerName
            Write-Host "WinRM disabled on $computerName"
            return $false
        }
        else{
            Invoke-WmiMethod -Path "Win32_Service.Name='WinRM'" -Name StartService -Computername $computerName
            write-Host "WinRM enabled on $computerName"
            return $true
        }

#        Invoke-WmiMethod -Credential $cred -ComputerName $computerName -Path win32_process -Name create -ArgumentList "powershell.exe -command Enable-PSRemoting -SkipNetworkProfileCheck -Force"
#        Invoke-WmiMethod -Credential $cred -ComputerName $computerName -Path win32_process -Name create -ArgumentList "powershell.exe -command WinRM QuickConfig -Quiet"

    } else {

         Write-Host "Cannot ping $computerName"
         return $false
    }
}

Function Get-SwitchPort{
    Param(
        [string]$hostname = $env:COMPUTERNAME
    )
    Begin{
        $defaultEnabled = 0
        Write-LogInfo -LogPath $global:sLogFile -Message " "
        Write-LogInfo -LogPath $global:sLogFile -Message "Starting on [$hostname]"
        if (!(Test-WSMan $hostname -ErrorAction SilentlyContinue)) { # If WinRM not Enabled
            if (Toggle-WinRM $hostname) {                        # Enable WinRM and log it
                Write-LogInfo -LogPath $global:sLogFile -Message "WinRM enabled on [$hostname]"
            }
        } else {
            $defaultEnabled = 1                                          # WinRM enabled by default. Change $var to match.
            Write-LogInfo -LogPath $global:sLogFile -Message "WinRM already enabled on [$hostname]"
        }
    }
    Process{
            $slashHostname = "\\$hostname"
            $hostname = $slashHostname.Substring(2)
        Try{
            if($local){
                $outText = Invoke-DiscoveryProtocolCapture -Force -Type LLDP | Get-DiscoveryProtocolData | Select-Object Computer,Device,Port,PortDescription,VLAN,Connection,IPAddress

                # ---------- Grab IPs and Interface Names ----------
                $IPAddresses = Get-NetIPAddress -AddressFamily IPv4 | Select-Object IPAddress, InterfaceAlias
                # ------------- Combine into one list --------------
                $outText | Add-Member -MemberType AliasProperty -Name InterfaceAlias -Value Connection
                $outText = Update-Object -LeftObject $outText -RightObject $IPAddresses -On InterfaceAlias
                # --------------------------------------------------

                $outText | Out-File $global:sLogFile -Append -Encoding UTF8
            }
            else{
                Write-Host "Hostname: $hostname"
                $outText = ($hostname | Invoke-DiscoveryProtocolCapture -Force -Credential $cred -Type LLDP | Get-DiscoveryProtocolData | Select-Object Computer,Device,Port,PortDescription,VLAN,Connection,IPAddress)
                if (!$outText){
                    Write-LogWarning -LogPath $global:sLogFile -Message "Failed to capture discovery packets for [$hostname]"
                    Write-LogInfo -LogPath $global:sLogFile -Message " "
                    Write-Host "Failed to capture discovery packets for [$hostname]"
                }
                else{
                    Write-LogInfo -LogPath $global:sLogFile -Message "Port information grabbed for [$hostname]"
                    Write-LogInfo -LogPath $global:sLogFile -Message " "

                    # ---------- Grab IPs and Interface Names ----------
                    $session = New-CimSession -Credential $cred -ComputerName $hostname
                    $IPAddresses = Get-NetIPAddress -CimSession $session -AddressFamily IPv4 | Select-Object IPAddress, InterfaceAlias
                    Get-CimSession | Remove-CimSession
                    # ------------- Combine into one list --------------
                    $outText | Add-Member -MemberType AliasProperty -Name InterfaceAlias -Value Connection
                    $outText = Update-Object -LeftObject $outText -RightObject $IPAddresses -On InterfaceAlias
                    # --------------------------------------------------

                    $outText | Out-File $global:sLogFile -Append -Encoding UTF8
                }
            }
            Start-Sleep 1
        }
        Catch{
            Write-LogWarning -LogPath $global:sLogFile -Message "Failed to grab port information for [$hostname]"
            Write-LogWarning -LogPath $global:sLogFile -Message " "
            Write-LogError -LogPath $global:sLogFile -Message "[ERROR]  $_.Exception" -ExitGracefully $True
        }
    }
    End{
        If ($defaultEnabled -eq 0){
            if(!(Toggle-WinRM $hostname)){
                Write-LogInfo -LogPath $global:sLogFile -Message "WinRM disabled on [$hostname]"
            }
        }
    }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Log -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

if($local){
    Get-SwitchPort $hostname
}
else{
    ForEach($hostname in Get-Content $hostnameFile){
        $psVersion = Invoke-Command -ComputerName $hostname -Credential $cred -ScriptBlock{$PSVersionTable.PSVersion} | Select -ExpandProperty "Major"
        if($psVersion -lt 5){
            Write-LogInfo -LogPath $global:sLogFile -Message "[$hostname] is running Powershell v$psVersion and will be skipped."
            Write-Host "Skipping [$hostname] as it is running Powershell v$psVersion"
        } elseif((Get-WMIObject -ComputerName $hostname win32_computersystem -Credential $cred | Select -ExpandProperty Model) -eq "Virtual Machine"){
            Write-LogInfo -LogPath $global:sLogFile -Message "[$hostname] is a VM and will be skipped."
            Write-Host "[$hostname] is a VM and will be skipped"
    #    } elseif(!$portInfo){
    #        Write-LogInfo -LogPath $global:sLogFile -Message "[INFO]  Assumed [$hostname] has teamed interfaces and will be skipped."
    #        Write-Host "[$hostname] has teamed network interfaces and will be skipped"
        }
        else{
            Get-SwitchPort $hostname
        }
    }
}

Stop-Log -LogPath $sLogFile