USE [master]
GO

/****** Object:  StoredProcedure [dbo].[usp_LogTPSValues]    Script Date: 1/27/2023 3:12:11 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_LogTPSValues]
(

@DurationToLogInMinutes INT NULL
,@DatabaseName VARCHAR(50) NULL
--,@tpcc_mssqls_duration  INT NULL

)

AS
BEGIN

SET NOCOUNT ON
/***************************************************************************************************
Procedure:          dbo.usp_LogTPSValues
Create Date:        2021-06-30
Author:             Robert F. Sonders
Description:        Procedure create to execute at the same time HammerDB is executing against the tpcc database
Call by:            Any query session connected to the instance
                    
Affected table(s):  [dbo.TPSvalues] (recreated for each run)
                    [dbo.TPSvaluesHistory] (all time history)
Used By:            HammerDB performance testing admin
Parameter(s):       @DurationToLogInMinutes - Should align with HammerDB MInutes for Test Duration
			       	@DatabaseName = The tpcc database name

PreStage: 			Disconnect all SPIDs to the tpcc database
					--UserCount by database
					Use Master
					SELECT 
						DB_NAME(dbid) as DBName, 
						COUNT(dbid) as NumberOfConnections,
						loginame as LoginName
					FROM
						sys.sysprocesses
					WHERE 
						dbid > 0
					GROUP BY 
						dbid, loginame;
					EXEC sp_who2

Usage:              
	Use Master
	EXEC master.dbo.usp_LogTPSValues
        @DurationToLogInMinutes = 60,
		@DatabaseName = 'tpcc'


Monitor: Open seperate query window
SELECT * FROM master.dbo.TPSvalues
SELECT * FROM master.dbo.TPSvaluesHistory

Cleanup:
DROP TABLE master.dbo.TPSvalues
DROP TABLE master.dbo.TPSvaluesHistory

Additional Considerations:
					Should we flush the PRoc cache before each run?
					DBCC FREEPROCCACHE

					Should we place this into a separate DBAMaint DB?

					More dynamic SQL with a database name string, etc IN clause

					THere is great deal of opportunity to flip the repetitive code to dynamic SQL. Right now, I am just getting it authored and working
					
					Need to think through a more grainular TPM metric collect. collet every 15 or 30 seconds.


HammerDB Considerations:
	HammerDB uses this SQL to pull transactions. This current procedure uses this counter configuration
	HammerDB uses this SQL to sample the transaction rate
	For reference: https://www.hammerdb.com/docs/ch06s02.html
	select object_name,cntr_value,* from sys.dm_os_performance_counters where counter_name = 'Batch Requests/sec'

	--A more granular database level report would be to use a different counter_name, in the same table
	select object_name,cntr_value,* from sys.dm_os_performance_counters where counter_name = 'transactions/sec' and instance_name = RTRIM(LTRIM('<SomeDatabaseName>'))

	TPM AND NOPM logic is all contained in C:\Program Files\HammerDB-4.1\src\mssqlserver\*.tcl files


****************************************************************************************************/

--Preprocessing
IF @DurationToLogInMinutes = NULL 
BEGIN PRINT '@DurationToLogInMinutes was not supplied. Rerun with a proper value' RETURN END

IF @DatabaseName = NULL 
BEGIN PRINT '@DatabaseName was not supplied. Rerun with a proper value' RETURN END


--Vars
	DECLARE @cntr_value BIGINT
	DECLARE @loopcount BIGINT
	DECLARE @datetime smalldatetime 
	DECLARE @CPUCount INT
	DECLARE @CommittedMemory INT
	DECLARE @TargetMemory INT
	DECLARE @MaxPreviousTPSValue BIGINT
	DECLARE @MaxRowID INT
	DECLARE @UserCount INT
	DECLARE @BatchID UNIQUEIDENTIFIER
	DECLARE @ServerName VARCHAR(20)
	DECLARE @CpuRankJSON NVARCHAR(MAX)
	DECLARE @CpuRank NVARCHAR(MAX)
	DECLARE @SQLcode01 NVARCHAR(max)
	DECLARE @StatusMessage NVARCHAR(max)



--Logging tables
	DROP TABLE IF EXISTS dbo.TPSvalues
	CREATE TABLE dbo.TPSvalues 
	(
	RowID_TPSvalues INT IDENTITY (1,1)
	,ServerName VARCHAR(20)
	,ValueReportTime smalldatetime
	,TPSvalue BIGINT
	,TPSvaluePerMinute BIGINT
	,TPSvaluePerSecond AS (TPSvaluePerMinute / 60) PERSISTED -- Line 291 WAITFOR DELAY '00:00:30' These INT values need to be equal. Need to move this pattern to Dynamic SQL for V2
	,UserCount INT
	,CPUCount INT
	,[CommittedMemory(MB)] BIGINT
	,[TargetMemoryGoal(MB)] BIGINT
	,BatchID UNIQUEIDENTIFIER
	,CpuRank NVARCHAR(MAX)
	) ;

	ALTER TABLE dbo.TPSvalues
		ADD CONSTRAINT PK_RowID_TPSvalues PRIMARY KEY CLUSTERED (RowID_TPSvalues);


