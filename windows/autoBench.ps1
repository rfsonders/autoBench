param ($type)
$workingDirectory = Split-Path $((Get-Variable MyInvocation).Value).MyCommand.Path
Import-Module -Name "$workingDirectory\conf.ps1" -Force
$finalPath = Join-Path $workingDirectory "final\"
$tclPath = Join-Path $workingDirectory "tcl\"
$templatePath = Join-Path $workingDirectory "template\"
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
    Write-Host "Not Implemented yet .." -ForegroundColor Yellow
}
if (($type -eq "setup") -or ($type -eq "allWithoutCopyDB") -or ($type -eq "all")){
    Write-Host "Generating .TCL and .YAML files based on autoBench config file" -ForegroundColor Yellow
    $i = 1
    foreach ($ip in $sqlips) {
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
        $newContent = $inMem -replace '<sqlip>',$ip 
        $newContent = $newContent -replace '<sqlport>',$sqlport 
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

        Write-Host $tclFile
        Write-Host $yamlFile
        $i = $i+1
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
            Start-Sleep -Seconds 1
            #kubectl -n $hammerdbNamespace get pods $podName -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}'
            #while ((kubectl -n $hammerdbNamespace get pods $podName -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') -ne 'True')
        } while ((kubectl -n $hammerdbNamespace get pods $podName -o jsonpath="{.status.phase}") -ne 'Running')
        
        Start-Sleep -Seconds 40
        kubectl -n $hammerdbNamespace get pods 
        kubectl -n $hammerdbNamespace cp $tclFilePath $tclPodPath
        write-host $tclFilePath
        write-host $tclPodPath
        $j = $j + 1
    }
}
if (($type -eq "execute") -or ($type -eq "allWithoutCopyDB") -or ($type -eq "all")){
    Write-Host "Starting Hammerdb benchmarking" -ForegroundColor Yellow
    Get-Job | Remove-Job -Force
    $k = 1
    foreach ($ip in $sqlips){
        $hammerPodName = "hammerdb-pod-" + $k.ToString()
        $jname = "hammerdb-Job-"+ $k.ToString()
        Start-Job -Name $jName -ScriptBlock { 
            Param ($Path, $hammerdbNamespace, $hammerPodName)
            cd $Path
            #kubectl -n $hammerdbNamespace exec -it $hammerPodName -- /bin/bash -c "source ~/.bashrc && ./hammerdbcli auto /home/hammerdb/HammerDB-4.6/autoRun-hammerdb-pod.tcl"
            kubectl -n $hammerdbNamespace exec -it $hammerPodName -- bash -c "cd /home/hammerdb/HammerDB-4.6; env PATH=usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/mssql-tools/bin:/usr/local/unixODBC/bin:/home/hammerdb/HammerDB-4.6 LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/:/home/hammerdb/instantclient_21_5/::/usr/local/unixODBC/lib ./hammerdbcli auto /home/hammerdb/HammerDB-4.6/autoRun-hammerdb-pod.tcl"
        } -ArgumentList($workingDirectory, $hammerdbNamespace, $hammerPodName)
        $k = $k + 1
    }

    [int]$noOfRow = 0
    while(Get-Job -State Running){
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








