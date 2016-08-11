#INIT VARIABLES
$global:array=@()
$totalcount=$null
$Falsecount=$null
$Truecount=$null
$PercentTrue=$null
$PercentFalse=$null
#MODIFY SQLSERVERLIST TO CONTAIN SQL SERVER INSTANCES
$SQLServerlist = "
Serverentry1\instance",`
"Serverentry2\instance"
$SQLPDB = ""

# Sql Server Query to ...
$SQLQuery = @"
SELECT TOP 1000 [session_id]
      ,[connect_time]
      ,[net_transport]
      ,[protocol_type]
      ,[encrypt_option]
      ,[auth_scheme]
      ,[node_affinity]
      ,[client_net_address]
      ,[client_tcp_port]
      ,[local_net_address]
      ,[local_tcp_port]
  FROM [master].[sys].[dm_exec_connections]
"@

# SQL Server Function to query the Operational Database Server
function Run-SQLDBQuery
{
    Param($sqlquery)

    try{
        $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
        $SqlConnection.ConnectionString = "Server=$SQLServer;Database=$SQLPDB;Integrated Security=True"
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandText = $sqlquery
        $SqlCmd.Connection = $SqlConnection
        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $SqlAdapter.SelectCommand = $SqlCmd
        $DataSet = New-Object System.Data.DataSet
        $SqlAdapter.Fill($DataSet) | Out-Null
        $SqlConnection.Close()
        $dataset.tables[0].Columns.Add("Instance") | Out-Null
        $Dataset.tables[0] | %{$_.Instance = $SQLServer}
        $columnArray = @()
        #CONVERT FROM DATASET TO PSOBJECT OTHERWISE RESULTS CANT BE COMBINED
        foreach ($Col in $Dataset.tables[0].Columns.ColumnName) {
            $ColumnArray += $Col.toString()
        }
        foreach ($Ro in $Dataset.tables[0].Rows) {
            $i=0;
            $rowObject = @{}
            foreach ($colu in $Ro.ItemArray) {
                $rowObject += @{$columnArray[$i]=$colu.toString()}
                $i++
            } 
            $global:array += New-Object PSObject -Property $rowObject
        }
    }
    catch{write-host "Instance Fail $SQLServer" -foregroundcolor red}
}

#RUN SERVERLIST AGAINST FUNCTION
foreach($SQLServer in $SQLServerlist)
{
    Run-SQLDBQuery $sqlquery
}

#FORMAT RESULTS
try{
    $totalcount=($global:array |select Instance,encrypt_option,local_net_address,client_net_address|measure).count
    $Falsecount=($global:array |select Instance,encrypt_option,local_net_address,client_net_address|where {$_.encrypt_option -eq "FALSE"}|measure).count
    $Truecount=($global:array |select Instance,encrypt_option,local_net_address,client_net_address|where {$_.encrypt_option -eq "TRUE"}|measure).count
    $PercentTrue="{0:N2}" -f (($Truecount/$totalcount)*100)
    $PercentFalse="{0:N2}" -f (($Falsecount/$totalcount)*100)
    write-host "OVERALL RESULTS" -ForegroundColor green
    "Percent Encrypted: $PercentTrue"
    "Percent Unencrypted: $PercentFalse"
    "Total SQL Connections: $totalcount"
    write-host "INDIVIDUAL INSTANCE RESULTS" -ForegroundColor green
    $global:array|group instance,encrypt_option|foreach{
        $b= $_.name -split ','
            [pscustomobject] @{
             Instance = $b[0];Encrypted = $b[1]
            'Sum Value' = ($_.group | measure ).count
            }
        }
}
catch{write-host "Failed exiting" -ForegroundColor red}