# Expert Astrology Backend Contract

This is the backend contract for Claude's frontend handoff. Existing non-streaming calls to `companion-reply` still work and return JSON.

## Intake Persistence

Table: `public.expert_astrology_intake`

Use Supabase client calls under the signed-in user session. RLS restricts each user to their own row.

Required owner field:
- `user_id`: current authenticated user id

Supported intake fields:
- `birth_date`: `YYYY-MM-DD`
- `birth_time`: `HH:MM[:SS]`, omitted when unknown
- `birth_time_unknown`: `true` when the user says they do not know their birth time
- `birth_place`: user-supplied place text
- `partner_birth_date`: `YYYY-MM-DD`
- `partner_birth_time`: `HH:MM[:SS]`, omitted when unknown
- `partner_birth_time_unknown`: `true` when partner/person birth time is unknown
- `partner_birth_place`: user-supplied place text
- `user_supplied_tradition_data`: JSON object containing manual fields only

Allowed manual tradition-data labels:
- `vedic.nakshatra`
- `vedic.siderealMoonRashi`
- `bazi.dayMaster`
- `bazi.fourPillars`
- `hellenistic.sect`
- `hellenistic.profectionYear`
- `evolutionary.relationshipPatternNotes`
- `evolutionary.reflectionPrompts`

Manual fields are user-supplied only. They are not app-calculated and should be labeled that way in UI.

## Intake Operations

Upsert:
```swift
try await client
    .from("expert_astrology_intake")
    .upsert(record, onConflict: "user_id")
    .execute()
```

Select:
```swift
let response: [ExpertAstrologyIntakeRecord] = try await client
    .from("expert_astrology_intake")
    .select()
    .eq("user_id", value: userId.uuidString)
    .limit(1)
    .execute()
    .value
```

Delete:
```swift
try await client
    .from("expert_astrology_intake")
    .delete()
    .eq("user_id", value: userId.uuidString)
    .execute()
```

## Reply Streaming

Endpoint: `POST /functions/v1/companion-reply`

Opt in with either:
- request header `Accept: text/event-stream`
- JSON body field `"stream": true`

SSE events:
- `meta`: `{ "usageEventId": "...", "specialistId": "mateo-vedic", "mode": "individual" }`
- `delta`: `{ "text": "partial assistant text" }`
- `done`: `{ "text": "complete assistant text", "usageEventId": "..." }`
- `error`: `{ "code": "provider_unavailable", "message": "..." }`

Only assistant text deltas are streamed. The backend does not stream prompts, hidden reasoning, chain-of-thought, or provider metadata.

## Prompt Hydration Rules

When an expert astrologer request arrives, the Edge Function reads the current user's intake row and merges it into prompt context.

The backend may pass through:
- user-supplied birth date/time/place availability and values
- birth time unknown flags
- whitelisted manual tradition fields

The backend must not calculate or infer:
- placements
- dashas
- BaZi pillars
- sect
- Lots
- aspects
- houses
- transits
- timing periods
- compatibility charts

Existing JSON response shape remains:
```json
{ "text": "...", "usageEventId": "..." }
```

## Chart Screenshot Import Foundation

This backend supports a future "upload chart screenshot" flow for both the
signed-in user and saved people. It does not perform chart calculation.
Uploaded images and extracted fields are intake aids only.

Private storage bucket:
- `expert-astrology-charts`
- allowed MIME types: JPEG, PNG, WebP, HEIC, HEIF
- max file size: 10 MB
- storage path must start with the authenticated user id:
  - self example: `{user_id}/self/{chart_import_id}.jpg`
  - person example: `{user_id}/people/{person_id}/{chart_import_id}.jpg`

Chart import table: `public.expert_astrology_chart_imports`
- `id`
- `user_id`
- `subject_type`: `self` or `person`
- `person_id`: required only when `subject_type = person`
- `storage_bucket`: always `expert-astrology-charts`
- `storage_path`
- `status`: `uploaded`, `extracted`, `needs_review`, `confirmed`, or `failed`
- `extracted_data`: machine/vision output awaiting review
- `confirmed_data`: user-confirmed extracted/manual fields
- `extraction_warnings`: array of warning strings
- `source_label`: optional source label such as `Astro-Seek screenshot`

Important rule:
- `extracted_data` must not be used as chart fact.
- Only `confirmed_data` may be passed into prompts.
- Even confirmed upload data is treated as user-supplied/extracted, not
  app-calculated.

Per-person intake table: `public.expert_person_astrology_intake`
- `user_id`
- `person_id`
- `display_name`
- `birth_date`
- `birth_time`
- `birth_time_unknown`
- `birth_place`
- `user_supplied_tradition_data`
- `chart_import_id`

Allowed confirmed upload labels:
- `western.sunSign`
- `western.moonSign`
- `western.risingSign`
- `western.venusSign`
- `western.marsSign`
- `western.houses`
- `western.aspects`
- all manual tradition labels listed above

Prompt hydration:
- Self intake still comes from `expert_astrology_intake`.
- If the request includes `selectedPersonId`, the backend reads
  `expert_person_astrology_intake` for that person and maps it to
  partner/person prompt context.
- The backend also reads the latest self/person chart import.
- Confirmed upload data is labeled under prompt-safe keys such as
  `uploadedChart.western.sunSign` or `person.uploadedChart.bazi.dayMaster`.
- Unconfirmed upload data becomes a data limitation only.

Future frontend should show a confirmation screen before moving extracted fields
from `extracted_data` into `confirmed_data`.
