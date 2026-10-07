"""One-page monthly PDF report for the patient to show their doctor (English, clinician-facing)."""
from datetime import datetime

from fpdf import FPDF

from ..models import UserData

_REASONS = {
    "too_hard": "too hard", "no_time": "no time", "pain": "pain/discomfort",
    "forgot": "kept forgetting", "dont_like": "did not like it", "not_relevant": "did not fit routine",
    "level_up": "achieved 6+ of 7 days, stepped up",
}


def _latin(text: str) -> str:
    """Core PDF fonts are Latin-1 only; replace anything else (e.g. Arabic names)."""
    return text.encode("latin-1", "replace").decode("latin-1").replace("?", "") if text else ""


def _bp_chart(pdf: FPDF, data: UserData, stats: dict, x: float, y: float, w: float, h: float) -> None:
    start, end = stats["period"]["start"], stats["period"]["end"]
    rs = sorted(
        (r for r in data.bp if start <= r.taken_at[:10] <= end), key=lambda r: r.taken_at
    )
    pdf.set_draw_color(180, 180, 180)
    pdf.rect(x, y, w, h)
    if len(rs) < 2:
        pdf.set_xy(x, y + h / 2 - 3)
        pdf.cell(w, 6, "Not enough readings for a chart", align="C")
        return
    lo, hi = 60, max(190, max(r.systolic for r in rs) + 10)

    def py(v):
        return y + h - (v - lo) / (hi - lo) * h

    pdf.set_font("Helvetica", "", 7)
    for ref, label in ((140, "140"), (90, "90"), (180, "180")):
        pdf.set_draw_color(230, 120, 120) if ref == 180 else pdf.set_draw_color(220, 220, 220)
        pdf.line(x, py(ref), x + w, py(ref))
        pdf.set_xy(x - 8, py(ref) - 2)
        pdf.cell(7, 4, label, align="R")
    step = w / (len(rs) - 1)
    for attr, color in (("systolic", (200, 40, 40)), ("diastolic", (40, 90, 200))):
        pdf.set_draw_color(*color)
        pdf.set_line_width(0.5)
        for i in range(len(rs) - 1):
            pdf.line(x + i * step, py(getattr(rs[i], attr)), x + (i + 1) * step, py(getattr(rs[i + 1], attr)))
    pdf.set_line_width(0.2)
    pdf.set_xy(x, y + h + 1)
    pdf.set_text_color(200, 40, 40)
    pdf.cell(30, 4, "- Systolic")
    pdf.set_text_color(40, 90, 200)
    pdf.cell(30, 4, "- Diastolic")
    pdf.set_text_color(0, 0, 0)


