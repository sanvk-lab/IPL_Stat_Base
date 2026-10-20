"""Pure functions that turn a ball into a match situation."""

from __future__ import annotations

from .constants import FRANCHISE_NAME, VENUE_CANONICAL, VENUE_CITY


def franchise_name(team: str) -> str:
    return FRANCHISE_NAME.get(team, team)


def franchise_id(team: str) -> str:
    return franchise_name(team).lower().replace(" ", "-")


def canonical_venue(raw_name: str | None) -> str:
    if not raw_name:
        return "Unknown venue"
    return VENUE_CANONICAL.get(raw_name, raw_name)


def venue_city(canonical: str, fallback: str | None = None) -> str | None:
    return VENUE_CITY.get(canonical, fallback)


def season_year(season: str) -> int:
    """Map a Cricsheet season label onto the IPL edition year."""
    text = str(season).strip()
    if "/" in text:
        start, end = text.split("/", 1)
        end = end.strip()
        if len(end) == 2:
            century = int(start[:2])
            end_year = century * 100 + int(end)
            # 2020/21 was the 2020 IPL, played entirely in 2020.
            if end_year == int(start) + 1 and int(start) == 2020:
                return 2020
            return end_year
        return int(end)
    return int(text)


def scheduled_over_count(overs: float | int | None, fallback: int = 20) -> int:
    """Overs allotted, rounding a partial allotment such as 16.2 up to 17."""
    if overs is None:
        return fallback
    value = float(overs)
    whole = int(value)
    if value - whole > 1e-9:
        return whole + 1
    return whole


def legal_balls_allotted(overs: float | int | None, balls_per_over: int = 6) -> int | None:
    """Cricsheet stores 16.2 as 16 overs and 2 balls, not a decimal fraction."""
    if overs is None:
        return None
    value = float(overs)
    whole = int(value)
    balls = int(round((value - whole) * 10))
    return whole * balls_per_over + balls


def phase_bounds(scheduled_overs: int) -> tuple[int, int]:
    """Return (last powerplay over, first death over), both 1-based.

    A 20-over innings is powerplay 1-6, middle 7-15, death 16-20.
    Shorter innings use the T20 powerplay ladder and a death of about
    the last quarter of the allotment.
    """
    n = max(int(scheduled_overs), 0)
    if n >= 19:
        powerplay = 6
    elif n >= 15:
        powerplay = 5
    elif n >= 12:
        powerplay = 4
    elif n >= 9:
        powerplay = 3
    elif n >= 5:
        powerplay = 2
    elif n >= 1:
        powerplay = 1
    else:
        powerplay = 0
    death_len = int(n * 0.25 + 0.5) if n else 0
    if powerplay + death_len > n:
        death_len = max(0, n - powerplay)
    death_from = (n - death_len + 1) if death_len else n + 1
    return powerplay, death_from


def phase_of(over_number: int, scheduled_overs: int, is_super_over: bool) -> str:
    if is_super_over:
        return "super_over"
    powerplay, death_from = phase_bounds(scheduled_overs)
    if over_number <= powerplay:
        return "powerplay"
    if over_number >= death_from:
        return "death"
    return "middle"


def rrr_band(required_rr: float | None, has_target: bool, balls_remaining: int | None) -> str:
    if not has_target:
        return "setting"
    if balls_remaining is None or balls_remaining <= 0:
        return "no_balls_left"
    if required_rr is None:
        return "setting"
    if required_rr < 6:
        return "under_6"
    if required_rr < 9:
        return "6_to_9"
    if required_rr < 12:
        return "9_to_12"
    return "12_plus"


def wickets_band(wickets_in_hand: int) -> str:
    if wickets_in_hand >= 8:
        return "8_to_10"
    if wickets_in_hand >= 5:
        return "5_to_7"
    if wickets_in_hand >= 3:
        return "3_to_4"
    return "0_to_2"
