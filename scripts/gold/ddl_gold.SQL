USE Datawarehouse;
GO

-- 1. Create Gold Schema if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold')
BEGIN
    EXEC('CREATE SCHEMA gold');
END
GO

-- --------------------------------------------------------
-- 2. DROP EXISTING DIMENSION TABLES (if re-running)
-- --------------------------------------------------------
IF OBJECT_ID('gold.dim_venue', 'U') IS NOT NULL DROP TABLE gold.dim_venue;
IF OBJECT_ID('gold.dim_player', 'U') IS NOT NULL DROP TABLE gold.dim_player;
IF OBJECT_ID('gold.dim_team', 'U') IS NOT NULL DROP TABLE gold.dim_team;
IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL DROP TABLE gold.dim_date;
GO

-- ========================================================
-- 3. CREATE DIMENSION TABLES
-- ========================================================

-- Dimension 1: Calendar / Date Dimension
CREATE TABLE gold.dim_date (
    date_key          INT PRIMARY KEY,          -- Format: YYYYMMDD (e.g., 20170405)
    full_date         DATE NOT NULL UNIQUE,
    year              SMALLINT NOT NULL,
    month             TINYINT NOT NULL,
    month_name        VARCHAR(15) NOT NULL,
    day               TINYINT NOT NULL,
    day_name          VARCHAR(15) NOT NULL,
    day_of_week       TINYINT NOT NULL,
    quarter           TINYINT NOT NULL,
    is_weekend        BIT NOT NULL
);
GO

-- Dimension 2: Team Dimension
CREATE TABLE gold.dim_team (
    team_key          INT IDENTITY(1,1) PRIMARY KEY,
    team_name         VARCHAR(50) NOT NULL UNIQUE
);
GO

-- Dimension 3: Player Dimension (Batters, Bowlers, Player of Match)
CREATE TABLE gold.dim_player (
    player_key        INT IDENTITY(1,1) PRIMARY KEY,
    player_name       VARCHAR(100) NOT NULL UNIQUE
);
GO

-- Dimension 4: Venue & Stadium Dimension
CREATE TABLE gold.dim_venue (
    venue_key         INT IDENTITY(1,1) PRIMARY KEY,
    venue_name        VARCHAR(150) NOT NULL,
    city              VARCHAR(50) NULL,
    CONSTRAINT UQ_gold_dim_venue UNIQUE (venue_name, city)
);
GO


USE Datawarehouse;
GO

-- --------------------------------------------------------
-- 1. DROP EXISTING FACT TABLES (Order matters due to FKs)
-- --------------------------------------------------------
IF OBJECT_ID('gold.fact_ball_deliveries', 'U') IS NOT NULL 
    DROP TABLE gold.fact_ball_deliveries;

IF OBJECT_ID('gold.fact_matches', 'U') IS NOT NULL 
    DROP TABLE gold.fact_matches;
GO

-- ========================================================
-- 2. FACT TABLE 1: MATCH LEVEL (1 row per match)
-- ========================================================
CREATE TABLE gold.fact_matches (
    match_id               INT PRIMARY KEY,
    date_key               INT NOT NULL REFERENCES gold.dim_date(date_key),
    venue_key              INT NOT NULL REFERENCES gold.dim_venue(venue_key),
    team1_key              INT NOT NULL REFERENCES gold.dim_team(team_key),
    team2_key              INT NOT NULL REFERENCES gold.dim_team(team_key),
    toss_winner_key        INT NOT NULL REFERENCES gold.dim_team(team_key),
    toss_decision          VARCHAR(10) NOT NULL,
    winner_key             INT NULL REFERENCES gold.dim_team(team_key),          -- NULL if No Result
    player_of_match_key    INT NULL REFERENCES gold.dim_player(player_key),      -- NULL if Unknown
    season                 VARCHAR(10) NOT NULL,
    match_type             VARCHAR(20) NOT NULL,
    overs                  TINYINT NOT NULL,
    balls_per_over         TINYINT NOT NULL,
    is_result              BIT NOT NULL                                          -- 1 = Winner declared, 0 = No Result
);
GO

