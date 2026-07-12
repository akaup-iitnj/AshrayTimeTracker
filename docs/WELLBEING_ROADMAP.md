# Personal wellbeing roadmap

## Product direction

Time Tracker can become a private pattern-finding journal, but it should describe correlations rather than claim to diagnose mood or prove causes. The useful question is: "What tends to be different before my lower-scoring days?"

The first foundation is now:

- One daily check-in with mood, energy, and calm scores from 1–5.
- A long-form daily reflection field that can hold typed text or a pasted transcript.
- Cross-device Supabase sync and dashboard/MCP exposure for those records.
- A configurable Android morning reminder that opens two saved YouTube videos.

## Sleep data recommendation

Use Android Health Connect first.

Samsung Health can synchronize Galaxy Watch sleep sessions and sleep stages to Health Connect. Time Tracker can then request read-only sleep permission and import `SleepSessionRecord` data with the user's explicit consent. This route is Android-standard, supports other watch ecosystems whose apps write to Health Connect, and avoids depending on a Samsung-only API.

Samsung also provides the Samsung Health Data SDK and it supports reading sleep data directly. It is a reasonable fallback if Health Connect omits a Samsung-specific metric, but publicly distributed apps must be registered through Samsung's partner process. The previous Samsung Health Android SDK was deprecated in July 2025.

Implementation sequence:

1. Add the official Android Health Connect dependency through a small Kotlin platform channel.
2. Request only `READ_SLEEP`, after a plain-language consent screen.
3. Import completed sleep sessions when the Android app opens or resumes.
4. Store nightly start, end, duration, and available stage totals locally and in Supabase.
5. Show the data source and last-import timestamp, and provide disconnect/delete controls.
6. Add heart rate or oxygen only if a specific user-facing insight genuinely needs it.

Before a public Play Store release, add a privacy policy, Health Apps declaration, Health Connect permission justification, and the required wellness/not-medical disclaimer.

## Voice reflection sequence

Voice should be built as a privacy-sensitive pipeline:

1. Record a short audio note locally.
2. Let the user review or delete it before upload.
3. Transcribe only after explicit opt-in. Prefer on-device transcription when quality is adequate; otherwise use an authenticated server function so no AI provider key ships in the app.
4. Save the transcript as the editable daily reflection.
5. Default to deleting the source audio after successful transcription, with an option to retain it.
6. Generate a short, user-editable summary and mood-language tags. Never silently overwrite the user's three scores.

## Pattern analysis

Do not start with an opaque "AI mood diagnosis." Start with transparent weekly observations that require enough data:

- Seven-day averages and changes for mood, energy, calm, sleep duration, and category hours.
- Plain correlations such as "Your lower-energy days followed nights with less sleep in 5 of the last 7 cases."
- Sample counts and confidence labels.
- The ability to hide a factor, correct a score, or mark an observation as unhelpful.
- Supportive language and a clear statement that the app is for personal reflection, not medical diagnosis or crisis care.

Only introduce model-generated explanations after the deterministic summaries are trustworthy and the user can inspect the underlying days.
