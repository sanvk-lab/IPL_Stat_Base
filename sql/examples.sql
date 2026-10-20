-- Batting and bowling scorecards. Each context is its own axis:
-- career, season, phase, venue, opposition, and batting_position.
-- Phase rows leave fifties, hundreds, and wicket hauls empty.

-- First-innings strike rate and average against the rest of the side.
-- sr_above_team is batter strike rate minus teammates. sr_vs_team is the ratio.
SELECT player, matches, innings, runs, strike_rate, team_strike_rate, sr_above_team, sr_vs_team,
       average, team_average, average_above_team, average_vs_team, runs_per_innings
FROM batter_advanced
WHERE axis = 'innings' AND axis_value = '1' AND balls >= 200
ORDER BY sr_above_team DESC;

-- Same comparison while chasing.
SELECT player, runs, strike_rate, team_strike_rate, sr_above_team, average, team_average, average_above_team
FROM batter_advanced
WHERE axis = 'innings' AND axis_value = '2' AND balls >= 200
ORDER BY sr_above_team DESC;

-- Strike rate, average, and runs per innings when the side's total is above 170,
-- and when it is 170 or less.
SELECT player, axis_value, runs, balls, strike_rate, average, runs_per_innings
FROM batter_advanced
WHERE axis = 'team_total' AND player = 'V Kohli'
ORDER BY axis_value;

-- Career batting: matches, runs, average, strike rate, runs per innings,
-- fifties, hundreds, and fifties-plus scored at a strike rate of 150 or 200.
SELECT player, matches, innings, runs, average, strike_rate, runs_per_innings,
       fifties, hundreds, fifties_sr_150, fifties_sr_200
FROM batter_career
ORDER BY runs DESC;

-- The same batting measures against one franchise.
SELECT player, matches, runs, average, strike_rate, runs_per_innings,
       fifties, hundreds, fifties_sr_150, fifties_sr_200
FROM batter_stats
WHERE axis = 'opposition' AND axis_value = 'Chennai Super Kings'
ORDER BY runs DESC;

-- First-innings bowling strike rate and average against the rest of the attack.
-- A negative sr_above_team means fewer balls per wicket than teammates.
SELECT player, matches, innings, wickets, wickets_per_innings, strike_rate, team_strike_rate,
       sr_above_team, sr_vs_team, average, team_average, average_above_team, average_vs_team
FROM bowler_advanced
WHERE axis = 'innings' AND axis_value = '1' AND balls >= 200
ORDER BY sr_above_team;

-- Same comparison while bowling second.
SELECT player, wickets, strike_rate, team_strike_rate, sr_above_team, average, team_average, average_above_team
FROM bowler_advanced
WHERE axis = 'innings' AND axis_value = '2' AND balls >= 200
ORDER BY sr_above_team;

-- Strike rate, average, and wickets when the batting side's total is above 200,
-- and when it is 200 or less.
SELECT player, axis_value, wickets, wickets_per_innings, strike_rate, average
FROM bowler_advanced
WHERE axis = 'team_total' AND player = 'JJ Bumrah'
ORDER BY axis_value;

-- Career bowling: matches, wickets, balls per wicket, economy,
-- runs per wicket, four- and five-wicket hauls, wickets per match.
SELECT player, matches, wickets, strike_rate, economy, average,
       four_wicket_hauls, five_wicket_hauls, wickets_per_match
FROM bowler_career
ORDER BY wickets DESC;

-- Bowling measures in the death overs. Haul columns are empty here.
SELECT player, matches, wickets, strike_rate, economy, average, wickets_per_match
FROM bowler_stats
WHERE axis = 'phase' AND axis_value = 'death' AND balls >= 200
ORDER BY economy;

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
