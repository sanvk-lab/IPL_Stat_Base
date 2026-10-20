"""Seeded next-season probabilities at each IPL ground."""

from __future__ import annotations

import random
import sqlite3
import zlib
from collections import defaultdict

SIMULATIONS = 2000


def ground_category(average_total: float | None) -> str | None:
    if average_total is None:
        return None
    if average_total >= 170:
        return "high_scoring"
    if average_total >= 155:
        return "mid_scoring"
    return "low_scoring"


def season_draws(innings: int, seasons: int) -> int:
    """Typical innings at this ground in one season."""
    if seasons <= 0:
        return 1
    return max(1, int(innings / seasons + 0.5))


def project_next_season(samples: list[int], draws: int, seed: int, simulations: int = SIMULATIONS) -> tuple[float, float]:
    """Bootstrap a season. Returns (probability the total is at least 1, expected total)."""
    rng = random.Random(seed)
    total_sum = 0
    successes = 0
    for _ in range(simulations):
        total = sum(rng.choice(samples) for _ in range(draws))
        total_sum += total
        if total >= 1:
            successes += 1
    return successes / simulations, total_sum / simulations


def _seed(player_id: str, venue: str) -> int:
    return zlib.crc32(f"{player_id}|{venue}".encode()) & 0xFFFFFFFF


def populate_ground_projections(conn: sqlite3.Connection, simulations: int = SIMULATIONS) -> None:
    averages = dict(conn.execute("SELECT venue, avg_first_innings FROM venue_summary"))
    _fill_batters(conn, averages, simulations)
    _fill_bowlers(conn, averages, simulations)


def _fill_batters(conn: sqlite3.Connection, averages: dict, simulations: int) -> None:
    grouped: dict[tuple[str, str], list[tuple[int, int, int, int]]] = defaultdict(list)
    rows = conn.execute(
        """
        SELECT b.player_id, m.venue, m.season_year, b.runs, b.balls,
               CASE WHEN b.dismissal_kind IS NOT NULL THEN 1 ELSE 0 END
        FROM batting_innings AS b
        JOIN matches AS m ON m.match_id = b.match_id
        WHERE b.is_super_over = 0 AND b.innings_number IN (1, 2)
        """
    )
    for player_id, venue, season, runs, balls, dismissed in rows:
        grouped[(player_id, venue)].append((season, runs, balls, dismissed))

    payload = []
    for (player_id, venue), innings in grouped.items():
        seasons = {item[0] for item in innings}
        runs = [item[1] for item in innings]
        balls = sum(item[2] for item in innings)
        dismissals = sum(item[3] for item in innings)
        total_runs = sum(runs)
        draws = season_draws(len(innings), len(seasons))
        probability, expected = project_next_season(runs, draws, _seed(player_id, venue), simulations)
        ground_average = averages.get(venue)
        payload.append(
            (
                player_id,
                venue,
                len(innings),
                total_runs,
                balls,
                dismissals,
                max(runs),
                round(total_runs / dismissals, 2) if dismissals else None,
                round(100.0 * total_runs / balls, 2) if balls else None,
                ground_average,
                ground_category(ground_average),
                round(probability, 4),
                round(expected, 2),
            )
        )
    conn.executemany(
        """
        INSERT INTO batter_ground (
            player_id, venue, innings, runs, balls, dismissals, highest,
            average, strike_rate, ground_average_total, ground_category,
            prob_scores_next_season, expected_runs_next_season
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        payload,
    )


def _fill_bowlers(conn: sqlite3.Connection, averages: dict, simulations: int) -> None:
    grouped: dict[tuple[str, str], list[tuple[int, int, int, int]]] = defaultdict(list)
    rows = conn.execute(
        """
        SELECT player_id, venue, season_year, balls, runs, wickets
        FROM bowling_innings
        WHERE innings_number IN (1, 2)
        """
    )
    for player_id, venue, season, balls, runs, wickets in rows:
        grouped[(player_id, venue)].append((season, balls, runs, wickets))

    payload = []
    for (player_id, venue), innings in grouped.items():
        seasons = {item[0] for item in innings}
        balls = sum(item[1] for item in innings)
        runs = sum(item[2] for item in innings)
        wickets_list = [item[3] for item in innings]
        wickets = sum(wickets_list)
        draws = season_draws(len(innings), len(seasons))
        probability, expected = project_next_season(
            wickets_list, draws, _seed(player_id, venue), simulations
        )
        ground_average = averages.get(venue)
        payload.append(
            (
                player_id,
                venue,
                len(innings),
                balls,
                runs,
                wickets,
                round(runs / wickets, 2) if wickets else None,
                round(balls / wickets, 2) if wickets else None,
                round(6.0 * runs / balls, 2) if balls else None,
                ground_average,
                ground_category(ground_average),
                round(probability, 4),
                round(expected, 2),
            )
        )
    conn.executemany(
        """
        INSERT INTO bowler_ground (
            player_id, venue, innings, balls, runs, wickets, average, strike_rate,
            economy, ground_average_total, ground_category, prob_wicket_next_season,
            expected_wickets_next_season
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        payload,
    )
