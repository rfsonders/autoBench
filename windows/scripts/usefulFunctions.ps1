function getIpAndPort($inputValue, [REF]$ipOut, [REF]$portOut){
    
    $splitedValues = $inputValue.Split(",")
    if ($splitedValues.count -eq 1){
        $ipOut.Value = $splitedValues[0]
        $portOut.Value = "1433"
    }
    if ($splitedValues.count -eq 2){
        $ipOut.Value = $splitedValues[0]
        $portOut.Value = $splitedValues[1] 
    }
}
<#
$ipOut = ""
$portOut = ""
getIpAndPort "100.10.10.1,31222" ([REF]$ipOut) ([REF]$portOut)
Write-Host "IP="+$ipOut 
Write-Host "Port="+$portOut
#>
<#
function Find-NewMessages($valvar1, [REF]$refvar1, [REF]$refvar2) {
    #//some stuff
    $refvar1.Value = "hi"
    $refvar2.Value = "bye"
  }
  
$refvar1 = "1"
$refvar2 = "2"
$valvar1 = "10.10.10.1,1444" 
Find-NewMessages $valvar1 ([REF]$refvar1) ([REF]$refvar2)
Write-Host "IP= "$refvar1 
Write-Host "Port= "$refvar2
#>