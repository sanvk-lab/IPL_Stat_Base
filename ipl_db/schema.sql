PRAGMA foreign_keys = ON;

CREATE TABLE dataset_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE metrics (
    metric_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    definition TEXT NOT NULL
);

CREATE TABLE players (
    player_id TEXT PRIMARY KEY,
    full_name TEXT NOT NULL,
    other_names TEXT
);

CREATE TABLE teams (
    team_name TEXT PRIMARY KEY,
    franchise_id TEXT NOT NULL,
    franchise_name TEXT NOT NULL
);

CREATE TABLE venues (
    venue TEXT PRIMARY KEY,
    city TEXT
);

CREATE TABLE venue_names (
    raw_name TEXT PRIMARY KEY,
    venue TEXT NOT NULL REFERENCES venues(venue)
);

CREATE TABLE matches (
    match_id INTEGER PRIMARY KEY,
    season_raw TEXT NOT NULL,
    season_year INTEGER NOT NULL,
    match_date TEXT NOT NULL,
    match_end_date TEXT,
    match_number INTEGER,
    stage TEXT NOT NULL,
    city TEXT,
    venue_raw TEXT,
    venue TEXT NOT NULL,
    team_a TEXT NOT NULL,
    team_b TEXT NOT NULL,
    franchise_a TEXT NOT NULL,
    franchise_b TEXT NOT NULL,
    toss_winner TEXT,
    toss_winner_franchise TEXT,
    toss_decision TEXT,
    result TEXT NOT NULL,
    winner TEXT,
    winner_franchise TEXT,
    eliminator_winner TEXT,
    eliminator_winner_franchise TEXT,
    match_winner TEXT,
    match_winner_franchise TEXT,
    win_by_runs INTEGER,
    win_by_wickets INTEGER,
    method TEXT,
    player_of_match TEXT,
    balls_per_over INTEGER NOT NULL,
    scheduled_overs INTEGER,
    data_version TEXT,
    source_file TEXT NOT NULL
);

CREATE TABLE squads (
    match_id INTEGER NOT NULL REFERENCES matches(match_id),
    team_name TEXT NOT NULL,
    player_id TEXT NOT NULL REFERENCES players(player_id),
    squad_order INTEGER NOT NULL,
    PRIMARY KEY (match_id, team_name, player_id)
);

CREATE TABLE innings (
    match_id INTEGER NOT NULL REFERENCES matches(match_id),
    innings_number INTEGER NOT NULL,
    batting_team TEXT NOT NULL,
    bowling_team TEXT NOT NULL,
    batting_franchise TEXT NOT NULL,
    bowling_franchise TEXT NOT NULL,
    is_super_over INTEGER NOT NULL,
    target_runs INTEGER,
    target_overs REAL,
    scheduled_overs INTEGER NOT NULL,
    scheduled_balls INTEGER,
    penalty_pre INTEGER NOT NULL,
    penalty_post INTEGER NOT NULL,
    runs INTEGER NOT NULL,
    wickets INTEGER NOT NULL,
    legal_balls INTEGER NOT NULL,
    PRIMARY KEY (match_id, innings_number)
);

CREATE TABLE deliveries (
    delivery_id INTEGER PRIMARY KEY,
    match_id INTEGER NOT NULL,
    innings_number INTEGER NOT NULL,
    over_number INTEGER NOT NULL,
    ball_in_over INTEGER NOT NULL,
    actual_delivery TEXT,
    is_legal INTEGER NOT NULL,
    is_super_over INTEGER NOT NULL,
    batter_id TEXT NOT NULL,
    bowler_id TEXT NOT NULL,
    non_striker_id TEXT NOT NULL,
    batter_runs INTEGER NOT NULL,
    extra_runs INTEGER NOT NULL,
    total_runs INTEGER NOT NULL,
    bowler_runs INTEGER NOT NULL,
    wide_runs INTEGER NOT NULL,
    noball_runs INTEGER NOT NULL,
    bye_runs INTEGER NOT NULL,
    legbye_runs INTEGER NOT NULL,
    penalty_runs INTEGER NOT NULL,
    is_four INTEGER NOT NULL,
    is_six INTEGER NOT NULL,
    is_dot INTEGER NOT NULL,
    wicket_count INTEGER NOT NULL,
    bowler_wickets INTEGER NOT NULL,
    player_out_id TEXT,
    wicket_kind TEXT,
    phase TEXT NOT NULL,
    batting_position INTEGER NOT NULL,
    innings_runs_before INTEGER NOT NULL,
    wickets_before INTEGER NOT NULL,
    legal_balls_before INTEGER NOT NULL,
    wickets_in_hand INTEGER NOT NULL,
    runs_required INTEGER,
    balls_remaining INTEGER,
    required_rr REAL,
    rrr_band TEXT NOT NULL,
    wickets_band TEXT NOT NULL,
    current_rr REAL,
    partnership_runs_before INTEGER NOT NULL,
    FOREIGN KEY (match_id, innings_number) REFERENCES innings(match_id, innings_number)
);

