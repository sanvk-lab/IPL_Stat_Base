import sqlite3
import unittest
from pathlib import Path

from ipl_db.build import build
from ipl_db.parse import parse_match

ROOT = Path(__file__).resolve().parents[1]


def _ball(batter, bowler, non_striker, batter_runs=0, extras=None, total=None, wickets=None, actual="0.1"):
    extras = extras or {}
    extra_runs = sum(extras.values())
    if total is None:
        total = batter_runs + extra_runs
    ball = {
        "actual_delivery": actual,
        "batter": batter,
        "bowler": bowler,
        "non_striker": non_striker,
        "runs": {"batter": batter_runs, "extras": extra_runs, "total": total},
    }
    if extras:
        ball["extras"] = extras
    if wickets:
        ball["wickets"] = wickets
    return ball


def _match():
    return {
        "meta": {"data_version": "1.3.0", "created": "2026-01-01", "revision": 1},
        "info": {
            "balls_per_over": 6,
            "dates": ["2008-06-01"],
            "event": {"name": "Indian Premier League", "match_number": 1},
            "gender": "male",
            "match_type": "T20",
            "outcome": {"winner": "Delhi Daredevils", "by": {"wickets": 9}},
            "overs": 20,
            "player_of_match": ["NA Saini"],
            "players": {
                "Kings XI Punjab": ["A Batter", "B Other"],
                "Delhi Daredevils": ["C Bowler", "D Fielder"],
            },
            "registry": {
                "people": {
                    "A Batter": "aaaaaaaa",
                    "B Other": "bbbbbbbb",
                    "C Bowler": "cccccccc",
                    "D Fielder": "dddddddd",
                    "NA Saini": "21d4e29b",
                }
            },
            "season": "2007/08",
            "teams": ["Kings XI Punjab", "Delhi Daredevils"],
            "toss": {"decision": "bat", "winner": "Kings XI Punjab"},
            "venue": "Feroz Shah Kotla",
            "city": "Delhi",
        },
        "innings": [
            {
                "team": "Kings XI Punjab",
                "overs": [
                    {
                        "over": 0,
                        "deliveries": [
                            _ball("A Batter", "C Bowler", "B Other", batter_runs=4, actual="0.1"),
                            _ball("A Batter", "C Bowler", "B Other", extras={"wides": 1}, actual="0.2"),
                            _ball("A Batter", "C Bowler", "B Other", extras={"byes": 1}, total=1, actual="0.2"),
                        ],
                    },
                    {
                        "over": 15,
                        "deliveries": [
                            _ball(
                                "A Batter",
                                "C Bowler",
                                "B Other",
                                wickets=[{"player_out": "A Batter", "kind": "bowled"}],
                                actual="15.1",
                            )
                        ],
                    },
                ],
            },
            {
                "team": "Delhi Daredevils",
                "target": {"overs": 20, "runs": 6},
                "overs": [
                    {
                        "over": 0,
                        "deliveries": [
                            _ball(
                                "D Fielder",
                                "A Batter",
                                "C Bowler",
                                extras={"noballs": 1},
                                batter_runs=4,
                                actual="0.1",
                            )
                        ],
                    }
                ],
            },
        ],
    }


