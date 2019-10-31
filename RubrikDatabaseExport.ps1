#######  Set Variables  #######
$RubrikIP = '<<replace with Rubrik IP address>>'
$RubrikUser = '<<replace with rubrik username>>'
$RubrikPass = '<<Replace with rubrik password' | ConvertTo-SecureString -AsPlainText -Force
$DBFilePath = "<<Replace with path.to DB file>>"
$DBLogFilePath = "<<Replace with path.to DBLogFile>>"
$LogDate = Get-Date -UFormat %d-%h-%Y
$exportstatus = @()

connect-rubrik -Server $RubrikIP -Username $RubrikUser -Password $RubrikPass | Out-Null

$RubrikDBs = Import-CSV "<<replace with CSV file location>>"
## Log file cleanup if neccessary ## Get-ChildItem -Path C:\Rubrik-DB-Restores -Recurse -File | Where {$_.CreationTime -lt (Get-Date).AddDays(-7)} | Remove-Item -Force
## Create log file if neccessary ## Start-Transcript c:\Rubrik-DB-Restores\$LogDate.log


ForEach($RubrikDB in $RubrikDBs){
                                If ((Get-RubrikDatabase -id $RubrikDB.id | Get-RubrikSnapshot | measure).count -lt 2)
                                    {           $temp = New-Object System.Object
                                                $temp | Add-Member -MemberType NoteProperty -Name Database -Value $RubrikDB.name
                                                $temp | Add-Member -MemberType NoteProperty -Name ExportID -Value ""
                                                $temp | Add-Member -MemberType NoteProperty -Name Status -Value "NONE-FOUND"
                                            $Exportstatus += $temp
                                    }
    
                                else 
                                    {
                                        $LastSnap = Get-RubrikDatabase -id $RubrikDB.id | Get-RubrikSnapshot | sort Date | Select Date -last 1 | select -ExpandProperty date
                                        $Oldest = (Get-Date).AddHours(-24)
                                        if ((Get-Date).hours -lt "6")
                                            {
                                            Export-RubrikDatabase -id $RubrikDB.id -RecoveryDateTime $LastSnap -TargetInstanceId $RubrikDB.TargetInstance -TargetDatabaseName $RubrikDB.name -TargetDataFilePath $DBFilePath -TargetLogFilePath $DBLogFilePath -Overwrite  -MaxDataStreams 4 -FinishRecovery -Confirm:$false -OutVariable ExportResult | out-null
                                            

                                                $temp = New-Object System.Object
                                                $temp | Add-Member -MemberType NoteProperty -Name Database -Value $RubrikDB.name
                                                $temp | Add-Member -MemberType NoteProperty -Name ExportID -Value $ExportResult.id
                                                $temp | Add-Member -MemberType NoteProperty -Name Status -Value $ExportResult.status
                                            $Exportstatus += $temp


                                                
                                            }
                                        else {
                                                $temp | Add-Member -MemberType NoteProperty -Name Database -Value $RubrikDB.name
                                                $temp | Add-Member -MemberType NoteProperty -Name ExportID -Value ""
                                                $temp | Add-Member -MemberType NoteProperty -Name Status -Value "NO-SCOPE"
                                            $Exportstatus += $temp
                                             }
                                    }
                                }

$ExportStatus | format-table -Autosize -Wrap

## Stop logging if logging is started in line 14 ## Stop-Transcript