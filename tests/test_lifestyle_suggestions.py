import unittest

from src.lifestyle_suggestions import (
    SuggestionDomain,
    generate_lifestyle_suggestions,
)


class LifestyleSuggestionTests(unittest.TestCase):
    def test_low_data_returns_data_support_without_inference(self):
        suggestions = generate_lifestyle_suggestions([{"sleep_hours": 5.5}])

        self.assertEqual([SuggestionDomain.DATA_SUPPORT], [s.domain for s in suggestions])
        self.assertIn("No behavior is inferred", suggestions[0].safety_note)

    def test_sleep_trigger_uses_recent_average(self):
        checkins = [
            {"sleep_hours": 6.0, "movement_break_frequency": "few_times"},
            {"sleep_hours": 6.5, "movement_break_frequency": "few_times"},
            {"sleep_hours": 6.0, "movement_break_frequency": "few_times"},
        ]

        suggestions = generate_lifestyle_suggestions(checkins)

        self.assertEqual(SuggestionDomain.SLEEP, suggestions[0].domain)
        self.assertIn("15- to 30-minute", suggestions[0].suggestion_text)

    def test_repeated_low_movement_trigger(self):
        checkins = [
            {"sleep_hours": 7.5, "movement_break_frequency": "Not at all"},
            {"sleep_hours": 7.0, "movement_break_frequency": "not_at_all"},
            {"sleep_hours": 7.2, "movement_break_frequency": "A few times during the day"},
        ]

        suggestions = generate_lifestyle_suggestions(checkins)

        self.assertEqual(SuggestionDomain.MOVEMENT, suggestions[0].domain)
        self.assertIn("physical limitations", suggestions[0].safety_note)

    def test_diet_requires_repeated_journal_entries(self):
        checkins = [
            {"sleep_hours": 7.5, "movement_break_frequency": "few_times", "food_journal": "soda"},
            {
                "sleep_hours": 7.4,
                "movement_break_frequency": "few_times",
                "food_journal": "sandwich and soda",
            },
            {
                "sleep_hours": 7.6,
                "movement_break_frequency": "few_times",
                "food_journal": "eggs and toast",
            },
        ]

        suggestions = generate_lifestyle_suggestions(checkins)

        self.assertEqual(SuggestionDomain.DIET, suggestions[0].domain)
        self.assertIn("single meal", suggestions[0].safety_note)

    def test_alcohol_high_frequency_trigger(self):
        checkins = [
            {"sleep_hours": 7.5, "movement_break_frequency": "few_times"},
            {"sleep_hours": 7.0, "movement_break_frequency": "few_times"},
            {"sleep_hours": 7.2, "movement_break_frequency": "few_times"},
        ]

        suggestions = generate_lifestyle_suggestions(
            checkins,
            profile={"alcohol_frequency": "4-6 times a week"},
        )

        self.assertEqual(SuggestionDomain.ALCOHOL, suggestions[0].domain)
        self.assertIn("does not label", suggestions[0].safety_note)

    def test_maintenance_when_all_triggers_clear(self):
        checkins = [
            {
                "sleep_hours": 7.5,
                "movement_break_frequency": "About once every hour or more",
                "food_journal": "salad beans fruit water",
            },
            {
                "sleep_hours": 8.0,
                "movement_break_frequency": "I did not spend much time sitting today",
                "food_journal": "vegetables fish brown rice water",
            },
            {
                "sleep_hours": 7.2,
                "movement_break_frequency": "A few times during the day",
                "food_journal": "eggs fruit greens tea",
            },
        ]

        suggestions = generate_lifestyle_suggestions(
            checkins,
            profile={"alcohol_frequency": "monthly"},
        )

        self.assertEqual(SuggestionDomain.MAINTENANCE, suggestions[0].domain)
        self.assertIn("does not imply zero", suggestions[0].safety_note)


if __name__ == "__main__":
    unittest.main()
