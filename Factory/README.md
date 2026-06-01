# Factory

Factory is a Simastry subproject for preparing and tracking the 3,456 companion assets:

- 1,728 Sun/Moon/Rising combinations
- male and female versions of each
- a Starter 24 phase for female and male hero companions for each zodiac sign
- a style-board upload area for visual references
- local folders for every companion
- a SQLite database as the source of truth
- browser dashboard for prompt batches, imports, review, and status

The factory does not automate image generation or bypass account limits. It prepares controlled batches and gives you a place to import generated files.

## ChatGPT Visual Production App

The internal ChatGPT app lives in:

```text
chatgpt-apps/companion-image-factory/
```

It guides teammates through realistic, emotionally magnetic companion image production and logs sessions back into Factory. The app does not generate images through an API or bypass ChatGPT account limits. Teammates use ChatGPT Images directly, then record prompt drafts, generated candidates, and review decisions in Factory.

Factory stores that work in SQLite and mirrors session artifacts to:

```text
workspace/visual-production/
```

## Start

```bash
python3 server.py --seed --port 8765
```

Then open:

```text
http://127.0.0.1:8765
```

## Mac Icon

Use `Factory.app` as the Mac launcher. It starts the local Factory server if needed and opens the dashboard.

To pin it:

1. Open this folder in Finder.
2. Drag `Factory.app` into the Dock.
3. Click `Factory` whenever you want to open the dashboard.

When `Factory` is running, the local dashboard server stays alive. Quit `Factory` from the Dock when you want to stop it.

## Local Workspace

Generated data lives in `workspace/`, which is ignored by git:

```text
workspace/
  simastry_assets.sqlite
  companions/
    0001__ada-marlowe__female__aries-sun_aries-moon_aries-rising/
      manifest.json
      references/
        identity/
      prompts/
      card/
      astrogram/
        profile/
        photos/
        videos/
      messages/
      review/
  batches/
  imports/
  cloud-drop/
    delegate-1/
    delegate-2/
  app-sync/
  daily-tasks/
  linear/
  references/
    style-board/
```

## Batch Workflow

1. Upload realistic dating-app or Instagram-style references into `Style references`.
2. Keep the dashboard scope on `Starter 24`.
3. Create a `10-photo same-person pack` batch of 24.
4. Use `workspace/batches/<batch-id>/prompt_sheet.md` as the daily GPT generation queue.
5. Ask GPT Image 2 to generate 10 individual images for each companion prompt.
6. Save finished files into the assigned cloud folder or `workspace/imports/<companion-id>/`.
7. Press `Scan folders` in the dashboard.
8. Review and approve the first 24 before expanding to the full catalog.

Import scanning copies files into the correct companion folder. It does not delete your import files.

## Image Realism Standard

Factory outputs should look like iPhone pictures of real people on Instagram, not AI-generated fashion editorials.

Default direction:

- casual phone-photo realism
- available light instead of cinematic lighting
- slightly imperfect framing, angle, focus, and exposure
- normal skin texture, pores, asymmetry, stray hair, and natural expressions
- believable outfits and locations a real person would post
- dating-app and Instagram energy, not model portfolio energy
- meaningful variation across the set: different poses, camera distances, angles, expressions, settings, outfits, and body crops
- meaningful wardrobe variation across a pack: do not repeat the same jacket, top color, silhouette, or outfit formula across most images; if one signature item appears, use it sparingly and rotate into different colors, layers, materials, and levels of polish

Avoid:

- airbrushed or plastic skin
- perfect symmetry or generic model faces
- high-fashion editorial poses unless explicitly requested
- fantasy styling, overproduced lighting, and hyper-polished cinematic cards
- anything that reads like an AI influencer
- repeated same-angle selfies or near-duplicate poses across a 10-photo pack
- repeated same-color tops or one recognizable hero jacket across most of a companion's pack

## Female Portrait Standard

For female companion portraits, keep the visual bar consistent across Factory prompts:

