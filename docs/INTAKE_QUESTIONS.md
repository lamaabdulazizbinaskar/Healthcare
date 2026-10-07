# LifeStep: what we ask, why, and what it decides

> Generated from `backend/app/intake/registry.py` and `backend/app/diseases/rules.py` (the same code the
> app runs). Regenerate with `cd backend && .venv/bin/python -m app.intake.export_doc`.

## The two reference documents (the only sources)

| Code | Document |
|---|---|
| **ACC/AHA 2017** | Whelton PK, Carey RM, et al. *2017 ACC/AHA/AAPA/ABC/ACPM/AGS/APhA/ASH/ASPC/NMA/PCNA Guideline for the Prevention, Detection, Evaluation, and Management of High Blood Pressure in Adults.* J Am Coll Cardiol 2018;71:e127–e248. |
| **ADA 2026** | American Diabetes Association Professional Practice Committee. *Standards of Care in Diabetes—2026.* Diabetes Care 2026;49(Suppl. 1):S1–S371. |

Section, recommendation (e.g. "rec 5.25") and table numbers were checked against the PDFs provided by
the team. Wording in the app is our own (the ADA license forbids reproducing its text or using it for
machine learning without permission; neither PDF is in this repository).

## How decisions are made

1. The patient answers the questions below (only the ones relevant to their condition are shown).
2. **Fixed, tested rules (R1–R22)** turn the answers into what is allowed, what is not, and what comes first.
   Rules are code, not AI, and are covered by unit tests in `backend/tests/`.
3. The AI (Claude, when switched on) only words the goals in plain Arabic/English, using guideline summaries
   that the rules allowed for this patient. Any goal not citing an allowed entry is dropped by code.

## How reliable is this?

| Part | Trust | Why / limits |
|---|---|---|
| Thresholds & safety (BP ≥ 180/120, glucose < 70 / < 54, pregnancy, potassium) | **High** | Directly from numbered recommendations/tables; unit-tested at the exact boundaries. |
| Lifestyle targets (sodium, DASH, 150 min/week, 5–7% weight, water instead of sugary drinks…) | **High** | Directly from ACC/AHA Table 15 and ADA Section 5 recommendations (grades A/B mostly). |
| The questions | **Moderate** | Each asks about something the guidelines say to assess, but our short, elder-friendly wording is **not a validated questionnaire**. Answers are self-reported. |
| Combining two guidelines into one rule set | **Moderate** | Each rule is sourced, but the combination is ours and has **not been clinically validated**. Where they differ we use the stricter goal (e.g. sodium < 1500 mg/day ACC/AHA vs < 2300 ADA). |
| Team choices (marked *Team-authored*) | **Low until reviewed** | Saudi food examples, meal ideas, reminder times, the 160/100 activity cut-off. Need clinician / dietitian review. |

**Before real patients:** a clinician should review rules R1–R22 against the two PDFs; pilot the Arabic
questions with 10–15 older Saudi patients; obtain ADA permission for any non-educational use.

## Decision rules

