import pytest

from app.safety.red_flags import evaluate


@pytest.mark.parametrize(
    "sys_,dia,expected",
    [
        (120, 80, "ok"),
        (139, 89, "ok"),
        (140, 85, "elevated"),
        (135, 90, "elevated"),
        (179, 119, "elevated"),
        (180, 100, "emergency"),  # boundary: systolic >= 180
        (150, 120, "emergency"),  # boundary: diastolic >= 120
        (210, 130, "emergency"),
    ],
)
def test_bp_thresholds(sys_, dia, expected):
    assert evaluate(sys_, dia).level == expected


@pytest.mark.parametrize(
    "symptom",
    ["chest_pain", "severe_headache", "shortness_of_breath", "vision_changes", "weakness_numbness"],
)
def test_any_warning_symptom_is_emergency_even_with_normal_bp(symptom):
    result = evaluate(118, 76, [symptom])
    assert result.level == "emergency"
    assert "997" in result.message_en and "997" in result.message_ar


def test_symptoms_without_reading():
    assert evaluate(symptoms=["chest_pain"]).level == "emergency"


def test_unknown_symptom_ignored():
    assert evaluate(symptoms=["tired"]).level == "ok"


def test_ask_routes_emergency_words_to_rule_engine_not_ai():
    from app.ai.ask import answer

    r = answer("عندي ألم في الصدر الآن", "hypertension", None, [])
    assert r["type"] == "emergency" and r["safety"]["level"] == "emergency"


def test_ask_never_lets_ai_answer_medicine_changes():
    from app.ai.ask import answer

    r = answer("Can I stop taking my amlodipine?", "hypertension", None, [])
    assert r["mode"] == "rule" and r["suggest_doctor"]


def test_ask_does_not_raise_false_alarms_on_normal_questions():
    from app.ai.ask import answer

    for q in ["What numbers are normal?", "Can I watch television after walking?", "I'm confused about my plan"]:
        assert answer(q, "hypertension", None, [])["type"] == "answer", q


def test_glucose_levels_follow_ada_table_6_4():
    from app.safety.red_flags import evaluate_glucose

    assert evaluate_glucose(110).level == "ok"
    assert evaluate_glucose(70).level == "ok"      # boundary: < 70 is low
    assert evaluate_glucose(69).level == "low"
    assert evaluate_glucose(54).level == "low"     # boundary: < 54 is level 2
    assert evaluate_glucose(53).level == "urgent"
    assert evaluate_glucose(90, ["fainted"]).level == "emergency"
