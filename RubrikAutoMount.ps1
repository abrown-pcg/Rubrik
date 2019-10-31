##########################  Rubrik Recovery from Last Snapshot  ##########################

#######  Set Variables  #######
$RubrikIP = '<<replace with IP address of Rubrik>>'
$VMtoMount = '<<replace with VM name>>'
#$VMtoMount = $Args[0]
$RecoverToVC = '<<replace with vcenter to recover to>>'
$RecoverToHost = '<<replace with esxi host to recover to>>'
$MountName = $VMtoMount.Replace(($VMtoMount.Substring(0,3)),'XXX')  # this section will amend the 1st 3 letters (site code) to a new code.  Replace XXX with new site code
$RubrikUser = '<<replace with Rubrik Username>>'
$RubrikPass = '<<replace with Rubrik User Password>>' | ConvertTo-SecureString -AsPlainText -Force
$vCentreUser = '<<replace with vCentre username>>'
$vCentrePass = '<<replace with vCentre password>>' | ConvertTo-SecureString -AsPlainText -Force
$VMGuestUser = '<<replace with VM Guest User>>'
$VMGuestPass = '<<replace with VM Guest Password>>' | ConvertTo-SecureString -AsPlainText -Force
$NewDNS = '<<Replace with comma delimited DNS servers>>'
$NewSiteSubnet = '<<Replace with site subnet>>'


#######  Connect to Rubrik (Slough)  #######

Connect-Rubrik $RubrikIP -Username $RubrikUser -Password $RubrikPass

#######  Identify Last Snapshot #######

$SnapshotID = Get-RubrikVM -Name $VMtoMount | Get-RubrikSnapshot | Sort-Object Date -desc | Select-Object -First 1 -ExpandProperty ID


#######  Mount Snapshot to vCentre and wait for power on #######

New-RubrikMount -id $SnapshotID -MountName $MountName -DisableNetwork:$true -Confirm:$false

$Message = "Waiting for VM to power on"
do
{
write-host $message
$message += "."
Start-Sleep -Seconds 10
}  Until(Get-VM -Name $MountName | Where-Object {$_.powerstate -eq "PoweredOn"} | ? { $True })



#######  User PowerCLI to Connect to Mounted VM and Identify new IP Address  and Gateway #######

Connect-VIServer $RecoverToVC -User $vCentreUser -Password $vCentrePass

$ipscriptGetIP = '(Get-NetAdapter | Where-Object {$_.InterfaceDescription -like "*VMX*"} | Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4"}) | Select -expandproperty IPAddress'
$ipscriptGetGW = '(Get-NetAdapter | Where-Object {$_.InterfaceDescription -like "*VMX*"} | Get-NetRoute -DestinationPrefix '
$ipscriptGetGW += [regex]::escape('0.0.0.0/0')| select -ExpandProperty NextHop
$currentIP = invoke-vmscript -ScriptText $ipscriptGetIP -ScriptType PowerShell -VM $MountName -GuestUser $VMGuestUser -GuestPassword $VMGuestPass
$currentGW = invoke-vmscript -ScriptText $ipscriptGetGW -ScriptType PowerShell -VM $MountName -GuestUser $VMGuestUser -GuestPassword $VMGuestPass
$NewIP = $CurrentIP.Split('.')
$NewIP[-3] = $NewSiteSubnet
$NewIP = $NewIP -join '.'

$NewGW = $CurrentGW.Split('.')
$NewGW[-3] = $NewSiteSubnet
$NewGW = $NewGW -join '.'

#Change the IP Address
$changingIp = '%WINDIR%\system32\netsh.exe interface ipv4 set address name="' + $getIntAlias + '" source=static address=' + $NewIP + ' gateway=' + $NewGW + ' gwmetric=1 store=persistent'
$setIp = invoke-vmscript -ScriptText $changingIp -ScriptType bat -VM $MountName -GuestUser $VMGuestUser -GuestPassword $VMGuestPass


#Change DNS Servers
Write-Host "Setting DNS Server to $newDNS"
$changeDNS = '%WINDIR%\system32\netsh.exe interface ipv4 set dnsservers name="' + $getIntAlias + '" source=static address=' + $newDNS + ' register=primary'
$setDNS = invoke-vmscript -ScriptText $changeDNS -ScriptType bat -VM $MountName -GuestUser $VMGuestUser -GuestPassword $VMGuestPass

#Register with DNS
Write-Host "Registering with DNS"
$registeringDNS = '%WINDIR%\System32\ipconfig /registerdns'
$segDNS = invoke-vmscript -ScriptText $registeringDNS -ScriptType bat -VM $MountName -GuestUser $VMGuestUser -GuestPassword $VMGuestPass




#######  Enable Network Adapter  #######


Get-NetAdapter | Where-Object {$_.InterfaceDescription -like "*Wireless-AC*"} | Enable-NetAdapter

$ChangeName = ‘Rename-Computer -ComputerName $VMtoMount -NewName $MountName -DomainCredential $credential -force -restart‘
$DoChangeName = invoke-vmscript -ScriptText $ChangeName -ScriptType PowerShell -VM $MountName -GuestUser $VMGuestUser -GuestPassword $VMGuestPass

