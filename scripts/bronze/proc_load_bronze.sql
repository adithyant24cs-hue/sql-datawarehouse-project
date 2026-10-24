CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME,@batch_start_time DATETIME,@batch_end_time DATETIME;
	BEGIN TRY
		PRINT '=============================================';
		PRINT 'Loading Bronze Layer';
		PRINT '=============================================';
		SET @batch_start_time = GETDATE();

		PRINT '---------------------------------------------';
		PRINT 'Loading Ipl ball by ball table';
		PRINT '---------------------------------------------';

		SET @start_time = GETDATE();

		PRINT '>>Truncating Table:bronze.crm_ipl_ball_by_ball'
		TRUNCATE TABLE bronze.crm_ipl_ball_by_ball

		PRINT 'Inserting Data Into:bronze.crm_ipl_ball_by_ball'
		BULK INSERT bronze.crm_ipl_ball_by_ball
		FROM 'C:\Users\adith\Downloads\ipl_ball_by_ball.csv'
		WITH
		(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '0x0A',
			CODEPAGE = '65001',
			TABLOCK
		);
        
		SET @end_time = GETDATE();
 		PRINT '>>> ------------------------------------------';
		PRINT '>> Load Duratio: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
		PRINT '>>> ------------------------------------------';
	    
		PRINT '---------------------------------------------';
		PRINT 'Loading Ipl Matches Table';
		PRINT '---------------------------------------------';

		SET @start_time = GETDATE();

	    
		PRINT '>>Truncating Table:bronze.crm_ipl_matches';
		TRUNCATE TABLE bronze.crm_ipl_matches

		PRINT 'Inserting Data Into: bronze.crm_ipl_matches';
		BULK INSERT bronze.crm_ipl_matches
		FROM 'C:\Users\adith\Downloads\ipl_matches.csv'
		WITH
		(
			FIRSTROW = 2,
			FIELDTERMINATOR = ',',
			ROWTERMINATOR = '0x0A',
			CODEPAGE = '65001'
		);
		SET @end_time = GETDATE();
 		PRINT '>>> ------------------------------------------';
		PRINT '>> Load Duratio: ' + CAST(DATEDIFF(second,@start_time,@end_time) AS NVARCHAR) + 'seconds';
		PRINT '>>> ------------------------------------------';

		SET @batch_end_time = GETDATE();
 		PRINT '==============================================';
		PRINT 'Loading bronze layer is completed';
		PRINT '>> Load Duratio: ' + CAST(DATEDIFF(SECOND,@batch_start_time,@batch_end_time) AS NVARCHAR) + 'seconds';
		PRINT '==============================================';

	END TRY
	BEGIN CATCH
		PRINT '=========================================';
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';
		PRINT 'Error Message' + ERROR_MESSAGE();
		PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '=========================================';
	END CATCH
END
EXEC bronze.load_bronze