IF NOT EXISTS (SELECT 1
           FROM INFORMATION_SCHEMA.TABLES 
           WHERE TABLE_SCHEMA = 'dbo' 
           AND TABLE_NAME = 'TPSvaluesHistory')
 BEGIN
 		CREATE TABLE dbo.TPSvaluesHistory
		(
		RowID_TPSvaluesHistory INT IDENTITY (1,1)
		,RowID_TPSvalues INT
		,ServerName VARCHAR(20) NOT NULL
		,ValueReportTime smalldatetime
		,TPSvalue BIGINT
		,TPSvaluePerMinute BIGINT
		,TPSvaluePerSecond BIGINT
		,UserCount INT
		,CPUCount INT
		,[CommittedMemory(MB)] BIGINT
		,[TargetMemoryGoal(MB)] BIGINT
		,HistoryLogTime smalldatetime DEFAULT GETDATE()
		,BatchID UNIQUEIDENTIFIER
		,CpuRank NVARCHAR(MAX)
		,Operation VARCHAR(10)
		)

		ALTER TABLE dbo.TPSvaluesHistory
			ADD CONSTRAINT PK_RowID_TPSvaluesHistory_ServerName PRIMARY KEY CLUSTERED (RowID_TPSvaluesHistory,ServerName);

		CREATE NONCLUSTERED INDEX [Idx_Average_Group] ON [dbo].[TPSvaluesHistory]
		(
			[ServerName] ASC,
			[ValueReportTime] ASC,
			[TPSvaluePerMinute] ASC,
			[UserCount] ASC,
			[BatchID] ASC
		)
END

--Trigger to write out history logging
	DROP TRIGGER IF EXISTS dbo.trg_RecordTPSvaluesHistory;

	SET @SQLcode01 = '
				CREATE TRIGGER dbo.trg_RecordTPSvaluesHistory 
				ON dbo.TPSvalues
					
					FOR INSERT
					AS
					BEGIN
						SET NOCOUNT ON;

						INSERT INTO TPSvaluesHistory
						(RowID_TPSvalues,ServerName,ValueReportTime,TPSvalue,TPSvaluePerMinute,TPSvaluePerSecond,UserCount,CPUCount,[CommittedMemory(MB)],[TargetMemoryGoal(MB)],HistoryLogTime,BatchID, CpuRank,Operation)

						SELECT RowID_TPSvalues,ServerName,ValueReportTime,TPSvalue,TPSvaluePerMinute,TPSvaluePerSecond,UserCount,CPUCount,[CommittedMemory(MB)],[TargetMemoryGoal(MB)], GETDATE(), BatchID, CpuRank, ''INSERTED''
						FROM INSERTED;

					END';
	--   PRINT @SQLcode01

	EXECUTE(@SQLcode01);

--System info 
	SELECT 
			@CPUcount 			= osn.cpu_count
			,@CommittedMemory 	= osmn.pages_kb/1024
			,@TargetMemory 		= osmn.target_kb/1024
			,@ServerName 		= @@SERVERNAME

	FROM sys.dm_os_nodes AS osn WITH (NOLOCK)
	INNER JOIN sys.dm_os_memory_nodes AS osmn WITH (NOLOCK)
	ON osn.memory_node_id = osmn.memory_node_id
	WHERE osn.node_state_desc <> N'ONLINE DAC' 
	OPTION (RECOMPILE);

-- how many minutes to take samples for
SET @loopcount = @DurationToLogInMinutes

--Get the first set of values
	SELECT	@cntr_value = cntr_value,
			--@datetime = getdate()
  		@datetime = getdate() at time zone 'Central Standard Time' --add this as a time zone variable
	
	FROM sys.dm_os_performance_counters WITH (NOLOCK)
	WHERE counter_name = 'Batch Requests/sec'
	--AND instance_name = RTRIM(LTRIM(@DatabaseName));

--Get the UserCount for SPIDs connected to the DB
	SELECT @UserCount = COUNT(es.session_id)
	FROM sys.dm_exec_sessions AS es WITH (NOLOCK)
	CROSS APPLY sys.dm_exec_input_buffer(es.session_id, NULL) AS ib
	WHERE es.database_id = DB_ID(@DatabaseName)
	AND es.session_id > 50
	AND es.session_id <> @@SPID 
	OPTION (RECOMPILE);

--Create a BatchID for this test
	select @BatchID = NEWID()

