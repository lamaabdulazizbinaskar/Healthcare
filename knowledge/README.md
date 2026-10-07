# LifeStep guidelines knowledge base

> ⚠️ **Must be verified before any real use.** Entries are short summaries **in our own words**
> of individual recommendations, with exact section / recommendation / table numbers, so that a
> clinician can check each one against the original documents.

## The two reference documents (the only sources used)

| Code | Document | Used for |
|---|---|---|
| **ADA 2026** | American Diabetes Association Professional Practice Committee. *Standards of Care in Diabetes—2026.* Diabetes Care 2026;49(Suppl. 1):S1–S371 | Diabetes: nutrition, activity, glucose safety, foot care, sleep, Ramadan fasting, BP in diabetes |
| **ACC/AHA 2017** | Whelton PK, Carey RM, et al. *2017 ACC/AHA/AAPA/ABC/ACPM/AGS/APhA/ASH/ASPC/NMA/PCNA Guideline for the Prevention, Detection, Evaluation, and Management of High Blood Pressure in Adults.* J Am Coll Cardiol 2018;71:e127–e248 | Hypertension: lifestyle (Section 6.2, Table 15), home BP (Section 4.2, Tables 8 and 10), adherence (12.1), crisis (11.2), diabetes (9.6), pregnancy (10.2.2) |

### Licensing: please read
- **Neither PDF is included in this repository**; link to the publishers instead.
- **ADA:** "may not be reproduced, distributed, or used for text or data mining, machine learning, or similar technologies without prior written permission" (permissions@diabetes.org). LifeStep therefore **never sends ADA text to the AI**; it uses only these team-written summaries with citations. For anything beyond an educational hackathon demo, **ask ADA for permission**.
- **ACC/AHA:** copies, modification or distribution of the document need permission from the American College of Cardiology.

## Layout
```
knowledge/
  hypertension/   ACC/AHA 2017 entries (HTN-*)
  diabetes/       ADA 2026 entries (DM-*)
```
Entries whose `source` starts with **Team-authored** are practical steps or local examples
that *apply* a cited recommendation (e.g. Saudi food swaps). They are not statements of the
guidelines and need clinician / dietitian review.

## Entry format
```markdown
## DM-NUTR-03: Short title
- source: ADA Standards of Care 2026, rec. 5.21 (A) and rec. 5.25 (B)
- tags: comma, separated
- frequency_hint: daily | weekly | monthly
- contraindications: optional

Plain-language summary (our own words). This is the only text the AI may ground goals in.
```