- early twenties only
- extremely attractive, while still realistic and believable as a real person
- long hair only; no shaved heads, buzz cuts, pixies, bobs, or short hair
- no African visual direction unless the founder explicitly assigns that companion to African descent; Ada is now explicitly assigned to African descent
- preserve the companion's sign lane through styling, setting, posture, expression, and emotional temperature rather than making her older, severe, or costume-like
- use real social-photo beauty, not fashion-editorial polish or AI-influencer perfection

## Male Portrait Standard

For male companion portraits, keep the visual bar consistent across Factory prompts:

- early thirties by default
- very attractive, while still realistic and believable as a real person
- fit face and fit body; healthy, athletic, and well-kept rather than average or soft
- stylish hair, strong grooming, clear jaw/cheek structure, and confident posture
- modern, tasteful styling that feels social-media attractive without becoming a fashion editorial
- preserve the companion's sign lane through setting, expression, posture, and emotional temperature rather than making him generic, plain, or stiff
- use real social-photo attractiveness, not psychic-ad polish, AI-influencer perfection, or corporate headshot styling

## Cast Distinction Standard

The Starter 24 must read as 24 different real people, not one model family with styling changes.

For every companion prompt and review:

- vary face structure, race/ethnic visual direction, age read, hair, body type, posture, wardrobe, setting, and emotional temperature
- keep one male and one female companion per zodiac sign
- preserve each companion's own identity across their photo pack
- check every new image against approved app characters before accepting it
- reject images that resemble Nadia, Ada, Leona, Zev, or any other approved character unless that companion is the intended identity
- use the companion's forbidden-overlap notes from `expo-prototype/CAST_BIBLE.md` when available
- do not generate multiple companions as the same warm brunette cafe/travel archetype
- treat Mara, Isolde, Mila, Nadia, and Leona as a high-risk visual-overlap cluster; future companions of any gender must separate harder at thumbnail size through face structure, hair shape/color, ethnic visual direction, posture, setting, and emotional temperature
- apply the same separation standard to men: avoid repeated dark-haired brooding handsome archetypes, repeated jaw/cheek structure, repeated leather-jacket formulas, and repeated rooftop/nightlife emotional lanes
- add more blonde men and blonde women across future companions when identity references allow it; do not override an already-approved dark-haired identity just to make a companion blonde

The goal is not generic diversity. The goal is a cast where each person feels specific enough to remember after one screen.

## Delegates

The Starter 24 are marked as existing characters. Female starters are initially assigned to `Delegate 1`; male starters are initially assigned to `Delegate 2`. You can change the delegate name, Slack handle or channel, target picture count, cloud folder, and character brief from each companion detail panel.

Use `Upload character references` inside a companion detail panel when you already have that person's identity. Those images live in that companion's `references/identity/` folder and are included in future prompt sheets.

`Draft Slack updates` creates local Slack-ready task drafts and prompt files in:

```text
workspace/daily-tasks/<date>/
```

`Push Slack assignments` posts those daily task packets to the assigned Slack user or channel when `SLACK_BOT_TOKEN` is configured. `Monitor Slack` checks posted assignment threads for worker replies and marks the assignment as `in_progress` or `worker_reported_done` when replies include completion language like "done", "complete", "uploaded", or "finished".

Slack setup:

```bash
export SLACK_BOT_TOKEN=xoxb-your-token
python3 server.py --port 8765
```

Delegate Slack targets can be a Slack channel ID, user ID, `#channel`, `@user`, or a Slack mention copied from Slack. Factory stores posted assignment metadata in SQLite so the dashboard can track message status and latest worker replies.

## Simastry Apps And Linear

`Sync Simastry apps` scans the local website and Expo prototype to identify the app-facing zodiac characters that already exist. Those characters are matched back to the Starter 24 by sign and saved in:

```text
workspace/app-sync/app_characters.json
```

The Swift iOS app currently creates companions dynamically through Supabase, so Factory treats the website and Expo cast as the fixed existing-character source.

`Build Linear plan` creates local Linear-ready issue drafts in:

```text
workspace/linear/<date>/
```

Factory does not post to Linear automatically. The drafts are meant to become production tickets once a Linear API key or manual import workflow is approved.
