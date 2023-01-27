param ($type)
$workingDirectory = Split-Path $((Get-Variable MyInvocation).Value).MyCommand.Path
Import-Module -Name "$workingDirectory\conf.ps1" -Force
Import-Module -Name "$workingDirectory\usefulFunctions.ps1" -Force
$finalPath = Join-Path $workingDirectory "final\"
$tclPath = Join-Path $workingDirectory "tcl\"
$templatePath = Join-Path $workingDirectory "template\"
$scriptsPath = Join-Path $workingDirectory "scripts\"
$sqlport=""
$sqlips = $mssqlips
if ($mssqlport -eq ""){
    $sqlport = "1433"
}else {
    $sqlport = $mssqlport
}

if (($type -eq "copyDb")  -or ($type -eq "all")){
    Write-Host "Not Implemented yet .." -ForegroundColor Yellow
}
if (($type -eq "restoreDb") -or ($type -eq "allWithoutCopyDB") -or ($type -eq "all")){
    Write-Host "Starting database restore on targer sql instance/s .." -ForegroundColor Yellow
    $restoreScript = Join-Path $scriptsPath "restoreTpccStagedDbLinux.sql"
    Get-Job | Remove-Job -Force
    $n = 1
    foreach ($ip in $sqlips){
        $jname = "restore-job-"+ $n.ToString()
        Write-Host $jname
        Start-Job -Name $jName -ScriptBlock { 
            Param ($Path, $restoreScript, $ip, $mssqlUser, $mssqlPass)
            cd $Path
            Invoke-Sqlcmd -InputFile $restoreScript -ServerInstance $ip -Database "master" -Username $mssqlUser -Password $mssqlPass -ConnectionTimeout 1000 -QueryTimeout 0 -verbose
        } -ArgumentList($workingDirectory, $restoreScript, $ip, $mssqlUser, $mssqlPass)
        $n = $n + 1
    }
    [int]$noOfRow = 0
    while(Get-Job -State Running){
        if(($noOfRow % 60) -eq 0){
            Write-Host ""
            Write-Host -NoNewline 'Restoring TPCC database on target machine/s=> '            
        }
        Write-Host -NoNewline ([char]9612) -ForegroundColor Cyan
        Start-Sleep -s 3
        $noOfRow = $noOfRow +1
    }

}
if (($type -eq "setup") -or ($type -eq "allWithoutCopyDB") -or ($type -eq "all")){
    Write-Host "Generating .TCL and .YAML files based on autoBench config file" -ForegroundColor Yellow
    $i = 1
    foreach ($ip in $sqlips) {
        $ipOut = ""
        $portOut = ""
        getIpAndPort $ip ([REF]$ipOut) ([REF]$portOut)
        #$hammerJobName = $hammerJob + $i.ToString()
        $hammerPodName = "hammerdb-pod-" + $i.ToString()
        $singleUserRunDuration = $execTime * 60

        $buildTclFileName = "autoRun-"+$hammerPodName+".tcl"
        $hammerYamlFileName = "hammerdb-pod-"+$i.ToString()+".yaml"
        $tclFile = Join-Path $tclPath $buildTclFileName
        
        if (Test-Path $tclFile) {
            Remove-Item $tclFile -Force
        }
        $tclTemplate = Join-Path $templatePath "autoDriveNew.tcl"
        Copy-Item -Path $tclTemplate -Destination $tclFile
        
        $inMem = Get-Content $tclFile 
        $newContent = $inMem -replace '<sqlip>',$ipOut 
        $newContent = $newContent -replace '<sqlport>',$portOut 
        $newContent = $newContent -replace '<sqluser>',$mssqlUser 
        $newContent = $newContent -replace '<sqlpass>',$mssqlPass 
        $newContent = $newContent -replace '<sqldb>',$mssqlDatabase 
        $newContent = $newContent -replace '<rampuptime>',$rampupTime 
        $newContent = $newContent -replace '<testduration>',$execTime 
        $newContent = $newContent -replace '<userload>',$loadRunUser 
        $newContent = $newContent -replace '<singleruntimeinsec>',$singleUserRunDuration 
        $newContent | Set-Content $tclFile

        $yamlTemplate = Join-Path $templatePath "hammer-pod.yaml"
        $yamlFile = Join-Path $finalPath $hammerYamlFileName
        if (Test-Path $yamlFile) {
            Remove-Item $yamlFile -Force
        }
        Copy-Item -Path $yamlTemplate -Destination $yamlFile

        $inMem2 = Get-Content $yamlFile 
        $newContent2 = $inMem2 -replace '<hammerpod>',$hammerPodName 
        $newContent2 = $newContent2 -replace '<hammernamespace>',$hammerdbNamespace 
        $newContent2 | Set-Content $yamlFile
        $i = $i+1
    }
    
    Write-Host "Deploy reporting storaed procedures" -ForegroundColor Yellow
    $usp1 = Join-Path $scriptsPath "usp_GetCpuMetrics.sql"
    $usp2 = Join-Path $scriptsPath "usp_LogTPSValues.sql"
    foreach ($ip in $sqlips){

        Invoke-Sqlcmd -InputFile $usp1 -ServerInstance $ip -Database "master" -Username $mssqlUser -Password $mssqlPass -ConnectionTimeout 100 -QueryTimeout 0 -verbose
        Start-Sleep 2
        Invoke-Sqlcmd -InputFile $usp2 -ServerInstance $ip -Database "master" -Username $mssqlUser -Password $mssqlPass -ConnectionTimeout 100 -QueryTimeout 0 -verbose
    }


    Write-Host "Deploying hammerdb pods and copying hammerdb tcl file" -ForegroundColor Yellow
    $j = 1
    foreach ($ip in $sqlips){
        $podName=""
        $tclFileName=""
        $tclFilePath=""
        $tclPodPath=""
        $podName = "hammerdb-pod-"+$j.ToString()
        $tclFileName = "autoRun-"+$podName+".tcl"
        $yamlFileName = "hammerdb-pod-"+$j.ToString()+".yaml"
        $yamlLocalPath = "final/"+$yamlFileName
        $tclFixedFileName = "autoRun-hammerdb-pod.tcl"
        #$tclLocalPath = "./tcl/"+$tclFileName
        $tclPodPath=$podName+":/home/hammerdb/HammerDB-4.6/"+$tclFixedFileName

        #$fileName = $yml.FullName
        #$tclFilePath = Join-Path $tclPath $tclFileName
        $tclFilePath = "tcl\"+$tclFileName
        kubectl delete -f $yamlLocalPath --force
        Start-Sleep -Seconds 5
        kubectl create -f $yamlLocalPath
        Write-Host "Waiting for container to be in ready state"
        do {
            kubectl -n $hammerdbNamespace get pods 
            Start-Sleep -Seconds 2
            #kubectl -n $hammerdbNamespace get pods $podName -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}'
            #while ((kubectl -n $hammerdbNamespace get pods $podName -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') -ne 'True')
        } while ((kubectl -n $hammerdbNamespace get pods $podName -o jsonpath="{.status.phase}") -ne 'Running')
        
        Start-Sleep -Seconds 40
        kubectl -n $hammerdbNamespace get pods 
        kubectl -n $hammerdbNamespace cp $tclFilePath $tclPodPath
        $j = $j + 1
    }

    
}
if (($type -eq "exec") -or ($type -eq "allWithoutCopyDB") -or ($type -eq "all")){
    Write-Host "Starting monitoring process" -ForegroundColor Yellow
    $execDuration = (([int]$rampupTime * [int]$userLoadSet) + ([int]$execTime * [int]$userLoadSet) + 2 )
    $execDurInStr = $execDuration.ToString()
    $monitorTemplate = Join-Path $templatePath "monitorSqlInstance.sql"
    $monitorScript = Join-Path $scriptsPath "monitorSqlInstance.sql"
    if (Test-Path $monitorScript) {
        Remove-Item $monitorScript -Force
    }
    Copy-Item -Path $monitorTemplate -Destination $monitorScript
    $inMem3 = Get-Content $monitorScript 
    $newContent3 = $inMem3 -replace '<execDuration>',$execDurInStr 
    $newContent3 = $newContent3 -replace '<dbname>',$mssqlDatabase 
    $newContent3 | Set-Content $monitorScript
    Get-Job | Remove-Job -Force
    $o = 1
    foreach ($ip in $sqlips){
        $jname = "mon-job-"+ $o.ToString()
        Write-Host $jname
        Start-Job -Name $jName -ScriptBlock { 
            Param ($Path, $monitorScript, $ip, $mssqlUser, $mssqlPass)
            cd $Path
            Invoke-Sqlcmd -InputFile $monitorScript -ServerInstance $ip -Database "master" -Username $mssqlUser -Password $mssqlPass -ConnectionTimeout 1000 -QueryTimeout 0 -verbose
        } -ArgumentList($workingDirectory, $monitorScript, $ip, $mssqlUser, $mssqlPass)
        $o = $o + 1
    }

    Write-Host "Starting Hammerdb benchmarking" -ForegroundColor Yellow
    $k = 1
    foreach ($ip in $sqlips){
        $hammerPodName = "hammerdb-pod-" + $k.ToString()
        $jname = "hammer-Job-"+ $k.ToString()
        Start-Job -Name $jName -ScriptBlock { 
            Param ($Path, $hammerdbNamespace, $hammerPodName)
            cd $Path
            #kubectl -n $hammerdbNamespace exec -it $hammerPodName -- /bin/bash -c "source ~/.bashrc && ./hammerdbcli auto /home/hammerdb/HammerDB-4.6/autoRun-hammerdb-pod.tcl"
            kubectl -n $hammerdbNamespace exec -it $hammerPodName -- bash -c "cd /home/hammerdb/HammerDB-4.6; env PATH=usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/mssql-tools/bin:/usr/local/unixODBC/bin:/home/hammerdb/HammerDB-4.6 LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/:/home/hammerdb/instantclient_21_5/::/usr/local/unixODBC/lib ./hammerdbcli auto /home/hammerdb/HammerDB-4.6/autoRun-hammerdb-pod.tcl"
        } -ArgumentList($workingDirectory, $hammerdbNamespace, $hammerPodName)
        $k = $k + 1
    }

    [int]$noOfRow = 0
    while(Get-Job -State Running | Where-Object {$_.Name.Contains("hammer-Job")} ){
        if(($noOfRow % 60) -eq 0){
            Write-Host ""
            Write-Host -NoNewline 'Running HammerDB TPC-C Benchmarking => '            
        }
        Write-Host -NoNewline ([char]9612) -ForegroundColor Cyan
        Start-Sleep -s 10
        $noOfRow = $noOfRow +1
    }
}
if (($type -eq "report") -or ($type -eq "allWithoutCopyDB") -or ($type -eq "all")){
    Write-Host "Not Implemented yet .." -ForegroundColor Yellow
}








