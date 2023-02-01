
## --------------------------------------------------
# Kubernetes related configs
## --------------------------------------------------
$hammerdbNamespace = 'hammer-db-ns'

## --------------------------------------------------
# SQL Server related configs
## --------------------------------------------------
# Can be set to either of these two values (linux or windows)
$sqlEnv="linux"  

# IP addresses of each SQL MI. Add prts if NodePort K8s configuratin
$mssqlips="10.129.80.55", "10.129.80.56", "10.129.80.57", "10.129.80.58", "10.129.80.59" 

# MI username
$mssqlUser='miadmin'

# MI Password
$mssqlPass='!!123abc' 

# TPC database
$mssqlDatabase='tpcc'

# SQL backup file location
# (do not provide back slash (/) at the end of the path)
$backupLocation="/var/opt/mssql/backups"  

## --------------------------------------------------
# Load run config
## --------------------------------------------------
# RampupTime and execTime in minutes per user load
$userLoadSet=5

# User load test groups
$loadRunUser='10 20 30 40 50'

# HammerDb Ramp up time
$rampupTime=1 

# Execute time per user group
$execTime=5