CREATE TABLE delivery_wickets (
    delivery_id INTEGER NOT NULL REFERENCES deliveries(delivery_id),
    player_out_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    bowler_credited INTEGER NOT NULL,
    fielders TEXT
);

CREATE TABLE batting_innings (
    match_id INTEGER NOT NULL,
    innings_number INTEGER NOT NULL,
    player_id TEXT NOT NULL,
    batting_position INTEGER NOT NULL,
    runs INTEGER NOT NULL,
    balls INTEGER NOT NULL,
    fours INTEGER NOT NULL,
    sixes INTEGER NOT NULL,
    dots INTEGER NOT NULL,
    dismissal_kind TEXT,
    bowler_out_id TEXT,
    entry_runs INTEGER NOT NULL,
    entry_wickets INTEGER NOT NULL,
    entry_phase TEXT NOT NULL,
    entry_rrr REAL,
    entry_rrr_band TEXT NOT NULL,
    entry_wickets_band TEXT NOT NULL,
    is_super_over INTEGER NOT NULL,
    PRIMARY KEY (match_id, innings_number, player_id),
    FOREIGN KEY (match_id, innings_number) REFERENCES innings(match_id, innings_number)
);

CREATE INDEX idx_deliveries_batter ON deliveries(batter_id);
CREATE INDEX idx_deliveries_bowler ON deliveries(bowler_id);
CREATE INDEX idx_deliveries_phase ON deliveries(phase);
CREATE INDEX idx_deliveries_match ON deliveries(match_id, innings_number);
CREATE INDEX idx_matches_season ON matches(season_year);
CREATE INDEX idx_matches_venue ON matches(venue);
CREATE INDEX idx_batting_player ON batting_innings(player_id);
CREATE INDEX idx_wickets_delivery ON delivery_wickets(delivery_id);
CREATE INDEX idx_wickets_player ON delivery_wickets(player_out_id);

CREATE VIEW batter_phase AS
WITH scoring AS (
    SELECT
        m.season_year,
        d.batter_id AS player_id,
        d.phase,
        COUNT(DISTINCT printf('%s-%s', d.match_id, d.innings_number)) AS innings,
        SUM(d.batter_runs) AS runs,
        SUM(CASE WHEN d.wide_runs = 0 THEN 1 ELSE 0 END) AS balls,
        SUM(d.is_four) AS fours,
        SUM(d.is_six) AS sixes,
        SUM(d.is_dot) AS dots
    FROM deliveries AS d
    JOIN matches AS m ON m.match_id = d.match_id
    GROUP BY m.season_year, d.batter_id, d.phase
),
outs AS (
    SELECT
        m.season_year,
        w.player_out_id AS player_id,
        d.phase,
        COUNT(*) AS dismissals
    FROM delivery_wickets AS w
    JOIN deliveries AS d ON d.delivery_id = w.delivery_id
    JOIN matches AS m ON m.match_id = d.match_id
    WHERE w.kind != 'retired hurt'
    GROUP BY m.season_year, w.player_out_id, d.phase
),
keys AS (
    SELECT season_year, player_id, phase FROM scoring
    UNION
    SELECT season_year, player_id, phase FROM outs
)
SELECT
    k.season_year,
    k.player_id,
    p.full_name AS player,
    k.phase,
    COALESCE(s.innings, 0) AS innings,
    COALESCE(s.runs, 0) AS runs,
    COALESCE(s.balls, 0) AS balls,
    COALESCE(s.fours, 0) AS fours,
    COALESCE(s.sixes, 0) AS sixes,
    COALESCE(s.dots, 0) AS dots,
    COALESCE(o.dismissals, 0) AS dismissals
FROM keys AS k
JOIN players AS p ON p.player_id = k.player_id
LEFT JOIN scoring AS s
    ON s.season_year = k.season_year AND s.player_id = k.player_id AND s.phase = k.phase
LEFT JOIN outs AS o
    ON o.season_year = k.season_year AND o.player_id = k.player_id AND o.phase = k.phase;

CREATE VIEW batter_phase_career AS
SELECT
    player_id,
    player,
    phase,
    SUM(innings) AS innings,
    SUM(runs) AS runs,
    SUM(balls) AS balls,
    SUM(fours) AS fours,
    SUM(sixes) AS sixes,
    SUM(dots) AS dots,
    SUM(dismissals) AS dismissals,
    ROUND(100.0 * SUM(runs) / NULLIF(SUM(balls), 0), 2) AS strike_rate,
    ROUND(1.0 * SUM(runs) / NULLIF(SUM(dismissals), 0), 2) AS average,
    ROUND(100.0 * (SUM(fours) + SUM(sixes)) / NULLIF(SUM(balls), 0), 2) AS boundary_percent,
    ROUND(100.0 * SUM(dots) / NULLIF(SUM(balls), 0), 2) AS dot_percent
