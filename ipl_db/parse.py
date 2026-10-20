"""Turn one Cricsheet match file into rows for the IPL database."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .constants import BOWLER_WICKET_KINDS, NON_WICKET_KINDS
from .context import (
    canonical_venue,
    franchise_id,
    franchise_name,
    legal_balls_allotted,
    phase_of,
    rrr_band,
    scheduled_over_count,
    season_year,
    venue_city,
    wickets_band,
)


def load_match(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    match_id = int(path.stem)
    return parse_match(data, match_id, path.name)


def parse_match(data: dict[str, Any], match_id: int, source_file: str) -> dict[str, Any]:
    info = data["info"]
    registry = (info.get("registry") or {}).get("people") or {}
    teams = list(info.get("teams") or [])
    if len(teams) != 2:
        raise ValueError(f"{source_file} does not list two teams")
    team_a, team_b = teams
    dates = info.get("dates") or []
    outcome = info.get("outcome") or {}
    by = outcome.get("by") or {}
    event = info.get("event") or {}
    toss = info.get("toss") or {}
    venue_raw = info.get("venue")
    venue = canonical_venue(venue_raw)
    balls_per_over = int(info.get("balls_per_over") or 6)
    scheduled = scheduled_over_count(info.get("overs"), 20)

    result_label = outcome.get("result")
    winner = outcome.get("winner")
    eliminator = outcome.get("eliminator")
    if winner:
        result = "win"
    elif result_label == "no result":
        result = "no result"
    elif result_label == "tie" or eliminator:
        result = "tie"
    else:
        result = result_label or "unknown"

    players: dict[str, str] = {}

    def player_id(name: str | None) -> str:
        if not name:
            name = "Unknown"
        identifier = registry.get(name) or f"name:{name}"
        players.setdefault(identifier, name)
        return identifier

    squads = []
    for team_name, names in (info.get("players") or {}).items():
        for order, name in enumerate(names, start=1):
            squads.append(
                {
                    "match_id": match_id,
                    "team_name": team_name,
                    "player_id": player_id(name),
                    "squad_order": order,
                }
            )

    player_of_match = info.get("player_of_match") or []
    for name in player_of_match:
        player_id(name)

    match = {
        "match_id": match_id,
        "season_raw": str(info.get("season")),
        "season_year": season_year(str(info.get("season"))),
        "match_date": dates[0] if dates else "",
        "match_end_date": dates[-1] if dates else None,
        "match_number": event.get("match_number"),
        "stage": event.get("stage") or "League",
        "city": info.get("city") or venue_city(venue),
        "venue_raw": venue_raw,
        "venue": venue,
        "team_a": team_a,
        "team_b": team_b,
        "franchise_a": franchise_name(team_a),
        "franchise_b": franchise_name(team_b),
        "toss_winner": toss.get("winner"),
        "toss_winner_franchise": franchise_name(toss["winner"]) if toss.get("winner") else None,
        "toss_decision": toss.get("decision"),
        "result": result,
        "winner": winner,
        "winner_franchise": franchise_name(winner) if winner else None,
        "eliminator_winner": eliminator,
        "eliminator_winner_franchise": franchise_name(eliminator) if eliminator else None,
        "match_winner": winner or eliminator,
        "match_winner_franchise": franchise_name(winner or eliminator) if (winner or eliminator) else None,
        "win_by_runs": by.get("runs"),
        "win_by_wickets": by.get("wickets"),
        "method": outcome.get("method"),
        "player_of_match": ", ".join(player_of_match) if player_of_match else None,
        "balls_per_over": balls_per_over,
        "scheduled_overs": scheduled,
        "data_version": (data.get("meta") or {}).get("data_version"),
        "source_file": source_file,
    }

    innings_rows = []
    deliveries = []
    wickets = []
    batting_rows = []
    next_delivery_id = 0
    for index, innings in enumerate(data.get("innings") or [], start=1):
        parsed = _parse_innings(
            innings,
            match_id=match_id,
            innings_number=index,
            team_a=team_a,
            team_b=team_b,
            balls_per_over=balls_per_over,
            match_overs=scheduled,
            player_id=player_id,
            next_delivery_id=next_delivery_id,
        )
        next_delivery_id = parsed["next_delivery_id"]
        innings_rows.append(parsed["innings"])
        deliveries.extend(parsed["deliveries"])
        wickets.extend(parsed["wickets"])
        batting_rows.extend(parsed["batting_innings"])

    team_rows = []
    for team_name in teams:
        team_rows.append(
            {
                "team_name": team_name,
                "franchise_id": franchise_id(team_name),
                "franchise_name": franchise_name(team_name),
            }
        )

    return {
        "match": match,
        "teams": team_rows,
        "venue": {"venue": venue, "city": venue_city(venue, info.get("city")), "raw_name": venue_raw},
        "players": players,
        "squads": squads,
        "innings": innings_rows,
        "deliveries": deliveries,
        "wickets": wickets,
        "batting_innings": batting_rows,
    }


def _parse_innings(
    innings: dict[str, Any],
    *,
    match_id: int,
    innings_number: int,
    team_a: str,
    team_b: str,
    balls_per_over: int,
    match_overs: int,
    player_id,
    next_delivery_id: int = 0,
) -> dict[str, Any]:
    batting_team = innings.get("team")
    if batting_team == team_a:
        bowling_team = team_b
    elif batting_team == team_b:
        bowling_team = team_a
    else:
        bowling_team = None
        for candidate in (team_a, team_b):
            if candidate != batting_team:
                bowling_team = candidate
                break
    is_super = 1 if innings.get("super_over") else 0
    target = innings.get("target") or {}
    target_runs = target.get("runs")
    target_overs = target.get("overs")
    if target_overs is not None:
        scheduled_overs = scheduled_over_count(target_overs, match_overs)
        scheduled_balls = legal_balls_allotted(target_overs, balls_per_over)
    else:
        scheduled_overs = 1 if is_super else match_overs
        scheduled_balls = balls_per_over if is_super else match_overs * balls_per_over
    penalty = innings.get("penalty_runs") or {}
    penalty_pre = int(penalty.get("pre") or 0)
    penalty_post = int(penalty.get("post") or 0)

    order: list[str] = []
    cards: dict[str, dict[str, Any]] = {}
    runs_so_far = penalty_pre
    wickets_so_far = 0
    legal_so_far = 0
    partnership = 0
    delivery_rows = []
    wicket_rows = []
    local_id = next_delivery_id

    for over in innings.get("overs") or []:
        over_number = int(over.get("over", 0)) + 1
        phase = phase_of(over_number, scheduled_overs, bool(is_super))
        for ball_in_over, ball in enumerate(over.get("deliveries") or [], start=1):
            local_id += 1
            extras = ball.get("extras") or {}
            runs = ball.get("runs") or {}
            wide = int(extras.get("wides") or 0)
            noball = int(extras.get("noballs") or 0)
            bye = int(extras.get("byes") or 0)
            legbye = int(extras.get("legbyes") or 0)
            penalty_runs = int(extras.get("penalty") or 0)
            batter_runs = int(runs.get("batter") or 0)
            extra_runs = int(runs.get("extras") or 0)
            total_runs = int(runs.get("total") or 0)
            is_legal = 0 if wide or noball else 1
            bowler_runs = total_runs - bye - legbye - penalty_runs

            batter = player_id(ball.get("batter"))
            bowler = player_id(ball.get("bowler"))
            non_striker = player_id(ball.get("non_striker"))
            for name in (batter, non_striker):
                if name and name not in order:
                    _open_card(
                        cards,
                        order,
                        name,
                        runs_so_far=runs_so_far,
                        wickets_so_far=wickets_so_far,
                        phase=phase,
                        has_target=target_runs is not None,
                        target_runs=target_runs,
                        scheduled_balls=scheduled_balls,
                        legal_so_far=legal_so_far,
                        is_super=is_super,
                        match_id=match_id,
                        innings_number=innings_number,
                    )
            position = order.index(batter) + 1 if batter in order else None

            counted_wickets = []
            bowler_wickets = 0
            for wicket in ball.get("wickets") or []:
                kind = wicket.get("kind") or "unknown"
                out_id = player_id(wicket.get("player_out"))
                credited = 1 if kind in BOWLER_WICKET_KINDS else 0
                counts = kind not in NON_WICKET_KINDS
                if credited and counts:
                    bowler_wickets += 1
                fielders = []
                for fielder in wicket.get("fielders") or []:
                    if isinstance(fielder, dict):
                        fname = fielder.get("name")
                        if fname:
                            player_id(fname)
                            label = fname + (" (sub)" if fielder.get("substitute") else "")
                            fielders.append(label)
                    elif isinstance(fielder, str):
                        fielders.append(fielder)
                wicket_rows.append(
                    {
                        "delivery_id": local_id,
                        "player_out_id": out_id,
                        "kind": kind,
                        "bowler_credited": credited,
                        "fielders": ", ".join(fielders) if fielders else None,
                    }
                )
                if counts:
                    counted_wickets.append((out_id, kind, bowler if credited else None))

            primary_out = None
            primary_kind = None
            for out_id, kind, _bowler in counted_wickets:
                if out_id == batter:
                    primary_out, primary_kind = out_id, kind
                    break
            if primary_out is None and counted_wickets:
                primary_out, primary_kind, _ = (
                    counted_wickets[0][0],
                    counted_wickets[0][1],
                    counted_wickets[0][2],
                )

            has_target = target_runs is not None
            runs_required = (int(target_runs) - runs_so_far) if has_target else None
            balls_remaining = None
            required_rr = None
            if scheduled_balls is not None:
                balls_remaining = max(scheduled_balls - legal_so_far, 0)
            if has_target and balls_remaining:
                required_rr = runs_required * 6 / balls_remaining
            current_rr = (runs_so_far * 6 / legal_so_far) if legal_so_far else None
            in_hand = max(10 - wickets_so_far, 0)

            delivery_rows.append(
                {
                    "delivery_id": local_id,
                    "match_id": match_id,
                    "innings_number": innings_number,
                    "over_number": over_number,
                    "ball_in_over": ball_in_over,
                    "actual_delivery": ball.get("actual_delivery"),
                    "is_legal": is_legal,
                    "is_super_over": is_super,
                    "batter_id": batter,
                    "bowler_id": bowler,
                    "non_striker_id": non_striker,
                    "batter_runs": batter_runs,
                    "extra_runs": extra_runs,
                    "total_runs": total_runs,
                    "bowler_runs": bowler_runs,
                    "wide_runs": wide,
                    "noball_runs": noball,
                    "bye_runs": bye,
                    "legbye_runs": legbye,
                    "penalty_runs": penalty_runs,
                    "is_four": 1 if batter_runs == 4 else 0,
                    "is_six": 1 if batter_runs == 6 else 0,
                    "is_dot": 1 if is_legal and total_runs == 0 else 0,
                    "wicket_count": len(counted_wickets),
                    "bowler_wickets": bowler_wickets,
                    "player_out_id": primary_out,
                    "wicket_kind": primary_kind,
                    "phase": phase,
                    "batting_position": position,
                    "innings_runs_before": runs_so_far,
                    "wickets_before": wickets_so_far,
                    "legal_balls_before": legal_so_far,
                    "wickets_in_hand": in_hand,
                    "runs_required": runs_required,
                    "balls_remaining": balls_remaining,
                    "required_rr": required_rr,
                    "rrr_band": rrr_band(required_rr, has_target, balls_remaining),
                    "wickets_band": wickets_band(in_hand),
                    "current_rr": current_rr,
                    "partnership_runs_before": partnership,
                }
            )

            if batter in cards and wide == 0:
                card = cards[batter]
                card["runs"] += batter_runs
                card["balls"] += 1
                card["fours"] += 1 if batter_runs == 4 else 0
                card["sixes"] += 1 if batter_runs == 6 else 0
                card["dots"] += 1 if is_legal and total_runs == 0 else 0
            for out_id, kind, credited_bowler in counted_wickets:
                if out_id in cards and cards[out_id]["dismissal_kind"] is None:
                    cards[out_id]["dismissal_kind"] = kind
                    cards[out_id]["bowler_out_id"] = credited_bowler

            runs_so_far += total_runs
            legal_so_far += is_legal
            partnership += total_runs
            if counted_wickets:
                wickets_so_far += len(counted_wickets)
                partnership = 0

    innings_row = {
        "match_id": match_id,
        "innings_number": innings_number,
        "batting_team": batting_team,
        "bowling_team": bowling_team,
        "batting_franchise": franchise_name(batting_team) if batting_team else None,
        "bowling_franchise": franchise_name(bowling_team) if bowling_team else None,
        "is_super_over": is_super,
        "target_runs": target_runs,
        "target_overs": target_overs,
        "scheduled_overs": scheduled_overs,
        "scheduled_balls": scheduled_balls,
        "penalty_pre": penalty_pre,
        "penalty_post": penalty_post,
        "runs": runs_so_far + penalty_post,
        "wickets": wickets_so_far,
        "legal_balls": legal_so_far,
    }
    return {
        "innings": innings_row,
        "deliveries": delivery_rows,
        "wickets": wicket_rows,
        "batting_innings": list(cards.values()),
        "next_delivery_id": local_id,
    }


def _open_card(
    cards: dict[str, dict[str, Any]],
    order: list[str],
    player: str,
    *,
    runs_so_far: int,
    wickets_so_far: int,
    phase: str,
    has_target: bool,
    target_runs: int | None,
    scheduled_balls: int | None,
    legal_so_far: int,
    is_super: int,
    match_id: int,
    innings_number: int,
) -> None:
    order.append(player)
    balls_remaining = None
    required_rr = None
    if scheduled_balls is not None:
        balls_remaining = max(scheduled_balls - legal_so_far, 0)
    if has_target and balls_remaining:
        required_rr = (int(target_runs) - runs_so_far) * 6 / balls_remaining
    in_hand = max(10 - wickets_so_far, 0)
    cards[player] = {
        "match_id": match_id,
        "innings_number": innings_number,
        "player_id": player,
        "batting_position": len(order),
        "runs": 0,
        "balls": 0,
        "fours": 0,
        "sixes": 0,
        "dots": 0,
        "dismissal_kind": None,
        "bowler_out_id": None,
        "entry_runs": runs_so_far,
        "entry_wickets": wickets_so_far,
        "entry_phase": phase,
        "entry_rrr": required_rr,
        "entry_rrr_band": rrr_band(required_rr, has_target, balls_remaining),
        "entry_wickets_band": wickets_band(in_hand),
        "is_super_over": is_super,
    }
