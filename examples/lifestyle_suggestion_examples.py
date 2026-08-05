"""Example inputs and outputs for the lifestyle suggestion engine.

Run from the repository root:

    python examples/lifestyle_suggestion_examples.py

This prints examples and writes the same content to:

    examples/lifestyle_suggestion_examples_output.txt
"""
from pathlib import Path
from pprint import pformat
import sys

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from src.lifestyle_suggestions import generate_lifestyle_suggestions

OUTPUT_PATH = Path(__file__).with_name("lifestyle_suggestion_examples_output.txt")


EXAMPLES = [
    {
        "name": "Low data coverage",
        "profile": {
            "age": 42,
            "sex": "female",
            "race": "Asian",
            "height": 165,
            "family_diabetes": "yes",
            "hypertension_history": "no",
            "hypertension_med": "no",
            "high_cholesterol": "no",
            "gestational_diabetes": "no",
            "alcohol_frequency": "monthly",
        },
        "checkins": [
            {
                "date": "2026-08-03",
                "sleep_hours": 6.0,
                "movement_break_frequency": "Once",
            }
        ],
    },
    {
        "name": "Short sleep pattern",
        "profile": {
            "age": 38,
            "sex": "male",
            "race": "Hispanic",
            "height": 178,
            "family_diabetes": "no",
            "hypertension_history": "no",
            "hypertension_med": "no",
            "high_cholesterol": "yes",
            "alcohol_frequency": "monthly",
        },
        "checkins": [
            {
                "date": "2026-08-01",
                "sleep_hours": 6.0,
                "movement_break_frequency": "A few times during the day",
            },
            {
                "date": "2026-08-02",
                "sleep_hours": 6.5,
                "movement_break_frequency": "A few times during the day",
            },
            {
                "date": "2026-08-03",
                "sleep_hours": 6.0,
                "movement_break_frequency": "About once every hour or more",
            },
        ],
    },
    {
        "name": "Repeated low movement breaks",
        "profile": {
            "age": 51,
            "sex": "female",
            "race": "Black",
            "height": 160,
            "family_diabetes": "yes",
            "hypertension_history": "yes",
            "hypertension_med": "yes",
            "high_cholesterol": "yes",
            "gestational_diabetes": "not applicable",
            "alcohol_frequency": "less than monthly",
        },
        "checkins": [
            {
                "date": "2026-08-01",
                "sleep_hours": 7.5,
                "movement_break_frequency": "Not at all",
                "physical_activities": [
                    {"type": "Brisk walking", "minutes": 15, "source": "Apple Health"}
                ],
            },
            {
                "date": "2026-08-02",
                "sleep_hours": 7.0,
                "movement_break_frequency": "Once",
            },
            {
                "date": "2026-08-03",
                "sleep_hours": 7.2,
                "movement_break_frequency": "A few times during the day",
            },
        ],
    },
    {
        "name": "Diet: repeated sugary drinks",
        "profile": {
            "age": 46,
            "sex": "male",
            "race": "White",
            "height": 182,
            "family_diabetes": "no",
            "hypertension_history": "no",
            "hypertension_med": "no",
            "high_cholesterol": "no",
            "alcohol_frequency": "weekly",
        },
        "checkins": [
            {
                "date": "2026-08-01",
                "sleep_hours": 7.5,
                "movement_break_frequency": "few_times",
                "food_journal": "Breakfast sandwich, soda, chicken bowl.",
            },
            {
                "date": "2026-08-02",
                "sleep_hours": 7.4,
                "movement_break_frequency": "few_times",
                "food_journal": "Toast, burger, soda, chips.",
            },
            {
                "date": "2026-08-03",
                "sleep_hours": 7.6,
                "movement_break_frequency": "few_times",
                "food_journal": "Eggs, rice, grilled fish.",
            },
        ],
    },
    {
        "name": "Diet: low fruit and vegetable pattern",
        "profile": {
            "age": 57,
            "sex": "female",
            "race": "Hispanic",
            "height": 158,
            "family_diabetes": "yes",
            "hypertension_history": "no",
            "hypertension_med": "no",
            "high_cholesterol": "yes",
            "gestational_diabetes": "no",
            "alcohol_frequency": "monthly",
        },
        "checkins": [
            {
                "date": "2026-08-01",
                "sleep_hours": 7.5,
                "movement_break_frequency": "few_times",
                "food_journal": "Egg sandwich, coffee, chicken and rice.",
            },
            {
                "date": "2026-08-02",
                "sleep_hours": 7.3,
                "movement_break_frequency": "few_times",
                "food_journal": "Toast, turkey sandwich, pasta.",
            },
            {
                "date": "2026-08-03",
                "sleep_hours": 7.6,
                "movement_break_frequency": "few_times",
                "food_journal": "Cereal, noodles, grilled chicken.",
            },
        ],
    },
    {
        "name": "Alcohol frequency pattern",
        "profile": {
            "age": 35,
            "sex": "female",
            "race": "Other",
            "height": 170,
            "family_diabetes": "no",
            "hypertension_history": "no",
            "hypertension_med": "no",
            "high_cholesterol": "no",
            "gestational_diabetes": "prefer not to answer",
            "alcohol_frequency": "4-6 times a week",
        },
        "checkins": [
            {
                "date": "2026-08-01",
                "sleep_hours": 7.5,
                "movement_break_frequency": "few_times",
            },
            {
                "date": "2026-08-02",
                "sleep_hours": 7.0,
                "movement_break_frequency": "few_times",
            },
            {
                "date": "2026-08-03",
                "sleep_hours": 7.2,
                "movement_break_frequency": "few_times",
            },
        ],
    },
    {
        "name": "Maintenance",
        "profile": {
            "age": 44,
            "sex": "male",
            "race": "Asian",
            "height": 176,
            "family_diabetes": "yes",
            "hypertension_history": "no",
            "hypertension_med": "no",
            "high_cholesterol": "no",
            "alcohol_frequency": "monthly",
        },
        "checkins": [
            {
                "date": "2026-08-01",
                "sleep_hours": 7.5,
                "movement_break_frequency": "About once every hour or more",
                "food_journal": "Oatmeal, fruit, salad, beans, water.",
            },
            {
                "date": "2026-08-02",
                "sleep_hours": 8.0,
                "movement_break_frequency": "I did not spend much time sitting today",
                "food_journal": "Eggs, vegetables, fish, brown rice.",
            },
            {
                "date": "2026-08-03",
                "sleep_hours": 7.2,
                "movement_break_frequency": "A few times during the day",
                "food_journal": "Greek yogurt, berries, greens, tea.",
            },
        ],
    },
]


