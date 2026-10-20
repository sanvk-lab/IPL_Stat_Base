# IPL Stat Base

Ball-by-ball Indian Premier League database. Batting and bowling are separate scorecards, and each scorecard is repeated on its own context axis: career, season, phase, venue, opposition, and batting position.

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

## Batting

`batter_career` is the career line. `batter_stats` is the same line with `axis` and `axis_value`.

| Column | Meaning |
| --- | --- |
| `matches` | Matches in the listed squad. On the batting-position axis, matches in which they batted there. On the phase axis, matches in which they faced that phase. |
| `innings` | Innings at the crease, including an opener who did not face a ball. |
| `runs` | Runs scored off the bat. |
| `average` | Runs per dismissal. A not-out, including retired hurt, stays out of the denominator. |
| `strike_rate` | Runs per 100 balls faced. Wides are not balls faced. |
| `runs_per_innings` | Runs divided by innings, not-outs included. |
| `fifties` | Innings of 50 to 99. |
| `hundreds` | Innings of 100 or more. |
| `fifties_sr_150` | Innings of 50 or more at a strike rate of 150 or higher. Hundreds are included. |
| `fifties_sr_200` | Innings of 50 or more at a strike rate of 200 or higher. |

A fifty belongs to the innings, so `fifties`, `hundreds`, `fifties_sr_150`, and `fifties_sr_200` are empty on the phase axis.

### Advanced batting

`batter_advanced` splits the same batter two more ways.

| `axis` | `axis_value` | What it is |
| --- | --- | --- |
| `innings` | `1` or `2` | Their side batted first, or chased |
| `team_total` | `above_170` or `170_or_below` | Their side's scoreboard total was above 170, or 170 or less |

On every row:

| Column | Meaning |
| --- | --- |
| `strike_rate`, `average`, `runs_per_innings` | The batter in that split. Average is runs per dismissal. Runs per innings keeps not-outs in the count. |
| `team_strike_rate`, `team_average` | The rest of the side in those same innings, with this batter removed. |
| `sr_above_team`, `average_above_team` | Batter minus the rest of the side. Positive means faster, or a higher average, than teammates. |
| `sr_vs_team`, `average_vs_team` | Batter divided by the rest of the side. `1.00` matches the teammates. |

The team rates use the teammates' runs and balls, so a batter is not compared with his own innings. Extras are in the 170 cutoff and out of both strike rates. Super overs are excluded.

## Bowling

`bowler_career` is the career line. `bowler_stats` carries the same axes except batting position.

| Column | Meaning |
| --- | --- |
| `matches` | Matches in the listed squad. On the phase axis, matches in which they bowled in that phase. |
| `wickets` | Bowled, caught, caught and bowled, lbw, stumped, and hit wicket. |
| `strike_rate` | Legal balls per wicket. |
| `economy` | Bowler runs per over. Byes, leg-byes, and penalty runs are excluded. |
| `average` | Bowler runs per wicket. |
| `four_wicket_hauls` | Innings with exactly four wickets. |
| `five_wicket_hauls` | Innings with five or more wickets. A six-wicket innings counts here, not also as a four-wicket haul. |
| `wickets_per_match` | Wickets divided by `matches`. |

Haul columns are empty on the phase axis.

### Advanced bowling

`bowler_advanced` uses the same two splits, with the bowling cutoff at 200.

| `axis` | `axis_value` | What it is |
| --- | --- | --- |
| `innings` | `1` or `2` | Bowling at the side batting first, or bowling second |
| `team_total` | `above_200` or `200_or_below` | The batting side's scoreboard total was above 200, or 200 or less |

| Column | Meaning |
| --- | --- |
| `strike_rate` | Legal balls per wicket. |
| `average` | Bowler runs per wicket. |
| `wickets` | Wickets in the split. |
| `wickets_per_innings` | Average wickets per bowling innings. |
| `team_strike_rate`, `team_average` | The rest of the attack in those same innings, with this bowler removed. |
| `sr_above_team`, `average_above_team` | Bowler minus the rest of the attack. Negative means fewer balls per wicket, or fewer runs per wicket, than teammates. |
| `sr_vs_team`, `average_vs_team` | Bowler divided by the rest of the attack. Below `1.00` is better than teammates. |

Super overs are excluded. The 200 cutoff counts extras on the scoreboard. The rates do not.

Axes in `batter_stats` and `bowler_stats`:

| `axis` | `axis_value` |
| --- | --- |
| `career` | `all` |
| `season` | Edition year, such as `2024` |
| `phase` | `powerplay`, `middle`, `death`, or `super_over` |
| `venue` | Canonical ground |
| `opposition` | Opposing franchise |
| `batting_position` | `1` through `11`, batting only |

Super overs are excluded from every axis except `phase = 'super_over'`.

## Situation cuts

These sit under the scorecards. The definitions also live in the `metrics` table.

| # | Cut | Where it sits |
| --- | --- | --- |
| 1 | Phase of play | `deliveries.phase`, `batter_stats` where `axis = 'phase'` |
| 2 | Setting or chasing, and required rate | `deliveries.rrr_band`, `batter_pressure` |
| 3 | Wickets in hand | `deliveries.wickets_band`, `batter_pressure` |
| 4 | Batting position | `batter_stats` where `axis = 'batting_position'` |
| 5 | Venue | `batter_stats` / `bowler_stats` where `axis = 'venue'` |
| 6 | Toss | `toss_summary` |
| 7 | Opposition | `axis = 'opposition'`, plus `head_to_head` |
| 8 | Season | `axis = 'season'` |

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
