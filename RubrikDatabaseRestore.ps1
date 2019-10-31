#######  Set Variables  #######
$rubrikDB = $Args[0]
$targetDB = $Args[1]
$RubrikIP = '<<replace with Rubrik IP address>>'
$RubrikUser = '<<replace with Rubrik username>>'
$RubrikPass = '<<replace with Rubrik password>>' | ConvertTo-SecureString -AsPlainText -Force
$DBFilePath = "<<Replace with Database File path>>"
$DBLogFilePath = "<<Replace with Database Log File Path>>"
$LogDate = Get-Date -UFormat %d-%h-%Y


connect-rubrik -Server $RubrikIP -Username $RubrikUser -Password $RubrikPass | Out-Null


if ($rubrikDB) { $rubrikDB } else { $RubrikDB = Read-host "Please enter Database Name to restore" }


Get-RubrikDatabase -name $rubrikDB | where {$_.rootproperties -like "*LIV*"} | select name,id -ExpandProperty rootproperties | select name,id,rootname -OutVariable DBInfo | Out-Null
$TargetRoot = ($DBInfo.Rootname).Replace((($DBInfo.Rootname).Substring(0,3)),'XXX') # this section changes the DB Root to point to a different site code.  Replace XXX with new site code
Get-RubrikSQLInstance | where {$_.rootproperties -like "*$TargetRoot*"} -OutVariable InstanceInfo | Out-Null
Get-RubrikDatabase -id $DBInfo.id | Get-RubrikSnapshot | sort date | select -last 1 -OutVariable SnapInfo | Out-Null
if ($targetDB) { $targetDB } else { $targetDB = $DBInfo.name }
Export-RubrikDatabase -id $DBInfo.id -RecoveryDateTime $SnapInfo.date -TargetInstanceId $InstanceInfo.id -TargetDatabaseName $targetDB -TargetDataFilePath $DBFilePath -TargetLogFilePath $DBLogFilePath -Overwrite  -MaxDataStreams 4 -FinishRecovery -Confirm:$false -OutVariable ExportResult | out-null
$Message = "Exporting database $DBInfo.name to $TargetRoot please wait."
write-host $Message

While ((Get-RubrikEvent |where {$_.ObjectName -eq "$DBInfo.name"} | sort date | select -Last 1).eventstatus -like "*Running*" -or $EventStatus.EventStatus -like "*Queue*") {
sleep 30
$Message += "."
write-host $Message
Get-RubrikEvent |where {$_.ObjectName -eq "$DBInfo.name"} | sort date | select -Last 1 -OutVariable EventStatus | Out-Null
}

Write-Host $EventStatus.eventinfo
Write-host "Done"