class ParseTests(unittest.TestCase):
    def test_situation_on_each_ball(self):
        parsed = parse_match(_match(), 335982, "335982.json")
        self.assertEqual(parsed["match"]["season_year"], 2008)
        self.assertEqual(parsed["match"]["venue"], "Arun Jaitley Stadium, Delhi")
        self.assertEqual(parsed["match"]["franchise_a"], "Punjab Kings")
        self.assertEqual(parsed["match"]["winner_franchise"], "Delhi Capitals")

        first, second = parsed["innings"]
        self.assertEqual(first["runs"], 6)
        self.assertEqual(first["wickets"], 1)
        self.assertEqual(first["legal_balls"], 3)
        self.assertEqual(second["target_runs"], 6)

        balls = parsed["deliveries"]
        self.assertEqual(balls[0]["phase"], "powerplay")
        self.assertEqual(balls[0]["batting_position"], 1)
        self.assertEqual(balls[0]["is_four"], 1)
        self.assertEqual(balls[0]["rrr_band"], "setting")
        self.assertEqual(balls[1]["is_legal"], 0)
        self.assertEqual(balls[1]["bowler_runs"], 1)
        self.assertEqual(balls[2]["bowler_runs"], 0)
        self.assertEqual(balls[2]["is_dot"], 0)
        self.assertEqual(balls[3]["phase"], "death")
        self.assertEqual(balls[3]["over_number"], 16)
        self.assertEqual(balls[3]["wicket_count"], 1)
        self.assertEqual(balls[3]["bowler_wickets"], 1)
        self.assertEqual(balls[3]["innings_runs_before"], 6)
        self.assertEqual(balls[4]["phase"], "powerplay")
        self.assertEqual(balls[4]["runs_required"], 6)
        self.assertEqual(balls[4]["balls_remaining"], 120)
        self.assertAlmostEqual(balls[4]["required_rr"], 0.3)
        self.assertEqual(balls[4]["rrr_band"], "under_6")
        self.assertEqual(balls[4]["is_legal"], 0)
        self.assertEqual(balls[4]["bowler_runs"], 5)
        self.assertEqual(balls[4]["batting_position"], 1)

        card = next(row for row in parsed["batting_innings"] if row["player_id"] == "aaaaaaaa")
        self.assertEqual(card["runs"], 4)
        self.assertEqual(card["balls"], 3)
        self.assertEqual(card["dismissal_kind"], "bowled")
        self.assertEqual(card["batting_position"], 1)
        self.assertEqual(card["entry_phase"], "powerplay")
        opener = next(row for row in parsed["batting_innings"] if row["player_id"] == "bbbbbbbb")
        self.assertEqual(opener["batting_position"], 2)
        self.assertEqual(opener["balls"], 0)

    def test_database_round_trip(self):
        import json
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            (folder / "335982.json").write_text(json.dumps(_match()), encoding="utf-8")
            out = folder / "ipl.sqlite"
            conn = build(folder, out)
            conn.row_factory = sqlite3.Row
            rate = conn.execute(
                """
                SELECT strike_rate, runs, balls, dismissals
                FROM batter_phase_career
                WHERE player = 'A Batter' AND phase = 'powerplay'
                """
            ).fetchone()
            self.assertEqual(rate["runs"], 4)
            self.assertEqual(rate["balls"], 2)
            self.assertEqual(rate["dismissals"], 0)
            death = conn.execute(
                """
                SELECT wickets, economy
                FROM bowler_phase_career
                WHERE player = 'C Bowler' AND phase = 'death'
                """
            ).fetchone()
            self.assertEqual(death["wickets"], 1)
            self.assertEqual(death["economy"], 0)
            venue = conn.execute("SELECT * FROM venue_summary").fetchone()
            self.assertEqual(venue["venue"], "Arun Jaitley Stadium, Delhi")
            self.assertEqual(venue["chases_won"], 1)
            batting = conn.execute(
                "SELECT * FROM batter_career WHERE player = 'A Batter'"
            ).fetchone()
            self.assertEqual(batting["matches"], 1)
            self.assertEqual(batting["innings"], 1)
            self.assertEqual(batting["runs"], 4)
            self.assertEqual(batting["average"], 4)
            self.assertEqual(batting["strike_rate"], 133.33)
            self.assertEqual(batting["runs_per_innings"], 4)
            self.assertEqual(batting["fifties"], 0)
            self.assertEqual(batting["hundreds"], 0)
            self.assertEqual(batting["fifties_sr_150"], 0)
            bowling = conn.execute(
                "SELECT * FROM bowler_career WHERE player = 'C Bowler'"
            ).fetchone()
            self.assertEqual(bowling["matches"], 1)
            self.assertEqual(bowling["wickets"], 1)
            self.assertEqual(bowling["strike_rate"], 3)
            self.assertEqual(bowling["economy"], 10)
            self.assertEqual(bowling["average"], 5)
            self.assertEqual(bowling["four_wicket_hauls"], 0)
            self.assertEqual(bowling["five_wicket_hauls"], 0)
            self.assertEqual(bowling["wickets_per_match"], 1)
            phase_haul = conn.execute(
                """
                SELECT four_wicket_hauls FROM bowler_stats
                WHERE player = 'C Bowler' AND axis = 'phase' AND axis_value = 'death'
                """
            ).fetchone()
            self.assertIsNone(phase_haul["four_wicket_hauls"])