| Rule | Decision | Source |
|---|---|---|
| R1 | BMI ≥ 25 → weight goal: ≥ 1 kg (hypertension) or 5–7% (diabetes). | ACC/AHA 2017 §6.2 rec 1, Table 15; ADA 2026 rec 5.12 |
| R2 | Salt at table / in cooking / salty foods 'often' → matching salt goals. | ACC/AHA 2017 §6.2 rec 3, Table 15; ADA 2026 rec 5.20 |
| R3 | < 5 servings of vegetables & fruit a day → vegetables goal (DASH / ADA pattern). | ACC/AHA 2017 §6.2 rec 2 (DASH); ADA 2026 rec 5.14 |
| R4 | Warning symptoms or BP ≥ 160/100 → light movement only + ask doctor; otherwise goals sized from weekly minutes. | ADA 2026 §5 pre-exercise risk (S104), recs 5.34–5.36; ACC/AHA 2017 §6.2 rec 5, Table 15 |
| R5 | BP ≥ 180/120 → emergency alert (safety engine). | ACC/AHA 2017 §11.2 (crisis > 180/120) |
| R6 | Upper-arm monitor → daily home BP; none/wrist → ask about a validated arm device. | ACC/AHA 2017 §4.2, Table 10; ADA 2026 rec 10.2 |
| R7 | Missed BP doses → medicine routine first; stopped → refer to doctor. | ACC/AHA 2017 §12.1 |
| R8 | ACE inhibitor/ARB/K-sparing diuretic or kidney disease → no potassium goal. | ACC/AHA 2017 §6.2 rec 4, Table 15 (potassium contraindications) |
| R9 | Heart disease / stroke → gentle activity; ask doctor. | ADA 2026 §5 pre-exercise risk (S104) |
| R10 | Pregnant → no plan; see doctor. | ACC/AHA 2017 §10.2.2 (pregnancy); ADA 2026 rec 10.12 |
| R11 | Tobacco/vape use → smoke-free goal. | ADA 2026 rec 5.40; ACC/AHA 2017 Table 5 |
| R12 | Short sleep (diabetes) → sleep routine goal; apnoea signs → ask doctor. | ADA 2026 recs 5.56–5.57; ACC/AHA 2017 §5.4.4, Table 5 (sleep apnoea) |
| R13 | The patient's chosen priorities come first. | ADA 2026 §4 person-centred collaborative care; ACC/AHA 2017 §12 |
| R14 | Age ≥ 65 / falls / joint pain → seated or chair-supported activity, balance practice, protein. | ADA 2026 recs 5.38, 13.2, 13.11b |
| R15 | Insulin/sulfonylurea or recent lows → carry glucose, check around exercise; glucose < 70 / < 54 safety alerts. | ADA 2026 §5 exercise & hypoglycemia (S105), recs 6.10, 6.15, 13.4 |
| R16 | Sugary drinks/juice → water-instead goal. | ADA 2026 recs 5.21, 5.25 |
| R17 | White bread/rice most meals → whole-grain / high-fibre goal. | ADA 2026 recs 5.14, 5.15, 5.24 |
| R18 | Eye disease → no vigorous/heavy exercise; numb feet/ulcer → daily foot check, proper shoes. | ADA 2026 §5 exercise with retinopathy / neuropathy (S107), recs 12.30–12.31 |
| R19 | Glucose meter/CGM → daily glucose log goal. | ADA 2026 recs 6.1–6.3, Table 6.3 |
| R20 | Plans to fast Ramadan → plan with care team well before. | ADA 2026 recs 5.32–5.33 |
| R21 | Feeling down/overwhelmed (diabetes) → tell your care team. | ADA 2026 recs 5.42–5.48 |
| R22 | Long sitting (diabetes) → move every 30 minutes. | ADA 2026 rec 5.34 (break up sitting every 30 min) |

## The questions

### About you · عنك

**Q1. Which condition do you have?**  
ما الحالة التي لديك؟  
*Answers:* High blood pressure / Diabetes / Both  
*Source:* ACC/AHA 2017 (hypertension); ADA Standards of Care 2026 (diabetes); ACC/AHA §9.6 (hypertension with diabetes).  
*Decides:* Chooses which guideline rules and knowledge are used (R1–R22).

**Q2. What should we call you?**  
بماذا نناديك؟  
*Source:* Not clinical (personalisation only).  
*Decides:* Greeting only.

**Q3. How old are you?**  
كم عمرك؟  
*Source:* ADA 2026 Section 13 (older adults ≥ 65: recs 13.2, 13.11a–b) and rec 5.38 (balance training).  
*Decides:* Age ≥ 65 → balance/flexibility and protein goals; smaller start (R14).

**Q4. Are you a man or a woman?**  
هل أنت رجل أم امرأة؟  
*Answers:* Man / Woman  
*Source:* ACC/AHA 2017 §10.2.2 (pregnancy); ADA 2026 rec 10.12.  
*Decides:* Shows the pregnancy question (R10).

**Q5. Are you pregnant, or planning a pregnancy?** *(asked only when relevant)*  
هل أنتِ حامل أو تخططين للحمل؟  
*Answers:* Yes / No / Not sure  
*Source:* ACC/AHA 2017 §10.2.2 (ACE inhibitors/ARBs must not be used in pregnancy; switch medicines); ADA 2026 rec 10.12.  
*Decides:* Yes → no lifestyle plan; she is referred to her doctor (R10).

**Q6. Your weight and height**  
وزنك وطولك  
*Source:* ACC/AHA 2017 §6.2 rec 1 and Table 15 (weight loss, ~1 mmHg per kg); ADA 2026 rec 5.12 (5–7% weight loss).  
*Decides:* BMI ≥ 25 → weight goal: ≥ 1 kg (hypertension) or 5–7% (diabetes) (R1).

### Your blood pressure · ضغط دمك

