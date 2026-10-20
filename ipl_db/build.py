"""Download Cricsheet IPL matches and load them into SQLite."""

from __future__ import annotations

import argparse
import sqlite3
import urllib.request
import zipfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from .constants import METRICS, SOURCE_LICENSE, SOURCE_URL
from .parse import load_match
from .project import SIMULATIONS, populate_ground_projections

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = Path(__file__).with_name("schema.sql")
DEFAULT_DB = ROOT / "data" / "ipl.sqlite"
DEFAULT_RAW = ROOT / "data" / "raw"


def download(dest: Path) -> Path:
    dest.mkdir(parents=True, exist_ok=True)
    zip_path = dest / "ipl_json.zip"
    urllib.request.urlretrieve(SOURCE_URL, zip_path)
    json_dir = dest / "json"
    json_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path) as archive:
        archive.extractall(json_dir)
    return json_dir


def build(json_dir: Path, out_path: Path) -> sqlite3.Connection:
    files = sorted(json_dir.glob("*.json"))
    if not files:
        raise FileNotFoundError(f"No match JSON files in {json_dir}")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        out_path.unlink()
    conn = sqlite3.connect(out_path)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA journal_mode = OFF")
    conn.execute("PRAGMA synchronous = OFF")
    conn.executescript(SCHEMA.read_text(encoding="utf-8"))
    conn.executemany(
        "INSERT INTO metrics (metric_id, name, definition) VALUES (?, ?, ?)",
        METRICS,
    )

    name_counts: dict[str, Counter[str]] = {}
    next_delivery_id = 1
    for path in files:
        parsed = load_match(path)
        for player_id, name in parsed["players"].items():
            name_counts.setdefault(player_id, Counter())[name] += 1
            conn.execute(
                "INSERT OR IGNORE INTO players (player_id, full_name) VALUES (?, ?)",
                (player_id, name),
            )
        for team in parsed["teams"]:
            conn.execute(
                """
                INSERT OR IGNORE INTO teams (team_name, franchise_id, franchise_name)
                VALUES (:team_name, :franchise_id, :franchise_name)
                """,
                team,
            )
        venue = parsed["venue"]
        if venue["raw_name"]:
            conn.execute(
                "INSERT OR IGNORE INTO venues (venue, city) VALUES (?, ?)",
                (venue["venue"], venue["city"]),
            )
            conn.execute(
                "INSERT OR IGNORE INTO venue_names (raw_name, venue) VALUES (?, ?)",
                (venue["raw_name"], venue["venue"]),
            )
        conn.execute(
            """
            INSERT INTO matches (
                match_id, season_raw, season_year, match_date, match_end_date,
                match_number, stage, city, venue_raw, venue, team_a, team_b,
                franchise_a, franchise_b, toss_winner, toss_winner_franchise,
                toss_decision, result, winner, winner_franchise, eliminator_winner,
                eliminator_winner_franchise, match_winner, match_winner_franchise,
                win_by_runs, win_by_wickets, method, player_of_match,
                balls_per_over, scheduled_overs, data_version, source_file
            ) VALUES (
                :match_id, :season_raw, :season_year, :match_date, :match_end_date,
                :match_number, :stage, :city, :venue_raw, :venue, :team_a, :team_b,
                :franchise_a, :franchise_b, :toss_winner, :toss_winner_franchise,
                :toss_decision, :result, :winner, :winner_franchise, :eliminator_winner,
                :eliminator_winner_franchise, :match_winner, :match_winner_franchise,
                :win_by_runs, :win_by_wickets, :method, :player_of_match,
                :balls_per_over, :scheduled_overs, :data_version, :source_file
            )
            """,
            parsed["match"],
        )
        conn.executemany(
            """
            INSERT INTO squads (match_id, team_name, player_id, squad_order)
            VALUES (:match_id, :team_name, :player_id, :squad_order)
            """,
            parsed["squads"],
        )
        conn.executemany(
            """
            INSERT INTO innings (
                match_id, innings_number, batting_team, bowling_team,
                batting_franchise, bowling_franchise, is_super_over, target_runs,
                target_overs, scheduled_overs, scheduled_balls, penalty_pre,
                penalty_post, runs, wickets, legal_balls
            ) VALUES (
                :match_id, :innings_number, :batting_team, :bowling_team,
                :batting_franchise, :bowling_franchise, :is_super_over, :target_runs,
                :target_overs, :scheduled_overs, :scheduled_balls, :penalty_pre,
                :penalty_post, :runs, :wickets, :legal_balls
            )
            """,
            parsed["innings"],
        )
        id_map = {}
        for delivery in parsed["deliveries"]:
            local_id = delivery["delivery_id"]
            if local_id in id_map:
                raise ValueError(f"Duplicate delivery id {local_id} in {path.name}")
            delivery["delivery_id"] = next_delivery_id
            id_map[local_id] = next_delivery_id
            next_delivery_id += 1
        for wicket in parsed["wickets"]:
            wicket["delivery_id"] = id_map[wicket["delivery_id"]]
        _insert_rows(conn, "deliveries", parsed["deliveries"])
        _insert_rows(conn, "delivery_wickets", parsed["wickets"])
        _insert_rows(conn, "batting_innings", parsed["batting_innings"])

    for player_id, counts in name_counts.items():
        full_name, others = _choose_name(counts)
        conn.execute(
            "UPDATE players SET full_name = ?, other_names = ? WHERE player_id = ?",
            (full_name, others, player_id),
        )

    seasons = conn.execute("SELECT MIN(season_year), MAX(season_year), COUNT(*) FROM matches").fetchone()
    deliveries = conn.execute("SELECT COUNT(*) FROM deliveries").fetchone()[0]
    meta = {
        "source_url": SOURCE_URL,
        "source_license": SOURCE_LICENSE,
        "source_archive_note": "Cricsheet IPL JSON zip, archive dated 2026-10-07",
        "built_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "match_count": str(seasons[2]),
        "delivery_count": str(deliveries),
        "season_min": str(seasons[0]),
        "season_max": str(seasons[1]),
        "attribution": "Match data © Cricsheet (https://cricsheet.org/), licensed under ODC-By.",
    }
    populate_ground_projections(conn)
    meta["ground_projection_sims"] = str(SIMULATIONS)
    meta["ground_projection"] = (
        "Seeded bootstrap of a typical season at each ground. "
        "Batter probability is the share of simulations with at least one run. "
        "Bowler probability is the share with at least one wicket."
    )
    conn.executemany("INSERT INTO dataset_meta (key, value) VALUES (?, ?)", meta.items())
    conn.commit()
    conn.execute("VACUUM")
    return conn