FROM batter_phase
GROUP BY player_id, player, phase;

CREATE VIEW bowler_phase AS
SELECT
    m.season_year,
    d.bowler_id AS player_id,
    p.full_name AS player,
    d.phase,
    COUNT(DISTINCT printf('%s-%s', d.match_id, d.innings_number)) AS innings,
    SUM(d.is_legal) AS balls,
    SUM(d.bowler_runs) AS runs,
    SUM(d.bowler_wickets) AS wickets,
    SUM(d.is_dot) AS dots,
    SUM(d.is_four) AS fours,
    SUM(d.is_six) AS sixes
FROM deliveries AS d
JOIN matches AS m ON m.match_id = d.match_id
JOIN players AS p ON p.player_id = d.bowler_id
GROUP BY m.season_year, d.bowler_id, p.full_name, d.phase;

CREATE VIEW bowler_phase_career AS
SELECT
    player_id,
    player,
    phase,
    SUM(innings) AS innings,
    SUM(balls) AS balls,
    SUM(runs) AS runs,
    SUM(wickets) AS wickets,
    SUM(dots) AS dots,
    ROUND(6.0 * SUM(runs) / NULLIF(SUM(balls), 0), 2) AS economy,
    ROUND(1.0 * SUM(runs) / NULLIF(SUM(wickets), 0), 2) AS average,
    ROUND(1.0 * SUM(balls) / NULLIF(SUM(wickets), 0), 2) AS strike_rate,
    ROUND(100.0 * SUM(dots) / NULLIF(SUM(balls), 0), 2) AS dot_percent
FROM bowler_phase
GROUP BY player_id, player, phase;

CREATE VIEW batter_pressure AS
WITH scoring AS (
    SELECT
        d.batter_id AS player_id,
        d.rrr_band,
        d.wickets_band,
        SUM(d.batter_runs) AS runs,
        SUM(CASE WHEN d.wide_runs = 0 THEN 1 ELSE 0 END) AS balls
    FROM deliveries AS d
    WHERE d.is_super_over = 0
    GROUP BY d.batter_id, d.rrr_band, d.wickets_band
),
outs AS (
    SELECT
        w.player_out_id AS player_id,
        d.rrr_band,
        d.wickets_band,
        COUNT(*) AS dismissals
    FROM delivery_wickets AS w
    JOIN deliveries AS d ON d.delivery_id = w.delivery_id
    WHERE d.is_super_over = 0 AND w.kind != 'retired hurt'
    GROUP BY w.player_out_id, d.rrr_band, d.wickets_band
)
SELECT
    p.full_name AS player,
    s.player_id,
    s.rrr_band,
    s.wickets_band,
    s.runs,
    s.balls,
    COALESCE(o.dismissals, 0) AS dismissals,
    ROUND(100.0 * s.runs / NULLIF(s.balls, 0), 2) AS strike_rate
FROM scoring AS s
JOIN players AS p ON p.player_id = s.player_id
LEFT JOIN outs AS o
    ON o.player_id = s.player_id
    AND o.rrr_band = s.rrr_band
    AND o.wickets_band = s.wickets_band;

CREATE VIEW batter_position AS
SELECT
    p.full_name AS player,
    b.player_id,
    b.batting_position,
    COUNT(*) AS innings,
    SUM(b.runs) AS runs,
    SUM(b.balls) AS balls,
    SUM(CASE WHEN b.dismissal_kind IS NOT NULL THEN 1 ELSE 0 END) AS dismissals,
    ROUND(100.0 * SUM(b.runs) / NULLIF(SUM(b.balls), 0), 2) AS strike_rate,
    ROUND(
        1.0 * SUM(b.runs) / NULLIF(SUM(CASE WHEN b.dismissal_kind IS NOT NULL THEN 1 ELSE 0 END), 0),
        2
    ) AS average
FROM batting_innings AS b
JOIN players AS p ON p.player_id = b.player_id
WHERE b.is_super_over = 0
GROUP BY p.full_name, b.player_id, b.batting_position;

CREATE VIEW batter_entry AS
SELECT
    p.full_name AS player,
    b.player_id,
    b.entry_phase,
    b.entry_wickets_band,
    b.entry_rrr_band,
    COUNT(*) AS innings,
    SUM(b.runs) AS runs,
    SUM(b.balls) AS balls,
    ROUND(100.0 * SUM(b.runs) / NULLIF(SUM(b.balls), 0), 2) AS strike_rate
FROM batting_innings AS b
JOIN players AS p ON p.player_id = b.player_id
WHERE b.is_super_over = 0
GROUP BY p.full_name, b.player_id, b.entry_phase, b.entry_wickets_band, b.entry_rrr_band;