-- ========================================================
-- 3. FACT TABLE 2: BALL DELIVERIES LEVEL (1 row per ball)
-- ========================================================
CREATE TABLE gold.fact_ball_deliveries (
    delivery_id            BIGINT IDENTITY(1,1) PRIMARY KEY,
    match_id               INT NOT NULL REFERENCES gold.fact_matches(match_id),
    date_key               INT NOT NULL REFERENCES gold.dim_date(date_key),
    venue_key              INT NOT NULL REFERENCES gold.dim_venue(venue_key),
    batting_team_key       INT NOT NULL REFERENCES gold.dim_team(team_key),
    bowling_team_key       INT NOT NULL REFERENCES gold.dim_team(team_key),
    batter_key             INT NOT NULL REFERENCES gold.dim_player(player_key),
    bowler_key             INT NOT NULL REFERENCES gold.dim_player(player_key),
    non_striker_key        INT NOT NULL REFERENCES gold.dim_player(player_key),
    player_dismissed_key   INT NULL REFERENCES gold.dim_player(player_key),

    -- Ball Event Dimensions
    innings                TINYINT NOT NULL,
    overs                  TINYINT NOT NULL,
    ball_in_over           TINYINT NOT NULL,
    over_ball_display      DECIMAL(4,1) NULL,
    legal_ball             BIT NOT NULL,

    -- Numerical Measures (Runs & Extras)
    batter_runs            TINYINT NOT NULL DEFAULT 0,
    extra_runs             TINYINT NOT NULL DEFAULT 0,
    total_runs             TINYINT NOT NULL DEFAULT 0,
    wides                  TINYINT NOT NULL DEFAULT 0,
    noballs                TINYINT NOT NULL DEFAULT 0,
    byes                   TINYINT NOT NULL DEFAULT 0,
    legbyes                TINYINT NOT NULL DEFAULT 0,
    penalty                TINYINT NOT NULL DEFAULT 0,

    -- Event Flags
    is_boundary_4          BIT NOT NULL DEFAULT 0,
    is_boundary_6          BIT NOT NULL DEFAULT 0,
    is_dot_ball            BIT NOT NULL DEFAULT 0,
    is_wicket              BIT NOT NULL DEFAULT 0,
    wicket_count           TINYINT NOT NULL DEFAULT 0,
    wicket_kind            VARCHAR(50) NULL,

    -- Match Phase Flags
    phase                  VARCHAR(20) NULL,
    is_powerplay           BIT NOT NULL DEFAULT 0,
    is_middle_overs        BIT NOT NULL DEFAULT 0,
    is_death_overs         BIT NOT NULL DEFAULT 0
);
GO

-- ========================================================
-- 4. PERFORMANCE INDEXES ON FOREIGN KEYS
-- Crucial for fast Star Schema JOINs in BI & reporting
-- ========================================================
CREATE NONCLUSTERED INDEX IX_fact_matches_date ON gold.fact_matches(date_key);
CREATE NONCLUSTERED INDEX IX_fact_matches_venue ON gold.fact_matches(venue_key);
CREATE NONCLUSTERED INDEX IX_fact_matches_team1 ON gold.fact_matches(team1_key);
CREATE NONCLUSTERED INDEX IX_fact_matches_team2 ON gold.fact_matches(team2_key);
CREATE NONCLUSTERED INDEX IX_fact_matches_winner ON gold.fact_matches(winner_key);

CREATE NONCLUSTERED INDEX IX_fact_deliveries_match ON gold.fact_ball_deliveries(match_id);
CREATE NONCLUSTERED INDEX IX_fact_deliveries_batter ON gold.fact_ball_deliveries(batter_key);
CREATE NONCLUSTERED INDEX IX_fact_deliveries_bowler ON gold.fact_ball_deliveries(bowler_key);
CREATE NONCLUSTERED INDEX IX_fact_deliveries_batteam ON gold.fact_ball_deliveries(batting_team_key);
CREATE NONCLUSTERED INDEX IX_fact_deliveries_bowlteam ON gold.fact_ball_deliveries(bowling_team_key);
GO


USE Datawarehouse;
GO

PRINT '==================================================';
PRINT 'Populating Gold Star Schema';
PRINT '==================================================';

-- 1. DELETE DATA SAFELY (In reverse FK dependency order)
DELETE FROM gold.fact_ball_deliveries;
DELETE FROM gold.fact_matches;
DELETE FROM gold.dim_venue;
DBCC CHECKIDENT ('gold.dim_venue', RESEED, 0);
DELETE FROM gold.dim_player;
DBCC CHECKIDENT ('gold.dim_player', RESEED, 0);
DELETE FROM gold.dim_team;
DBCC CHECKIDENT ('gold.dim_team', RESEED, 0);
DELETE FROM gold.dim_date;
GO

-- 2. POPULATE DIM_DATE
PRINT '1/6 Loading dim_date...';
INSERT INTO gold.dim_date (
    date_key, full_date, year, month, month_name, 
    day, day_name, day_of_week, quarter, is_weekend
)
SELECT 
    YEAR(d.match_date) * 10000 + MONTH(d.match_date) * 100 + DAY(d.match_date) AS date_key,
    d.match_date,
    YEAR(d.match_date) AS [year],
    MONTH(d.match_date) AS [month],
    DATENAME(MONTH, d.match_date) AS month_name,
    DAY(d.match_date) AS [day],
    DATENAME(WEEKDAY, d.match_date) AS day_name,
    DATEPART(WEEKDAY, d.match_date) AS day_of_week,
    DATEPART(QUARTER, d.match_date) AS [quarter],
    CASE WHEN DATEPART(WEEKDAY, d.match_date) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM (
    SELECT DISTINCT match_date FROM silver.crm_ipl_matches WHERE match_date IS NOT NULL
) d;
GO

-- 3. POPULATE DIM_TEAM
PRINT '2/6 Loading dim_team...';
INSERT INTO gold.dim_team (team_name)
SELECT DISTINCT team_name
FROM (
    SELECT team1 AS team_name FROM silver.crm_ipl_matches WHERE team1 IS NOT NULL
    UNION
    SELECT team2 FROM silver.crm_ipl_matches WHERE team2 IS NOT NULL
    UNION
    SELECT batting_team FROM silver.crm_ipl_ball_by_ball WHERE batting_team IS NOT NULL
    UNION
    SELECT bowling_team FROM silver.crm_ipl_ball_by_ball WHERE bowling_team IS NOT NULL
) t
WHERE team_name NOT LIKE '%"%'  -- Filters out any stray quotes
ORDER BY team_name;
GO

-- 4. POPULATE DIM_PLAYER
PRINT '3/6 Loading dim_player...';
INSERT INTO gold.dim_player (player_name)
SELECT DISTINCT player_name
FROM (
    SELECT batter AS player_name FROM silver.crm_ipl_ball_by_ball WHERE batter IS NOT NULL
    UNION
    SELECT bowler FROM silver.crm_ipl_ball_by_ball WHERE bowler IS NOT NULL
    UNION
    SELECT non_striker FROM silver.crm_ipl_ball_by_ball WHERE non_striker IS NOT NULL
    UNION
    SELECT wicket_player_out FROM silver.crm_ipl_ball_by_ball WHERE wicket_player_out IS NOT NULL
    UNION
    SELECT player_of_match FROM silver.crm_ipl_matches WHERE player_of_match IS NOT NULL
) p
ORDER BY player_name;
GO

-- 5. POPULATE DIM_VENUE
PRINT '4/6 Loading dim_venue...';
INSERT INTO gold.dim_venue (venue_name, city)
SELECT DISTINCT venue, city
FROM silver.crm_ipl_matches
WHERE venue IS NOT NULL;
GO

-- 6. POPULATE FACT_MATCHES
PRINT '5/6 Loading fact_matches...';
INSERT INTO gold.fact_matches (
    match_id, date_key, venue_key, team1_key, team2_key, 
    toss_winner_key, toss_decision, winner_key, player_of_match_key, 
    season, match_type, overs, balls_per_over, is_result
)
SELECT 
    m.match_id,
    d.date_key,
    v.venue_key,
    t1.team_key  AS team1_key,
    t2.team_key  AS team2_key,
    tw.team_key  AS toss_winner_key,
    CASE WHEN m.toss_decision IN ('bat', 'field') THEN m.toss_decision ELSE 'field' END AS toss_decision,
    w.team_key   AS winner_key,
    p.player_key AS player_of_match_key,
    m.season,
    m.match_type,
    m.overs,
    m.balls_per_over,
    CASE WHEN m.winner IS NOT NULL THEN 1 ELSE 0 END AS is_result
FROM silver.crm_ipl_matches m
INNER JOIN gold.dim_date d  ON m.match_date = d.full_date
INNER JOIN gold.dim_venue v ON m.venue = v.venue_name AND ISNULL(m.city, '') = ISNULL(v.city, '')
INNER JOIN gold.dim_team t1 ON m.team1 = t1.team_name
INNER JOIN gold.dim_team t2 ON m.team2 = t2.team_name
INNER JOIN gold.dim_team tw ON m.toss_winner = tw.team_name
LEFT JOIN gold.dim_team w   ON m.winner = w.team_name
LEFT JOIN gold.dim_player p ON m.player_of_match = p.player_name;
GO

