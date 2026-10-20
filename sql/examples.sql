-- Contextual IPL queries. Open data/ipl.sqlite and run any statement.
-- Rates treat a wide as not a ball faced. Bowler runs exclude byes,
-- leg-byes, and penalty runs. Regulation winners ignore the eliminator.

-- 1. Phase of play. Career strike rate by phase, minimum 150 balls.
SELECT player, phase, innings, runs, balls, dismissals, strike_rate, average, boundary_percent
FROM batter_phase_career
WHERE phase != 'super_over' AND balls >= 150
ORDER BY phase, strike_rate DESC;

-- 1. Death bowling economy, minimum 120 legal balls.
SELECT player, balls, runs, wickets, economy, average, dot_percent
FROM bowler_phase_career
WHERE phase = 'death' AND balls >= 120
ORDER BY economy;

-- 2. Required rate. Batting when the chase already needs 12 an over.
SELECT player, runs, balls, dismissals, strike_rate
FROM batter_pressure
WHERE rrr_band = '12_plus' AND balls >= 80
ORDER BY strike_rate DESC;

-- 3. Wickets in hand. The same batters once 8 wickets are down.
SELECT player, runs, balls, dismissals, strike_rate
FROM batter_pressure
WHERE wickets_band = '0_to_2' AND rrr_band != 'setting' AND balls >= 60
ORDER BY strike_rate DESC;

-- 4. Batting position. Output from number 4.
SELECT player, innings, runs, balls, dismissals, strike_rate, average
FROM batter_position
WHERE batting_position = 4 AND balls >= 200
ORDER BY average DESC;

-- 5. Venue. Scoring rate by phase at one ground.
SELECT phase, runs, balls, wickets, scoring_rate
FROM venue_phase
WHERE venue = 'M Chinnaswamy Stadium, Bengaluru'
ORDER BY CASE phase
    WHEN 'powerplay' THEN 1
    WHEN 'middle' THEN 2
    WHEN 'death' THEN 3
END;

-- 6. Toss. Did choosing to bowl win the match that season?
SELECT season_year, toss_decision, matches, toss_winner_won, decided,
       ROUND(100.0 * toss_winner_won / NULLIF(decided, 0), 1) AS win_percent
FROM toss_summary
ORDER BY season_year, toss_decision;

-- 7. Opposition. One batter against each franchise.
SELECT opposition, runs, balls, dismissals, strike_rate
FROM batter_vs_franchise
WHERE player = 'V Kohli'
ORDER BY runs DESC;

-- 8. Season. A franchise's batting strike rate by phase in one edition.
-- For batting rows, rate is the strike rate. For bowling rows, rate is the economy.
SELECT phase, runs, balls, wickets, rate
FROM team_phase
WHERE season_year = 2026 AND franchise = 'Mumbai Indians' AND role = 'batting'
ORDER BY phase;
