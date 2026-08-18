from __future__ import annotations

import json
import logging
import os
import re
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass
from typing import Any


logger = logging.getLogger(__name__)

DISCLAIMER = "Suggestions support general wellness and are not medical advice."

PROHIBITED_PATTERNS = (
    r"\byou have\b",
    r"\byou are diagnosed\b",
    r"\bcure\b",
    r"\btreat\b",
    r"\bmedication\b",
    r"\binsulin resistance diagnosis\b",
)


@dataclass(frozen=True)
class DailyInsightCard:
    icon: str
    title: str
    what_we_noticed: str
    why_it_may_matter: str
    next_step: str


def generate_daily_insights(check_in: dict[str, Any]) -> dict[str, Any]:
    fallback_cards = _rule_based_cards(check_in)
    rewritten = _rewrite_with_openai(fallback_cards, check_in)
    if rewritten:
        return {
            "source": "openai_rewrite",
            "insights": [asdict(card) for card in rewritten],
            "disclaimer": DISCLAIMER,
        }
    return {
        "source": "rule_fallback",
        "insights": [asdict(card) for card in fallback_cards],
        "disclaimer": DISCLAIMER,
    }


def _rule_based_cards(check_in: dict[str, Any]) -> list[DailyInsightCard]:
    cards = [
        _sleep_card(check_in),
        _activity_card(check_in),
        _movement_card(check_in),
    ]
    if _string_value(check_in, "foodJournal", "food_journal") == "Added":
        cards.append(_food_card(check_in))
    return cards


def _sleep_card(check_in: dict[str, Any]) -> DailyInsightCard:
    sleep = _float_value(check_in, "sleepHours", "sleep_hours")
    if sleep is None:
        return DailyInsightCard(
            icon="moon.zzz",
            title="Sleep",
            what_we_noticed="No sleep duration was logged for last night.",
            why_it_may_matter="Without sleep information, the app should not guess how sleep may relate to today's routine.",
            next_step="Try logging sleep hours tomorrow if you have them.",
        )
    if sleep < 6:
        return DailyInsightCard(
            icon="moon.zzz",
            title="Sleep",
            what_we_noticed=f"You slept for about {_format_number(sleep)} hours last night.",
            why_it_may_matter="Getting enough sleep may support energy regulation and metabolic health.",
            next_step="If possible, begin your bedtime routine 15 minutes earlier tonight.",
        )
    if sleep <= 9:
        return DailyInsightCard(
            icon="moon.zzz",
            title="Sleep",
            what_we_noticed=f"You slept for about {_format_number(sleep)} hours last night.",
            why_it_may_matter="A consistent, sufficient sleep window may support daily energy and metabolic health.",
            next_step="Try keeping a similar sleep schedule tomorrow.",
        )
    return DailyInsightCard(
        icon="moon.zzz",
        title="Sleep",
        what_we_noticed=f"You logged about {_format_number(sleep)} hours of sleep last night.",
        why_it_may_matter="Long sleep can happen for many reasons, so one day should not be interpreted as a medical signal.",
        next_step="If this pattern continues, note how your energy feels during the day.",
    )


def _activity_card(check_in: dict[str, Any]) -> DailyInsightCard:
    active_today = _bool_value(check_in, "activeToday", "active_today")
    activity_type = _string_value(check_in, "activityType", "activity_type")
    duration = _int_value(check_in, "activityDuration", "activity_duration") or 0
    normalized_type = activity_type.lower()
    is_strength = "strength" in normalized_type or "weight" in normalized_type or "resistance" in normalized_type

    if active_today is None:
        return DailyInsightCard(
            icon="figure.walk",
            title="Physical activity",
            what_we_noticed="No physical activity answer was logged today.",
            why_it_may_matter="Without activity information, the app should not infer whether today was active or inactive.",
            next_step="Try answering the activity question tomorrow, even if the answer is no.",
        )
    if active_today is False:
        return DailyInsightCard(
            icon="figure.walk",
            title="Physical activity",
            what_we_noticed="You reported no moderate, vigorous, or strengthening activity today.",
            why_it_may_matter="Even brief activity can support daily energy use and insulin sensitivity over time.",
            next_step="Tomorrow, try one low-barrier option, such as a 5- to 10-minute walk.",
        )

    if activity_type:
        logged = f"You logged {activity_type.lower()}"
        if duration > 0:
            logged += f" for about {duration} minutes"
        logged += "."
    else:
        logged = "You reported being physically active today."

    if duration > 0 and duration < 30:
        return DailyInsightCard(
            icon="dumbbell" if is_strength else "figure.walk",
            title="Physical activity",
            what_we_noticed=logged,
            why_it_may_matter="Some activity is meaningful, and adding a little more can support metabolic health habits.",
            next_step="Tomorrow, try adding 5 more minutes if that feels realistic.",
        )
    if is_strength:
        next_step = "Tomorrow, consider a short walk if it fits your day."
    else:
        next_step = "Try keeping this activity pattern tomorrow."
    return DailyInsightCard(
        icon="dumbbell" if is_strength else "figure.walk",
        title="Physical activity",
        what_we_noticed=logged,
        why_it_may_matter="Regular movement, including aerobic or strengthening activity, may support insulin sensitivity over time.",
        next_step=next_step,
    )


