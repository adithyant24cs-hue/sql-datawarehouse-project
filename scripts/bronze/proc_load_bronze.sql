
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
