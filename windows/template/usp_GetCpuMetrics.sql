USE [master]
GO

/****** Object:  StoredProcedure [dbo].[usp_GetCpuMetrics]    Script Date: 1/27/2023 3:09:46 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_GetCpuMetrics]

@CpuRankJSON NVARCHAR(MAX) OUTPUT
AS
BEGIN

SET NOCOUNT ON
/***************************************************************************************************
Procedure:          dbo.usp_GetCpuMetrics
Create Date:        2021-07-07
Author:             Robert F. Sonders
Description:        Procedure create to execute at the same time HammerDB is executing against the tpcc database
Call by:            master.dbo.usp_LogTPSValues
                    
Affected table(s):  [dbo.TPSvalues] (recreated for each run)
                    [dbo.TPSvaluesHistory] (all time history)
Used By:            HammerDB performance testing admin
Parameter(s):       None


Usage:              
				EXEC master.dbo.usp_GetCpuMetrics

Monitor:			Open seperate query window
SELECT * FROM master.dbo.TPSvalues
SELECT * FROM master.dbo.TPSvaluesHistory

Cleanup:
DROP TABLE master.dbo.TPSvalues
DROP TABLE master.dbo.TPSvaluesHistory

Additional Considerations:

****************************************************************************************************/

--Vars
--DECLARE @tpccDatabaseName VARCHAR(50)
--DECLARE @tpccDatabaseNameCpuPercent DECIMAL(5,2)
--DECLARE @tempdbDatabaseName VARCHAR(50)
--DECLARE @tempdbDatabaseNameCpuPercent DECIMAL(5,2)


DROP TABLE IF EXISTS #temp;

WITH DB_CPU_Stats
AS
(SELECT pa.DatabaseID, DB_Name(pa.DatabaseID) AS [DatabaseName],
        SUM(qs.total_worker_time/1000) AS [CPU_Time_Ms]
 FROM sys.dm_exec_query_stats AS qs WITH (NOLOCK)
 CROSS APPLY (SELECT CONVERT(int, value) AS [DatabaseID] 
              FROM sys.dm_exec_plan_attributes(qs.plan_handle)
              WHERE attribute = N'dbid') AS pa
 --WHERE DB_Name(pa.DatabaseID) = @DatabaseName
 GROUP BY DatabaseID)

SELECT ROW_NUMBER() OVER(ORDER BY [CPU_Time_Ms] DESC) AS [CpuRank]
       ,[DatabaseName]
       --,DatabaseID, [CPU_Time_Ms] AS [CPU Time (ms)]
       ,CAST([CPU_Time_Ms] * 1.0 / SUM([CPU_Time_Ms]) OVER() * 100.0 AS DECIMAL(5, 2)) AS [CpuPercent]
INTO #temp
FROM DB_CPU_Stats
WHERE DatabaseID <> 32767 -- ResourceDB

SET @CpuRankJSON =
( 
  SELECT * 
  FROM #temp
  FOR JSON PATH, ROOT('CpuRank')
)

RETURN

END--end procedure

GO