def _movement_card(check_in: dict[str, Any]) -> DailyInsightCard:
    movement = _string_value(check_in, "movementBreaks", "movement_breaks")
    options = {
        "About once an hour or more": DailyInsightCard(
            icon="figure.stand",
            title="Movement breaks",
            what_we_noticed="You took movement breaks about once an hour or more while sitting.",
            why_it_may_matter="Breaking up long sitting periods may support glucose and energy regulation.",
            next_step="Try keeping that same break pattern tomorrow.",
        ),
        "A few times during the day": DailyInsightCard(
            icon="figure.stand",
            title="Movement breaks",
            what_we_noticed="You took movement breaks a few times today.",
            why_it_may_matter="Short breaks can reduce long uninterrupted sitting time.",
            next_step="Tomorrow, attach one extra 2- to 3-minute break to a fixed moment, such as after lunch.",
        ),
        "Once": DailyInsightCard(
            icon="figure.stand",
            title="Movement breaks",
            what_we_noticed="You logged one movement break today.",
            why_it_may_matter="Starting small can make movement breaks easier to repeat.",
            next_step="Tomorrow, try adding one extra 2- to 3-minute standing or walking break.",
        ),
        "Not at all": DailyInsightCard(
            icon="figure.stand",
            title="Movement breaks",
            what_we_noticed="You reported no movement breaks during sitting periods today.",
            why_it_may_matter="Long uninterrupted sitting may be related to daily metabolic patterns.",
            next_step="Tomorrow, choose one long sitting period and add one 2- to 3-minute break.",
        ),
        "I did not spend much time sitting": DailyInsightCard(
            icon="figure.stand",
            title="Movement breaks",
            what_we_noticed="You did not spend much time sitting today.",
            why_it_may_matter="Less sitting means movement breaks may be less relevant for this particular day.",
            next_step="No extra sitting-break action is needed from this log.",
        ),
    }
    if movement in options:
        return options[movement]
    return DailyInsightCard(
        icon="figure.stand",
        title="Movement breaks",
        what_we_noticed="No movement-break answer was logged today.",
        why_it_may_matter="Without this answer, the app should not guess how much sitting was interrupted.",
        next_step="Try answering the movement-break question tomorrow.",
    )


def _food_card(check_in: dict[str, Any]) -> DailyInsightCard:
    description = _string_value(check_in, "foodJournalDescription", "food_journal_description")
    photo_count = _int_value(check_in, "foodPhotoCount", "food_photo_count") or 0
    carbs = _float_value(check_in, "foodCarbohydrates", "food_carbohydrates")
    protein = _float_value(check_in, "foodProtein", "food_protein")
    text = description.lower()

    if description:
        noticed = f"You added a food journal note: {description}"
    elif photo_count > 0:
        plural = "" if photo_count == 1 else "s"
        noticed = f"You uploaded {photo_count} food photo{plural} today."
    else:
        noticed = "You added a food journal today."

    if "soda" in text or "juice" in text or "sweet" in text:
        next_step = "Tomorrow, notice whether swapping one sweet drink for water or unsweetened tea feels realistic."
    elif carbs is not None and carbs >= 75 and protein is not None and protein < 20:
        next_step = "Tomorrow, try pairing a carbohydrate-rich meal with one protein source."
    elif carbs is not None and carbs >= 75:
        next_step = "Tomorrow, notice how hunger or energy feels after a carbohydrate-rich meal."
    elif protein is not None and protein >= 20:
        next_step = "Tomorrow, notice whether a similar protein-containing meal helps fullness or energy."
    else:
        next_step = "Tomorrow, add one detail about timing, vegetables, protein, or drinks if you log food again."

    return DailyInsightCard(
        icon="fork.knife",
        title="Food reflection",
        what_we_noticed=noticed,
        why_it_may_matter="Meal timing and food combinations can be useful context when reflecting on energy, hunger, and metabolic health patterns.",
        next_step=next_step,
    )


