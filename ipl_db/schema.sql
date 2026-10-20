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
