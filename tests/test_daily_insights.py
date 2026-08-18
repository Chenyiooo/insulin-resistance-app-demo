from urllib.error import HTTPError
from unittest.mock import patch

from backend.daily_insights import generate_daily_insights
from backend import main


def test_daily_insights_returns_required_rule_cards_without_food():
    result = generate_daily_insights(
        {
            "sleepHours": "5.5",
            "activeToday": False,
            "movementBreaks": "Not at all",
            "foodJournal": "",
        }
    )

    titles = [card["title"] for card in result["insights"]]
    assert result["source"] == "rule_fallback"
    assert titles == ["Sleep", "Physical activity", "Movement breaks"]
    assert "5.5 hours" in result["insights"][0]["what_we_noticed"]
    assert "2- to 3-minute" in result["insights"][2]["next_step"]


def test_daily_insights_adds_food_only_when_logged():
    result = generate_daily_insights(
        {
            "sleepHours": "7",
            "activeToday": True,
            "activityType": "Brisk walking",
            "activityDuration": "30",
            "movementBreaks": "A few times during the day",
            "foodJournal": "Added",
            "foodJournalDescription": "rice bowl with chicken",
            "foodCarbohydrates": "82",
            "foodProtein": "18",
        }
    )

    food = result["insights"][-1]
    assert food["title"] == "Food reflection"
    assert "rice bowl with chicken" in food["what_we_noticed"]
    assert "protein" in food["next_step"]


def test_daily_insights_openai_http_error_falls_back_to_rules():
    error = HTTPError(
        url="https://api.openai.com/v1/responses",
        code=429,
        msg="quota",
        hdrs=None,
        fp=None,
    )
    with patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"}, clear=False):
        with patch("backend.daily_insights.urllib.request.urlopen", side_effect=error):
            result = generate_daily_insights({"sleepHours": "8", "activeToday": True})

    assert result["source"] == "rule_fallback"
    assert result["insights"][0]["title"] == "Sleep"


def test_daily_insights_openai_rewrite_is_used_when_safe():
    class FakeResponse:
        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc, traceback):
            return False

        def read(self):
            return b'''
            {
              "output_text": "{\\"insights\\":[{\\"icon\\":\\"moon.zzz\\",\\"title\\":\\"Sleep\\",\\"what_we_noticed\\":\\"You slept for about 8 hours last night.\\",\\"why_it_may_matter\\":\\"Steady sleep can support daily energy and metabolic health.\\",\\"next_step\\":\\"Try keeping a similar bedtime routine tomorrow.\\"},{\\"icon\\":\\"figure.walk\\",\\"title\\":\\"Physical activity\\",\\"what_we_noticed\\":\\"You reported being physically active today.\\",\\"why_it_may_matter\\":\\"Regular movement may support insulin sensitivity over time.\\",\\"next_step\\":\\"Try keeping this activity pattern tomorrow.\\"},{\\"icon\\":\\"figure.stand\\",\\"title\\":\\"Movement breaks\\",\\"what_we_noticed\\":\\"No movement-break answer was logged today.\\",\\"why_it_may_matter\\":\\"Without this answer, the app should not guess about sitting time.\\",\\"next_step\\":\\"Try answering the movement-break question tomorrow.\\"}]}"
            }
            '''

    with patch.dict("os.environ", {"OPENAI_API_KEY": "test-key"}, clear=False):
        with patch("backend.daily_insights.urllib.request.urlopen", return_value=FakeResponse()):
            result = generate_daily_insights({"sleepHours": "8", "activeToday": True})

    assert result["source"] == "openai_rewrite"
    assert result["insights"][0]["next_step"] == "Try keeping a similar bedtime routine tomorrow."


def test_daily_insights_endpoint_accepts_checkin_payload():
    response = main.daily_insights(
        main.DailyInsightsRequest(
            check_in={
                "sleepHours": "8",
                "activeToday": True,
                "activityDuration": "30",
                "movementBreaks": "About once an hour or more",
            }
        )
    )

    assert response["insights"][0]["title"] == "Sleep"
    assert response["disclaimer"] == "Suggestions support general wellness and are not medical advice."
