"""Print the contextual summaries stored in the IPL database."""

from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = ROOT / "data" / "ipl.sqlite"


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description="Read contextual IPL summaries from the database.")
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--sql", help="Run one SQL statement and print the rows.")
    parser.add_argument("--limit", type=int, default=8)
    args = parser.parse_args(argv)
    conn = sqlite3.connect(args.db)
    conn.row_factory = sqlite3.Row
    if args.sql:
        _print_rows(conn.execute(args.sql).fetchall())
        return
    meta = dict(conn.execute("SELECT key, value FROM dataset_meta"))
    print(f"IPL database  {meta.get('season_min')}–{meta.get('season_max')}")
    print(f"{meta.get('match_count')} matches, {meta.get('delivery_count')} deliveries")
    print(meta.get("attribution", ""))
    print()
    _section(conn, "Phase of play — batting strike rate, minimum 200 balls", """
        SELECT player, phase, runs, balls, dismissals, strike_rate, average, boundary_percent
        FROM batter_phase_career
        WHERE phase != 'super_over' AND balls >= 200
        ORDER BY strike_rate DESC
        LIMIT ?
    """, (args.limit,))
    _section(conn, "Phase of play — bowling economy, minimum 200 balls", """
        SELECT player, phase, balls, runs, wickets, economy, average, strike_rate
        FROM bowler_phase_career
        WHERE phase != 'super_over' AND balls >= 200
        ORDER BY economy ASC
        LIMIT ?
    """, (args.limit,))
    _section(conn, "Chase pressure — strike rate when the required rate is 12 or more, minimum 100 balls", """
        SELECT player, runs, balls, dismissals, strike_rate
        FROM batter_pressure
        WHERE rrr_band = '12_plus' AND balls >= 100
        ORDER BY strike_rate DESC
        LIMIT ?
    """, (args.limit,))
    _section(conn, "Venues — first-innings average and chase success, minimum 20 completed matches", """
        SELECT venue, matches, avg_first_innings,
               chases_won, decided_chases,
               ROUND(100.0 * chases_won / NULLIF(decided_chases, 0), 1) AS chase_win_percent
        FROM venue_summary
        WHERE completed >= 20
        ORDER BY avg_first_innings DESC
        LIMIT ?
    """, (args.limit,))
    _section(conn, "Toss — share of decided matches won by the side that chose to bat or field", """
        SELECT toss_decision,
               SUM(matches) AS matches,
               SUM(toss_winner_won) AS wins,
               SUM(decided) AS decided,
               ROUND(100.0 * SUM(toss_winner_won) / NULLIF(SUM(decided), 0), 1) AS win_percent
        FROM toss_summary
        GROUP BY toss_decision
        ORDER BY toss_decision
    """)


def _section(conn: sqlite3.Connection, title: str, sql: str, params: tuple = ()) -> None:
    print(title)
    _print_rows(conn.execute(sql, params).fetchall())
    print()


def _print_rows(rows: list[sqlite3.Row]) -> None:
    if not rows:
        print("(no rows)")
        return
    headers = rows[0].keys()
    widths = [len(header) for header in headers]
    values = []
    for row in rows:
        rendered = ["" if value is None else str(value) for value in row]
        values.append(rendered)
        widths = [max(width, len(text)) for width, text in zip(widths, rendered)]
    print("  ".join(header.ljust(width) for header, width in zip(headers, widths)))
    for rendered in values:
        print("  ".join(text.ljust(width) for text, width in zip(rendered, widths)))


if __name__ == "__main__":
    main()