def main():
    output_blocks = []
    for example in EXAMPLES:
        input_payload = {
            "profile": example["profile"],
            "checkins": example["checkins"],
        }

        suggestions = generate_lifestyle_suggestions(
            checkins=example["checkins"],
            profile=example["profile"],
            max_suggestions=2,
        )
        output_payload = [suggestion_to_dict(suggestion) for suggestion in suggestions]

        block = "\n".join(
            [
                f"=== {example['name']} ===",
                "Input:",
                pformat(input_payload, sort_dicts=False),
                "",
                "Output:",
                pformat(output_payload, sort_dicts=False),
            ]
        )
        output_blocks.append(block)

    rendered_output = "\n\n".join(output_blocks) + "\n"
    print(rendered_output)
    OUTPUT_PATH.write_text(rendered_output, encoding="utf-8")
    print(f"Wrote example output to {OUTPUT_PATH}")


def suggestion_to_dict(suggestion):
    return {
        "domain": suggestion.domain.value,
        "title": suggestion.title,
        "suggestion_text": suggestion.suggestion_text,
        "trigger_reason": suggestion.trigger_reason,
        "candidate_action": suggestion.candidate_action,
        "safety_note": suggestion.safety_note,
        "priority": suggestion.priority,
        "confidence": suggestion.confidence,
    }


if __name__ == "__main__":
    main()