def _choose_name(counts: Counter[str]) -> tuple[str, str | None]:
    ranking = sorted(counts.items(), key=lambda item: (item[1], len(item[0])), reverse=True)
    full_name = ranking[0][0]
    others = [name for name, _count in ranking[1:]]
    return full_name, ", ".join(others) if others else None


def _insert_rows(conn: sqlite3.Connection, table: str, rows: list[dict]) -> None:
    if not rows:
        return
    columns = list(rows[0].keys())
    sql = (
        f"INSERT INTO {table} ({', '.join(columns)}) "
        f"VALUES ({', '.join(':' + column for column in columns)})"
    )
    conn.executemany(sql, rows)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Build the IPL SQLite database from Cricsheet JSON.")
    parser.add_argument("--json-dir", type=Path, help="Directory of Cricsheet match JSON files.")
    parser.add_argument("--download", type=Path, nargs="?", const=DEFAULT_RAW, help="Download the Cricsheet zip here, then build.")
    parser.add_argument("--out", type=Path, default=DEFAULT_DB, help="Output SQLite path.")
    args = parser.parse_args(argv)
    json_dir = args.json_dir
    if args.download is not None:
        json_dir = download(args.download)
    if json_dir is None:
        parser.error("Pass --json-dir or --download")
    conn = build(json_dir, args.out)
    meta = dict(conn.execute("SELECT key, value FROM dataset_meta"))
    print(f"Wrote {args.out}")
    print(f"Matches: {meta['match_count']}  Deliveries: {meta['delivery_count']}")
    print(f"Seasons: {meta['season_min']}–{meta['season_max']}")


if __name__ == "__main__":
    main()