def _rewrite_with_openai(cards: list[DailyInsightCard], check_in: dict[str, Any]) -> list[DailyInsightCard] | None:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None

    prompt = {
        "instruction": (
            "Rewrite these daily wellness insight cards into supportive, natural language. "
            "Do not change titles, icons, facts, or recommendation direction. "
            "Use only the user's provided check-in data. Do not diagnose, prescribe medication, "
            "judge foods as good or bad, or mention weekly risk. Keep each field concise."
        ),
        "check_in": _safe_check_in_summary(check_in),
        "cards": [asdict(card) for card in cards],
        "required_output": {
            "insights": [
                {
                    "icon": "same as input",
                    "title": "same as input",
                    "what_we_noticed": "fact traceable to check-in",
                    "why_it_may_matter": "general metabolic health relation, not diagnosis",
                    "next_step": "one small action for tomorrow",
                }
            ]
        },
    }
    payload = {
        "model": os.getenv("OPENAI_INSIGHTS_MODEL", "gpt-4o-mini"),
        "input": [{"role": "user", "content": [{"type": "input_text", "text": json.dumps(prompt)}]}],
    }
    request = urllib.request.Request(
        "https://api.openai.com/v1/responses",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        logger.warning("OpenAI daily insights request failed status=%s", exc.code)
        return None
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        logger.warning("OpenAI daily insights request failed: %s", exc)
        return None

    output_text = _extract_openai_text(raw)
    parsed = _parse_json_object(output_text)
    if not parsed:
        return None
    return _validate_rewritten_cards(parsed.get("insights"), cards)


def _validate_rewritten_cards(value: Any, fallback_cards: list[DailyInsightCard]) -> list[DailyInsightCard] | None:
    if not isinstance(value, list) or len(value) != len(fallback_cards):
        return None
    rewritten: list[DailyInsightCard] = []
    for item, fallback in zip(value, fallback_cards):
        if not isinstance(item, dict):
            return None
        if item.get("title") != fallback.title or item.get("icon") != fallback.icon:
            return None
        card = DailyInsightCard(
            icon=fallback.icon,
            title=fallback.title,
            what_we_noticed=_clean_text(item.get("what_we_noticed"), fallback.what_we_noticed),
            why_it_may_matter=_clean_text(item.get("why_it_may_matter"), fallback.why_it_may_matter),
            next_step=_clean_text(item.get("next_step"), fallback.next_step),
        )
        if not _card_is_safe(card):
            return None
        rewritten.append(card)
    return rewritten


def _clean_text(value: Any, fallback: str) -> str:
    if not isinstance(value, str):
        return fallback
    normalized = " ".join(value.split()).strip()
    if not normalized or len(normalized) > 260:
        return fallback
    return normalized


def _card_is_safe(card: DailyInsightCard) -> bool:
    combined = " ".join([card.what_we_noticed, card.why_it_may_matter, card.next_step]).lower()
    return not any(re.search(pattern, combined) for pattern in PROHIBITED_PATTERNS)


def _extract_openai_text(response: dict[str, Any]) -> str:
    if isinstance(response.get("output_text"), str):
        return response["output_text"]
    parts: list[str] = []
    for item in response.get("output", []):
        for content in item.get("content", []):
            text = content.get("text")
            if isinstance(text, str):
                parts.append(text)
    return "\n".join(parts)


def _parse_json_object(text: str) -> dict[str, Any] | None:
    if not text:
        return None
    try:
        parsed = json.loads(text)
        return parsed if isinstance(parsed, dict) else None
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", text, flags=re.DOTALL)
        if not match:
            return None
        try:
            parsed = json.loads(match.group(0))
            return parsed if isinstance(parsed, dict) else None
        except json.JSONDecodeError:
            return None


def _safe_check_in_summary(check_in: dict[str, Any]) -> dict[str, Any]:
    allowed_keys = [
        "sleepHours",
        "sleep_hours",
        "activeToday",
        "active_today",
        "activityType",
        "activity_type",
        "activityDuration",
        "activity_duration",
        "movementBreaks",
        "movement_breaks",
        "foodJournal",
        "food_journal",
        "foodJournalDescription",
        "food_journal_description",
        "foodPhotoCount",
        "food_photo_count",
        "foodCalories",
        "food_calories",
        "foodCarbohydrates",
        "food_carbohydrates",
        "foodProtein",
        "food_protein",
        "foodFat",
        "food_fat",
    ]
    return {key: check_in.get(key) for key in allowed_keys if key in check_in}


def _string_value(data: dict[str, Any], *keys: str) -> str:
    for key in keys:
        value = data.get(key)
        if value is not None:
            return str(value).strip()
    return ""


def _float_value(data: dict[str, Any], *keys: str) -> float | None:
    value = _string_value(data, *keys)
    if not value:
        return None
    try:
        return float(value)
    except ValueError:
        return None


def _int_value(data: dict[str, Any], *keys: str) -> int | None:
    value = _float_value(data, *keys)
    if value is None:
        return None
    return int(value)


def _bool_value(data: dict[str, Any], *keys: str) -> bool | None:
    for key in keys:
        if key not in data:
            continue
        value = data[key]
        if isinstance(value, bool):
            return value
        if isinstance(value, str):
            normalized = value.strip().lower()
            if normalized in {"true", "yes", "1"}:
                return True
            if normalized in {"false", "no", "0"}:
                return False
    return None


def _format_number(value: float) -> str:
    return str(int(value)) if value.is_integer() else f"{value:.1f}"