CREATE VIEW venue_summary AS
WITH inn AS (
    SELECT
        match_id,
        MAX(CASE WHEN innings_number = 1 THEN runs END) AS first_runs,
        MAX(CASE WHEN innings_number = 2 THEN runs END) AS second_runs,
        MAX(CASE WHEN innings_number = 2 THEN batting_team END) AS chase_team
    FROM innings
    WHERE is_super_over = 0 AND innings_number IN (1, 2)
    GROUP BY match_id
)
SELECT
    m.venue,
    v.city,
    COUNT(*) AS matches,
    SUM(CASE WHEN m.result != 'no result' THEN 1 ELSE 0 END) AS completed,
    ROUND(AVG(inn.first_runs), 1) AS avg_first_innings,
    ROUND(AVG(inn.second_runs), 1) AS avg_second_innings,
    SUM(CASE WHEN m.winner = inn.chase_team THEN 1 ELSE 0 END) AS chases_won,
    SUM(CASE WHEN m.result = 'win' AND inn.chase_team IS NOT NULL THEN 1 ELSE 0 END) AS decided_chases
FROM matches AS m
JOIN venues AS v ON v.venue = m.venue
LEFT JOIN inn ON inn.match_id = m.match_id
GROUP BY m.venue, v.city;

CREATE VIEW venue_phase AS
SELECT
    m.venue,
    d.phase,
    SUM(d.total_runs) AS runs,
    SUM(d.is_legal) AS balls,
    SUM(d.wicket_count) AS wickets,
    ROUND(6.0 * SUM(d.total_runs) / NULLIF(SUM(d.is_legal), 0), 2) AS scoring_rate
FROM deliveries AS d
JOIN matches AS m ON m.match_id = d.match_id
WHERE d.is_super_over = 0
GROUP BY m.venue, d.phase;

CREATE VIEW toss_summary AS
SELECT
    season_year,
    toss_decision,
    COUNT(*) AS matches,
    SUM(CASE WHEN result = 'no result' THEN 1 ELSE 0 END) AS no_results,
    SUM(CASE WHEN result = 'tie' THEN 1 ELSE 0 END) AS ties,
    SUM(CASE WHEN result = 'win' AND toss_winner = winner THEN 1 ELSE 0 END) AS toss_winner_won,
    SUM(CASE WHEN result = 'win' THEN 1 ELSE 0 END) AS decided
FROM matches
GROUP BY season_year, toss_decision;

CREATE VIEW head_to_head AS
SELECT
    CASE WHEN franchise_a < franchise_b THEN franchise_a ELSE franchise_b END AS franchise_1,
    CASE WHEN franchise_a < franchise_b THEN franchise_b ELSE franchise_a END AS franchise_2,
    COUNT(*) AS matches,
    SUM(
        CASE
            WHEN match_winner_franchise = CASE
                WHEN franchise_a < franchise_b THEN franchise_a ELSE franchise_b
            END THEN 1 ELSE 0
        END
    ) AS wins_1,
    SUM(
        CASE
            WHEN match_winner_franchise = CASE
                WHEN franchise_a < franchise_b THEN franchise_b ELSE franchise_a
            END THEN 1 ELSE 0
        END
    ) AS wins_2
FROM matches
WHERE result != 'no result'
GROUP BY franchise_1, franchise_2;

CREATE VIEW batter_vs_franchise AS
WITH scoring AS (
    SELECT
        d.batter_id AS player_id,
        i.bowling_franchise AS opposition,
        SUM(d.batter_runs) AS runs,
        SUM(CASE WHEN d.wide_runs = 0 THEN 1 ELSE 0 END) AS balls
    FROM deliveries AS d
    JOIN innings AS i
        ON i.match_id = d.match_id AND i.innings_number = d.innings_number
    WHERE d.is_super_over = 0
    GROUP BY d.batter_id, i.bowling_franchise
),
outs AS (
    SELECT
        w.player_out_id AS player_id,
        i.bowling_franchise AS opposition,
        COUNT(*) AS dismissals
    FROM delivery_wickets AS w
    JOIN deliveries AS d ON d.delivery_id = w.delivery_id
    JOIN innings AS i
        ON i.match_id = d.match_id AND i.innings_number = d.innings_number
    WHERE d.is_super_over = 0 AND w.kind != 'retired hurt'
    GROUP BY w.player_out_id, i.bowling_franchise
)
SELECT
    p.full_name AS player,
    s.player_id,
    s.opposition,
    s.runs,
    s.balls,
    COALESCE(o.dismissals, 0) AS dismissals,
    ROUND(100.0 * s.runs / NULLIF(s.balls, 0), 2) AS strike_rate
FROM scoring AS s
JOIN players AS p ON p.player_id = s.player_id
LEFT JOIN outs AS o
    ON o.player_id = s.player_id AND o.opposition = s.opposition;