--Get the CPU Metrics as JSON. 
	EXEC master.dbo.usp_GetCpuMetrics
	@CpuRankJSON OUTPUT
	SELECT @CpuRank = @CpuRankJSON

	INSERT INTO TPSvalues 
	(ServerName,ValueReportTime,TPSvalue,UserCount,CPUCount,[CommittedMemory(MB)],[TargetMemoryGoal(MB)], BatchID, CpuRank)
	VALUES (@ServerName,@datetime, @cntr_value, @UserCount,@CPUcount, @CommittedMemory, @TargetMemory, @BatchID,@CpuRank)


	WAITFOR DELAY '00:00:01'
--
-- Start loop to collect TPS every minute
--
	WHILE @loopcount <> 0
	BEGIN
	SELECT @cntr_value = cntr_value,
			--@datetime = getdate()
			@datetime = getdate() at time zone 'Central Standard Time' --add this as a time zone variable
	FROM sys.dm_os_performance_counters WITH (NOLOCK)
	WHERE counter_name = 'Batch Requests/sec'


		--Get the Max RowID to store the previous value, to calculate the difference for the TPS
		SELECT	@MaxRowID = MAX(RowID_TPSvalues)
		FROM	TPSvalues

		SELECT @MaxPreviousTPSValue = TPSvalue
		FROM	TPSvalues
		WHERE RowID_TPSvalues = @MaxRowID

		SELECT @UserCount = COUNT(es.session_id)
		FROM sys.dm_exec_sessions AS es WITH (NOLOCK)
		CROSS APPLY sys.dm_exec_input_buffer(es.session_id, NULL) AS ib
		WHERE es.database_id = DB_ID(@DatabaseName)
		AND es.session_id > 50
		AND es.session_id <> @@SPID 
		OPTION (RECOMPILE);		

	--Get the CPU Metrics as JSON. 
		EXEC master.dbo.usp_GetCpuMetrics
		@CpuRankJSON OUTPUT
		SELECT @CpuRank = @CpuRankJSON


		INSERT INTO TPSvalues 
		(ServerName,ValueReportTime,TPSvalue,TPSvaluePerMinute, UserCount,CPUCount,[CommittedMemory(MB)],[TargetMemoryGoal(MB)], BatchID, CpuRank)
		VALUES (@ServerName,@datetime,@cntr_value, @cntr_value - @MaxPreviousTPSValue, @UserCount,@CPUcount, @CommittedMemory, @TargetMemory, @BatchID,@CpuRank)

	--Report out while we are running	

		SET @StatusMessage = ' ''Processing for ' + CAST(@loopcount AS VARCHAR(6)) + ' more minutes. HammerDB @UserCount = ' + CAST(@UserCount AS VARCHAR(6))  + ''
		SET @SQLcode01 = ' RAISERROR(' +@StatusMessage+ ''',0,1) WITH NOWAIT '
		
		--PRINT @StatusMessage
		--PRINT  @SQLcode01  
		
		EXECUTE (@SQLcode01)

		WAITFOR DELAY '00:01:00' 
	
		SET @loopcount = @loopcount - 1
	
	END --end WHILE

-- All done with loop, write out the last value

		--Get the Max RowID to store the previous value, to calculate the difference for the TPS
		SELECT	@MaxRowID = MAX(RowID_TPSvalues)
		FROM	TPSvalues

		SELECT @MaxPreviousTPSValue = TPSvalue
		FROM	TPSvalues
		WHERE RowID_TPSvalues = @MaxRowID


		SELECT @UserCount = COUNT(es.session_id)
		FROM sys.dm_exec_sessions AS es WITH (NOLOCK)
		CROSS APPLY sys.dm_exec_input_buffer(es.session_id, NULL) AS ib
		WHERE es.database_id = DB_ID(@DatabaseName)
		AND es.session_id > 50
		AND es.session_id <> @@SPID 
		OPTION (RECOMPILE);	


		SELECT @cntr_value = cntr_value,
				--@datetime = getdate()
				@datetime = getdate() at time zone 'Central Standard Time' --add this as a time zone variable
		FROM sys.dm_os_performance_counters WITH (NOLOCK)
		WHERE counter_name = 'Batch Requests/sec'

	--Get the CPU Metrics as JSON. 
		EXEC master.dbo.usp_GetCpuMetrics
		@CpuRankJSON OUTPUT	
		SELECT @CpuRank = @CpuRankJSON

	INSERT INTO TPSvalues 
	(ServerName,ValueReportTime,TPSvalue,TPSvaluePerMinute,UserCount,CPUCount,[CommittedMemory(MB)],[TargetMemoryGoal(MB)], BatchID, CpuRank)
		VALUES (@ServerName,@datetime,@cntr_value, @cntr_value - @MaxPreviousTPSValue, @UserCount, @CPUcount, @CommittedMemory, @TargetMemory, @BatchID, @CpuRank)


--Dump out tables for reference
SELECT * FROM TPSvalues
SELECT * FROM TPSvaluesHistory


END --End proc
GO