**Q7. What is your blood pressure usually?** *(hypertension only)*  
كم يكون ضغطك عادةً؟  
*Source:* ACC/AHA 2017 Table 6 (BP categories), §11.2 (crisis > 180/120), §9.6 and ADA 2026 rec 10.4 (goal < 130/80 with diabetes); ADA 2026 S104 (inadequately managed hypertension before exercise).  
*Decides:* ≥ 180/120 → emergency alert (R5); ≥ 160/100 → light activity only + ask doctor (R4); ≥ 130/80 → daily home readings (R6).

**Q8. Do you have a blood pressure monitor at home?** *(hypertension only)*  
هل لديك جهاز ضغط في البيت؟  
*Answers:* Yes, with an arm cuff / Yes, on the wrist / No  
*Source:* ACC/AHA 2017 §4.2 and Table 10 (HBPM with automated validated devices); ADA 2026 rec 10.2.  
*Decides:* Arm cuff → daily home reading goal; wrist/none → ask about a validated arm monitor (R6).

**Q9. Which blood pressure medicines do you take?** *(hypertension only)*  
ما أدوية الضغط التي تأخذها؟  
*Answers:* Amlodipine / Losartan / Valsartan / Lisinopril / Perindopril / Hydrochlorothiazide / Indapamide / Bisoprolol  
*Source:* ACC/AHA 2017 §6.2 rec 4 and Table 15 (potassium: caution with drugs that reduce potassium excretion); §12.1 (adherence).  
*Decides:* ACE inhibitor/ARB → no potassium goal (R8); any BP medicine → medicine routine and refill goals (R7).

**Q10. In the last 7 days, did you miss any BP medicine?** *(hypertension only)*  
في آخر 7 أيام، هل نسيت أي جرعة من دواء الضغط؟  
*Answers:* No, I took them all / Yes, 1 or 2 times / Yes, 3 times or more / I stopped taking them  
*Source:* ACC/AHA 2017 §12.1 (non-adherence is a major cause of poor BP control) and §12.1.1.  
*Decides:* Missed → medicine routine is the first daily goal; stopped → see your doctor, no medicine goals (R7).

### Your diabetes · السكري لديك

**Q11. What type of diabetes do you have?** *(diabetes only)*  
ما نوع السكري لديك؟  
*Answers:* Type 2 / Type 1 / I'm not sure  
*Source:* ADA 2026 Section 2 (classification) and rec 5.36 (activity grades differ for type 1 and type 2).  
*Decides:* Recorded for the doctor report and for the AI's wording (no separate rule).

**Q12. Which diabetes medicines do you use?** *(diabetes only)*  
ما أدوية السكري التي تستخدمها؟  
*Answers:* Insulin injections / Gliclazide / glimepiride (sulfonylurea) / Metformin / Weekly injection (e.g. semaglutide) / Empagliflozin / dapagliflozin / Other  
*Source:* ADA 2026 Section 5 (exercise & hypoglycemia with insulin or insulin secretagogues, S105), recs 6.6, 13.4, 5.28.  
*Decides:* Insulin or sulfonylurea → low-sugar safety goals (carry glucose, check around exercise) (R15).

**Q13. In the last 3 months, did you have low blood sugar (shaky, sweaty, under 70)?** *(diabetes only)*  
في آخر 3 أشهر، هل حدث لك انخفاض في السكر (رجفة، تعرق، أقل من 70)؟  
*Answers:* No / Once or twice / Often / Yes, I needed help from someone  
*Source:* ADA 2026 rec 6.10 (review hypoglycemia history at every encounter), Table 6.4 (levels: < 70, < 54, severe), rec 6.15.  
*Decides:* Any → low-sugar safety goals (R15); needed help → 'tell your doctor' alert.

**Q14. How do you check your blood sugar?** *(diabetes only)*  
كيف تقيس السكر؟  
*Answers:* Finger-prick meter / Sensor on my arm (CGM) / I don't check at home  
*Source:* ADA 2026 recs 6.1–6.2 (assessing glycemic status) and Section 7 (blood glucose monitoring, CGM); rec 6.14.  
*Decides:* Meter/CGM → daily glucose log goal (R19); none → A1C goal only.

**Q15. Has your doctor told you about any of these?** *(diabetes only)*  
هل أخبرك طبيبك بأي مما يلي؟  
*Answers:* Diabetes affecting my eyes / Numb, tingling or burning feet / A foot wound or ulcer (now or before)  
*Source:* ADA 2026 Section 5 (exercise with retinopathy / peripheral neuropathy, S104–S107); recs 12.26, 12.30, 12.31.  
*Decides:* Eye disease → no vigorous/heavy exercise; numb feet/ulcer → daily foot check, proper shoes, low-impact activity (R18).

