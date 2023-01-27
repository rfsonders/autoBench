$workingDirectory = Split-Path $((Get-Variable MyInvocation).Value).MyCommand.Path
Import-Module -Name "$workingDirectory\conf.ps1" -Force
$templatePath = Join-Path $workingDirectory "template\"

$scripts = Get-ChildItem -Path $templatePath -Filter "*.sql"
foreach ($scr in $scripts){
    $scriptName = $scr.FullName
    #$inputFile = Join-Path $templatePath $scriptName
    Invoke-Sqlcmd -InputFile $scriptName -ServerInstance "10.129.80.56" -Database "tpcc" -Username "miadmin" -Password "!!123abc" -ConnectionTimeout 100 -QueryTimeout 0 -verbose #*> "File1.log"
}
