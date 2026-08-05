"""Rule-based lifestyle suggestions for daily check-ins.

This module intentionally keeps lifestyle guidance separate from the
insulin-resistance prediction model. It uses recent user-entered behavior data
to choose small, concrete, non-diagnostic suggestions.
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Any, Iterable


class SuggestionDomain(str, Enum):
    """Supported lifestyle suggestion domains."""

    SLEEP = "sleep"
    MOVEMENT = "movement"
    DIET = "diet"
    ALCOHOL = "alcohol"
    MAINTENANCE = "maintenance"
    DATA_SUPPORT = "data_support"


@dataclass(frozen=True)
class Suggestion:
    """A user-facing lifestyle suggestion with auditable rule metadata."""

    domain: SuggestionDomain
    title: str
    suggestion_text: str
    trigger_reason: str
    candidate_action: str
    safety_note: str
    priority: int
    confidence: str


@dataclass(frozen=True)
class LifestyleSuggestionConfig:
    """Rule thresholds for lifestyle suggestions."""

    lookback_days: int = 7
    minimum_checkins_for_behavior_rules: int = 3
    minimum_food_journal_entries: int = 3
    adult_sleep_threshold_hours: float = 7.0
    alcohol_high_frequency_rank: int = 5
    repeated_low_movement_days: int = 2


MOVEMENT_BREAK_RANKS = {
    "about once every hour or more": 4,
    "hourly or more": 4,
    "i did not spend much time sitting today": 4,
    "little sitting": 4,
    "a few times during the day": 3,
    "few times": 3,
    "once": 2,
    "not at all": 1,
}

ALCOHOL_FREQUENCY_RANKS = {
    "never": 0,
    "not at all": 0,
    "less than monthly": 1,
    "monthly": 2,
    "2-4 times a month": 2,
    "weekly": 3,
    "once a week": 3,
    "2-3 times a week": 4,
    "4-6 times a week": 5,
    "daily": 6,
    "every day": 6,
}

DIET_PATTERNS = (
    (
        "sugary_drinks",
        ("soda", "soft drink", "sweet tea", "juice", "sports drink", "energy drink"),
        "Swap one sweet drink for water, sparkling water, or unsweetened tea tomorrow.",
    ),
    (
        "refined_grains",
        ("white bread", "white rice", "pastry", "donut", "bagel", "fries", "chips"),
        (
            "Choose one higher-fiber swap tomorrow, such as whole-grain bread, "
            "beans, fruit, or vegetables."
        ),
    ),
    (
        "low_produce",
        ("vegetable", "vegetables", "salad", "fruit", "berries", "greens"),
        "Add one fruit or non-starchy vegetable to a meal you already planned tomorrow.",
    ),
)


def generate_lifestyle_suggestions(
    checkins: Iterable[dict[str, Any]],
    profile: dict[str, Any] | None = None,
    config: LifestyleSuggestionConfig | None = None,
    max_suggestions: int = 2,
) -> list[Suggestion]:
    """Generate prioritized lifestyle suggestions from recent check-ins.

    `checkins` should contain the most recent daily records, ideally one per
    day. Each record may include sleep_hours, movement_break_frequency,
    food_journal, alcohol_frequency, and physical_activities. The function does
    not diagnose disease or infer behavior from missing data.
    """
    profile = profile or {}
    config = config or LifestyleSuggestionConfig()
    recent = list(checkins)[-config.lookback_days :]

    if len(recent) < config.minimum_checkins_for_behavior_rules:
        return [_data_support_suggestion(len(recent), config)]

    candidates = [
        _sleep_suggestion(recent, config),
        _movement_suggestion(recent, config),
        _diet_suggestion(recent, config),
        _alcohol_suggestion(recent, profile, config),
    ]
    suggestions = [candidate for candidate in candidates if candidate is not None]

    if not suggestions:
        suggestions.append(_maintenance_suggestion(recent, config))

    suggestions.sort(key=lambda suggestion: suggestion.priority)
    return suggestions[:max_suggestions]


def _data_support_suggestion(
    checkin_count: int, config: LifestyleSuggestionConfig
) -> Suggestion:
    needed = config.minimum_checkins_for_behavior_rules
    return Suggestion(
        domain=SuggestionDomain.DATA_SUPPORT,
        title="Build the check-in pattern",
        suggestion_text=(
            "Log one easy item today, such as sleep hours or movement breaks, "
            "so future suggestions can reflect your actual routine."
        ),
        trigger_reason=(
            f"Only {checkin_count} recent check-in(s) are available; at least "
            f"{needed} are needed before behavior patterns are inferred."
        ),
        candidate_action="Encourage one easy logging action.",
        safety_note="No behavior is inferred from missing check-ins.",
        priority=10,
        confidence="low",
    )


def _sleep_suggestion(
    checkins: list[dict[str, Any]], config: LifestyleSuggestionConfig
) -> Suggestion | None:
    sleep_values = [_to_float(row.get("sleep_hours")) for row in checkins]
    sleep_values = [value for value in sleep_values if value is not None]
    if len(sleep_values) < config.minimum_checkins_for_behavior_rules:
        return None

    average_sleep = sum(sleep_values) / len(sleep_values)
    if average_sleep >= config.adult_sleep_threshold_hours:
        return None

    return Suggestion(
        domain=SuggestionDomain.SLEEP,
        title="Make a little more sleep room",
        suggestion_text=(
            "Try adding a 15- to 30-minute sleep opportunity tonight, such as "
            "starting your wind-down a little earlier."
        ),
        trigger_reason=(
            f"Recent average sleep is {average_sleep:.1f} hours, below the "
            f"{config.adult_sleep_threshold_hours:.0f}-hour adult threshold."
        ),
        candidate_action="Add 15-30 minutes of sleep opportunity.",
        safety_note=(
            "This is general lifestyle guidance, not a diagnosis. Consider "
            "professional care for persistent sleep problems."
        ),
        priority=20,
        confidence="medium",
    )


def _movement_suggestion(
    checkins: list[dict[str, Any]], config: LifestyleSuggestionConfig
) -> Suggestion | None:
    ranks = [
        _movement_rank(row.get("movement_break_frequency"))
        for row in checkins
        if row.get("movement_break_frequency") is not None
    ]
    low_days = [rank for rank in ranks if rank is not None and rank <= 2]
    if len(low_days) < config.repeated_low_movement_days:
        return None

    return Suggestion(
        domain=SuggestionDomain.MOVEMENT,
        title="Add one sitting break",
        suggestion_text=(
            "Attach one 2- to 3-minute standing or walking break to a routine "
            "you already have, like after coffee, lunch, or a meeting."
        ),
        trigger_reason=(
            f"Movement breaks were low on {len(low_days)} recent check-in days."
        ),
        candidate_action="Add one movement break to an existing routine.",
        safety_note=(
            "Adapt the break to your mobility and physical limitations; seated "
            "range-of-motion movement can count when standing is not a good fit."
        ),
        priority=30,
        confidence="medium",
    )


def _diet_suggestion(
    checkins: list[dict[str, Any]], config: LifestyleSuggestionConfig
) -> Suggestion | None:
    journals = [
        str(row.get("food_journal", "")).lower()
        for row in checkins
        if str(row.get("food_journal", "")).strip()
    ]
    if len(journals) < config.minimum_food_journal_entries:
        return None

    for pattern_name, keywords, action in DIET_PATTERNS:
        if pattern_name == "low_produce":
            produce_mentions = sum(
                1 for journal in journals if any(k in journal for k in keywords)
            )
            if produce_mentions > len(journals) // 2:
                continue
            trigger = "Recent food journals include few repeated fruit or vegetable mentions."
        else:
            matching_days = sum(
                1 for journal in journals if any(k in journal for k in keywords)
            )
            if matching_days < 2:
                continue
            trigger = f"Recent food journals repeatedly mention {pattern_name.replace('_', ' ')}."

        return Suggestion(
            domain=SuggestionDomain.DIET,
            title="Try one food swap",
            suggestion_text=action,
            trigger_reason=trigger,
            candidate_action="Offer one concrete substitution or addition.",
            safety_note=(
                "This uses repeated journal patterns only; no judgment is made "
                "from a single meal or skipped journal."
            ),
            priority=40,
            confidence="medium",
        )
    return None


def _alcohol_suggestion(
    checkins: list[dict[str, Any]],
    profile: dict[str, Any],
    config: LifestyleSuggestionConfig,
) -> Suggestion | None:
    values = [
        row.get("alcohol_frequency")
        for row in checkins
        if row.get("alcohol_frequency") is not None
    ]
    if not values and profile.get("alcohol_frequency") is not None:
        values = [profile.get("alcohol_frequency")]

    ranks = [_alcohol_rank(value) for value in values]
    ranks = [rank for rank in ranks if rank is not None]
    if not ranks or max(ranks) < config.alcohol_high_frequency_rank:
        return None

    return Suggestion(
        domain=SuggestionDomain.ALCOHOL,
        title="Choose one lower-alcohol occasion",
        suggestion_text=(
            "Pick one usual drinking occasion this week and make it lower "
            "alcohol, alcohol-free, or shorter."
        ),
        trigger_reason="Alcohol frequency is above the configured threshold.",
        candidate_action="Choose one lower-alcohol occasion.",
        safety_note=(
            "This does not label alcohol use. People who are pregnant, under "
            "21, taking interacting medicines, or advised not to drink should "
            "follow clinician guidance."
        ),
        priority=50,
        confidence="medium",
    )


def _maintenance_suggestion(
    checkins: list[dict[str, Any]], config: LifestyleSuggestionConfig
) -> Suggestion:
    return Suggestion(
        domain=SuggestionDomain.MAINTENANCE,
        title="Keep the routine that is working",
        suggestion_text=(
            "Your recent check-ins do not show a clear lifestyle trigger. Keep "
            "one habit that felt easiest this week and repeat it tomorrow."
        ),
        trigger_reason=(
            f"At least {config.minimum_checkins_for_behavior_rules} recent "
            "check-ins are available and no configured trigger fired."
        ),
        candidate_action="Reinforce stable or improving behavior.",
        safety_note=(
            "Staying within these behavior targets does not imply zero insulin "
            "resistance or cardiometabolic risk."
        ),
        priority=90,
        confidence="medium",
    )


def _movement_rank(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value)
    return MOVEMENT_BREAK_RANKS.get(_normalize_label(value))


def _alcohol_rank(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value)
    return ALCOHOL_FREQUENCY_RANKS.get(_normalize_label(value))


def _normalize_label(value: Any) -> str:
    return " ".join(str(value).strip().lower().replace("_", " ").split())


def _to_float(value: Any) -> float | None:
    try:
        if value is None or value == "":
            return None
        return float(value)
    except (TypeError, ValueError):
        return None