CREATE VIEW bowler_vs_franchise AS
SELECT
    p.full_name AS player,
    d.bowler_id AS player_id,
    i.batting_franchise AS opposition,
    SUM(d.is_legal) AS balls,
    SUM(d.bowler_runs) AS runs,
    SUM(d.bowler_wickets) AS wickets,
    ROUND(6.0 * SUM(d.bowler_runs) / NULLIF(SUM(d.is_legal), 0), 2) AS economy
FROM deliveries AS d
JOIN innings AS i
    ON i.match_id = d.match_id AND i.innings_number = d.innings_number
JOIN players AS p ON p.player_id = d.bowler_id
WHERE d.is_super_over = 0
GROUP BY p.full_name, d.bowler_id, i.batting_franchise;

CREATE VIEW team_phase AS
SELECT
    m.season_year,
    i.batting_franchise AS franchise,
    'batting' AS role,
    d.phase,
    SUM(d.batter_runs) AS runs,
    SUM(CASE WHEN d.wide_runs = 0 THEN 1 ELSE 0 END) AS balls,
    SUM(d.wicket_count) AS wickets,
    ROUND(
        100.0 * SUM(d.batter_runs)
        / NULLIF(SUM(CASE WHEN d.wide_runs = 0 THEN 1 ELSE 0 END), 0),
        2
    ) AS rate
FROM deliveries AS d
JOIN matches AS m ON m.match_id = d.match_id
JOIN innings AS i
    ON i.match_id = d.match_id AND i.innings_number = d.innings_number
WHERE d.is_super_over = 0
GROUP BY m.season_year, i.batting_franchise, d.phase
UNION ALL
SELECT
    m.season_year,
    i.bowling_franchise AS franchise,
    'bowling' AS role,
    d.phase,
    SUM(d.bowler_runs) AS runs,
    SUM(d.is_legal) AS balls,
    SUM(d.bowler_wickets) AS wickets,
    ROUND(6.0 * SUM(d.bowler_runs) / NULLIF(SUM(d.is_legal), 0), 2) AS rate
FROM deliveries AS d
JOIN matches AS m ON m.match_id = d.match_id
JOIN innings AS i
    ON i.match_id = d.match_id AND i.innings_number = d.innings_number
WHERE d.is_super_over = 0
GROUP BY m.season_year, i.bowling_franchise, d.phase;

-- Scorecard measures, one row per player per context axis.
-- Career, season, venue, and opposition rows count a fifty or a
-- wicket-haul for the whole innings. Phase rows carry the rate stats
-- only: a fifty is not a property of one phase, so those columns are null.
-- Super overs are left out of every axis except phase = 'super_over'.

CREATE VIEW player_appearances AS
SELECT
    s.player_id,
    s.match_id,
    m.season_year,
    m.venue,
    CASE
        WHEN t.franchise_name = m.franchise_a THEN m.franchise_b
        ELSE m.franchise_a
    END AS opposition
FROM squads AS s
JOIN matches AS m ON m.match_id = s.match_id
JOIN teams AS t ON t.team_name = s.team_name;

CREATE VIEW player_matches AS
SELECT 'career' AS axis, 'all' AS axis_value, player_id, COUNT(DISTINCT match_id) AS matches
FROM player_appearances
GROUP BY player_id
UNION ALL
SELECT 'season', CAST(season_year AS TEXT), player_id, COUNT(DISTINCT match_id)
FROM player_appearances
GROUP BY player_id, season_year
UNION ALL
SELECT 'venue', venue, player_id, COUNT(DISTINCT match_id)
FROM player_appearances
GROUP BY player_id, venue
UNION ALL
SELECT 'opposition', opposition, player_id, COUNT(DISTINCT match_id)
FROM player_appearances
GROUP BY player_id, opposition;

CREATE VIEW batter_innings_detail AS
SELECT
    b.match_id,
    b.player_id,
    b.runs,
    b.balls,
    b.batting_position,
    CASE WHEN b.dismissal_kind IS NOT NULL THEN 1 ELSE 0 END AS dismissed,
    m.season_year,
    m.venue,
    i.bowling_franchise AS opposition,
    CASE WHEN b.runs >= 50 AND b.runs < 100 THEN 1 ELSE 0 END AS is_fifty,
    CASE WHEN b.runs >= 100 THEN 1 ELSE 0 END AS is_hundred,
    CASE
        WHEN b.runs >= 50 AND b.balls > 0 AND (100.0 * b.runs / b.balls) >= 150 THEN 1
        ELSE 0
    END AS is_fifty_sr_150,
    CASE
        WHEN b.runs >= 50 AND b.balls > 0 AND (100.0 * b.runs / b.balls) >= 200 THEN 1
        ELSE 0
    END AS is_fifty_sr_200
FROM batting_innings AS b
JOIN matches AS m ON m.match_id = b.match_id
JOIN innings AS i
    ON i.match_id = b.match_id AND i.innings_number = b.innings_number
