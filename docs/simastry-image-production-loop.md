# Simastry Image Model 2 Production Loop

This workflow supports two production paths for the first Simastry expert image set:

- ChatGPT Pro app loop: uses your existing logged-in ChatGPT subscription and does not require an API key.
- API loop: uses the bundled GPT Image CLI and requires `OPENAI_API_KEY`.

Both paths start with the five canonical expert portraits, then use those approved portraits as references for alternates, avatars, and council key art.

## ChatGPT Pro App Loop

Use this route when you want to generate through the ChatGPT Mac app with your Pro subscription.

```bash
scripts/copy-simastry-chatgpt-prompt.sh leyla-hero
```

The script copies the selected prompt to the macOS clipboard and opens ChatGPT. Paste/send the prompt in ChatGPT, then save the generated PNG under:

```text
output/imagegen/simastry-experts/leyla-western-hero.png
```

Recommended run order:

```bash
scripts/copy-simastry-chatgpt-prompt.sh leyla-hero
scripts/copy-simastry-chatgpt-prompt.sh listening
scripts/copy-simastry-chatgpt-prompt.sh chart
scripts/copy-simastry-chatgpt-prompt.sh smile
scripts/copy-simastry-chatgpt-prompt.sh avatar
```

Repeat the same pattern in a new ChatGPT chat for:

- `mateo-hero`
- `naomi-hero`
- `soren-hero`
- `nadia-hero`

Keep each expert's alternates in the same ChatGPT thread as their hero and use the expected filenames:

- `<expert-slug>-listening.png`
- `<expert-slug>-chart.png`
- `<expert-slug>-smile.png`
- `<expert-slug>-avatar.png`

After all five hero portraits are saved, start a new ChatGPT chat, attach the five hero PNGs, then run:

```bash
scripts/copy-simastry-chatgpt-prompt.sh council
```

Save the result as:

```text
output/imagegen/simastry-experts/council-key-art-16x9.png
```

Use this optional validation command once all files are saved:

```bash
scripts/run-simastry-image-loop.sh validate
```

Then stage the portrait replacements for Claude:

```bash
scripts/stage-simastry-images-for-assets.sh
```

This creates:

```text
ExternalAssets/simastry-expert-asset-handoff/
```

The staged folder mirrors the legacy Factory imageset names Claude should replace in `App/Assets.xcassets`.

Portrait handoff mapping:

- Leyla -> `Factory_virgo-mara_*`
- Mateo -> `Factory_libra-mateo_*`
- Naomi -> `Factory_capricorn-naomi_*`
- Soren -> `Factory_aries-cassian_*`
- Nadia -> `Factory_sagittarius-nadia_*`

Per expert, the generated avatar becomes `profile`, the hero becomes `card`, and the hero/listening/chart/smile set is cycled through `post1` through `post10` so every existing Factory imageset has a replacement image.

## API Loop

## Prerequisites

- Set `OPENAI_API_KEY` in the local shell before live runs.
- Use the bundled CLI at `${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/image_gen.py`.
- Run commands from the repository root.

The wrapper intentionally calls the bundled CLI instead of a custom SDK runner.

## Run Order

```bash
scripts/run-simastry-image-loop.sh heroes
```

Inspect the five hero images in `output/imagegen/simastry-experts/`:

- `leyla-western-hero.png`
- `mateo-vedic-hero.png`
- `naomi-chinese-hero.png`
- `soren-ancient-hero.png`
- `nadia-evolutionary-hero.png`

If those are approved, continue:

```bash
scripts/run-simastry-image-loop.sh variants
scripts/run-simastry-image-loop.sh council
scripts/run-simastry-image-loop.sh validate
```

Use `--dry-run` with `heroes`, `variants`, or `council` to inspect the API payloads without making image calls. The `variants` and `council` dry runs still require the referenced hero files to exist because the underlying CLI validates image inputs.

## Output Contract

Final assets are written to `output/imagegen/simastry-experts/`.

Portraits and alternates are `2560x3200` PNGs. Avatars are `2048x2048` PNGs. Council key art is a `3840x2160` PNG.

## Visual QA

Check every selected asset for:

- no text or watermark
- no pastel zodiac clip-art, neon, fantasy costumes, tarot clutter, or plastic 3D render look
- natural anatomy and hands where visible
- coherent deep-black, champagne-gold, celestial-blue, and muted-violet visual language
- identity consistency across each expert's hero, alternates, and avatar
- five distinct specialists in the council image

After approval, run the staging script and let Claude handle imageset replacement, landing background swap, and the emblem set integration.
