#Kubernetes related configs
$hammerdbNamespace = 'hammer-db-ns'
# SQL Server related configs
$sqlEnv="linux"  # this variable can be set to either of these two values (linux or windows)
$mssqlips="10.129.80.55", "10.129.80.56","10.129.80.57"
$mssqlport=""       # comma sepreted SQL ports, if not provided, it will use deport 1433 
$mssqlUser='miadmin'
$mssqlPass='!!123abc' 
$mssqlDatabase='tpcc'
$backupLocation="/var/opt/mssql/backups"  #Location to keep backup and other useful scripts (do not provide back slash (/) at the end of the path)
# Load run config
# rampupTime and execTime in minutes per user load
$userLoadSet=3
$loadRunUser='2 4 6'
$rampupTime=1 
$execTime=2
