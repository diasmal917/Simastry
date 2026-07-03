# Simastry Specialist Improvement Workflow

## Principle

Production specialists do not self-modify.

All improvements are:

- eval-driven
- human-reviewed
- versioned
- tested
- deployed intentionally

The live app must never let a user conversation rewrite a specialist harness, prompt, memory, or future behavior automatically.

## Workflow

1. Collect feedback or observe a failure.
2. Convert the failure into an eval case.
3. Run specialist evals with `npm run eval:specialists`.
4. Confirm the failure reproduces.
5. Improve the relevant harness or prompt builder manually.
6. Run evals again.
7. Compare the report before and after.
8. Check that no other specialist regressed.
9. Update version metadata in `ai/specialists/specialistVersions.ts`.
10. Ship after review.

## Examples

Failure: Mateo answers a Mercury retrograde question like a Western astrologer.

Fix: Add an eval case, strengthen Mateo's Budha/Jyotish framing, then run evals.

Failure: Naomi interprets Scorpio compatibility.

Fix: Add an eval case, strengthen Naomi's boundary against Western signs, then run evals.

Failure: Leyla invents a Rising sign.

Fix: Add a missing-data eval, strengthen the prompt builder and Leyla harness, then run evals.

Failure: Everyone mode produces five similar answers.

Fix: Add a distinctiveness eval, strengthen individual harness voices, then check Everyone mode routing.

## Running Evals

Default command:

```sh
npm run eval:specialists
```

If `ANTHROPIC_API_KEY` is configured, the runner uses live Anthropic responses by default. Without a key, it uses fixture responses so deterministic checks, prompt wiring, file presence, version metadata, and report generation can still run locally.

Force fixture mode:

```sh
SIMASTRY_EVAL_RESPONSE_MODE=fixture npm run eval:specialists
```

Force live model mode:

```sh
SIMASTRY_EVAL_RESPONSE_MODE=anthropic npm run eval:specialists
```

Enable the optional AI judge:

```sh
SIMASTRY_EVAL_USE_AI_JUDGE=true npm run eval:specialists
```

Generated reports are written to `reports/specialist-evals/latest.json` and `reports/specialist-evals/latest.md`. They are ignored by git by default.

## Forbidden

Never allow a production agent to rewrite its own harness.

Never use user conversations to mutate future responses automatically.

Never log sensitive birth data unnecessarily.

Never ship harness changes without running evals.

Never collapse the five specialists into one general astrology prompt.
