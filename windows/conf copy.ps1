#Kubernetes related configs
$hammerdbNamespace = 'default'
# SQL Server related configs
$mssqlips="100.82.2.86"  #, "100.98.26.162","100.98.26.163"
$mssqlport="31222"       # comma sepreted SQL ports, if not provided, it will use deport 1433 
$mssqlUser='SA'
$mssqlPass='sqladmin#02' 
$mssqlDatabase='tpcc'

# Load run config
$loadRunUser='2 4 6'
$rampupTime=1 
$execTime=2