WHERE b.is_super_over = 0;

CREATE VIEW batter_stats AS
WITH scored AS (
    SELECT
        'career' AS axis,
        'all' AS axis_value,
        player_id,
        COUNT(DISTINCT match_id) AS batting_matches,
        COUNT(*) AS innings,
        SUM(runs) AS runs,
        SUM(balls) AS balls,
        SUM(dismissed) AS dismissals,
        SUM(is_fifty) AS fifties,
        SUM(is_hundred) AS hundreds,
        SUM(is_fifty_sr_150) AS fifties_sr_150,
        SUM(is_fifty_sr_200) AS fifties_sr_200
    FROM batter_innings_detail
    GROUP BY player_id
    UNION ALL
    SELECT
        'season',
        CAST(season_year AS TEXT),
        player_id,
        COUNT(DISTINCT match_id),
        COUNT(*),
        SUM(runs),
        SUM(balls),
        SUM(dismissed),
        SUM(is_fifty),
        SUM(is_hundred),
        SUM(is_fifty_sr_150),
        SUM(is_fifty_sr_200)
    FROM batter_innings_detail
    GROUP BY player_id, season_year
    UNION ALL
    SELECT
        'venue',
        venue,
        player_id,
        COUNT(DISTINCT match_id),
        COUNT(*),
        SUM(runs),
        SUM(balls),
        SUM(dismissed),
        SUM(is_fifty),
        SUM(is_hundred),
        SUM(is_fifty_sr_150),
        SUM(is_fifty_sr_200)
    FROM batter_innings_detail
    GROUP BY player_id, venue
    UNION ALL
    SELECT
        'opposition',
        opposition,
        player_id,
        COUNT(DISTINCT match_id),
        COUNT(*),
        SUM(runs),
        SUM(balls),
        SUM(dismissed),
        SUM(is_fifty),
        SUM(is_hundred),
        SUM(is_fifty_sr_150),
        SUM(is_fifty_sr_200)
    FROM batter_innings_detail
    GROUP BY player_id, opposition
    UNION ALL
    SELECT
        'batting_position',
        CAST(batting_position AS TEXT),
        player_id,
        COUNT(DISTINCT match_id),
        COUNT(*),
        SUM(runs),
        SUM(balls),
        SUM(dismissed),
        SUM(is_fifty),
        SUM(is_hundred),
        SUM(is_fifty_sr_150),
        SUM(is_fifty_sr_200)
    FROM batter_innings_detail
    GROUP BY player_id, batting_position
),
phase_scoring AS (
    SELECT
        d.batter_id AS player_id,
        d.phase AS axis_value,
        COUNT(DISTINCT d.match_id) AS matches,
        COUNT(DISTINCT printf('%s-%s', d.match_id, d.innings_number)) AS innings,
        SUM(d.batter_runs) AS runs,
        SUM(CASE WHEN d.wide_runs = 0 THEN 1 ELSE 0 END) AS balls
    FROM deliveries AS d
    GROUP BY d.batter_id, d.phase
),
phase_outs AS (
    SELECT
        w.player_out_id AS player_id,
        d.phase AS axis_value,
        COUNT(*) AS dismissals
    FROM delivery_wickets AS w
    JOIN deliveries AS d ON d.delivery_id = w.delivery_id
    WHERE w.kind != 'retired hurt'
    GROUP BY w.player_out_id, d.phase
),
phased AS (
    SELECT
        s.player_id,
        s.axis_value,
        s.matches,
        s.innings,
        s.runs,
        s.balls,
        COALESCE(o.dismissals, 0) AS dismissals
    FROM phase_scoring AS s
    LEFT JOIN phase_outs AS o
        ON o.player_id = s.player_id AND o.axis_value = s.axis_value
    UNION ALL
    SELECT
        o.player_id,
        o.axis_value,
        COUNT(DISTINCT d.match_id),
        COUNT(DISTINCT printf('%s-%s', d.match_id, d.innings_number)),
        0,
        0,
        o.dismissals
    FROM phase_outs AS o
    JOIN delivery_wickets AS w ON w.player_out_id = o.player_id AND w.kind != 'retired hurt'
    JOIN deliveries AS d ON d.delivery_id = w.delivery_id AND d.phase = o.axis_value
    WHERE NOT EXISTS (
        SELECT 1 FROM phase_scoring AS s
        WHERE s.player_id = o.player_id AND s.axis_value = o.axis_value
    )
    GROUP BY o.player_id, o.axis_value, o.dismissals
),
keys AS (
    SELECT axis, axis_value, player_id FROM scored
    UNION
    SELECT axis, axis_value, player_id FROM player_matches
    UNION
    SELECT 'phase', axis_value, player_id FROM phased
)
SELECT
    p.full_name AS player,
    k.player_id,
    k.axis,
    k.axis_value,
    CASE
        WHEN k.axis = 'phase' THEN ph.matches
        WHEN k.axis = 'batting_position' THEN s.batting_matches
        ELSE COALESCE(pm.matches, s.batting_matches, 0)
    END AS matches,
    COALESCE(CASE WHEN k.axis = 'phase' THEN ph.innings ELSE s.innings END, 0) AS innings,
    COALESCE(CASE WHEN k.axis = 'phase' THEN ph.runs ELSE s.runs END, 0) AS runs,
    COALESCE(CASE WHEN k.axis = 'phase' THEN ph.balls ELSE s.balls END, 0) AS balls,
    COALESCE(CASE WHEN k.axis = 'phase' THEN ph.dismissals ELSE s.dismissals END, 0) AS dismissals,
    ROUND(
        1.0 * CASE WHEN k.axis = 'phase' THEN ph.runs ELSE s.runs END
        / NULLIF(CASE WHEN k.axis = 'phase' THEN ph.dismissals ELSE s.dismissals END, 0),
        2
    ) AS average,
    ROUND(
        100.0 * CASE WHEN k.axis = 'phase' THEN ph.runs ELSE s.runs END
        / NULLIF(CASE WHEN k.axis = 'phase' THEN ph.balls ELSE s.balls END, 0),
        2
    ) AS strike_rate,
    ROUND(
        1.0 * CASE WHEN k.axis = 'phase' THEN ph.runs ELSE s.runs END
        / NULLIF(CASE WHEN k.axis = 'phase' THEN ph.innings ELSE s.innings END, 0),
        2
    ) AS runs_per_innings,
    CASE WHEN k.axis = 'phase' THEN NULL ELSE COALESCE(s.fifties, 0) END AS fifties,
    CASE WHEN k.axis = 'phase' THEN NULL ELSE COALESCE(s.hundreds, 0) END AS hundreds,
    CASE WHEN k.axis = 'phase' THEN NULL ELSE COALESCE(s.fifties_sr_150, 0) END AS fifties_sr_150,
    CASE WHEN k.axis = 'phase' THEN NULL ELSE COALESCE(s.fifties_sr_200, 0) END AS fifties_sr_200
