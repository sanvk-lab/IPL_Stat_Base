# IPL Stat Base

Ball-by-ball Indian Premier League database. Every delivery carries the situation it was bowled in, and the views turn that into batting, bowling, venue, toss, and opposition summaries.

The request named contextual metrics and then stopped at "1)". **Phase of play is metric 1.** Metrics 2–8 are the rest of the usual situation frame, so the same ball can also be read by chase pressure, wickets in hand, batting position, venue, toss, opposition, and season. The definitions live in the `metrics` table.

## Data

Matches come from [Cricsheet](https://cricsheet.org/) (`ipl_json.zip`, archive dated 2026-10-07): 1,243 IPL matches, seasons 2008 through 2026. Cricsheet publishes that database under the [Open Data Commons Attribution License](data/cricsheet-LICENSE.txt). This SQLite file is a derived database. Attribute Cricsheet and keep the license notice with any copy.

```text
Match data © Cricsheet (https://cricsheet.org/), licensed under ODC-By.
```

`data/ipl.sqlite` is the built database. Rebuild it with the Python 3 standard library:

```bash
python -m ipl_db.build --download
# or, if the JSON files are already unpacked:
python -m ipl_db.build --json-dir /path/to/json --out data/ipl.sqlite
```

Print a short contextual report:

```bash
python -m ipl_db.report
```

Run one query:

```bash
python -m ipl_db.report --sql "SELECT player, phase, strike_rate FROM batter_phase_career WHERE player = 'V Kohli'"
```

More queries are in `sql/examples.sql`.

## Metrics

| # | Metric | Where it sits |
| --- | --- | --- |
| 1 | Phase of play | `deliveries.phase`, `batter_phase_career`, `bowler_phase_career` |
| 2 | Setting or chasing, and required rate | `deliveries.rrr_band`, `batter_pressure` |
| 3 | Wickets in hand | `deliveries.wickets_band`, `batter_pressure` |
| 4 | Batting position | `batting_innings`, `batter_position` |
| 5 | Venue | `matches.venue`, `venue_summary`, `venue_phase` |
| 6 | Toss | `toss_summary` |
| 7 | Opposition | `head_to_head`, `batter_vs_franchise`, `bowler_vs_franchise` |
| 8 | Season | `matches.season_year` on every season-scoped view |

### Phase of play

A full T20 innings is split at the over, not the ball:

- **powerplay** — overs 1–6
- **middle** — overs 7–15
- **death** — overs 16–20

Shorter innings use the T20 powerplay ladder (6 overs from 19, 5 from 15, 4 from 12, 3 from 9, 2 from 5, otherwise 1). Death is the last quarter of the allotment, and it never overlaps the powerplay. Super overs are phase `super_over`.

### Required rate

While a side is setting a total, `rrr_band` is `setting`. While chasing, the required rate is taken at the **start** of the ball:

| Band | Required run rate |
| --- | --- |
| `under_6` | below 6 |
| `6_to_9` | 6 up to 9 |
| `9_to_12` | 9 up to 12 |
| `12_plus` | 12 or more |
| `no_balls_left` | no legal balls left in the allotment |

Cricsheet target overs such as `16.2` mean 16 overs and 2 balls.

### Wickets in hand

Counted at the start of the ball. `8_to_10`, `5_to_7`, `3_to_4`, `0_to_2`. Retired hurt does not take a wicket. Retired out does.

### Counting rules

- Balls faced exclude wides and include no-balls.
- Bowler balls are legal balls only.
- Bowler runs are the total on the ball, excluding byes, leg-byes, and penalty runs.
- Bowler wickets are bowled, caught, caught and bowled, lbw, stumped, and hit wicket.
- A four or six is `batter_runs` of 4 or 6, which also includes an all-run four or six.
- A dot is a legal ball with no runs of any kind.
- Batting position is order of appearance. The striker on ball one is 1 and the non-striker is 2.
- `matches.winner` is the regulation winner. `matches.match_winner` is that winner, or the eliminator winner when the match was tied.
- Chase success in `venue_summary` uses the regulation winner.
- `team_phase.rate` is strike rate for batting rows and economy for bowling rows.

### Names that are folded together

Franchise renames share one name in the `franchise_*` columns. The original team name stays on the match.

- Delhi Daredevils → Delhi Capitals
- Kings XI Punjab → Punjab Kings
- Royal Challengers Bangalore → Royal Challengers Bengaluru
- Rising Pune Supergiants → Rising Pune Supergiant

Deccan Chargers and Sunrisers Hyderabad stay separate. Venue strings that are only a city suffix, or a rename of the same ground, share `matches.venue`. Sardar Patel Stadium, Motera and Narendra Modi Stadium stay separate because the old ground was demolished. The raw string is in `venue_names` and `matches.venue_raw`.

`season_year` is the edition year: `2007/08` → 2008, `2009/10` → 2010, `2020/21` → 2020.

## Tables

| Table | Contents |
| --- | --- |
| `matches` | One row per match, including toss, result, venue, and season |
| `innings` | Runs, wickets, target, and super-over flag |
| `deliveries` | One row per ball, with phase, required rate, wickets in hand, and batting position |
| `delivery_wickets` | Each dismissal on a ball |
| `batting_innings` | One innings for a batter, including the situation when they came in |
| `squads` | Listed players and their squad order |
| `players`, `teams`, `venues` | Ids, franchise names, and canonical grounds |
| `dataset_meta`, `metrics` | Source, license, and the metric definitions |

## Tests

```bash
python -m unittest discover -s tests
```
