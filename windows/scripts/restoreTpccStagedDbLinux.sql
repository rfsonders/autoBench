USE [master]
GO

SELECT 'Start restore to: '+ @@SERVERNAME + ' at ' + CAST(getdate() AS VARCHAR(20)) 

--updated with the Feb 2022 datacontroller fixes in place.
--Contained Availability Groups or CAG

--we need to remove the .mdf first.
--rm /var/opt/mssql/data/tpcc.mdf

--If database exists, we need to drop first


USE [master]
GO
	IF EXISTS(SELECT * FROM sys.databases WHERE name = 'tpcc')
	BEGIN
		ALTER DATABASE [tpcc] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
		DROP DATABASE [tpcc]
	END;

--confirm the proper file
--	RESTORE HEADERONLY   
--	FROM DISK = N'/var/opt/mssql/backups/TPCC-200Warehouse.bak';

--When connected to the LB, you will not see the DB in a Restoring state.
--SPID is restoring, STATS will not surface back to the calling application.
	RESTORE DATABASE [tpcc] 
	FROM  DISK = N'/var/opt/mssql/backups/TPCC-200Warehouse.bak' WITH  FILE = 1,  
	MOVE N'tpcc' TO N'/var/opt/mssql/data/tpcc.mdf',  
	MOVE N'tpcc_log' TO N'/var/opt/mssql/data-log/tpcc_log.ldf',  
	NOUNLOAD,  STATS = 5;

--Added back to the CAG automatically.

SELECT 'Restore to: '+ @@SERVERNAME + ' completed at ' + CAST(getdate() AS VARCHAR(20)) 
SELECT ''