FROM keys AS k
JOIN players AS p ON p.player_id = k.player_id
LEFT JOIN scored AS s
    ON s.axis = k.axis AND s.axis_value = k.axis_value AND s.player_id = k.player_id
LEFT JOIN player_matches AS pm
    ON pm.axis = k.axis AND pm.axis_value = k.axis_value AND pm.player_id = k.player_id
LEFT JOIN phased AS ph
    ON k.axis = 'phase' AND ph.axis_value = k.axis_value AND ph.player_id = k.player_id
WHERE k.axis = 'phase'
   OR s.player_id IS NOT NULL
   OR (pm.player_id IS NOT NULL AND k.axis = 'career' AND s.player_id IS NOT NULL);

CREATE VIEW batter_career AS
SELECT
    player,
    player_id,
    matches,
    innings,
    runs,
    average,
    strike_rate,
    runs_per_innings,
    fifties,
    hundreds,
    fifties_sr_150,
    fifties_sr_200
FROM batter_stats
WHERE axis = 'career';

CREATE VIEW bowling_innings AS
SELECT
    d.match_id,
    d.innings_number,
    d.bowler_id AS player_id,
    m.season_year,
    m.venue,
    i.batting_franchise AS opposition,
    SUM(d.is_legal) AS balls,
    SUM(d.bowler_runs) AS runs,
    SUM(d.bowler_wickets) AS wickets
FROM deliveries AS d
JOIN matches AS m ON m.match_id = d.match_id
JOIN innings AS i
    ON i.match_id = d.match_id AND i.innings_number = d.innings_number
WHERE d.is_super_over = 0
GROUP BY d.match_id, d.innings_number, d.bowler_id, m.season_year, m.venue, i.batting_franchise;

