# Factory

Factory is a Simastry subproject for locking and producing the final 24 companion identities:

- 1,728 Sun/Moon/Rising combinations
- male and female versions of each
- a Starter 24 phase for female and male hero companions for each zodiac sign
- an identity-first Cast Studio for app-facing companions
- a Candidate Library for custom replacement identities
- a style-board area for reusable picture references and written style prompts
- local folders for approved images, candidates, references, and prompt packs
- a SQLite database as the source of truth
- browser dashboard for judging identities, starting Codex-assisted image jobs, uploading candidates, swapping approved slots, consolidating duplicates, and exporting app packages

The factory does not call an image API or bypass account limits. It prepares Codex-ready image jobs, tracks output folders, and gives you a place to import generated files.

## Main Workflow

The dashboard is now a casting studio for the final 24:

1. Review the `Cast Studio` board and lock identities before treating assets as complete.
2. Use casting states: `needs_decision`, `locked`, `needs_better_photos`, `replace_identity`, `consolidate_duplicate`, and `archived`.
3. Click a profile to manage its references, candidates, approved app slots, rejected images, archived versions, and prompt packs.
4. Use the red hover trash control to move a picture out of approved and into that character's rejected tab.
5. Upload generated candidates, promote them into app slots, or replace a slot directly with an upload.
6. Use `Candidate Library` to add custom replacement identities from one or more reference pictures.
7. Consolidate duplicate/custom candidates into the winning app-facing companion instead of deleting them.
8. Keep each final companion focused on the required app slots:
   - `profile_avatar`
   - `card_portrait`
   - `astrogram_01` through `astrogram_10`
9. Export an app package when locked identities and approved slots are ready.

Generation is Codex-assisted in this version. Use `Start 10 Astrogram Image Job` in Cast Studio, or `Add + start image job` in Candidate Library, to create the normal same-person, Instagram-like 10-photo job. Factory shows the full Codex prompt, the reference folder, and a dedicated output folder. After Codex saves images into that output folder, use `Refresh Job Results` to import them as candidates. This normal 10-photo job is separate from the Style Board.

Use `Generate style-board set` when you want one picture per style-board item. If the Style Board has 10 references, Factory creates 10 distinct prompt items: each one matches a single uploaded style picture or written style prompt rather than blending the whole board into one general style.

After importing generated candidates, rate each picture and add feedback notes. Future style-board prompt packs summarize high-rated outputs to reinforce and low-rated outputs to avoid.

Use `Import approved pictures` to pull already-approved portraits and Astrogram photos from the existing Factory review folders and Expo prototype assets into the managed character gallery. The import is safe to run repeatedly: it fills empty approved slots and does not overwrite slots that already have an approved picture. Bulk import focuses on visible app pictures; identity references can still be uploaded from each character detail page.

Factory does not write approved images directly into the Swift, Expo, or website asset folders in this version. Use `Export app package` to create a manifest, approved-image folder, missing-slot report, and casting-status report under:

```text
workspace/exports/app-assets/
```

Generation jobs are manual. They create prompt packs for ChatGPT Images / GPT Image 2 and track the work locally; they do not call an image API.

## Start

```bash
python3 server.py --seed --port 8765
```

Then open:

```text
http://127.0.0.1:8765
```

## iPhone / Mobile Web App

Factory can run as a mobile-friendly local web app from your Mac. Use this when you want to review, upload, reject, promote, and lock characters from your iPhone.

Start mobile mode on the Mac:

```bash
Factory/bin/launch-factory-mobile
```

The script opens Factory on the Mac and prints an iPhone URL like:

```text
http://192.168.1.23:8765/
```

Open that URL in Safari on the iPhone while the iPhone and Mac are on the same trusted Wi-Fi network. In Safari, use Share -> Add to Home Screen to make it feel like a small app.

Mobile mode binds Factory to the local network. Use it on trusted Wi-Fi only, and stop the server when you are done if you do not want other devices on the same network to see it.

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
  characters/
    char-custom-.../
      profile.json
      references/
      candidates/
      approved/
      generation-jobs/
      rejected/
  imports/
  exports/
    app-assets/
  references/
    style-board/
    style-prompts.json
```

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
