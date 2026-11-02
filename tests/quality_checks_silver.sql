USE Datawarehouse;
GO

-- ========================================================
-- 1. ROW COUNT CHECK (Compare Bronze vs Silver)
-- ========================================================
SELECT 'Matches' AS Table_Name, 
       (SELECT COUNT(*) FROM bronze.crm_ipl_matches) AS Bronze_Rows,
       (SELECT COUNT(*) FROM silver.crm_ipl_matches) AS Silver_Rows
UNION ALL
SELECT 'Ball_By_Ball', 
       (SELECT COUNT(*) FROM bronze.crm_ipl_ball_by_ball),
       (SELECT COUNT(*) FROM silver.crm_ipl_ball_by_ball);
GO


-- ========================================================
-- 2. DUPLICATE CHECK (Should return 0 rows)
-- ========================================================
-- Check for duplicate match_ids in matches
SELECT match_id, COUNT(*) AS duplicate_count
FROM silver.crm_ipl_matches
GROUP BY match_id
HAVING COUNT(*) > 1;

-- Check for duplicate balls in ball_by_ball
SELECT match_id, innings, overs, ball_in_over, COUNT(*) AS duplicate_count
FROM silver.crm_ipl_ball_by_ball
GROUP BY match_id, innings, overs, ball_in_over
HAVING COUNT(*) > 1;
GO


-- ========================================================
-- 3. OLD TEAM NAMES CHECK (Should return 0 rows)
-- Confirms old franchise names were renamed
-- ========================================================
SELECT DISTINCT team1 AS remaining_old_team
FROM silver.crm_ipl_matches
WHERE team1 IN (
    'Delhi Daredevils', 
    'Kings XI Punjab', 
    'Rising Pune Supergiants', 
    'Royal Challengers Bangalore'
);
GO


-- ========================================================
-- 4. CITY CLEANING CHECK (Should return 0 rows)
-- Confirms 'Bangalore' is gone and Dubai/Sharjah venues have cities
-- ========================================================
SELECT match_id, city, venue
FROM silver.crm_ipl_matches
WHERE city = 'Bangalore'
   OR (city IS NULL AND (venue LIKE '%Dubai%' OR venue LIKE '%Sharjah%'));
GO


-- ========================================================
-- 5. "NO RESULT" & "UNKNOWN" CHECK (Should return 0 rows)
-- Confirms these strings were converted to clean NULLs
-- ========================================================
SELECT match_id, winner, player_of_match
FROM silver.crm_ipl_matches
WHERE winner IN ('No Result', 'Unknown')
   OR player_of_match = 'Unknown';
GO


-- 
-- 6. DATE CONVERSION CHECK (Should return 0 rows)
-- Confirms dates are valid DATE types and not NULL
-- ========================================================
SELECT match_id, match_date
FROM silver.crm_ipl_matches
WHERE match_date IS NULL;
GO


-- ========================================================
-- 7. NUMERIC / NULL CHECK (Should return 0 rows)
-- Confirms runs & extras defaulted to 0 instead of NULL
-- ========================================================
SELECT COUNT(*) AS null_runs_found
FROM silver.crm_ipl_ball_by_ball
WHERE total_runs IS NULL 
   OR batter_runs IS NULL 
   OR extra_runs IS NULL;
GO
===========================================================