def build_pdf(data: UserData, stats: dict) -> bytes:
    p = data.profile
    pdf = FPDF(format="A4")
    pdf.set_auto_page_break(False)
    pdf.add_page()
    pdf.set_margins(15, 12, 15)

    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(0, 9, "LifeStep - Monthly lifestyle & home BP report", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(90, 90, 90)
    pdf.cell(
        0, 5,
        f"Period: {stats['period']['start']} to {stats['period']['end']}   |   "
        f"Generated: {datetime.now():%Y-%m-%d %H:%M}",
        new_x="LMARGIN", new_y="NEXT",
    )
    pdf.set_text_color(0, 0, 0)
    pdf.ln(2)

    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 6, "Patient", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 9)
    if p:
        name = _latin(p.name) or "(name in Arabic, see app)"
        pdf.multi_cell(
            0, 4.5,
            f"{name}, {p.age} y, {p.sex}. Weight {p.weight_kg:g} kg, height {p.height_cm:g} cm, BMI {p.bmi}. "
            f"Medications (self-reported): {_latin(', '.join(p.medications)) or 'none'}. "
            f"Limitations: {', '.join(l.replace('_', ' ') for l in p.limitations) or 'none'}. "
            f"Other conditions: {', '.join(c.replace('_', ' ') for c in p.conditions) or 'none reported'}. "
            f"Diagnosed: {p.diagnosed.replace('_', ' ')}. "
            f"Usual BP (self-reported): {f'{p.usual_systolic}/{p.usual_diastolic}' if p.usual_systolic else 'unknown'}. "
            f"Condition: {p.disease.replace('both', 'hypertension + diabetes')}."
            + (
                f" Diabetes: {p.diabetes_type}; medicines: {', '.join(p.diabetes_meds) or 'none'}; "
                f"low sugars (3 mo): {p.low_sugar}; complications: {', '.join(p.complications) or 'none reported'}; "
                f"plans to fast Ramadan: {p.fasting}."
                if p.has_diabetes else ""
            ),
            new_x="LMARGIN", new_y="NEXT",
        )
    pdf.ln(2)

    bp = stats["bp"]
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(95, 6, "Home blood pressure")
    pdf.cell(0, 6, f"Plan adherence: {stats['adherence_percent']}%", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 9)
    if bp["count"]:
        lines = [
            f"Readings: {bp['count']}   Average: {bp['avg_systolic']}/{bp['avg_diastolic']} mmHg",
            f"Start of period avg: {bp['first_avg']}  ->  End of period avg: {bp['last_avg']} "
            f"({'+' if bp['change_systolic'] > 0 else ''}{bp['change_systolic']} systolic)",
            f"Highest: {bp['max']['systolic']}/{bp['max']['diastolic']} on {bp['max']['taken_at'][:10]}   "
            f"Lowest: {bp['min']['systolic']}/{bp['min']['diastolic']}",
            f"Readings >=140/90: {bp['above_target_count']}   Crisis range (>=180/120): {bp['crisis_count']}",
            f"Readings with warning symptoms reported: {len(bp['with_symptoms'])}",
        ]
        for line in lines:
            pdf.cell(0, 4.8, line, new_x="LMARGIN", new_y="NEXT")
    else:
        pdf.cell(0, 5, "No readings logged in this period.", new_x="LMARGIN", new_y="NEXT")

    gl = stats.get("glucose", {})
    if gl.get("count"):
        pdf.ln(1)
        pdf.set_font("Helvetica", "B", 11)
        pdf.cell(0, 6, "Self-monitored blood glucose (mg/dL)", new_x="LMARGIN", new_y="NEXT")
        pdf.set_font("Helvetica", "", 9)
        fasting = f"   Fasting average: {gl['fasting_avg']}" if gl.get("fasting_avg") else ""
        pdf.cell(0, 4.8, f"Readings: {gl['count']}   Average: {gl['avg']}{fasting}   Highest: {gl['highest']}",
                 new_x="LMARGIN", new_y="NEXT")
        pdf.cell(0, 4.8, f"Below 70 (level 1): {gl['lows']}   Below 54 (level 2): {gl['very_lows']}   "
                         f"Within 70-180: {gl['in_range_pct']}%  (ADA 2026 Tables 6.3/6.4)", new_x="LMARGIN", new_y="NEXT")

    chart_top = pdf.get_y() + 3
    _bp_chart(pdf, data, stats, 23, chart_top, 172, 40)
    pdf.set_y(chart_top + 47)

    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 6, "Lifestyle goals (lowest adherence first)", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "B", 8)
    pdf.set_fill_color(235, 235, 235)
    pdf.cell(125, 5, "Goal", border=1, fill=True)
    pdf.cell(25, 5, "Frequency", border=1, fill=True)
    pdf.cell(30, 5, "Done", border=1, fill=True, new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 8)
    for row in stats["goals"][:10]:
        title = _latin(row["title_en"]) + (" (replaced)" if row["retired"] else "")
        pdf.cell(125, 5, title[:85], border=1)
        pdf.cell(25, 5, row["frequency"], border=1)
        pdf.cell(30, 5, f"{row['adherence']}%", border=1, new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)

    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 6, "Plan changes (difficulties reported / goals stepped up)", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 8.5)
    if stats["difficulties"]:
        for d in stats["difficulties"][:5]:
            pdf.multi_cell(
                0, 4.5,
                _latin(f"{d['date']}: '{d['old_en']}' - {_REASONS.get(d['reason'], d['reason'])}. "
                       f"Adjusted to: '{d['new_en']}'."),
                new_x="LMARGIN", new_y="NEXT",
            )
    else:
        pdf.cell(0, 5, "None reported.", new_x="LMARGIN", new_y="NEXT")

    pdf.set_y(-24)
    pdf.set_font("Helvetica", "I", 7.5)
    pdf.set_text_color(100, 100, 100)
    pdf.multi_cell(
        0, 3.6,
        "Patient-generated data from a home BP monitor and self-reported check-ins; not verified by a clinician. "
        "Lifestyle goals are derived from the 2017 ACC/AHA High Blood Pressure Guideline and the ADA Standards of Care "
        "in Diabetes 2026, and are meant to support, not replace, the treating physician's plan. LifeStep does not change "
        "medications.",
    )
    return bytes(pdf.output())
