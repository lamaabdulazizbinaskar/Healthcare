/// Client-side mirror of backend/app/safety/red_flags.py so the emergency alert also fires
/// instantly and offline. Rule-based, never AI. KEEP THRESHOLDS IN SYNC WITH THE BACKEND.
library;

const int crisisSystolic = 180;
const int crisisDiastolic = 120;

const List<String> warningSymptoms = [
  'chest_pain',
  'severe_headache',
  'shortness_of_breath',
  'vision_changes',
  'weakness_numbness',
  'confusion_speech',
];

bool isEmergency({
  int? systolic,
  int? diastolic,
  List<String> symptoms = const [],
}) {
  final crisis =
      (systolic != null && systolic >= crisisSystolic) ||
      (diastolic != null && diastolic >= crisisDiastolic);
  return crisis || symptoms.any(warningSymptoms.contains);
}
