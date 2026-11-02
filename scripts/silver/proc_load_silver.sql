USE Datawarehouse;
GO
EXEC silver.load_silver

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        PRINT '==================================================';
        PRINT 'Loading Silver Layer: Starting IPL Data Cleaning';
        PRINT '==================================================';

        -- --------------------------------------------------
        -- 1. CLEAN AND LOAD: silver.crm_ipl_matches
        -- --------------------------------------------------
        PRINT 'Truncating silver.crm_ipl_matches...';
        TRUNCATE TABLE silver.crm_ipl_matches;

        PRINT 'Inserting cleaned data into silver.crm_ipl_matches...';
        ;WITH CleanedMatches AS (
            SELECT
                match_id,
                TRY_CONVERT(DATE, TRIM(match_date), 105) AS match_date,
                TRIM(season) AS season,

                -- Fix Missing/Unknown Cities based on Venue
                CASE 
                    WHEN TRIM(city) = 'Unknown' AND venue LIKE '%Dubai%' THEN 'Dubai'
                    WHEN TRIM(city) = 'Unknown' AND venue LIKE '%Sharjah%' THEN 'Sharjah'
                    WHEN TRIM(city) = 'Bangalore' THEN 'Bengaluru'
                    WHEN TRIM(city) = 'Unknown' THEN NULL
                    ELSE TRIM(city)
                END AS city,

                -- Clean venue string
                REPLACE(TRIM(venue), '"', '') AS venue,

                -- Standardize Team 1
                CASE 
                    WHEN TRIM(team1) = 'Delhi Daredevils' THEN 'Delhi Capitals'
                    WHEN TRIM(team1) = 'Kings XI Punjab' THEN 'Punjab Kings'
                    WHEN TRIM(team1) = 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
                    WHEN TRIM(team1) = 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
                    ELSE TRIM(team1)
                END AS team1,

                -- Standardize Team 2
                CASE 
                    WHEN TRIM(team2) = 'Delhi Daredevils' THEN 'Delhi Capitals'
                    WHEN TRIM(team2) = 'Kings XI Punjab' THEN 'Punjab Kings'
                    WHEN TRIM(team2) = 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
                    WHEN TRIM(team2) = 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
                    ELSE TRIM(team2)
                END AS team2,

                -- Standardize Toss Winner
                CASE 
                    WHEN TRIM(toss_winner) = 'Delhi Daredevils' THEN 'Delhi Capitals'
                    WHEN TRIM(toss_winner) = 'Kings XI Punjab' THEN 'Punjab Kings'
                    WHEN TRIM(toss_winner) = 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
                    WHEN TRIM(toss_winner) = 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
                    ELSE TRIM(toss_winner)
                END AS toss_winner,

                LOWER(TRIM(toss_decision)) AS toss_decision,

                -- Standardize Match Winner & replace 'No Result' with NULL
                CASE 
                    WHEN TRIM(winner) IN ('No Result', 'Unknown', '') THEN NULL
                    WHEN TRIM(winner) = 'Delhi Daredevils' THEN 'Delhi Capitals'
                    WHEN TRIM(winner) = 'Kings XI Punjab' THEN 'Punjab Kings'
                    WHEN TRIM(winner) = 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
                    WHEN TRIM(winner) = 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
                    ELSE TRIM(winner)
                END AS winner,

                -- Replace 'Unknown' Player of Match with NULL
                CASE 
                    WHEN TRIM(player_of_match) IN ('Unknown', '') THEN NULL
                    ELSE TRIM(player_of_match)
                END AS player_of_match,

                TRIM(match_type) AS match_type,
                TRY_CAST(TRIM(overs) AS TINYINT) AS overs,
                TRY_CAST(TRIM(balls_per_over) AS TINYINT) AS balls_per_over,

                ROW_NUMBER() OVER (
                    PARTITION BY match_id 
                    ORDER BY TRY_CONVERT(DATE, TRIM(match_date), 105) DESC
                ) AS rn
            FROM bronze.crm_ipl_matches
            WHERE match_id IS NOT NULL
        )
        INSERT INTO silver.crm_ipl_matches (
            match_id, match_date, season, city, venue, team1, team2, 
            toss_winner, toss_decision, winner, player_of_match, 
            match_type, overs, balls_per_over
        )
        SELECT 
            match_id, match_date, season, city, venue, team1, team2, 
            toss_winner, toss_decision, winner, player_of_match, 
            match_type, overs, balls_per_over
        FROM CleanedMatches
        WHERE rn = 1;

        PRINT 'silver.crm_ipl_matches loaded successfully (' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows).';

        -- --------------------------------------------------
        -- 2. CLEAN AND LOAD: silver.crm_ipl_ball_by_ball
        -- --------------------------------------------------
        PRINT 'Truncating silver.crm_ipl_ball_by_ball...';
        TRUNCATE TABLE silver.crm_ipl_ball_by_ball;

        PRINT 'Inserting cleaned data into silver.crm_ipl_ball_by_ball...';
        ;WITH CleanedBallByBall AS (
            SELECT
                b.match_id,
                b.match_date,
                TRIM(b.season) AS season,

                -- Fix Missing/Unknown Cities based on Venue
                CASE 
                    WHEN TRIM(b.city) = 'Unknown' AND b.venue LIKE '%Dubai%' THEN 'Dubai'
                    WHEN TRIM(b.city) = 'Unknown' AND b.venue LIKE '%Sharjah%' THEN 'Sharjah'
                    WHEN TRIM(b.city) = 'Bangalore' THEN 'Bengaluru'
                    WHEN TRIM(b.city) = 'Unknown' THEN NULL
                    ELSE TRIM(b.city)
                END AS city,

                REPLACE(TRIM(b.venue), '"', '') AS venue,

                -- Standardize Teams
                CASE 
                    WHEN TRIM(b.team1) = 'Delhi Daredevils' THEN 'Delhi Capitals'
                    WHEN TRIM(b.team1) = 'Kings XI Punjab' THEN 'Punjab Kings'
                    WHEN TRIM(b.team1) = 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
                    WHEN TRIM(b.team1) = 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
                    ELSE TRIM(b.team1)
                END AS team1,

                CASE 
                    WHEN TRIM(b.team2) = 'Delhi Daredevils' THEN 'Delhi Capitals'
                    WHEN TRIM(b.team2) = 'Kings XI Punjab' THEN 'Punjab Kings'
                    WHEN TRIM(b.team2) = 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
                    WHEN TRIM(b.team2) = 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
                    ELSE TRIM(b.team2)
                END AS team2,

                CASE 
                    WHEN TRIM(b.batting_team) = 'Delhi Daredevils' THEN 'Delhi Capitals'
                    WHEN TRIM(b.batting_team) = 'Kings XI Punjab' THEN 'Punjab Kings'
                    WHEN TRIM(b.batting_team) = 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
                    WHEN TRIM(b.batting_team) = 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
                    ELSE TRIM(b.batting_team)
                END AS batting_team,

                CASE 
                    WHEN TRIM(b.bowling_team) = 'Delhi Daredevils' THEN 'Delhi Capitals'
                    WHEN TRIM(b.bowling_team) = 'Kings XI Punjab' THEN 'Punjab Kings'
                    WHEN TRIM(b.bowling_team) = 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
                    WHEN TRIM(b.bowling_team) = 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
                    ELSE TRIM(b.bowling_team)
                END AS bowling_team,

                TRY_CAST(TRIM(b.innings) AS TINYINT) AS innings,
                TRY_CAST(TRIM(b.overs) AS TINYINT) AS overs,
                TRY_CAST(TRIM(b.ball_in_over) AS TINYINT) AS ball_in_over,

                -- Boolean flags
                CASE WHEN TRIM(b.legal_ball) IN ('1', 'TRUE', 'true') THEN 1 ELSE 0 END AS legal_ball,
                TRY_CAST(TRIM(b.legal_ball_number) AS TINYINT) AS legal_ball_number,
                TRY_CAST(TRIM(b.over_ball_display) AS DECIMAL(4,1)) AS over_ball_display,

                TRIM(b.batter) AS batter,
                TRIM(b.bowler) AS bowler,
                TRIM(b.non_striker) AS non_striker,

                -- Runs and Extras (Default NULLs/blanks to 0)
                ISNULL(TRY_CAST(TRIM(b.batter_runs) AS TINYINT), 0) AS batter_runs,
                ISNULL(TRY_CAST(TRIM(b.extra_runs) AS TINYINT), 0) AS extra_runs,
                ISNULL(TRY_CAST(TRIM(b.total_runs) AS TINYINT), 0) AS total_runs,
                ISNULL(TRY_CAST(TRIM(b.wides) AS TINYINT), 0) AS wides,
                ISNULL(TRY_CAST(TRIM(b.noballs) AS TINYINT), 0) AS noballs,
                ISNULL(TRY_CAST(TRIM(b.byes) AS TINYINT), 0) AS byes,
                ISNULL(TRY_CAST(TRIM(b.legbyes) AS TINYINT), 0) AS legbyes,
                ISNULL(TRY_CAST(TRIM(b.penalty) AS TINYINT), 0) AS penalty,

                -- Boundary / Dot / Wicket Flags
                CASE WHEN TRIM(b.is_boundary_4) IN ('1', 'TRUE', 'true') THEN 1 ELSE 0 END AS is_boundary_4,
                CASE WHEN TRIM(b.is_boundary_6) IN ('1', 'TRUE', 'true') THEN 1 ELSE 0 END AS is_boundary_6,
                CASE WHEN TRIM(b.is_dot_ball) IN ('1', 'TRUE', 'true') THEN 1 ELSE 0 END AS is_dot_ball,
                CASE WHEN TRIM(b.is_wicket) IN ('1', 'TRUE', 'true') THEN 1 ELSE 0 END AS is_wicket,

                ISNULL(TRY_CAST(TRIM(b.wicket_count) AS TINYINT), 0) AS wicket_count,
                NULLIF(TRIM(b.wicket_player_out), '') AS wicket_player_out,
                NULLIF(TRIM(b.wicket_kind), '') AS wicket_kind,
                NULLIF(TRIM(b.wicket_fielders), '') AS wicket_fielders,

                TRY_CAST(TRIM(b.innings_runs_so_far) AS SMALLINT) AS innings_runs_so_far,
                TRY_CAST(TRIM(b.innings_wickets_so_far) AS TINYINT) AS innings_wickets_so_far,
                TRY_CAST(TRIM(b.balls_remaining) AS SMALLINT) AS balls_remaining,
                TRY_CAST(TRIM(b.current_run_rate) AS DECIMAL(5,2)) AS current_run_rate,

                TRIM(b.phase) AS phase,
                CASE WHEN TRIM(b.is_powerplay) IN ('1', 'TRUE', 'true') THEN 1 ELSE 0 END AS is_powerplay,
                CASE WHEN TRIM(b.is_middle_overs) IN ('1', 'TRUE', 'true') THEN 1 ELSE 0 END AS is_middle_overs,
                CASE WHEN TRIM(b.is_death_overs) IN ('1', 'TRUE', 'true') THEN 1 ELSE 0 END AS is_death_overs,

                CASE 
                    WHEN TRIM(b.toss_winner) = 'Delhi Daredevils' THEN 'Delhi Capitals'
                    WHEN TRIM(b.toss_winner) = 'Kings XI Punjab' THEN 'Punjab Kings'
                    WHEN TRIM(b.toss_winner) = 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
                    WHEN TRIM(b.toss_winner) = 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
                    ELSE TRIM(b.toss_winner)
                END AS toss_winner,

                LOWER(TRIM(b.toss_decision)) AS toss_decision,

                CASE 
                    WHEN TRIM(b.match_winner) IN ('No Result', 'Unknown', '') THEN NULL
                    WHEN TRIM(b.match_winner) = 'Delhi Daredevils' THEN 'Delhi Capitals'
                    WHEN TRIM(b.match_winner) = 'Kings XI Punjab' THEN 'Punjab Kings'
                    WHEN TRIM(b.match_winner) = 'Rising Pune Supergiants' THEN 'Rising Pune Supergiant'
                    WHEN TRIM(b.match_winner) = 'Royal Challengers Bangalore' THEN 'Royal Challengers Bengaluru'
                    ELSE TRIM(b.match_winner)
                END AS match_winner,

                CASE WHEN TRIM(b.batting_team_won) IN ('1', 'TRUE', 'true') THEN 1 
                     WHEN TRIM(b.batting_team_won) IN ('0', 'FALSE', 'false') THEN 0 
                     ELSE NULL END AS batting_team_won,

                TRY_CAST(TRIM(b.target) AS SMALLINT) AS target,
                TRY_CAST(TRIM(b.runs_required) AS SMALLINT) AS runs_required,
                TRY_CAST(TRIM(b.required_run_rate) AS DECIMAL(5,2)) AS required_run_rate,
                CASE WHEN TRIM(b.is_chasing) IN ('1', 'TRUE', 'true') THEN 1 
                     WHEN TRIM(b.is_chasing) IN ('0', 'FALSE', 'false') THEN 0 
                     ELSE NULL END AS is_chasing,

                -- Deduplication filter
                ROW_NUMBER() OVER (
                    PARTITION BY b.match_id, b.innings, b.overs, b.ball_in_over 
                    ORDER BY b.match_id
                ) AS rn
            FROM bronze.crm_ipl_ball_by_ball b
            WHERE b.match_id IS NOT NULL
        )
        INSERT INTO silver.crm_ipl_ball_by_ball (
            match_id, match_date, season, city, venue, team1, team2, 
            batting_team, bowling_team, innings, overs, ball_in_over, 
            legal_ball, legal_ball_number, over_ball_display, 
            batter, bowler, non_striker, batter_runs, extra_runs, 
            total_runs, wides, noballs, byes, legbyes, penalty, 
            is_boundary_4, is_boundary_6, is_dot_ball, is_wicket, 
            wicket_count, wicket_player_out, wicket_kind, wicket_fielders, 
            innings_runs_so_far, innings_wickets_so_far, balls_remaining, 
            current_run_rate, phase, is_powerplay, is_middle_overs, 
            is_death_overs, toss_winner, toss_decision, match_winner, 
            batting_team_won, target, runs_required, required_run_rate, is_chasing
        )
        SELECT 
            match_id, match_date, season, city, venue, team1, team2, 
            batting_team, bowling_team, innings, overs, ball_in_over, 
            legal_ball, legal_ball_number, over_ball_display, 
            batter, bowler, non_striker, batter_runs, extra_runs, 
            total_runs, wides, noballs, byes, legbyes, penalty, 
            is_boundary_4, is_boundary_6, is_dot_ball, is_wicket, 
            wicket_count, wicket_player_out, wicket_kind, wicket_fielders, 
            innings_runs_so_far, innings_wickets_so_far, balls_remaining, 
            current_run_rate, phase, is_powerplay, is_middle_overs, 
            is_death_overs, toss_winner, toss_decision, match_winner, 
            batting_team_won, target, runs_required, required_run_rate, is_chasing
        FROM CleanedBallByBall
        WHERE rn = 1;

        PRINT 'silver.crm_ipl_ball_by_ball loaded successfully (' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows).';
        PRINT '==================================================';
        PRINT 'Silver Layer Load Completed Successfully!';
        PRINT '==================================================';

    END TRY
    BEGIN CATCH
        PRINT 'ERROR: Failed to load silver layer.';
        PRINT ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO
