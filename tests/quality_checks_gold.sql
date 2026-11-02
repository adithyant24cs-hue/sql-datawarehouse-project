USE Datawarehouse;
GO


SELECT TOP 10
    p.player_name,
    COUNT(DISTINCT f.match_id) AS matches_played,
    SUM(f.batter_runs) AS total_runs,
    SUM(CAST(f.is_boundary_4 AS INT)) AS fours,
    SUM(CAST(f.is_boundary_6 AS INT)) AS sixes,
    ROUND(CAST(SUM(f.batter_runs) AS FLOAT) / NULLIF(COUNT(DISTINCT f.match_id), 0), 2) AS runs_per_match
FROM gold.fact_ball_deliveries f
INNER JOIN gold.dim_player p ON f.batter_key = p.player_key
GROUP BY p.player_name
ORDER BY total_runs DESC;
GO


SELECT 
    t.team_name,
    COUNT(*) AS total_matches_won,
    COUNT(CASE WHEN m.toss_decision = 'bat' AND m.winner_key = m.toss_winner_key THEN 1 END) AS won_batting_first,
    COUNT(CASE WHEN m.toss_decision = 'field' AND m.winner_key = m.toss_winner_key THEN 1 END) AS won_chasing
FROM gold.fact_matches m
INNER JOIN gold.dim_team t ON m.winner_key = t.team_key
GROUP BY t.team_name
ORDER BY total_matches_won DESC;
GO

SELECT TOP 10
    p.player_name AS bowler,
    COUNT(DISTINCT f.match_id) AS matches_played,
    COUNT(CASE WHEN f.is_wicket = 1 AND f.wicket_kind NOT IN ('run out', 'retired hurt', 'obstructing the field') THEN 1 END) AS total_wickets,
    SUM(CAST(f.is_dot_ball AS INT)) AS dot_balls_bowled,
    SUM(f.total_runs) AS runs_conceded
FROM gold.fact_ball_deliveries f
INNER JOIN gold.dim_player p ON f.bowler_key = p.player_key
GROUP BY p.player_name
ORDER BY total_wickets DESC;
GO