-- 7. POPULATE FACT_BALL_DELIVERIES
PRINT '6/6 Loading fact_ball_deliveries...';
INSERT INTO gold.fact_ball_deliveries (
    match_id, date_key, venue_key, batting_team_key, bowling_team_key, 
    batter_key, bowler_key, non_striker_key, player_dismissed_key, 
    innings, overs, ball_in_over, over_ball_display, legal_ball, 
    batter_runs, extra_runs, total_runs, wides, noballs, byes, legbyes, penalty, 
    is_boundary_4, is_boundary_6, is_dot_ball, is_wicket, wicket_count, 
    wicket_kind, phase, is_powerplay, is_middle_overs, is_death_overs
)
SELECT 
    b.match_id,
    d.date_key,
    v.venue_key,
    bt.team_key   AS batting_team_key,
    bl.team_key   AS bowling_team_key,
    bat.player_key AS batter_key,
    bowl.player_key AS bowler_key,
    ns.player_key AS non_striker_key,
    pout.player_key AS player_dismissed_key,
    ISNULL(b.innings, 1) AS innings,
    b.overs,
    b.ball_in_over,
    b.over_ball_display,
    b.legal_ball,
    b.batter_runs,
    b.extra_runs,
    b.total_runs,
    b.wides,
    b.noballs,
    b.byes,
    b.legbyes,
    b.penalty,
    b.is_boundary_4,
    b.is_boundary_6,
    b.is_dot_ball,
    b.is_wicket,
    b.wicket_count,
    b.wicket_kind,
    b.phase,
    b.is_powerplay,
    b.is_middle_overs,
    b.is_death_overs
FROM silver.crm_ipl_ball_by_ball b
INNER JOIN gold.fact_matches fm ON b.match_id = fm.match_id
INNER JOIN gold.dim_date d   ON b.match_date = d.full_date
INNER JOIN gold.dim_venue v  ON b.venue = v.venue_name AND ISNULL(b.city, '') = ISNULL(v.city, '')
INNER JOIN gold.dim_team bt  ON b.batting_team = bt.team_name
INNER JOIN gold.dim_team bl  ON b.bowling_team = bl.team_name
INNER JOIN gold.dim_player bat  ON b.batter = bat.player_name
INNER JOIN gold.dim_player bowl ON b.bowler = bowl.player_name
INNER JOIN gold.dim_player ns   ON b.non_striker = ns.player_name
LEFT JOIN gold.dim_player pout  ON b.wicket_player_out = pout.player_name;
GO

PRINT '==================================================';
PRINT 'Star Schema Model Loaded Successfully!';
PRINT '==================================================';

-- Verify counts
SELECT 'dim_date' AS [Table], COUNT(*) AS [Rows] FROM gold.dim_date
UNION ALL SELECT 'dim_team', COUNT(*) FROM gold.dim_team
UNION ALL SELECT 'dim_player', COUNT(*) FROM gold.dim_player
UNION ALL SELECT 'dim_venue', COUNT(*) FROM gold.dim_venue
UNION ALL SELECT 'fact_matches', COUNT(*) FROM gold.fact_matches
UNION ALL SELECT 'fact_ball_deliveries', COUNT(*) FROM gold.fact_ball_deliveries;
GO



USE Datawarehouse;
GO

PRINT '==================================================';
PRINT 'Completing Star Schema Load (Fact Tables)';
PRINT '==================================================';

-- 1. Clear fact tables safely
DELETE FROM gold.fact_ball_deliveries;
DELETE FROM gold.fact_matches;
GO

-- 2. POPULATE FACT_MATCHES (With NULL safety defaults)
PRINT 'Loading gold.fact_matches...';

INSERT INTO gold.fact_matches (
    match_id, date_key, venue_key, team1_key, team2_key, 
    toss_winner_key, toss_decision, winner_key, player_of_match_key, 
    season, match_type, overs, balls_per_over, is_result
)
SELECT 
    m.match_id,
    d.date_key,
    v.venue_key,
    t1.team_key  AS team1_key,
    t2.team_key  AS team2_key,
    tw.team_key  AS toss_winner_key,
    CASE WHEN m.toss_decision IN ('bat', 'field') THEN m.toss_decision ELSE 'field' END AS toss_decision,
    w.team_key   AS winner_key,
    p.player_key AS player_of_match_key,
    ISNULL(m.season, 'Unknown') AS season,
    ISNULL(m.match_type, 'T20') AS match_type,
    ISNULL(m.overs, 20)         AS overs,           -- Default to 20 if NULL
    ISNULL(m.balls_per_over, 6) AS balls_per_over,  -- Default to 6 if NULL
    CASE WHEN m.winner IS NOT NULL THEN 1 ELSE 0 END AS is_result
