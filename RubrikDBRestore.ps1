#requires -version 4

<#
.SYNOPSIS
  Manual Restoration Script for Rubrik Database Backups
.DESCRIPTION
  This script is used by Public Consulting Group to restore Databases that are backed up to AIMES Rubrik to another server.
.PARAMETER sourcedb
    the name of the Source Database as it appears in AIMES
.PARAMETER targetdb
    the name that you wish the database to have on the target server
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Andy Brown
  Creation Date:  04-Sep-2019
  Purpose/Change: Initial script development
.EXAMPLE
  RubrikDBRestore.ps1 -sourcedb MyDatabase -targetdb YourDatabase
#>

param(
		[string]$Sourcedb = $(throw "-sourcedb is required."),
		[string]$Targetdb = $(throw "-targetdb is required."),
)

##################################################################################
#######             Clear Variables and Import Rubrik Modules              #######
##################################################################################


Clear-Variable rubrik*
Get-Module -ListAvailable *Rubrik* | Import-Module -Force

##################################################################################
#############                       Set Variables                    #############
##################################################################################

$RubrikIP = '<<replace with Rubrik IP address>>'
$RubrikUser = '<<replace with Rubrik Username>>'
$RubrikPass = '<<replace with Rubrik Password>>' | ConvertTo-SecureString -AsPlainText -Force
$RubrikDBFilePath = "<<replace with DB File path>>$targetdb.mdf"
$RubrikDBLogFilePath = "<<Replace with DB log file path>>$targetdb.ldf"
$RubrikLogDate = Get-Date -UFormat %d-%h-%Y
$Rubrikexportstatus = @()
$RubrikDBName = $SourceDb
$RubrikDBTarget = $TargetDb
$RubrikDBTargetServer = $TargetSvr

##################################################################################
#############                      Connect to Rubrik                 #############
##################################################################################


connect-rubrik -Server $RubrikIP -Username $RubrikUser -Password $RubrikPass | Out-Null

##################################################################################
#############              Get Info on Database and Target           #############
##################################################################################

$RubrikDatabaseInfo = (Get-RubrikDatabase | select name,id -ExpandProperty rootproperties | where {$_.name -eq "$RubrikDBNAME" -and $_.rootname -like "*<<Replace with Source side code>>*"})
$RubrikTarget = (Get-RubrikSQLInstance | select id -expandproperty rootproperties | select id,rootname | where {$_.rootname -like "$RubrikDBTargetServer*"})

##################################################################################
#############              Get the Latest Snapshot Backup            #############
##################################################################################

$RubrikLastSnap = Get-RubrikDatabase -id $RubrikDatabaseInfo.id | Get-RubrikSnapshot | sort Date | Select Date -last 1 | select -ExpandProperty date

##################################################################################
#############               Initiate/Queue DB Restoration            #############
##################################################################################

			Export-RubrikDatabase -id $RubrikDatabaseInfo.id -RecoveryDateTime $RubrikLastSnap -TargetInstanceId $RubrikTarget.id -TargetDatabaseName $RubrikDBTarget -TargetDataFilePath $RubrikDBFilePath -TargetLogFilePath $RubrikDBLogFilePath -Overwrite  -MaxDataStreams 4 -FinishRecovery -Confirm:$false -OutVariable RubrikExportResult | out-null
			$RubrikEventSeriesID = ((Get-RubrikEvent | where {$_.jobInstanceiD -eq $RubrikExportResult.id}).eventseriesID | select -last 1)
            write-host "Queuing Event on Rubrik.  Please wait... Status/Progress will update every 20 seconds"

##################################################################################
#############          Waiting 30 seconds for job to Queue           #############
##################################################################################

            sleep 30

##################################################################################
#############                     Get Status Events                  #############
##################################################################################


            $RubrikEvents = (Get-RubrikEvent -EventSeriesId $RubrikEventSeriesID | select time,objectName,eventstatus,eventprogress,eventinfo)
            $RubrikLastEvent = ($RubrikEvents | select -first 1)

##################################################################################
############# Loop updating status and display until Job is completed ############
##################################################################################


            while($RubrikLastEvent.Eventstatus -eq "Queued" -or $RubrikLastEvent.EventStatus -eq "Running" -or $RubrikLastEvent.EventStatus -eq "TaskSuccess"){
                    $Rubriktemp = New-Object System.Object
			        $Rubriktemp | Add-Member -MemberType NoteProperty -Name SourceInstance -Value $RubrikDatabaseInfo.rootname
			        $Rubriktemp | Add-Member -MemberType NoteProperty -Name SourceDatabase -Value $RubrikDatabaseInfo.name
			        $Rubriktemp | Add-Member -MemberType NoteProperty -Name TargetInstance -Value $RubrikTarget.rootname
			        $Rubriktemp | Add-Member -MemberType NoteProperty -Name TargetDatabase -Value $RubrikDBTarget
			        $Rubriktemp | Add-Member -MemberType NoteProperty -Name LastEventTime -Value $RubrikLastEvent.time
			        $Rubriktemp | Add-Member -MemberType NoteProperty -Name Status -Value $RubrikLastEvent.Eventstatus
                    $Rubriktemp | Add-Member -MemberType NoteProperty -Name Progress -Value $RubrikLastEvent.eventprogress
                    $Rubriktemp | Add-Member -MemberType NoteProperty -Name EventInfo -Value $RubrikLastEvent.eventinfo
			        $RubrikExportstatus = $Rubriktemp    
                    $RubrikExportStatus | format-table -AutoSize -Wrap -HideTableHeaders
                    sleep 20
                    $RubrikEvents = (Get-RubrikEvent -EventSeriesId $RubrikEventSeriesID | select time,objectName,eventstatus,eventprogress,eventinfo)
                    $RubrikLastEvent = ($RubrikEvents | select -first 1)
                    }  

##################################################################################
#############   Assess success criteria and display Success/Failure   ############
##################################################################################
                                                                                              
            if ($RubrikLastEvent.eventstatus -eq "Success"){
                write-host "Restore Completed Successfully"}
            if ($RubrikLastEvent.eventstatus -eq "Failure"){
                write-host "Restore Failed"
                write-host $RubrikLastEvent.eventinfo}