**Q16. Do you plan to fast in Ramadan?** *(diabetes only)*  
هل تنوي صيام رمضان؟  
*Answers:* Yes / Not sure / No  
*Source:* ADA 2026 recs 5.32 (IDF-DAR pre-fasting risk assessment) and 5.33 (adjust treatment well in advance).  
*Decides:* Yes/not sure → 'plan fasting with your care team' goal (R20).

### Your health and safety · صحتك وسلامتك

**Q17. Do you have any of these conditions?**  
هل لديك أي من هذه الأمراض؟  
*Answers:* Kidney disease / Heart disease or heart failure / Previous stroke / High cholesterol  
*Source:* ACC/AHA 2017 §6.2 rec 4 (potassium contraindicated in CKD), Table 5; ADA 2026 S104 (higher-risk people start with low-intensity exercise).  
*Decides:* Kidney disease → no potassium goal, fluid caution (R8); heart disease/stroke → gentle activity, ask doctor (R9).

**Q18. Do any of these happen to you?**  
هل يحدث لك أي مما يلي؟  
*Answers:* Chest pain, or I can do less exercise than before / Dizziness when I stand up, or fainting / My doctor said to exercise only with supervision  
*Source:* ADA 2026 Section 5 'Pre-exercise Risk' (S104): reduced exercise tolerance, orthostatic hypotension and other conditions need assessment first; ACC/AHA 2017 §11.2 (chest pain as a warning sign).  
*Decides:* Any yes → light movement only + 'check with your doctor before more exercise' (R4).

**Q19. Do any of these apply to you?**  
هل ينطبق عليك أي مما يلي؟  
*Answers:* I fell in the past year / I feel unsteady when I walk / I use a cane or walker / Knee, hip or back pain when I move  
*Source:* ADA 2026 rec 13.2 (screen older adults for falls and persistent pain), rec 5.38 (balance training), S104 (balance impairment).  
*Decides:* Falls/balance/joint pain → seated or chair-supported activity with balance practice (R14).

### Moving · الحركة

**Q20. In a usual week, on how many days do you walk briskly or exercise for at least 10 minutes?**  
في أسبوع عادي، كم يومًا تمشي بنشاط أو تمارس الرياضة 10 دقائق على الأقل؟  
*Answers:* 0 days / 1–2 days / 3–4 days / 5 days or more  
*Source:* ADA 2026 rec 5.34 (evaluate baseline physical activity) and 5.36 (≥ 150 min/week over ≥ 3 days); ACC/AHA 2017 Table 15 (aerobic 90–150 min/week).  
*Decides:* Weekly minutes = days × minutes; below goal → activity goal a little above current level (R4).

**Q21. On those days, for how long?** *(asked only when relevant)*  
في تلك الأيام، لكم من الوقت؟  
*Answers:* About 10 minutes / About 20 minutes / 30 minutes or more  
*Source:* ADA 2026 rec 5.34 (baseline activity); ACC/AHA 2017 Table 15.  
*Decides:* Weekly activity minutes (R4).

**Q22. On a usual day, how many hours do you spend sitting?** *(diabetes only)*  
في يوم عادي، كم ساعة تقضيها جالسًا؟  
*Answers:* Less than 4 hours / 4 to 8 hours / More than 8 hours  
*Source:* ADA 2026 rec 5.34 (evaluate sedentary time; interrupt sitting at least every 30 min).  
*Decides:* Long sitting → 'move every 30 minutes' goal (R22).

### Food and drinks · الأكل والمشروبات

**Q23. On a usual day, how many servings of vegetables and fruit do you eat?**  
في يوم عادي، كم حصة من الخضار والفواكه تأكل؟  
*Answers:* None / 1–2 / 3–4 / 5 or more  
*Source:* ACC/AHA 2017 §6.2 rec 2, Table 15 (DASH: rich in fruits and vegetables); ADA 2026 rec 5.14 (non-starchy vegetables, whole fruits).  
*Decides:* Few servings → daily vegetables goal (R3).

**Q24. How often is your bread or rice white (not whole grain)?**  
كم مرة يكون خبزك أو أرزك أبيض (غير أسمر)؟  
*Answers:* Always / Often / Sometimes / Rarely / Never  
*Source:* ADA 2026 recs 5.14, 5.24 (high-fibre, minimally processed carbohydrates); ACC/AHA 2017 Table 15 (DASH: whole grains).  
*Decides:* Always/often → whole-grain / high-fibre goal (R17).