FROM silver.crm_ipl_matches m
INNER JOIN gold.dim_date d  ON m.match_date = d.full_date
INNER JOIN gold.dim_venue v ON m.venue = v.venue_name AND ISNULL(m.city, '') = ISNULL(v.city, '')
INNER JOIN gold.dim_team t1 ON m.team1 = t1.team_name
INNER JOIN gold.dim_team t2 ON m.team2 = t2.team_name
INNER JOIN gold.dim_team tw ON m.toss_winner = tw.team_name
LEFT JOIN gold.dim_team w   ON m.winner = w.team_name
LEFT JOIN gold.dim_player p ON m.player_of_match = p.player_name;

PRINT 'gold.fact_matches loaded successfully (' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows).';
GO

-- 3. POPULATE FACT_BALL_DELIVERIES
PRINT 'Loading gold.fact_ball_deliveries...';

INSERT INTO gold.fact_ball_deliveries (
    match_id, date_key, venue_key, batting_team_key, bowling_team_key, 
    batter_key, bowler_key, non_striker_key, player_dismissed_key, 
    innings, overs, ball_in_over, over_ball_display, legal_ball, 
    batter_runs, extra_runs, total_runs, wides, noballs, byes, legbyes, penalty, 
    is_boundary_4, is_boundary_6, is_dot_ball, is_wicket, wicket_count, 
    wicket_kind, phase, is_powerplay, is_middle_overs, is_death_overs
)
SELECT 
    b.match_id,
    fm.date_key,       -- Inherited directly from fact_matches
    fm.venue_key,      -- Inherited directly from fact_matches
    bt.team_key   AS batting_team_key,
    bl.team_key   AS bowling_team_key,
    bat.player_key AS batter_key,
    bowl.player_key AS bowler_key,
    ns.player_key AS non_striker_key,
    pout.player_key AS player_dismissed_key,
    ISNULL(b.innings, 1) AS innings,
    ISNULL(b.overs, 0) AS overs,
    ISNULL(b.ball_in_over, 1) AS ball_in_over,
    b.over_ball_display,
    b.legal_ball,
    b.batter_runs,
    b.extra_runs,
    b.total_runs,
    b.wides,
    b.noballs,
    b.byes,
    b.legbyes,
    b.penalty,
    b.is_boundary_4,
    b.is_boundary_6,
    b.is_dot_ball,
    b.is_wicket,
    b.wicket_count,
    b.wicket_kind,
    b.phase,
    b.is_powerplay,
    b.is_middle_overs,
    b.is_death_overs
FROM silver.crm_ipl_ball_by_ball b
INNER JOIN gold.fact_matches fm ON b.match_id = fm.match_id
INNER JOIN gold.dim_team bt  ON b.batting_team = bt.team_name
INNER JOIN gold.dim_team bl  ON b.bowling_team = bl.team_name
INNER JOIN gold.dim_player bat  ON b.batter = bat.player_name
INNER JOIN gold.dim_player bowl ON b.bowler = bowl.player_name
INNER JOIN gold.dim_player ns   ON b.non_striker = ns.player_name
LEFT JOIN gold.dim_player pout  ON b.wicket_player_out = pout.player_name;

PRINT 'gold.fact_ball_deliveries loaded successfully (' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows).';
GO

PRINT '==================================================';
PRINT 'FINAL VERIFICATION: ALL STAR SCHEMA TABLES';
PRINT '==================================================';

SELECT 'dim_date' AS [Table], COUNT(*) AS [Total_Rows] FROM gold.dim_date
UNION ALL SELECT 'dim_team', COUNT(*) FROM gold.dim_team
UNION ALL SELECT 'dim_player', COUNT(*) FROM gold.dim_player
UNION ALL SELECT 'dim_venue', COUNT(*) FROM gold.dim_venue
UNION ALL SELECT 'fact_matches', COUNT(*) FROM gold.fact_matches
UNION ALL SELECT 'fact_ball_deliveries', COUNT(*) FROM gold.fact_ball_deliveries;
GO
