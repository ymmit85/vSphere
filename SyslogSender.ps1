Function SyslogSender ()
{
       <#
              .SYNOPSIS
                     UDP client creation to send message to a syslog server.
					 This script was sourced from https://www.sgc-univ.net/powershell-udp-client-and-syslog-messages/.
					 
					 
              .DESCRIPTION
                     Basic usage:
                           $Obj = ./SyslogSender 192.168.2.4
                           $Obj.Send("string message1")
                           $Obj.Send("string message2")
                $Obj.Send($message)
      
                           This uses the following defaults:
								  - Source : SyslogSender
                                  - Facility : user
                                  - Severity : info
                                  - Timestamp : now
                                  - Computername : name of the computer on which the script is executed.
                                  - Syslog Port: 514
      
                     Advanced usage:
                           $Obj = ./SyslogSender 192.168.231.3 432
                                  This defines a custom port when setting up the object
      
                           $Obj.Send("String Message", "String Facility", "String Severity", "String Timestamp", "String Hostname")
                                  This sends a message with a custom facility, severity, timestamp and hostname.
                                  i.e. $obj.Send("Script Error", "local7", "alert", $(Get-Date), $env:COMPUTERNAME)
								  
						   $Obj.Send("String Message" , "PowerShell Script.ps1", "alert", "user")
								This sends a message with the Source being defined in the message as "PowerShell Script.ps1", the message is also an "alert".
       #>
  
    Param
    (
        [String]$Destination = $(throw "ERROR: SYSLOG Host Required..."),
        [Int32]$Port = 514
    )
  
    $ObjSyslogSender = New-Object PsObject
    $ObjSyslogSender.PsObject.TypeNames.Insert(0, "SyslogSender")
    
	# Initialize the udp 'connection'
    $ObjSyslogSender | Add-Member -MemberType NoteProperty -Name UDPClient -Value $(New-Object System.Net.Sockets.UdpClient)
    $ObjSyslogSender.UDPClient.Connect($Destination, $Port)
    
	# Add the Send method:
    $ObjSyslogSender | Add-Member -MemberType ScriptMethod -Name Send -Value {
        
		Param
        (
                     [String]$Data = $(throw "Error SyslogSender: No data to send!"),
					 [String]$Source = "SyslogSender",
                     [String]$Severity = "info",
                     [String]$Facility = "user",
                     [String]$Timestamp = $(Get-Date),
                     [String]$Hostname = $env:COMPUTERNAME
        )
        
		# Maps used to translate string to corresponding decimal value
        $FacilityMap = @{ 
                     "kern" = 0;"user" = 1;"mail" = 2;"daemon" = 3;"security" = 4;"auth" = 4;"syslog" = 5;
                     "lpr" = 6;"news" = 7;"uucp" = 8;"cron" = 9;"authpriv" = 10;"ftp" = 11;"ntp" = 12;
                     "logaudit" = 13;"logalert" = 14;"clock" = 15;"local0" = 16;"local1" = 17;"local2" = 18;
                     "local3" = 19;"local4" = 20;"local5" = 21;"local6" = 21;"local7" = 23;
			}
        $SeverityMap = @{ 
                     "emerg" = 0;"panic" = 0;"alert" = 1;"crit" = 2;"error" = 3;"err" = 3;"warning" = 4;
                     "warn" = 4;"notice" = 5;"info" = 6;"debug" = 7;
              }
        # Map facility, default to user
              $FacilityDec = 1
        if ($FacilityMap.ContainsKey($Facility))
        {
            $FacilityDec = $FacilityMap[$Facility]
        }
 
        # Map severity, default to info
              $SeverityDec = 6
        if ($SeverityMap.ContainsKey($Severity))
        {
            $SeverityDec = $SeverityMap[$Severity]
        }       
 
        # Calculate PRI code
		$PRI = ($FacilityDec * 8) + $SeverityDec
             
		#Format message content to include severity
		$Content = "$($Severity.Substring(0).ToUpper()) $data"
		#write-host "$content"
 
        #Build message content
        $Message = "<$PRI> $Timestamp $Hostname $Content - $Source"
        #write-host $Message
       
        #Format the data, recommended is a maximum length of 1kb
        $Message = $([System.Text.Encoding]::ASCII).GetBytes($message)
        
		#write-host $Message
        if ($Message.Length -gt 1024)
        {
            $Message = $Message.Substring(0, 1024)
        }
        # Send the message
        $this.UDPClient.Send($Message, $Message.Length) | Out-Null
 
    }
    $ObjSyslogSender
}