**Q25. How often do you drink juice, soft drinks or sweetened tea/coffee?**  
كم مرة تشرب العصير أو المشروبات الغازية أو الشاي/القهوة المحلّاة؟  
*Answers:* Always / Often / Sometimes / Rarely / Never  
*Source:* ADA 2026 recs 5.21 (choose water) and 5.25 (replace sugar-sweetened beverages, including juices).  
*Decides:* Sometimes or more → 'water instead' goal (R16).

**Q26. How often do you add salt to your food at the table?**  
كم مرة تضيف الملح إلى طعامك على السفرة؟  
*Answers:* Always / Often / Sometimes / Rarely / Never  
*Source:* ACC/AHA 2017 §6.2 rec 3, Table 15 (sodium < 1500 mg/day or ≥ 1000 mg reduction); ADA 2026 rec 5.20 (< 2300 mg/day).  
*Decides:* Always/often → 'no salt shaker' goal (R2).

**Q27. How often are salt, stock cubes or seasoning powder added when cooking at home?**  
كم مرة يُضاف الملح أو مكعب المرق أو البهارات المملحة عند الطبخ في البيت؟  
*Answers:* Always / Often / Sometimes / Rarely / Never  
*Source:* ACC/AHA 2017 §6.2 rec 3, Table 15; ADA 2026 rec 5.20 (limit processed foods to lower sodium).  
*Decides:* Always/often → stock-cube cooking goal (R2).

**Q28. How often do you eat salty or processed foods (white cheese, pickles, chips, fast food)?**  
كم مرة تأكل أطعمة مالحة أو مصنّعة (جبن أبيض، مخللات، شيبس، وجبات سريعة)؟  
*Answers:* Always / Often / Sometimes / Rarely / Never  
*Source:* ADA 2026 rec 5.20 and 5.14 (minimise processed and ultra-processed foods); ACC/AHA 2017 Table 15.  
*Decides:* Always/often → salty-food swap goals (R2).

### Smoking, sleep and mood · التدخين والنوم والمزاج

**Q29. Do you smoke or vape (cigarettes, shisha, e-cigarettes)?**  
هل تدخن (سجائر، شيشة، سجائر إلكترونية)؟  
*Answers:* Yes, every day / Yes, sometimes / I quit / Never  
*Source:* ADA 2026 rec 5.40 (ask routinely about tobacco or vape use; advise complete avoidance); ACC/AHA 2017 Table 5 (smoking as a modifiable CVD risk factor).  
*Decides:* Current use → smoke-free goal (R11).

**Q30. How many hours do you usually sleep at night?**  
كم ساعة تنام عادةً في الليل؟  
*Answers:* Less than 5 / 5 to 6 / 7 to 9 / More than 9  
*Source:* ADA 2026 recs 5.56 (screen for sleep health) and 5.57 (sleep-promoting routines).  
*Decides:* Short sleep (with diabetes) → sleep-routine goal (R12).

**Q31. Do any of these happen to you?**  
هل يحدث لك أي مما يلي؟  
*Answers:* I snore loudly / I often feel sleepy in the day / Someone saw me stop breathing in sleep  
*Source:* ACC/AHA 2017 §5.4.4 and Table 5 (obstructive sleep apnoea); ADA 2026 rec 5.56 (screen for sleep disorders).  
*Decides:* Possible sleep apnoea → 'ask your doctor' note on plan and doctor report; not a diagnosis (R12).

**Q32. In the last 2 weeks, have you felt down or overwhelmed by your diabetes?** *(diabetes only)*  
في آخر أسبوعين، هل شعرت بالإحباط أو الإرهاق بسبب السكري؟  
*Answers:* No / Sometimes / Often  
*Source:* ADA 2026 recs 5.42–5.48 (psychosocial care; screen for diabetes distress, anxiety, depression). Single question, not a validated screening tool.  
*Decides:* Sometimes/often → 'tell your care team' note (R21); not a diagnosis.

### Your goals · أهدافك

**Q33. What would you like to work on first?**  
ما الذي تريد أن تبدأ به؟  
*Answers:* Eating less salt / Less sugar and sweet drinks / Eating healthier / Moving more / Losing weight / Remembering medicines / Quitting smoking / Sleeping better  
*Source:* ADA 2026 Section 4 (person-centred collaborative care; shared goal setting) and rec 5.1 (DSMES); ACC/AHA 2017 §12 (team-based, patient-centred care).  
*Decides:* Chosen areas come first in the plan (R13). Safety rules still apply.