CREATE VIEW bowler_stats AS
WITH bowled AS (
    SELECT
        'career' AS axis,
        'all' AS axis_value,
        player_id,
        COUNT(DISTINCT match_id) AS bowling_matches,
        COUNT(*) AS innings,
        SUM(balls) AS balls,
        SUM(runs) AS runs,
        SUM(wickets) AS wickets,
        SUM(CASE WHEN wickets = 4 THEN 1 ELSE 0 END) AS four_wicket_hauls,
        SUM(CASE WHEN wickets >= 5 THEN 1 ELSE 0 END) AS five_wicket_hauls
    FROM bowling_innings
    GROUP BY player_id
    UNION ALL
    SELECT
        'season',
        CAST(season_year AS TEXT),
        player_id,
        COUNT(DISTINCT match_id),
        COUNT(*),
        SUM(balls),
        SUM(runs),
        SUM(wickets),
        SUM(CASE WHEN wickets = 4 THEN 1 ELSE 0 END),
        SUM(CASE WHEN wickets >= 5 THEN 1 ELSE 0 END)
    FROM bowling_innings
    GROUP BY player_id, season_year
    UNION ALL
    SELECT
        'venue',
        venue,
        player_id,
        COUNT(DISTINCT match_id),
        COUNT(*),
        SUM(balls),
        SUM(runs),
        SUM(wickets),
        SUM(CASE WHEN wickets = 4 THEN 1 ELSE 0 END),
        SUM(CASE WHEN wickets >= 5 THEN 1 ELSE 0 END)
    FROM bowling_innings
    GROUP BY player_id, venue
    UNION ALL
    SELECT
        'opposition',
        opposition,
        player_id,
        COUNT(DISTINCT match_id),
        COUNT(*),
        SUM(balls),
        SUM(runs),
        SUM(wickets),
        SUM(CASE WHEN wickets = 4 THEN 1 ELSE 0 END),
        SUM(CASE WHEN wickets >= 5 THEN 1 ELSE 0 END)
    FROM bowling_innings
    GROUP BY player_id, opposition
),
phased AS (
    SELECT
        d.bowler_id AS player_id,
        d.phase AS axis_value,
        COUNT(DISTINCT d.match_id) AS matches,
        COUNT(DISTINCT printf('%s-%s', d.match_id, d.innings_number)) AS innings,
        SUM(d.is_legal) AS balls,
        SUM(d.bowler_runs) AS runs,
        SUM(d.bowler_wickets) AS wickets
    FROM deliveries AS d
    GROUP BY d.bowler_id, d.phase
),
keys AS (
    SELECT axis, axis_value, player_id FROM bowled
    UNION
    SELECT 'phase', axis_value, player_id FROM phased
)
SELECT
    p.full_name AS player,
    k.player_id,
    k.axis,
    k.axis_value,
    CASE
        WHEN k.axis = 'phase' THEN ph.matches
        ELSE COALESCE(pm.matches, b.bowling_matches, 0)
    END AS matches,
    COALESCE(CASE WHEN k.axis = 'phase' THEN ph.innings ELSE b.innings END, 0) AS innings,
    COALESCE(CASE WHEN k.axis = 'phase' THEN ph.balls ELSE b.balls END, 0) AS balls,
    COALESCE(CASE WHEN k.axis = 'phase' THEN ph.runs ELSE b.runs END, 0) AS runs,
    COALESCE(CASE WHEN k.axis = 'phase' THEN ph.wickets ELSE b.wickets END, 0) AS wickets,
    ROUND(
        1.0 * CASE WHEN k.axis = 'phase' THEN ph.balls ELSE b.balls END
        / NULLIF(CASE WHEN k.axis = 'phase' THEN ph.wickets ELSE b.wickets END, 0),
        2
    ) AS strike_rate,
    ROUND(
        6.0 * CASE WHEN k.axis = 'phase' THEN ph.runs ELSE b.runs END
        / NULLIF(CASE WHEN k.axis = 'phase' THEN ph.balls ELSE b.balls END, 0),
        2
    ) AS economy,
    ROUND(
        1.0 * CASE WHEN k.axis = 'phase' THEN ph.runs ELSE b.runs END
        / NULLIF(CASE WHEN k.axis = 'phase' THEN ph.wickets ELSE b.wickets END, 0),
        2
    ) AS average,
    CASE WHEN k.axis = 'phase' THEN NULL ELSE COALESCE(b.four_wicket_hauls, 0) END AS four_wicket_hauls,
    CASE WHEN k.axis = 'phase' THEN NULL ELSE COALESCE(b.five_wicket_hauls, 0) END AS five_wicket_hauls,
    ROUND(
        1.0 * CASE WHEN k.axis = 'phase' THEN ph.wickets ELSE b.wickets END
        / NULLIF(
            CASE
                WHEN k.axis = 'phase' THEN ph.matches
                ELSE COALESCE(pm.matches, b.bowling_matches)
            END,
            0
        ),
        2
    ) AS wickets_per_match
FROM keys AS k
JOIN players AS p ON p.player_id = k.player_id
LEFT JOIN bowled AS b
    ON b.axis = k.axis AND b.axis_value = k.axis_value AND b.player_id = k.player_id
LEFT JOIN player_matches AS pm
    ON pm.axis = k.axis AND pm.axis_value = k.axis_value AND pm.player_id = k.player_id
LEFT JOIN phased AS ph
    ON k.axis = 'phase' AND ph.axis_value = k.axis_value AND ph.player_id = k.player_id;

CREATE VIEW bowler_career AS
SELECT
    player,
    player_id,
    matches,
    wickets,
    strike_rate,
    economy,
    average,
    four_wicket_hauls,
    five_wicket_hauls,
    wickets_per_match
FROM bowler_stats
WHERE axis = 'career';
