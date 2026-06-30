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
