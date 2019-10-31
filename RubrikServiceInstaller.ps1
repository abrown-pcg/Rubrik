## Script to Install Rubrik Backup Service and configure appropriate settings.  

function Get-ComputerSite($ComputerName)
{
   $site = nltest /server:$ComputerName /dsgetsite 2>$null
   if($LASTEXITCODE -eq 0){ $site[0] }
}


$UserName = <<replace with rubrik username>>
$Password = <<Replace with rurbik password>>

$RubrikWorkDir = "C:\RubrikWorkArea"
$ComputerHostName = (Get-ComputerInfo | Select -ExpandProperty csName)
$ComputerSite = Get-ComputerSite $ComputerHostName
$RubrikPackageLocation = "<<Replace with Rubrik Package location path>>"
$RubrikPackageLocation += $ComputerSite
$RubrikPackageLocation += "\RubrikBackupService.msi"
$RubrikServiceName = "Rubrik Backup Service"
$WorkDirRegPath = "HKLM:\SOFTWARE\Rubrik Inc.\Backup Service\"
$WorkDirRegKey = "Database Log Backup Path"

##note above package location relies on folder structure \\pathtofiles\ADSiteName\RubrikPackage 



write-host $RubrikWorkDir
write-host $ComputerHostName
write-host $ComputerSite
write-host $RubrikPackageLocation



# Add Rubrik Service as Domain Admin  
Add-LocalGroupMember -Group "Administrators" -Member "<<replace with Rubrik Admin user>>"


# Install Rubrik Service 
Start-Process msiexec.exe -Wait -ArgumentList '/I $RubrikPackageLocation /quiet'



# Stop Rubrik Service
Write-Host "Waiting one minute for service to install"
Sleep 60
Stop-Service $RubrikServiceName


# Add working path and change service to use it
New-Item -ItemType Directory -Path $RubrikWorkDir
New-Item -Path $WorkDirRegPath -name $WorkDirRegKey -Force
Sleep 30
Set-Item -Path $WorkDirRegPath $WorkDirRegKey -Value $RubrikWorkDir


# Change Service to run using Rubrik Service Account
$service = gwmi win32_service -computer $ComputerHostName -filter "name='$RubrikServiceName'"
$service.change($null,$null,$null,$null,$null,$null,$UserName,$Password,$null,$null,$null)


# Start Rubrik Service

Start-Service $RubrikServiceName

