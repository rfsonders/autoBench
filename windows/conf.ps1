#Kubernetes related configs
$hammerdbNamespace = 'hammer-db-ns'
# SQL Server related configs
$mssqlips="10.129.80.55", "10.129.80.56" #,"100.98.26.163"
$mssqlport=""       # comma sepreted SQL ports, if not provided, it will use deport 1433 
$mssqlUser='miadmin'
$mssqlPass='!!123abc' 
$mssqlDatabase='tpcc'

# Load run config
# rampupTime and execTime in minutes per user load
$loadRunUser='2 4 6'
$rampupTime=1 
$execTime=2
