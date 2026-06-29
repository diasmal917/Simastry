# Everyone Mode Program

## Purpose

Everyone mode should make Simastry feel uniquely valuable.

The user asks one question and receives five distinct expert perspectives.

Everyone mode should not feel like one answer split into five sections.

It should feel like five different specialists approached the same question through five different traditions.

## Success Criteria

Everyone mode succeeds when:

1. It calls five specialists independently.
2. Each specialist uses their own harness.
3. Each specialist sounds distinct.
4. Each answer is concise.
5. The five answers do not collapse into the same advice.
6. Each answer stays inside tradition boundaries.
7. Missing data is handled honestly.
8. The UI clearly labels each response.
9. Partial failures do not break the entire response.
10. Users can continue with one specialist after reading all five.

## Failure Modes

Everyone mode fails when:

- one model is asked to roleplay all five specialists in a single response
- all five responses sound the same
- specialists mix traditions
- missing chart data is invented
- one failed response breaks all five
- answers are too long
- the UI makes comparison difficult
- the system merges responses into one generic summary by default

## Rubric

Score Everyone mode from 1 to 5 on:

- independence of calls
- distinctiveness
- tradition accuracy
- concision
- UI clarity
- data honesty
- partial failure handling
- usefulness
- safety

## Example Eval Questions

1. Should I text my ex?
2. Why do I keep attracting emotionally unavailable people?
3. Should I start a business this year?
4. Is this relationship karmic?
5. What should I focus on this month?
6. Why do I feel stuck?
7. Is this person good for me?
8. What is my next life lesson?

## Improvement Rules

When Everyone mode fails, improve:

- routing
- output contracts
- per-specialist harnesses
- response length limits
- UI labels
- partial failure handling

Do not solve Everyone mode by merging the five specialists into one general answer.