class BuiltDatabaseTests(unittest.TestCase):
    def test_shipped_database_holds_together(self):
        db_path = ROOT / "data" / "ipl.sqlite"
        if not db_path.exists():
            self.skipTest("database has not been built")
        conn = sqlite3.connect(db_path)
        matches, deliveries, players = conn.execute(
            """
            SELECT
                (SELECT COUNT(*) FROM matches),
                (SELECT COUNT(*) FROM deliveries),
                (SELECT COUNT(*) FROM players)
            """
        ).fetchone()
        self.assertGreater(matches, 1000)
        self.assertGreater(deliveries, 200000)
        self.assertGreater(players, 500)
        seasons = [row[0] for row in conn.execute("SELECT DISTINCT season_year FROM matches ORDER BY 1")]
        self.assertIn(2008, seasons)
        self.assertIn(2026, seasons)
        phases = {row[0] for row in conn.execute("SELECT DISTINCT phase FROM deliveries")}
        self.assertEqual(phases, {"powerplay", "middle", "death", "super_over"})
        mismatch = conn.execute(
            """
            SELECT COUNT(*) FROM (
                SELECT i.match_id, i.innings_number, i.runs,
                       i.penalty_pre + i.penalty_post + COALESCE(SUM(d.total_runs), 0) AS ball_runs
                FROM innings i
                LEFT JOIN deliveries d
                  ON d.match_id = i.match_id AND d.innings_number = i.innings_number
                GROUP BY i.match_id, i.innings_number
                HAVING i.runs != ball_runs
            )
            """
        ).fetchone()[0]
        self.assertEqual(mismatch, 0)
        negative = conn.execute(
            "SELECT COUNT(*) FROM deliveries WHERE batter_runs < 0 OR total_runs < 0 OR bowler_runs < 0"
        ).fetchone()[0]
        self.assertEqual(negative, 0)
        kohli = conn.execute(
            """
            SELECT runs, fifties, hundreds, fifties_sr_150, fifties_sr_200, matches, innings
            FROM batter_career WHERE player = 'V Kohli'
            """
        ).fetchone()
        self.assertGreater(kohli[0], 7000)
        self.assertGreater(kohli[2], 0)
        self.assertLessEqual(kohli[4], kohli[3])
        self.assertLessEqual(kohli[3], kohli[1] + kohli[2])
        self.assertGreater(kohli[5], kohli[6] - 5)
        milestone = conn.execute(
            """
            SELECT COUNT(*) FROM batter_career
            WHERE fifties_sr_200 > fifties_sr_150
               OR fifties_sr_150 > fifties + hundreds
               OR fifties < 0 OR hundreds < 0
            """
        ).fetchone()[0]
        self.assertEqual(milestone, 0)
        haul = conn.execute(
            """
            SELECT
                (SELECT COUNT(*) FROM bowling_innings WHERE wickets = 4),
                (SELECT COUNT(*) FROM bowling_innings WHERE wickets >= 5),
                (SELECT COALESCE(SUM(four_wicket_hauls), 0) FROM bowler_career),
                (SELECT COALESCE(SUM(five_wicket_hauls), 0) FROM bowler_career)
            """
        ).fetchone()
        self.assertEqual(haul[0], haul[2])
        self.assertEqual(haul[1], haul[3])
        self.assertGreater(haul[1], 0)


if __name__ == "__main__":
    unittest.main()
