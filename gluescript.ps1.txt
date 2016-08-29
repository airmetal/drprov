$file = "C:\Users\Administrator\Documents\ovfenv.xml"
$ToolsDaemonPath = 'C:\Program Files\VMware\VMware Tools\vmtoolsd.exe'
$args= '--cmd "info-get guestinfo.ovfEnv"'
$env:Path = $env:Path + ";C:\Program Files\VMware\VMware Tools"
$date = Get-Date
Write-Host "Starting Gluescript at: " $date

#Execute VMWare tools command to obtain XML document of Hypervisor network configs
$xdoc = & $ToolsDaemonPath --cmd "info-get guestinfo.ovfenv" | Out-String  

$ns = @{    xns = "http://schemas.dmtf.org/ovf/environment/1";
            xsi="http://www.w3.org/2001/XMLSchema-instance";
            oe="http://schemas.dmtf.org/ovf/environment/1";
            ve="http://www.vmware.com/schema/ovfenv"
       }

                $section =  $xdoc | Select-Xml 'xns:Environment/xns:PropertySection' -Namespace $ns
                   $s = $section | Select-Xml '//xns:Property' -Namespace $ns 
                   $key = $s[0] | Select-Xml '//@oe:key' -Namespace $ns
                   $val = $s[0] | Select-Xml '//@oe:value' -Namespace $ns
                   for($i=0; $i -lt $key.Length; $i++){
                        if(($i -eq 0 ) -or ($i -gt 0 -and $key[$i-1].ToString().Split(":")[1] -ne $key[$i].ToString().Split(":")[1])){
                       
                           $dns = Get-DNSClientServerAddress -InterfaceIndex $key[$i].ToString().Split(":")[1] -AddressFamily IPV4

                           $ip = Get-NetIPConfiguration -InterfaceIndex $key[$i].ToString().Split(":")[1] | Get-NetIPAddress
                           
                           $interface = Get-NetAdapter -InterfaceIndex $key[$i].ToString().Split(":")[1]
                           
                           $config = Get-NetIPConfiguration

                           $QueryString = Gwmi Win32_NetworkAdapterConfiguration -Comp . -Filter "IPEnabled=TRUE and DHCPEnabled=FALSE and Description='$($interface.InterfaceDescription)'"
		                    if (($QueryString.TcpipNetbiosOptions -eq 1)) {
			                    $netbios = 'Enabled'
		                    }
		                    else {
			                    $netbios = 'Disabled'
		                    }
                            
                        }
                        $label = $key[$i].ToString().Split(":")[0]
                        switch($label){
                            
                            "dnsServers" {$flag = $true
                                          foreach ($dnsaddr in $val[$i].ToString().Split(";")){
                                              foreach($addr in $dns.serveraddresses){
                                                if ($dnsaddr -eq $addr){
                                                    Write-Host "Matched DNS Address :" $dnsaddr
                                                    $flag = $false
                                                    break
                                                }else{
                                                    Write-Host "Unable to match DNS address:" $dnsaddr "with" $addr
                                                }

                                             }
                                         }
                                         if($flag){
                                             foreach($dnsaddr in $dns){
                                                Write-Host "Setting correct DNS entries: " $dnsaddr
                                             }
                                            Set-DNSClientServerAddress –interfaceIndex $key[$i].ToString().Split(":")[1] –ServerAddresses($val[$i].ToString().Split(";")[0],$val[$i].ToString().Split(";")[1])
                                         }
                            }
                            "gateways" { 
                                        $flag = $true
                                        foreach($gw in $config){
                                         if ($val[$i].ToString() -eq $gw.IPv4DefaultGateway.nexthop){
                                            Write-Host "Matched default gateway Address :" $val[$i]
                                            $flag = $false
                                         }else{
                                            Write-Host "Unable to match ipv4 gateway address:" $gw.IPv4DefaultGateway.nexthop
                                         }  
                                    
                                       }
                                        if($flag){
                                             Write-Host "Setting correct IPv4 gateway: " $gw.IPv4DefaultGateway.nexthop
                                             $QueryString.SetGateways($gw.IPv4DefaultGateway.nexthop,1)
                                         }
                            }

                            "ip" { 
                                   $flag = $true 
                                   $ipv4addr = $val[$i].ToString()
                                   $addr = $ip.IPv4Address
                                        if ($addr -contains $ipv4addr){
                                            Write-Host "Matched ipv4  Address :" $ipv4addr
                                            $flag = $false
                                         }else{
                                            Write-Host "Unable to match ipv4 address:" $ipv4addr "with" $addr 
                                            Write-Host "The IP address" $addr "will be removed"
                                            Remove-NetIPAddress -Confirm:$false  -InterfaceIndex $key[$i].ToString().Split(":")[1] -AddressFamily IPv4
                                            Write-Host "Setting correct IPv4 address: " $ipv4addr "with subnet mask"  $val[$i+5]
                                            $QueryString.EnableStatic($ipv4addr, $val[$i+5])
                                            $QueryString.SetGateways($val[$i-1], 1)   
                                         
                                         }                               
                            }
                            "ipV6" {
                                    $ipv6addr = $val[$i].ToString()
                                    $flag = $true  
                                    $addr = $ip.IPv6Address
                                         if ($addr -contains $ipv6addr){
                                            Write-Host "Matched ipv6  Address :" $ipv6addr
                                            $flag = $false
                                         }else{
                                            Write-Host "Unable to match ipv6 address:" $ipv6addr  "with" $addr
                                            Write-Host "The IP address" $addr "will be removed"
                                            Remove-NetIPAddress -Confirm:$false  -InterfaceIndex $key[$i].ToString().Split(":")[1] -AddressFamily IPv6
                                         }         
                                       if($flag){   
                                           Write-Host "Setting correct IPv6 address: " $ipv6addr "with prefix" $val[$i+2]
                                           [int]$tmp = $val[$i+2].ToString()
                                           New-NetIPAddress -InterfaceIndex $key[$i].ToString().Split(":")[1] -IPAddress $ipv6addr -PrefixLength $tmp -AddressFamily IPv6 
                                       }
                            }
                            "ipV6Gateways" {  $flag = $true
                                              foreach($addr in $config){
                                              $tokens = $addr.IPv6DefaultGateway.NextHop
                                              $shortened = $(ConvertTo-IPAddressCompressedForm $val[$i])
                                                foreach($nexthop in $tokens){
                                                 if ($shortened -eq $nexthop ){
                                                    Write-Host "Matched ipv6 gateway Address :" $val[$i] 
                                                    $flag = $false
                                                 }else{
                                                    Write-Host "Unable to match ipv6 gateway address:" $val[$i]  "with" $nexthop
                                                    Write-Host "The IP v6 gateway address" $nexthop "will be removed"
                                                    Remove-NetRoute -Confirm:$false –DestinationPrefix ::/0 -InterfaceIndex $key[$i].ToString().Split(":")[1] -NextHop $nexthop
                                                    
                                                 }                                    
                                               }
                                            }
                                            if($flag){
                                               Write-Host "Setting correct IPv6 Gateways: " $val[$i]
                                               New-NetRoute -Confirm:$false –DestinationPrefix ::/0 -InterfaceIndex $key[$i].ToString().Split(":")[1] –NextHop $val[$i] 
                                            }
                       
                            }
                             "netBIOS" {  
                                                 $toVal = $val[$i].ToString().Trim()
                                                 $fromVal = $netbios.ToString().Trim()
                                                 if ($toVal -eq $fromVal){
                                                    Write-Host "Matched netbios state :" $toVal 
                                                 }else{
                                                    Write-Host "Unable to match Netbios state :" $toVal 
                                                    if($toVal -eq "Enabled"){
                                                        Write-Host "Setting netbios state to Enabled"
                                                        $QueryString.SetTcpipNetbios(1) 
                                                    }else{
                                                         Write-Host "Setting netbios state to Disabled"
                                                        $QueryString.SetTcpipNetbios(2) 
                                                    }
                                                 } 
                              }

                            
                    }                   
                    
function ConvertTo-Mask {
  <#
    .Synopsis
      Returns a dotted decimal subnet mask from a mask length.                             $subnet = ConvertTo-Mask($ip.l
    .Description
      ConvertTo-Mask returns a subnet mask in dotted decimal format from an integer value ranging 
      between 0 and 32. ConvertTo-Mask first creates a binary string from the length, converts 
      that to an unsigned 32-bit integer then calls ConvertTo-DottedDecimalIP to complete the operation.
    .Parameter MaskLength
      The number of bits which must be masked.
  #>
  
  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
    [Alias("Length")]
    [ValidateRange(0, 32)]
    $MaskLength
  )
  
  Process {
    return ConvertTo-DottedDecimalIP ([Convert]::ToUInt32($(("1" * $MaskLength).PadRight(32, "0")), 2))
  }
}

<#
.SYNOPSIS
    Converts long form IP address into its short form
.DESCRIPTION
    Converts long form IP address into its short form
.PARAMETER IPAddress
    The IP address to convert.
.EXAMPLE
    PS C:\> ConvertTo-IPAddressCompressedForm 2001:0db8:03cd:0000:0000:ef45:0006:0123
#>
function ConvertTo-IPAddressCompressedForm($IPAddress) {
     [System.Net.IPAddress]::Parse($IPAddress).IPAddressToString
}

}
Write-Host "Gluescript completed execution"  

Write-Host "Executing DNS change script"

ipconfig /flushdns
net stop netlogon
net stop dnscache
net start dnscache
net start netlogon
ipconfig /registerdns

Write-Host "Finished executing DNS change script"