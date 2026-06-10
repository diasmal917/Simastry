#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import csv
import json
import mimetypes
import os
import re
import shutil
import sqlite3
import sys
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = ROOT.parent
STATIC_DIR = ROOT / "static"
WORKSPACE_DIR = ROOT / "workspace"
DB_PATH = WORKSPACE_DIR / "simastry_assets.sqlite"
COMPANIONS_DIR = WORKSPACE_DIR / "companions"
BATCHES_DIR = WORKSPACE_DIR / "batches"
IMPORTS_DIR = WORKSPACE_DIR / "imports"
REFERENCES_DIR = WORKSPACE_DIR / "references" / "style-board"
CLOUD_DROP_DIR = WORKSPACE_DIR / "cloud-drop"
DAILY_TASKS_DIR = WORKSPACE_DIR / "daily-tasks"
APP_SYNC_DIR = WORKSPACE_DIR / "app-sync"
LINEAR_DIR = WORKSPACE_DIR / "linear"
VISUAL_PRODUCTION_DIR = WORKSPACE_DIR / "visual-production"
SLACK_BOT_TOKEN = os.environ.get("SLACK_BOT_TOKEN", "").strip()

IMAGE_REALISM_STANDARD = (
    "Image realism standard: make outputs look like casual iPhone pictures of real people on Instagram, "
    "not AI-generated fashion editorials or model portfolio shots. Use available light, slightly imperfect "
    "framing, ordinary camera artifacts, normal skin texture, asymmetry, stray hair, natural expressions, "
    "and believable outfits and locations. Avoid airbrushed or plastic skin, perfect symmetry, generic model "
    "faces, cinematic overproduction, fantasy styling, and anything that reads like an AI influencer."
)

POSE_VARIATION_STANDARD = (
    "Pose variation standard: across any photo set, vary pose, camera distance, camera angle, crop, expression, "
    "setting, outfit, and body position. Include a mix of close portrait, mirror/selfie, three-quarter body, "
    "full-body or walking, seated/cafe, indoor candid, outdoor candid, low-light social, and profile/avatar crops. "
    "Do not repeat the same face angle, hand placement, background, outfit, or model pose across multiple images. "
    "Wardrobe variety is mandatory: do not use the same top color, same jacket, same silhouette, or same outfit "
    "formula across most of a pack. If a signature item appears, use it sparingly and rotate into different colors, "
    "layers, fabrics, and levels of polish."
)

CAST_DISTINCTION_STANDARD = (
    "Cast distinction standard: the Starter 24 must read as 24 different real people, not one model family with "
    "styling changes. Vary face structure, race or ethnic visual direction, age read, hair, body type, posture, "
    "wardrobe, setting, and emotional temperature. Reject any output that resembles another approved app companion "
    "unless that exact companion identity is intended. Do not generate multiple companions as the same warm brunette "
    "cafe or travel archetype; that lane belongs only to the companion explicitly assigned to it. Treat Mara, Isolde, "
    "Mila, Nadia, and Leona as a high-risk visual-overlap cluster; future companions of any gender must separate harder "
    "at thumbnail size through face structure, hair shape or color, ethnic visual direction, posture, setting, and emotional "
    "temperature. Apply the same standard to men: avoid repeated dark-haired brooding handsome archetypes, repeated jaw or "
    "cheek structure, repeated leather-jacket formulas, and repeated rooftop or nightlife emotional lanes. Add more blonde "
    "men and blonde women across future companions when identity references allow it, but do not override an already-approved "
    "dark-haired identity just to make a companion blonde."
)

FEMALE_PORTRAIT_STANDARD = (
    "Female portrait standard: for female companions, make her early twenties only and extremely attractive while "
    "still realistic and believable as a real person. Use long hair only; no shaved heads, buzz cuts, pixies, bobs, "
    "or short hair. Do not use African visual direction unless the founder explicitly assigns that companion to "
    "African descent; Ada is now explicitly assigned to African descent. Preserve the companion's sign lane through "
    "styling, setting, posture, expression, and emotional temperature instead of making her older, severe, "
    "costume-like, or editorial."
)

MALE_PORTRAIT_STANDARD = (
    "Male portrait standard: for male companions, make him early thirties by default and very attractive while still "
    "realistic and believable as a real person. Give him a fit face and fit body: healthy, athletic, well-kept, "
    "stylish, strong grooming, clear jaw and cheek structure, and confident posture. Use tasteful modern styling "
    "that feels social-media attractive without becoming a fashion editorial, psychic-ad polish, AI-influencer "
    "perfection, or a corporate headshot. Preserve the companion's sign lane through setting, expression, posture, "
    "and emotional temperature instead of making him generic, plain, average, soft, or stiff."
)

SIGNS = [
    "Aries",
    "Taurus",
    "Gemini",
    "Cancer",
    "Leo",
    "Virgo",
    "Libra",
    "Scorpio",
    "Sagittarius",
    "Capricorn",
    "Aquarius",
    "Pisces",
]

FEMALE_NAMES = [
    "Ada",
    "Alina",
    "Amara",
    "Anya",
    "Arden",
    "Astra",
    "Bianca",
    "Celine",
    "Clara",
    "Dahlia",
    "Elara",
    "Elise",
    "Freya",
    "Gia",
    "Helena",
    "Iris",
    "Isolde",
    "Juno",
    "Kaia",
    "Lena",
    "Leona",
    "Liora",
    "Mara",
    "Mila",
    "Nadia",
    "Noa",
    "Opal",
    "Rhea",
    "Selene",
    "Seren",
    "Sofia",
    "Talia",
    "Valen",
    "Vera",
    "Vesper",
    "Zara",
]

MALE_NAMES = [
    "Adrian",
    "Alaric",
    "Alden",
    "Arlo",
    "Atlas",
    "Bastien",
    "Callum",
    "Cassian",
    "Ciro",
    "Dante",
    "Dorian",
    "Elias",
    "Emil",
    "Ezra",
    "Felix",
    "Gideon",
    "Hugo",
    "Idris",
    "Jonas",
    "Kai",
    "Leo",
    "Lucian",
    "Milo",
    "Nico",
    "Orion",
    "Owen",
    "Rafael",
    "Remy",
    "Rhys",
    "Rowan",
    "Silas",
    "Soren",
    "Theo",
    "Valen",
    "Viktor",
    "Zev",
]

SURNAMES = [
    "Aster",
    "Bellamy",
    "Cairn",
    "Darrow",
    "Evers",
    "Vale",
    "Marin",
    "Solace",
    "Arden",
    "Voss",
    "Ren",
    "Hale",
    "Lumen",
    "Noctis",
    "Vey",
    "Marlowe",
    "Sable",
    "Kestrel",
    "Riven",
    "Thorne",
    "Calix",
    "Dusk",
    "Aurel",
    "Winters",
    "Cove",
    "Damaris",
    "Kairo",
    "Lark",
    "Mercer",
    "Nadir",
    "Oris",
    "Pallas",
    "Quill",
    "Rook",
    "Severin",
    "Tarin",
    "Umber",
    "Vireo",
    "Wynn",
    "Xanthe",
    "Yarrow",
    "Zephyr",
    "Ames",
    "Briar",
    "Cyra",
    "Draven",
    "Eden",
    "Frost",
]

SIGN_PROFILES = {
    "Aries": {
        "drive": "acts first, says the brave thing, and turns tension into motion",
        "need": "needs directness, heat, and proof that desire is alive",
        "front": "arrives with kinetic confidence and a sharp emotional spark",
        "visual": "ember light, red leather accents, clean athletic lines",
        "archetype": "The Spark",
    },
    "Taurus": {
        "drive": "chooses slowly, protects pleasure, and notices what feels real",
        "need": "needs consistency, sensual reassurance, and loyalty that can be felt",
        "front": "arrives steady, tactile, and quietly impossible to rush",
        "visual": "velvet shadows, garden texture, sculptural earth tones",
        "archetype": "The Anchor",
    },
    "Gemini": {
        "drive": "follows curiosity, tests every angle, and keeps the exchange alive",
        "need": "needs wit, variety, and room to change their mind out loud",
        "front": "arrives bright, quick, and socially electric",
        "visual": "glass reflections, editorial layers, silver-blue highlights",
        "archetype": "The Signal",
    },
    "Cancer": {
        "drive": "protects intimacy, reads the room, and remembers what mattered",
        "need": "needs emotional safety, tenderness, and a private rhythm",
        "front": "arrives soft, watchful, and quietly magnetic",
        "visual": "moonlit water, pearl fabric, warm domestic glow",
        "archetype": "The Keeper",
    },
    "Leo": {
        "drive": "leads with warmth, wants to be chosen, and turns affection into theatre",
        "need": "needs admiration, generosity, and a love that feels proud",
        "front": "arrives radiant, expressive, and unmistakably present",
        "visual": "gold rim light, stage shadows, regal tailoring",
        "archetype": "The Flame",
    },
    "Virgo": {
        "drive": "refines the messy thing, notices the pattern, and loves through usefulness",
        "need": "needs clarity, competence, and small proofs of care",
        "front": "arrives precise, composed, and observant",
        "visual": "linen, botanical detail, warm desk light, quiet structure",
        "archetype": "The Editor",
    },
    "Libra": {
        "drive": "seeks harmony, reads desire through aesthetics, and negotiates connection",
        "need": "needs grace, reciprocity, and a partner who can meet them halfway",
        "front": "arrives elegant, diplomatic, and socially attuned",
        "visual": "soft pink marble, balanced symmetry, museum light",
        "archetype": "The Muse",
    },
    "Scorpio": {
        "drive": "goes beneath the surface, tests loyalty, and transforms whatever is hidden",
        "need": "needs truth, depth, and the safety to be intense without apology",
        "front": "arrives private, penetrating, and emotionally charged",
        "visual": "black water, candlelight, oxblood silk, controlled shadow",
        "archetype": "The Depth",
    },
    "Sagittarius": {
        "drive": "chases meaning, expands the horizon, and says the honest thing",
        "need": "needs freedom, laughter, and a future big enough to move toward",
        "front": "arrives expansive, candid, and restless in the best way",
        "visual": "open roads, sunlit stone, travel-worn elegance",
        "archetype": "The Horizon",
    },
    "Capricorn": {
        "drive": "builds what lasts, respects effort, and turns ambition into devotion",
        "need": "needs reliability, earned trust, and a love with backbone",
        "front": "arrives composed, restrained, and quietly formidable",
        "visual": "charcoal wool, city stone, winter light, old money restraint",
        "archetype": "The Architect",
    },
    "Aquarius": {
        "drive": "questions the script, protects individuality, and bonds through ideas",
        "need": "needs space, intelligence, and a connection that does not cage them",
        "front": "arrives cool, unusual, and impossible to fully predict",
        "visual": "electric cyan, chrome, night air, future-classic styling",
        "archetype": "The Circuit",
    },
    "Pisces": {
        "drive": "feels the invisible, dissolves boundaries, and turns longing into art",
        "need": "needs compassion, enchantment, and emotional permission to drift",
        "front": "arrives dreamy, porous, and quietly cinematic",
        "visual": "sea mist, gauze, opal light, painterly softness",
        "archetype": "The Dream",
    },
}

ASSET_EXTENSIONS = {
    ".apng",
    ".avif",
    ".gif",
    ".heic",
    ".jpeg",
    ".jpg",
    ".m4v",
    ".mov",
    ".mp4",
    ".png",
    ".webm",
    ".webp",
}
VIDEO_EXTENSIONS = {".m4v", ".mov", ".mp4", ".webm"}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def slugify(value: str) -> str:
    value = value.lower().strip()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-")


def safe_filename(value: str) -> str:
    name = Path(value).name.strip() or "reference.png"
    stem = slugify(Path(name).stem) or "reference"
    suffix = Path(name).suffix.lower()
    if suffix not in {".avif", ".heic", ".jpeg", ".jpg", ".png", ".webp"}:
        suffix = ".png"
    return f"{stem}{suffix}"


def ensure_workspace() -> None:
    for directory in [
        WORKSPACE_DIR,
        COMPANIONS_DIR,
        BATCHES_DIR,
        IMPORTS_DIR,
        REFERENCES_DIR,
        CLOUD_DROP_DIR,
        DAILY_TASKS_DIR,
        APP_SYNC_DIR,
        LINEAR_DIR,
        VISUAL_PRODUCTION_DIR,
    ]:
        directory.mkdir(parents=True, exist_ok=True)
    readme = IMPORTS_DIR / "README.txt"
    if not readme.exists():
        readme.write_text(
            "Put generated files in a folder named after a companion id or slug.\n"
            "Example: imports/simastry-0001/card.png\n\n"
            "The scanner copies files into companion folders and leaves imports in place.\n",
            encoding="utf-8",
        )


def connect() -> sqlite3.Connection:
    ensure_workspace()
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_db() -> None:
    with connect() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS companions (
              id TEXT PRIMARY KEY,
              index_number INTEGER NOT NULL,
              slug TEXT NOT NULL UNIQUE,
              display_name TEXT NOT NULL,
              gender TEXT NOT NULL,
              sun_sign TEXT NOT NULL,
              moon_sign TEXT NOT NULL,
              rising_sign TEXT NOT NULL,
              title TEXT NOT NULL,
              archetype TEXT NOT NULL,
              voice TEXT NOT NULL,
              visual_direction TEXT NOT NULL,
              prompt_core TEXT NOT NULL,
              folder_name TEXT NOT NULL,
              folder_path TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'todo',
              card_count INTEGER NOT NULL DEFAULT 0,
              photo_count INTEGER NOT NULL DEFAULT 0,
              video_count INTEGER NOT NULL DEFAULT 0,
              is_starter INTEGER NOT NULL DEFAULT 0,
              starter_rank INTEGER,
              character_source TEXT NOT NULL DEFAULT 'generated_from_scratch',
              character_brief TEXT NOT NULL DEFAULT '',
              delegate_name TEXT NOT NULL DEFAULT '',
              delegate_email TEXT NOT NULL DEFAULT '',
              delegate_slack TEXT NOT NULL DEFAULT '',
              app_character_key TEXT NOT NULL DEFAULT '',
              app_character_name TEXT NOT NULL DEFAULT '',
              app_sources TEXT NOT NULL DEFAULT '',
              app_asset_count INTEGER NOT NULL DEFAULT 0,
              app_astrogram_count INTEGER NOT NULL DEFAULT 0,
              target_photo_count INTEGER NOT NULL DEFAULT 10,
              cloud_folder_path TEXT NOT NULL DEFAULT '',
              last_batch_id TEXT,
              notes TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS batches (
              id TEXT PRIMARY KEY,
              kind TEXT NOT NULL,
              label TEXT NOT NULL,
              scope TEXT NOT NULL DEFAULT 'all',
              companion_count INTEGER NOT NULL,
              directory TEXT NOT NULL,
              created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS assets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              companion_id TEXT NOT NULL,
              asset_type TEXT NOT NULL,
              local_path TEXT NOT NULL UNIQUE,
              source_path TEXT NOT NULL,
              batch_id TEXT,
              status TEXT NOT NULL DEFAULT 'imported',
              created_at TEXT NOT NULL,
              FOREIGN KEY (companion_id) REFERENCES companions(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS app_characters (
              id TEXT PRIMARY KEY,
              sign TEXT NOT NULL,
              display_name TEXT NOT NULL,
              source_summary TEXT NOT NULL DEFAULT '',
              sources_json TEXT NOT NULL DEFAULT '[]',
              asset_paths_json TEXT NOT NULL DEFAULT '[]',
              astrogram_count INTEGER NOT NULL DEFAULT 0,
              factory_companion_ids TEXT NOT NULL DEFAULT '[]',
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS visual_production_sessions (
              id TEXT PRIMARY KEY,
              operator TEXT NOT NULL,
              character_name TEXT NOT NULL,
              companion_id TEXT NOT NULL DEFAULT '',
              presentation TEXT NOT NULL,
              age_read TEXT NOT NULL,
              archetype TEXT NOT NULL,
              sensuality_level INTEGER NOT NULL DEFAULT 2,
              realism_target TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'drafting',
              session_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS visual_production_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id TEXT NOT NULL,
              event_type TEXT NOT NULL,
              payload_json TEXT NOT NULL DEFAULT '{}',
              created_at TEXT NOT NULL,
              FOREIGN KEY (session_id) REFERENCES visual_production_sessions(id) ON DELETE CASCADE
            );

            CREATE TABLE IF NOT EXISTS slack_assignments (
              id TEXT PRIMARY KEY,
              task_date TEXT NOT NULL,
              delegate_name TEXT NOT NULL,
              slack_target TEXT NOT NULL DEFAULT '',
              channel_id TEXT NOT NULL DEFAULT '',
              message_ts TEXT NOT NULL DEFAULT '',
              message_link TEXT NOT NULL DEFAULT '',
              status TEXT NOT NULL DEFAULT 'drafted',
              companion_ids_json TEXT NOT NULL DEFAULT '[]',
              slack_message TEXT NOT NULL DEFAULT '',
              slack_draft_path TEXT NOT NULL DEFAULT '',
              prompt_file_path TEXT NOT NULL DEFAULT '',
              latest_reply_ts TEXT NOT NULL DEFAULT '',
              latest_reply_text TEXT NOT NULL DEFAULT '',
              error TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            );

            CREATE INDEX IF NOT EXISTS idx_companions_status ON companions(status);
            CREATE INDEX IF NOT EXISTS idx_companions_signs ON companions(sun_sign, moon_sign, rising_sign);
            CREATE INDEX IF NOT EXISTS idx_assets_companion ON assets(companion_id);
            CREATE INDEX IF NOT EXISTS idx_app_characters_sign ON app_characters(sign);
            CREATE INDEX IF NOT EXISTS idx_visual_sessions_status ON visual_production_sessions(status, updated_at);
            CREATE INDEX IF NOT EXISTS idx_visual_events_session ON visual_production_events(session_id, created_at);
            CREATE INDEX IF NOT EXISTS idx_slack_assignments_status ON slack_assignments(status, updated_at);
            """
        )
        companion_columns = {row["name"] for row in conn.execute("PRAGMA table_info(companions)")}
        if "is_starter" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN is_starter INTEGER NOT NULL DEFAULT 0")
        if "starter_rank" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN starter_rank INTEGER")
        if "character_source" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN character_source TEXT NOT NULL DEFAULT 'generated_from_scratch'")
        if "character_brief" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN character_brief TEXT NOT NULL DEFAULT ''")
        if "delegate_name" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN delegate_name TEXT NOT NULL DEFAULT ''")
        if "delegate_email" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN delegate_email TEXT NOT NULL DEFAULT ''")
        if "delegate_slack" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN delegate_slack TEXT NOT NULL DEFAULT ''")
        if "app_character_key" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN app_character_key TEXT NOT NULL DEFAULT ''")
        if "app_character_name" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN app_character_name TEXT NOT NULL DEFAULT ''")
        if "app_sources" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN app_sources TEXT NOT NULL DEFAULT ''")
        if "app_asset_count" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN app_asset_count INTEGER NOT NULL DEFAULT 0")
        if "app_astrogram_count" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN app_astrogram_count INTEGER NOT NULL DEFAULT 0")
        if "target_photo_count" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN target_photo_count INTEGER NOT NULL DEFAULT 10")
        if "cloud_folder_path" not in companion_columns:
            conn.execute("ALTER TABLE companions ADD COLUMN cloud_folder_path TEXT NOT NULL DEFAULT ''")
        batch_columns = {row["name"] for row in conn.execute("PRAGMA table_info(batches)")}
        if "scope" not in batch_columns:
            conn.execute("ALTER TABLE batches ADD COLUMN scope TEXT NOT NULL DEFAULT 'all'")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_companions_starter ON companions(is_starter, starter_rank)")


def companion_from_row(row: sqlite3.Row) -> dict[str, Any]:
    item = dict(row)
    item["folder_path"] = str(Path(item["folder_path"]))
    item["has_app_character"] = 1 if item.get("app_character_key") else 0
    target = int(item.get("target_photo_count") or 10)
    photos = int(item.get("photo_count") or 0)
    item["remaining_photo_count"] = max(target - photos, 0)
    item["is_complete"] = 1 if target > 0 and photos >= target else 0
    item["completion_percent"] = min(round((photos / target) * 100), 100) if target else 0
    item["identity_reference_dir"] = str(identity_reference_dir(item))
    item["identity_reference_count"] = len(list_identity_reference_files(item))
    return item


def build_companion(index_number: int, combo_index: int, gender: str, sun: str, moon: str, rising: str) -> dict[str, str | int]:
    first_names = FEMALE_NAMES if gender == "female" else MALE_NAMES
    first = first_names[combo_index % len(first_names)]
    surname = SURNAMES[(combo_index // len(first_names)) % len(SURNAMES)]
    display_name = f"{first} {surname}"
    slug = slugify(f"{display_name}-{gender}-{sun}-sun-{moon}-moon-{rising}-rising")
    companion_id = f"simastry-{index_number:04d}"
    starter_rank = None
    if sun == moon == rising:
        starter_rank = (SIGNS.index(sun) * 2) + (1 if gender == "female" else 2)
    is_starter = 1 if starter_rank else 0
    delegate_slug = "delegate-1" if gender == "female" else "delegate-2"
    cloud_folder_path = CLOUD_DROP_DIR / delegate_slug / companion_id
    combo_label = f"{sun} Sun / {moon} Moon / {rising} Rising"
    title = f"{display_name} - {combo_label}"
    sun_profile = SIGN_PROFILES[sun]
    moon_profile = SIGN_PROFILES[moon]
    rising_profile = SIGN_PROFILES[rising]
    if sun == moon:
        archetype = f"{sun_profile['archetype']} in pure form"
    else:
        archetype = f"{sun_profile['archetype']} with {moon} instincts"
    voice = (
        f"{display_name} {sun_profile['drive']}. "
        f"Emotionally, this companion {moon_profile['need']}. "
        f"At first impression, this companion {rising_profile['front']}."
    )
    visual_parts = []
    for profile in [sun_profile, moon_profile, rising_profile]:
        if profile["visual"] not in visual_parts:
            visual_parts.append(profile["visual"])
    visual_direction = "Primary visual language: " + "; ".join(visual_parts) + "."
    prompt_core = (
        "Create a realistic Simastry companion portrait that feels like an iPhone photo of a real person. "
        f"Subject: {display_name}, {gender}, {combo_label}. "
        f"Personality: {voice} "
        f"Visual direction: {visual_direction} "
        f"{IMAGE_REALISM_STANDARD} "
        f"{CAST_DISTINCTION_STANDARD} "
        "Make the person feel emotionally specific, intimate, modern, and believable. "
        "Use a phone-card-friendly vertical composition with clean negative space. "
        "No text, no zodiac glyphs, no logo, no watermark, no extra people, no corporate headshot style."
    )
    folder_name = (
        f"{index_number:04d}__{slugify(display_name)}__{gender}__"
        f"{slugify(sun)}-sun_{slugify(moon)}-moon_{slugify(rising)}-rising"
    )
    folder_path = COMPANIONS_DIR / folder_name
    return {
        "id": companion_id,
        "index_number": index_number,
        "slug": slug,
        "display_name": display_name,
        "gender": gender,
        "sun_sign": sun,
        "moon_sign": moon,
        "rising_sign": rising,
        "title": title,
        "archetype": archetype,
        "voice": voice,
        "visual_direction": visual_direction,
        "prompt_core": prompt_core,
        "folder_name": folder_name,
        "folder_path": str(folder_path),
        "is_starter": is_starter,
        "starter_rank": starter_rank or 0,
        "character_source": "existing_character" if is_starter else "generated_from_scratch",
        "character_brief": "",
        "delegate_name": "Delegate 1" if is_starter and gender == "female" else ("Delegate 2" if is_starter else ""),
        "delegate_email": "",
        "delegate_slack": "",
        "app_character_key": "",
        "app_character_name": "",
        "app_sources": "",
        "app_asset_count": 0,
        "app_astrogram_count": 0,
        "target_photo_count": 10,
        "cloud_folder_path": str(cloud_folder_path) if is_starter else "",
    }


def companion_directories(folder_path: Path) -> list[Path]:
    return [
        folder_path,
        folder_path / "references" / "identity",
        folder_path / "prompts",
        folder_path / "card",
        folder_path / "astrogram" / "profile",
        folder_path / "astrogram" / "photos",
        folder_path / "astrogram" / "videos",
        folder_path / "messages",
        folder_path / "review",
    ]


def write_manifest(companion: dict[str, Any]) -> None:
    folder = Path(companion["folder_path"])
    for directory in companion_directories(folder):
        directory.mkdir(parents=True, exist_ok=True)
    manifest = {
        "id": companion["id"],
        "title": companion["title"],
        "display_name": companion["display_name"],
        "gender": companion["gender"],
        "signs": {
            "sun": companion["sun_sign"],
            "moon": companion["moon_sign"],
            "rising": companion["rising_sign"],
        },
        "archetype": companion["archetype"],
        "voice": companion["voice"],
        "visual_direction": companion["visual_direction"],
        "prompt_core": companion["prompt_core"],
        "phase": "starter-24" if companion.get("is_starter") else "full-catalog",
        "starter_rank": companion.get("starter_rank") or None,
        "production": {
            "character_source": companion.get("character_source"),
            "character_brief": companion.get("character_brief"),
            "delegate_name": companion.get("delegate_name"),
            "delegate_email": companion.get("delegate_email"),
            "delegate_slack": companion.get("delegate_slack"),
            "app_character_key": companion.get("app_character_key"),
            "app_character_name": companion.get("app_character_name"),
            "app_sources": companion.get("app_sources"),
            "app_asset_count": companion.get("app_asset_count"),
            "app_astrogram_count": companion.get("app_astrogram_count"),
            "target_photo_count": companion.get("target_photo_count"),
            "cloud_folder_path": companion.get("cloud_folder_path"),
        },
        "folders": {
            "identity_references": "references/identity",
            "prompts": "prompts",
            "card": "card",
            "profile": "astrogram/profile",
            "photos": "astrogram/photos",
            "videos": "astrogram/videos",
            "messages": "messages",
            "review": "review",
        },
    }
    (folder / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    if companion.get("cloud_folder_path"):
        Path(str(companion["cloud_folder_path"])).mkdir(parents=True, exist_ok=True)


def identity_reference_dir(companion: dict[str, Any] | sqlite3.Row) -> Path:
    return Path(companion["folder_path"]) / "references" / "identity"


def list_identity_reference_files(companion: dict[str, Any] | sqlite3.Row) -> list[Path]:
    directory = identity_reference_dir(companion)
    if not directory.exists():
        return []
    return sorted(
        [
            path
            for path in directory.iterdir()
            if path.is_file() and path.suffix.lower() in {".avif", ".heic", ".jpeg", ".jpg", ".png", ".webp"}
        ],
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )


def identity_reference_items(companion: dict[str, Any] | sqlite3.Row) -> list[dict[str, Any]]:
    return [
        {
            "name": path.name,
            "path": str(path),
            "url": f"/api/companions/{companion['id']}/identity-references/file/{path.name}",
            "size": path.stat().st_size,
            "created_at": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(timespec="seconds"),
        }
        for path in list_identity_reference_files(companion)
    ]


def seed_catalog(create_folders: bool = True) -> dict[str, Any]:
    init_db()
    created = 0
    updated = 0
    index_number = 1
    combo_index = 0
    timestamp = now_iso()
    with connect() as conn:
        for sun in SIGNS:
            for moon in SIGNS:
                for rising in SIGNS:
                    for gender in ["female", "male"]:
                        companion = build_companion(index_number, combo_index, gender, sun, moon, rising)
                        exists = conn.execute(
                            "SELECT id, status, card_count, photo_count, video_count FROM companions WHERE id = ?",
                            (companion["id"],),
                        ).fetchone()
                        if exists:
                            updated += 1
                            conn.execute(
                                """
                                UPDATE companions
                                SET slug = ?, display_name = ?, gender = ?, sun_sign = ?, moon_sign = ?,
                                    rising_sign = ?, title = ?, archetype = ?, voice = ?,
                                    visual_direction = ?, prompt_core = ?, folder_name = ?,
                                    folder_path = ?, is_starter = ?, starter_rank = ?,
                                    character_source = CASE
                                      WHEN is_starter = 1 AND character_source = 'generated_from_scratch' THEN ?
                                      WHEN character_source = '' THEN ?
                                      ELSE character_source
                                    END,
                                    delegate_name = CASE WHEN delegate_name = '' THEN ? ELSE delegate_name END,
                                    delegate_email = CASE WHEN delegate_email = '' THEN ? ELSE delegate_email END,
                                    delegate_slack = CASE WHEN delegate_slack = '' THEN ? ELSE delegate_slack END,
                                    app_character_key = CASE WHEN app_character_key = '' THEN ? ELSE app_character_key END,
                                    app_character_name = CASE WHEN app_character_name = '' THEN ? ELSE app_character_name END,
                                    app_sources = CASE WHEN app_sources = '' THEN ? ELSE app_sources END,
                                    app_asset_count = CASE WHEN app_asset_count < 1 THEN ? ELSE app_asset_count END,
                                    app_astrogram_count = CASE WHEN app_astrogram_count < 1 THEN ? ELSE app_astrogram_count END,
                                    target_photo_count = CASE WHEN target_photo_count < 1 THEN ? ELSE target_photo_count END,
                                    cloud_folder_path = CASE WHEN cloud_folder_path = '' THEN ? ELSE cloud_folder_path END,
                                    updated_at = ?
                                WHERE id = ?
                                """,
                                (
                                    companion["slug"],
                                    companion["display_name"],
                                    companion["gender"],
                                    companion["sun_sign"],
                                    companion["moon_sign"],
                                    companion["rising_sign"],
                                    companion["title"],
                                    companion["archetype"],
                                    companion["voice"],
                                    companion["visual_direction"],
                                    companion["prompt_core"],
                                    companion["folder_name"],
                                    companion["folder_path"],
                                    companion["is_starter"],
                                    companion["starter_rank"],
                                    companion["character_source"],
                                    companion["character_source"],
                                    companion["delegate_name"],
                                    companion["delegate_email"],
                                    companion["delegate_slack"],
                                    companion["app_character_key"],
                                    companion["app_character_name"],
                                    companion["app_sources"],
                                    companion["app_asset_count"],
                                    companion["app_astrogram_count"],
                                    companion["target_photo_count"],
                                    companion["cloud_folder_path"],
                                    timestamp,
                                    companion["id"],
                                ),
                            )
                        else:
                            created += 1
                            conn.execute(
                                """
                                INSERT INTO companions (
                                  id, index_number, slug, display_name, gender, sun_sign, moon_sign,
                                  rising_sign, title, archetype, voice, visual_direction, prompt_core,
                                  folder_name, folder_path, is_starter, starter_rank, character_source,
                                  character_brief, delegate_name, delegate_email, delegate_slack,
                                  app_character_key, app_character_name, app_sources, app_asset_count,
                                  app_astrogram_count, target_photo_count, cloud_folder_path, created_at, updated_at
                                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                                """,
                                (
                                    companion["id"],
                                    companion["index_number"],
                                    companion["slug"],
                                    companion["display_name"],
                                    companion["gender"],
                                    companion["sun_sign"],
                                    companion["moon_sign"],
                                    companion["rising_sign"],
                                    companion["title"],
                                    companion["archetype"],
                                    companion["voice"],
                                    companion["visual_direction"],
                                    companion["prompt_core"],
                                    companion["folder_name"],
                                    companion["folder_path"],
                                    companion["is_starter"],
                                    companion["starter_rank"],
                                    companion["character_source"],
                                    companion["character_brief"],
                                    companion["delegate_name"],
                                    companion["delegate_email"],
                                    companion["delegate_slack"],
                                    companion["app_character_key"],
                                    companion["app_character_name"],
                                    companion["app_sources"],
                                    companion["app_asset_count"],
                                    companion["app_astrogram_count"],
                                    companion["target_photo_count"],
                                    companion["cloud_folder_path"],
                                    timestamp,
                                    timestamp,
                                ),
                            )
                        if create_folders:
                            write_manifest(companion)
                        index_number += 1
                    combo_index += 1
        conn.commit()
    return {
        "created": created,
        "updated": updated,
        "total": created + updated,
        "folders": create_folders,
        "workspace": str(WORKSPACE_DIR),
    }


def stats() -> dict[str, Any]:
    init_db()
    with connect() as conn:
        totals = dict(
            conn.execute(
                """
                SELECT
                  COUNT(*) AS total,
                  SUM(CASE WHEN status = 'todo' THEN 1 ELSE 0 END) AS todo,
                  SUM(CASE WHEN status = 'queued' THEN 1 ELSE 0 END) AS queued,
                  SUM(CASE WHEN status = 'generated' THEN 1 ELSE 0 END) AS generated,
                  SUM(CASE WHEN status = 'reviewed' THEN 1 ELSE 0 END) AS reviewed,
                  SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) AS approved,
                  SUM(CASE WHEN is_starter = 1 THEN 1 ELSE 0 END) AS starter_total,
                  SUM(CASE WHEN is_starter = 1 AND status = 'todo' THEN 1 ELSE 0 END) AS starter_todo,
                  SUM(CASE WHEN is_starter = 1 AND status = 'queued' THEN 1 ELSE 0 END) AS starter_queued,
                  SUM(CASE WHEN is_starter = 1 AND status = 'generated' THEN 1 ELSE 0 END) AS starter_generated,
                  SUM(CASE WHEN is_starter = 1 AND status = 'reviewed' THEN 1 ELSE 0 END) AS starter_reviewed,
                  SUM(CASE WHEN is_starter = 1 AND status = 'approved' THEN 1 ELSE 0 END) AS starter_approved,
                  SUM(CASE WHEN is_starter = 1 AND photo_count >= target_photo_count AND target_photo_count > 0 THEN 1 ELSE 0 END) AS starter_complete,
                  SUM(CASE WHEN is_starter = 1 AND (photo_count < target_photo_count OR target_photo_count < 1) THEN 1 ELSE 0 END) AS starter_incomplete,
                  SUM(CASE WHEN is_starter = 1 AND delegate_name != '' THEN 1 ELSE 0 END) AS starter_assigned,
                  SUM(CASE WHEN is_starter = 1 AND character_source = 'existing_character' THEN 1 ELSE 0 END) AS starter_existing_characters,
                  SUM(CASE WHEN is_starter = 1 AND app_character_key != '' THEN 1 ELSE 0 END) AS starter_app_characters,
                  SUM(card_count) AS cards,
                  SUM(photo_count) AS photos,
                  SUM(video_count) AS videos,
                  SUM(CASE WHEN is_starter = 1 THEN card_count ELSE 0 END) AS starter_cards,
                  SUM(CASE WHEN is_starter = 1 THEN photo_count ELSE 0 END) AS starter_photos,
                  SUM(CASE WHEN is_starter = 1 THEN video_count ELSE 0 END) AS starter_videos
                FROM companions
                """
            ).fetchone()
        )
        batch_count = conn.execute("SELECT COUNT(*) FROM batches").fetchone()[0]
        asset_count = conn.execute("SELECT COUNT(*) FROM assets").fetchone()[0]
        app_character_count = conn.execute("SELECT COUNT(*) FROM app_characters").fetchone()[0]
        visual_session_count = conn.execute("SELECT COUNT(*) FROM visual_production_sessions").fetchone()[0]
        visual_approved_count = conn.execute(
            "SELECT COUNT(*) FROM visual_production_sessions WHERE status = 'approved'"
        ).fetchone()[0]
        slack_assignment_count = conn.execute("SELECT COUNT(*) FROM slack_assignments").fetchone()[0]
        slack_posted_count = conn.execute(
            "SELECT COUNT(*) FROM slack_assignments WHERE status IN ('posted', 'in_progress', 'worker_reported_done')"
        ).fetchone()[0]
        totals["batch_count"] = batch_count
        totals["asset_count"] = asset_count
        totals["app_character_count"] = app_character_count
        totals["visual_session_count"] = visual_session_count
        totals["visual_approved_count"] = visual_approved_count
        totals["slack_assignment_count"] = slack_assignment_count
        totals["slack_posted_count"] = slack_posted_count
        totals["slack_enabled"] = 1 if SLACK_BOT_TOKEN else 0
        totals["workspace"] = str(WORKSPACE_DIR)
        totals["imports"] = str(IMPORTS_DIR)
        totals["reference_count"] = len(list_reference_files())
        totals["references"] = str(REFERENCES_DIR)
        totals["cloud_drop"] = str(CLOUD_DROP_DIR)
        totals["daily_tasks"] = str(DAILY_TASKS_DIR)
        totals["visual_production"] = str(VISUAL_PRODUCTION_DIR)
        return {key: (value if value is not None else 0) for key, value in totals.items()}


def list_reference_files() -> list[Path]:
    ensure_workspace()
    return sorted(
        [
            path
            for path in REFERENCES_DIR.iterdir()
            if path.is_file() and path.suffix.lower() in {".avif", ".heic", ".jpeg", ".jpg", ".png", ".webp"}
        ],
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )


def list_references() -> dict[str, Any]:
    files = list_reference_files()
    return {
        "count": len(files),
        "directory": str(REFERENCES_DIR),
        "items": [
            {
                "name": path.name,
                "path": str(path),
                "url": f"/api/references/file/{path.name}",
                "size": path.stat().st_size,
                "created_at": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(timespec="seconds"),
            }
            for path in files
        ],
    }


def save_reference_uploads(files: list[dict[str, Any]]) -> dict[str, Any]:
    ensure_workspace()
    saved: list[dict[str, Any]] = []
    for index, file_info in enumerate(files, start=1):
        data_url = str(file_info.get("data", ""))
        if not data_url:
            continue
        if "," in data_url and data_url.startswith("data:"):
            header, encoded = data_url.split(",", 1)
            mime = header.split(";", 1)[0].replace("data:", "")
            suffix = mimetypes.guess_extension(mime) or Path(str(file_info.get("name", ""))).suffix or ".png"
        else:
            encoded = data_url
            suffix = Path(str(file_info.get("name", ""))).suffix or ".png"
        try:
            raw = base64.b64decode(encoded, validate=False)
        except Exception:
            continue
        if not raw:
            continue
        original = safe_filename(str(file_info.get("name", f"reference-{index}{suffix}")))
        stem = Path(original).stem
        extension = Path(original).suffix or suffix
        target = REFERENCES_DIR / original
        counter = 2
        while target.exists():
            target = REFERENCES_DIR / f"{stem}-{counter}{extension}"
            counter += 1
        target.write_bytes(raw)
        saved.append({"name": target.name, "path": str(target), "url": f"/api/references/file/{target.name}"})
    return {"saved": len(saved), "items": saved, "directory": str(REFERENCES_DIR)}


def save_identity_reference_uploads(companion_id: str, files: list[dict[str, Any]]) -> dict[str, Any]:
    companion = get_companion(companion_id)
    if not companion:
        raise KeyError(companion_id)
    directory = identity_reference_dir(companion)
    directory.mkdir(parents=True, exist_ok=True)
    saved: list[dict[str, Any]] = []
    for index, file_info in enumerate(files, start=1):
        data_url = str(file_info.get("data", ""))
        if not data_url:
            continue
        if "," in data_url and data_url.startswith("data:"):
            header, encoded = data_url.split(",", 1)
            mime = header.split(";", 1)[0].replace("data:", "")
            suffix = mimetypes.guess_extension(mime) or Path(str(file_info.get("name", ""))).suffix or ".png"
        else:
            encoded = data_url
            suffix = Path(str(file_info.get("name", ""))).suffix or ".png"
        try:
            raw = base64.b64decode(encoded, validate=False)
        except Exception:
            continue
        if not raw:
            continue
        original = safe_filename(str(file_info.get("name", f"identity-reference-{index}{suffix}")))
        stem = Path(original).stem
        extension = Path(original).suffix or suffix
        target = directory / original
        counter = 2
        while target.exists():
            target = directory / f"{stem}-{counter}{extension}"
            counter += 1
        target.write_bytes(raw)
        saved.append({"name": target.name, "path": str(target), "url": f"/api/companions/{companion['id']}/identity-references/file/{target.name}"})
    refreshed = get_companion(companion["id"])
    return {
        "saved": len(saved),
        "items": saved,
        "directory": str(directory),
        "companion": refreshed,
    }


def object_blocks_from_array(text: str, marker: str) -> list[str]:
    marker_index = text.find(marker)
    if marker_index < 0:
        return []
    equals_index = text.find("=", marker_index)
    array_start = text.find("[", equals_index if equals_index >= 0 else marker_index)
    if array_start < 0:
        return []
    blocks: list[str] = []
    depth = 0
    block_start: int | None = None
    in_string = False
    quote = ""
    escape = False
    for index in range(array_start + 1, len(text)):
        char = text[index]
        if in_string:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == quote:
                in_string = False
            continue
        if char in {"'", '"', "`"}:
            in_string = True
            quote = char
            continue
        if char == "{":
            if depth == 0:
                block_start = index
            depth += 1
            continue
        if char == "}":
            depth -= 1
            if depth == 0 and block_start is not None:
                blocks.append(text[block_start : index + 1])
                block_start = None
            continue
        if char == "]" and depth == 0:
            break
    return blocks


def js_string_field(block: str, field: str) -> str:
    match = re.search(rf"\b{re.escape(field)}\s*:\s*['\"]([^'\"]+)['\"]", block)
    return match.group(1).strip() if match else ""


def js_asset_references(block: str) -> list[str]:
    refs = re.findall(r"require\(\s*['\"]([^'\"]+)['\"]\s*\)", block)
    refs.extend(re.findall(r"\b(?:image|backdropImage)\s*:\s*['\"]([^'\"]+)['\"]", block))
    return refs


def resolve_asset_path(source_file: Path, ref: str) -> str:
    if ref.startswith("assets/"):
        path = PROJECT_ROOT / "website" / ref
    else:
        path = (source_file.parent / ref).resolve()
    return str(path)


def source_record(name: str, source_file: Path, block: str, label: str) -> dict[str, Any]:
    refs = js_asset_references(block)
    assets = []
    for ref in refs:
        path = resolve_asset_path(source_file, ref)
        assets.append({"ref": ref, "path": path, "exists": Path(path).exists()})
    return {
        "source": name,
        "label": label,
        "file": str(source_file),
        "assets": assets,
    }


def expo_asset_maps(text: str) -> tuple[dict[str, str], dict[str, list[str]]]:
    image_refs: dict[str, str] = {}
    astrogram_refs: dict[str, list[str]] = {}

    images_match = re.search(r"const\s+images\s*=\s*\{(?P<body>.*?)\n\};", text, re.DOTALL)
    if images_match:
        for key, ref in re.findall(r"\b([A-Za-z0-9_]+)\s*:\s*require\(\s*['\"]([^'\"]+)['\"]\s*\)", images_match.group("body")):
            image_refs[key] = ref

    photos_match = re.search(r"const\s+factoryAstrogramPhotos[^=]*=\s*\{(?P<body>.*?)\n\};", text, re.DOTALL)
    if photos_match:
        for companion_id, body in re.findall(r"['\"]([^'\"]+)['\"]\s*:\s*\[(.*?)\]", photos_match.group("body"), re.DOTALL):
            astrogram_refs[companion_id] = re.findall(r"require\(\s*['\"]([^'\"]+)['\"]\s*\)", body)

    return image_refs, astrogram_refs


def expo_block_asset_refs(block: str, companion_id: str, image_refs: dict[str, str], astrogram_refs: dict[str, list[str]]) -> list[str]:
    refs = js_asset_references(block)
    for image_key in re.findall(r"\bimages\.([A-Za-z0-9_]+)\b", block):
        ref = image_refs.get(image_key)
        if ref:
            refs.append(ref)
    refs.extend(astrogram_refs.get(companion_id, []))
    return refs


def expo_source_record(source_file: Path, block: str, companion_id: str, image_refs: dict[str, str], astrogram_refs: dict[str, list[str]]) -> dict[str, Any]:
    refs = expo_block_asset_refs(block, companion_id, image_refs, astrogram_refs)
    assets = []
    seen: set[str] = set()
    for ref in refs:
        if ref in seen:
            continue
        seen.add(ref)
        path = resolve_asset_path(source_file, ref)
        assets.append({"ref": ref, "path": path, "exists": Path(path).exists()})
    return {
        "source": "expo-prototype",
        "label": "Expo prototype companion data",
        "file": str(source_file),
        "assets": assets,
    }


def scan_simastry_app_characters() -> list[dict[str, Any]]:
    characters: dict[str, dict[str, Any]] = {}

    def ensure_character(sign: str, display_name: str = "", gender: str = "", explicit_id: str = "") -> dict[str, Any]:
        key = explicit_id or slugify(f"{sign}-{display_name or gender}")
        if not key:
            key = slugify(display_name)
        existing = characters.setdefault(
            key,
            {
                "id": key,
                "sign": sign.title(),
                "display_name": display_name or sign.title(),
                "gender": gender,
                "sources": [],
                "asset_paths": [],
                "astrogram_count": 0,
            },
        )
        if display_name and existing["display_name"] == existing["sign"]:
            existing["display_name"] = display_name
        return existing

    expo_file = PROJECT_ROOT / "expo-prototype" / "data" / "companions.ts"
    if expo_file.exists():
        text = expo_file.read_text(encoding="utf-8")
        image_refs, astrogram_refs = expo_asset_maps(text)
        for block in object_blocks_from_array(text, "export const companions"):
            companion_id = js_string_field(block, "id")
            sign = js_string_field(block, "sign")
            display_name = js_string_field(block, "displayName")
            gender = js_string_field(block, "gender")
            if not sign:
                continue
            character = ensure_character(sign, display_name, gender, companion_id)
            record = expo_source_record(expo_file, block, companion_id, image_refs, astrogram_refs)
            character["sources"].append(record)
            character["asset_paths"].extend(record["assets"])
            character["astrogram_count"] += sum(1 for asset in record["assets"] if "/assets/astrogram/" in asset["path"])

    website_file = PROJECT_ROOT / "website" / "script.js"
    if website_file.exists() and not characters:
        text = website_file.read_text(encoding="utf-8")
        for block in object_blocks_from_array(text, "const signProfiles"):
            sign = js_string_field(block, "name")
            if not sign:
                continue
            character = ensure_character(sign)
            record = source_record("website-sign-profile", website_file, block, "Website zodiac profile")
            character["sources"].append(record)
            character["asset_paths"].extend(record["assets"])
        for block in object_blocks_from_array(text, "const featuredCompanions"):
            sign_key = js_string_field(block, "sign")
            if not sign_key:
                continue
            sign = sign_key.title()
            character = ensure_character(sign)
            record = source_record("website-featured-hero", website_file, block, "Website featured companion hero")
            character["sources"].append(record)
            character["asset_paths"].extend(record["assets"])

    return sorted(characters.values(), key=lambda item: SIGNS.index(item["sign"]) if item["sign"] in SIGNS else 99)


def sync_simastry_apps() -> dict[str, Any]:
    init_db()
    characters = scan_simastry_app_characters()
    timestamp = now_iso()
    with connect() as conn:
        conn.execute("DELETE FROM app_characters")
        for character in characters:
            unique_assets: list[dict[str, Any]] = []
            seen_paths: set[str] = set()
            for asset in character["asset_paths"]:
                path = asset["path"]
                if path in seen_paths:
                    continue
                seen_paths.add(path)
                unique_assets.append(asset)
            sources = sorted({source["source"] for source in character["sources"]})
            starter_rows = conn.execute(
                """
                SELECT id, display_name, gender
                FROM companions
                WHERE is_starter = 1 AND sun_sign = ? AND moon_sign = ? AND rising_sign = ?
                  AND (? = '' OR gender = ?)
                ORDER BY starter_rank
                """,
                (character["sign"], character["sign"], character["sign"], character.get("gender", ""), character.get("gender", "")),
            ).fetchall()
            factory_ids = [row["id"] for row in starter_rows]
            source_summary = ", ".join(sources)
            conn.execute(
                """
                INSERT INTO app_characters (
                  id, sign, display_name, source_summary, sources_json,
                  asset_paths_json, astrogram_count, factory_companion_ids, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    character["id"],
                    character["sign"],
                    character["display_name"],
                    source_summary,
                    json.dumps(character["sources"], indent=2),
                    json.dumps(unique_assets, indent=2),
                    int(character["astrogram_count"]),
                    json.dumps(factory_ids),
                    timestamp,
                ),
            )
            conn.execute(
                """
                UPDATE companions
                SET character_source = 'existing_character',
                    app_character_key = ?,
                    app_character_name = ?,
                    app_sources = ?,
                    app_asset_count = ?,
                    app_astrogram_count = ?,
                    updated_at = ?
                WHERE is_starter = 1 AND sun_sign = ? AND moon_sign = ? AND rising_sign = ?
                  AND (? = '' OR gender = ?)
                """,
                (
                    character["id"],
                    character["display_name"],
                    source_summary,
                    len(unique_assets),
                    int(character["astrogram_count"]),
                    timestamp,
                    character["sign"],
                    character["sign"],
                    character["sign"],
                    character.get("gender", ""),
                    character.get("gender", ""),
                ),
            )
        conn.commit()
    payload = list_app_characters()
    (APP_SYNC_DIR / "app_characters.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return {
        "synced": payload["count"],
        "starter_matches": sum(len(item["factory_companions"]) for item in payload["items"]),
        "output": str(APP_SYNC_DIR / "app_characters.json"),
        "items": payload["items"],
    }


def list_app_characters() -> dict[str, Any]:
    init_db()
    with connect() as conn:
        rows = conn.execute("SELECT * FROM app_characters ORDER BY id").fetchall()
        items: list[dict[str, Any]] = []
        for row in rows:
            factory_ids = json.loads(row["factory_companion_ids"] or "[]")
            factory_rows = []
            if factory_ids:
                placeholders = ",".join("?" for _ in factory_ids)
                factory_rows = conn.execute(
                    f"SELECT id, display_name, gender, photo_count, target_photo_count, cloud_folder_path FROM companions WHERE id IN ({placeholders}) ORDER BY starter_rank",
                    factory_ids,
                ).fetchall()
            assets = json.loads(row["asset_paths_json"] or "[]")
            items.append(
                {
                    "id": row["id"],
                    "sign": row["sign"],
                    "display_name": row["display_name"],
                    "source_summary": row["source_summary"],
                    "asset_count": len(assets),
                    "existing_asset_count": sum(1 for asset in assets if asset.get("exists")),
                    "astrogram_count": row["astrogram_count"],
                    "assets": assets,
                    "sources": json.loads(row["sources_json"] or "[]"),
                    "factory_companions": [dict(item) for item in factory_rows],
                    "updated_at": row["updated_at"],
                }
            )
    items.sort(key=lambda item: SIGNS.index(item["sign"]) if item["sign"] in SIGNS else 99)
    return {"count": len(items), "directory": str(APP_SYNC_DIR), "items": items}


def generate_linear_drafts() -> dict[str, Any]:
    init_db()
    app_payload = list_app_characters()
    if not app_payload["items"]:
        sync_simastry_apps()
        app_payload = list_app_characters()
    task_date = datetime.now().strftime("%Y-%m-%d")
    linear_dir = LINEAR_DIR / task_date
    linear_dir.mkdir(parents=True, exist_ok=True)
    issue_drafts: list[dict[str, Any]] = []
    for character in app_payload["items"]:
        companions = character["factory_companions"]
        companion_lines = "\n".join(
            [
                f"- {item['id']} / {item['display_name']} / {item['gender']}: "
                f"{item['photo_count']}/{item['target_photo_count']} pictures, cloud folder `{item['cloud_folder_path']}`"
                for item in companions
            ]
        )
        asset_lines = "\n".join(
            [
                f"- {Path(asset['path']).name}: {'found' if asset.get('exists') else 'missing'} at `{asset['path']}`"
                for asset in character["assets"]
            ]
        )
        description = (
            f"## Goal\nLock the app-facing {character['sign']} character, `{character['display_name']}`, "
            "as a Factory production unit and finish the Starter 24 asset set.\n\n"
            "## Existing Simastry sources\n"
            f"- Sources: {character['source_summary'] or 'No source summary'}\n"
            f"- Existing app asset files found: {character['existing_asset_count']}/{character['asset_count']}\n"
            f"- Existing Astrogram photos found: {character['astrogram_count']}\n\n"
            "## Factory companions\n"
            f"{companion_lines or '- No matching Starter 24 companion found'}\n\n"
            "## Work checklist\n"
            "- Confirm the existing character identity reference images are uploaded in Factory.\n"
            "- Generate or import the 10-photo same-person pack for each Starter companion variant.\n"
            "- Scan folders in Factory and confirm each Starter companion reaches its target picture count.\n"
            "- Review the images for same-person consistency, social-photo realism, and no text/logo artifacts.\n"
            "- Decide which final app asset should be exported into the Swift app, Expo prototype, and website.\n\n"
            "## Existing app assets\n"
            f"{asset_lines or '- No app assets detected yet'}"
        )
        issue_drafts.append(
            {
                "title": f"[Factory] Finish {character['sign']} app character assets - {character['display_name']}",
                "description": description,
                "labels": ["factory", "assets", "starter-24", character["sign"].lower()],
                "project": "Simastry Asset Factory",
                "source": "local-draft",
            }
        )
    issue_drafts.append(
        {
            "title": "[Factory] Wire approved companion assets into Simastry apps",
            "description": (
                "## Goal\nConnect approved Factory assets back into the real Simastry app surfaces.\n\n"
                "## Targets\n"
                "- Swift iOS app: decide how bundled app characters should reference approved Factory assets.\n"
                "- Expo prototype: replace prototype image imports with approved Factory asset paths.\n"
                "- Website: keep hero-cast and sign profile imagery aligned with the approved app characters.\n"
                "- Factory: keep app sync as the production source of truth for what already exists and what still needs work.\n\n"
                "## Notes\n"
                "The Swift app currently creates user companions dynamically through Supabase. The fixed app-facing cast appears in the Expo prototype and website."
            ),
            "labels": ["factory", "integration", "linear", "simastry-apps"],
            "project": "Simastry Asset Factory",
            "source": "local-draft",
        }
    )
    markdown_path = linear_dir / "linear_issue_drafts.md"
    json_path = linear_dir / "linear_issue_drafts.json"
    markdown_lines = [
        f"# Linear issue drafts - {task_date}",
        "",
        "These are local drafts only. Factory is not posting to Linear automatically.",
        "",
    ]
    for index, issue in enumerate(issue_drafts, start=1):
        markdown_lines.extend(
            [
                f"## {index}. {issue['title']}",
                "",
                f"Labels: {', '.join(issue['labels'])}",
                f"Project: {issue['project']}",
                "",
                issue["description"],
                "",
            ]
        )
    markdown_path.write_text("\n".join(markdown_lines), encoding="utf-8")
    json_path.write_text(json.dumps(issue_drafts, indent=2), encoding="utf-8")
    return {
        "created": len(issue_drafts),
        "directory": str(linear_dir),
        "markdown": str(markdown_path),
        "json": str(json_path),
        "issues": issue_drafts,
    }


def list_companions(params: dict[str, list[str]]) -> dict[str, Any]:
    init_db()
    limit = min(max(int(params.get("limit", ["120"])[0]), 1), 500)
    offset = max(int(params.get("offset", ["0"])[0]), 0)
    where = []
    args: list[Any] = []
    search = params.get("search", [""])[0].strip()
    status_filter = params.get("status", [""])[0].strip()
    gender_filter = params.get("gender", [""])[0].strip()
    sign_filter = params.get("sign", [""])[0].strip()
    scope_filter = params.get("scope", [""])[0].strip()
    if scope_filter == "starter":
        where.append("is_starter = 1")
    if search:
        where.append(
            "(id LIKE ? OR slug LIKE ? OR display_name LIKE ? OR sun_sign LIKE ? OR moon_sign LIKE ? OR rising_sign LIKE ?)"
        )
        like = f"%{search}%"
        args.extend([like, like, like, like, like, like])
    if status_filter:
        where.append("status = ?")
        args.append(status_filter)
    if gender_filter:
        where.append("gender = ?")
        args.append(gender_filter)
    if sign_filter:
        where.append("(sun_sign = ? OR moon_sign = ? OR rising_sign = ?)")
        args.extend([sign_filter, sign_filter, sign_filter])
    where_sql = f"WHERE {' AND '.join(where)}" if where else ""
    with connect() as conn:
        total = conn.execute(f"SELECT COUNT(*) FROM companions {where_sql}", args).fetchone()[0]
        rows = conn.execute(
            f"""
            SELECT *
            FROM companions
            {where_sql}
            ORDER BY CASE WHEN is_starter = 1 THEN 0 ELSE 1 END,
                     COALESCE(NULLIF(starter_rank, 0), index_number),
                     index_number ASC
            LIMIT ? OFFSET ?
            """,
            [*args, limit, offset],
        ).fetchall()
        return {"total": total, "items": [companion_from_row(row) for row in rows], "limit": limit, "offset": offset}


def get_companion(companion_id: str) -> dict[str, Any] | None:
    init_db()
    with connect() as conn:
        row = conn.execute(
            "SELECT * FROM companions WHERE id = ? OR slug = ?",
            (companion_id, companion_id),
        ).fetchone()
        if not row:
            return None
        companion = companion_from_row(row)
        assets = conn.execute(
            "SELECT * FROM assets WHERE companion_id = ? ORDER BY created_at DESC LIMIT 60",
            (companion["id"],),
        ).fetchall()
        companion["assets"] = [dict(asset) for asset in assets]
        companion["identity_references"] = identity_reference_items(companion)
        return companion


def set_status(companion_id: str, status_value: str, notes: str | None = None) -> dict[str, Any]:
    allowed = {"todo", "queued", "generated", "reviewed", "approved", "blocked"}
    if status_value not in allowed:
        raise ValueError(f"Unknown status: {status_value}")
    timestamp = now_iso()
    with connect() as conn:
        row = conn.execute("SELECT id FROM companions WHERE id = ? OR slug = ?", (companion_id, companion_id)).fetchone()
        if not row:
            raise KeyError(companion_id)
        if notes is None:
            conn.execute(
                "UPDATE companions SET status = ?, updated_at = ? WHERE id = ?",
                (status_value, timestamp, row["id"]),
            )
        else:
            conn.execute(
                "UPDATE companions SET status = ?, notes = ?, updated_at = ? WHERE id = ?",
                (status_value, notes, timestamp, row["id"]),
            )
        conn.commit()
    result = get_companion(row["id"])
    assert result is not None
    return result


def update_production(companion_id: str, payload: dict[str, Any]) -> dict[str, Any]:
    allowed_sources = {"existing_character", "generated_from_scratch"}
    character_source = str(payload.get("character_source", "existing_character")).strip()
    if character_source not in allowed_sources:
        character_source = "existing_character"
    character_brief = str(payload.get("character_brief", "")).strip()
    cloud_folder_path = str(payload.get("cloud_folder_path", "")).strip()
    target_photo_count = max(int(payload.get("target_photo_count", 10) or 10), 1)
    timestamp = now_iso()
    with connect() as conn:
        row = conn.execute("SELECT * FROM companions WHERE id = ? OR slug = ?", (companion_id, companion_id)).fetchone()
        if not row:
            raise KeyError(companion_id)
        delegate_name = str(payload.get("delegate_name", row["delegate_name"])).strip()
        delegate_email = str(payload.get("delegate_email", row["delegate_email"])).strip()
        fallback_slack = row["delegate_slack"] if "delegate_slack" in row.keys() else ""
        delegate_slack = str(payload.get("delegate_slack", fallback_slack)).strip()
        if cloud_folder_path:
            Path(cloud_folder_path).mkdir(parents=True, exist_ok=True)
        conn.execute(
            """
            UPDATE companions
            SET character_source = ?, character_brief = ?, delegate_name = ?, delegate_email = ?, delegate_slack = ?,
                target_photo_count = ?, cloud_folder_path = ?, updated_at = ?
            WHERE id = ?
            """,
            (
                character_source,
                character_brief,
                delegate_name,
                delegate_email,
                delegate_slack,
                target_photo_count,
                cloud_folder_path,
                timestamp,
                row["id"],
            ),
        )
        conn.commit()
    result = get_companion(row["id"])
    assert result is not None
    return result


VISUAL_ARCHETYPES = {
    "magnetic_stranger": "The magnetic stranger",
    "impossible_ex": "The impossible ex",
    "dangerous_calm": "The dangerous calm one",
    "warm_obsession": "The warm obsession",
    "untouchable_muse": "The untouchable muse",
    "private_softness": "Private softness",
}

VISUAL_STATUSES = {"drafting", "prompted", "generated", "reviewed", "approved", "rejected", "blocked"}


def normalize_visual_status(value: Any, fallback: str = "drafting") -> str:
    status = str(value or fallback).strip().lower().replace(" ", "_")
    return status if status in VISUAL_STATUSES else fallback


def visual_session_from_row(row: sqlite3.Row, include_events: bool = False) -> dict[str, Any]:
    item = dict(row)
    try:
        item["session"] = json.loads(item.pop("session_json") or "{}")
    except json.JSONDecodeError:
        item["session"] = {}
    if include_events:
        with connect() as conn:
            events = conn.execute(
                "SELECT * FROM visual_production_events WHERE session_id = ? ORDER BY created_at ASC, id ASC",
                (item["id"],),
            ).fetchall()
        item["events"] = [
            {
                "id": event["id"],
                "event_type": event["event_type"],
                "payload": json.loads(event["payload_json"] or "{}"),
                "created_at": event["created_at"],
            }
            for event in events
        ]
    return item


def list_visual_sessions(limit: int = 40) -> dict[str, Any]:
    init_db()
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT * FROM visual_production_sessions
            ORDER BY updated_at DESC
            LIMIT ?
            """,
            (max(min(limit, 200), 1),),
        ).fetchall()
    return {"items": [visual_session_from_row(row) for row in rows], "total": len(rows), "directory": str(VISUAL_PRODUCTION_DIR)}


def get_visual_session(session_id: str) -> dict[str, Any] | None:
    init_db()
    with connect() as conn:
        row = conn.execute("SELECT * FROM visual_production_sessions WHERE id = ?", (session_id,)).fetchone()
    if not row:
        return None
    return visual_session_from_row(row, include_events=True)


def create_visual_session(payload: dict[str, Any]) -> dict[str, Any]:
    init_db()
    timestamp = now_iso()
    operator = str(payload.get("operator", "")).strip() or "Unassigned"
    character_name = str(payload.get("character_name", "")).strip() or "Unnamed character"
    companion_id = str(payload.get("companion_id", "")).strip()
    presentation = str(payload.get("presentation", "")).strip() or "unspecified"
    age_read = str(payload.get("age_read", "")).strip() or "mid-to-late 20s"
    archetype = str(payload.get("archetype", "magnetic_stranger")).strip()
    if archetype not in VISUAL_ARCHETYPES:
        archetype = "magnetic_stranger"
    sensuality_level = max(1, min(int(payload.get("sensuality_level", 2) or 2), 3))
    realism_target = str(payload.get("realism_target", "")).strip() or "realistic phone-photo intimacy"
    status = normalize_visual_status(payload.get("status"), "drafting")
    session_id = f"visual-{int(time.time())}-{slugify(character_name)[:32] or 'character'}"
    session = {
        "visual_goal": str(payload.get("visual_goal", "")).strip(),
        "wardrobe": str(payload.get("wardrobe", "")).strip(),
        "setting": str(payload.get("setting", "")).strip(),
        "attraction_notes": str(payload.get("attraction_notes", "")).strip(),
        "avoid": str(payload.get("avoid", "")).strip(),
        "ethics_note": "AI companion is transparent. Do not imply a real person, real romantic obligation, or financial dependency.",
    }
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO visual_production_sessions (
              id, operator, character_name, companion_id, presentation, age_read, archetype,
              sensuality_level, realism_target, status, session_json, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                session_id,
                operator,
                character_name,
                companion_id,
                presentation,
                age_read,
                archetype,
                sensuality_level,
                realism_target,
                status,
                json.dumps(session, ensure_ascii=True),
                timestamp,
                timestamp,
            ),
        )
        conn.execute(
            """
            INSERT INTO visual_production_events (session_id, event_type, payload_json, created_at)
            VALUES (?, 'session_created', ?, ?)
            """,
            (session_id, json.dumps(payload, ensure_ascii=True), timestamp),
        )
        conn.commit()
    result = get_visual_session(session_id)
    assert result is not None
    write_visual_session_artifact(result)
    return result


def log_visual_event(session_id: str, event_type: str, payload: dict[str, Any]) -> dict[str, Any]:
    init_db()
    event_type = slugify(event_type).replace("-", "_") or "note"
    timestamp = now_iso()
    status = normalize_visual_status(payload.get("status"), "")
    with connect() as conn:
        row = conn.execute("SELECT id FROM visual_production_sessions WHERE id = ?", (session_id,)).fetchone()
        if not row:
            raise KeyError(session_id)
        conn.execute(
            """
            INSERT INTO visual_production_events (session_id, event_type, payload_json, created_at)
            VALUES (?, ?, ?, ?)
            """,
            (session_id, event_type, json.dumps(payload, ensure_ascii=True), timestamp),
        )
        if status:
            conn.execute(
                "UPDATE visual_production_sessions SET status = ?, updated_at = ? WHERE id = ?",
                (status, timestamp, session_id),
            )
        else:
            conn.execute("UPDATE visual_production_sessions SET updated_at = ? WHERE id = ?", (timestamp, session_id))
        conn.commit()
    result = get_visual_session(session_id)
    assert result is not None
    write_visual_session_artifact(result)
    return result


def write_visual_session_artifact(session: dict[str, Any]) -> None:
    session_dir = VISUAL_PRODUCTION_DIR / session["id"]
    session_dir.mkdir(parents=True, exist_ok=True)
    (session_dir / "session.json").write_text(json.dumps(session, indent=2, ensure_ascii=True), encoding="utf-8")
    latest_prompt = ""
    for event in reversed(session.get("events", [])):
        payload = event.get("payload", {})
        prompt = payload.get("prompt")
        if prompt:
            latest_prompt = str(prompt)
            break
    if latest_prompt:
        (session_dir / "latest-prompt.txt").write_text(latest_prompt + "\n", encoding="utf-8")


def latest_batch_prompt_map(kind: str = "photo-pack", scope: str = "starter") -> tuple[str | None, dict[str, str]]:
    with connect() as conn:
        row = conn.execute(
            """
            SELECT id, directory
            FROM batches
            WHERE kind = ? AND scope = ?
            ORDER BY created_at DESC, id DESC
            LIMIT 1
            """,
            (kind, scope),
        ).fetchone()
    if not row:
        return None, {}
    jsonl_path = Path(row["directory"]) / "prompts.jsonl"
    prompt_map: dict[str, str] = {}
    if jsonl_path.exists():
        for line in jsonl_path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                continue
            prompt_map[str(item.get("companion_id", ""))] = str(item.get("prompt", ""))
    return str(Path(row["directory"]) / "prompt_sheet.md"), prompt_map


def slack_api_request(method: str, payload: dict[str, Any]) -> dict[str, Any]:
    if not SLACK_BOT_TOKEN:
        raise RuntimeError("SLACK_BOT_TOKEN is not set. Factory can draft Slack assignments, but cannot post or monitor yet.")
    request = Request(
        f"https://slack.com/api/{method}",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {SLACK_BOT_TOKEN}",
            "Content-Type": "application/json; charset=utf-8",
        },
        method="POST",
    )
    with urlopen(request, timeout=20) as response:
        result = json.loads(response.read().decode("utf-8"))
    if not result.get("ok"):
        raise RuntimeError(f"Slack {method} failed: {result.get('error', 'unknown_error')}")
    return result


def slack_paginated_request(method: str, payload: dict[str, Any]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    cursor = ""
    while True:
        page_payload = dict(payload)
        if cursor:
            page_payload["cursor"] = cursor
        result = slack_api_request(method, page_payload)
        for key in ("channels", "members", "messages"):
            if key in result:
                items.extend(result[key])
                break
        cursor = result.get("response_metadata", {}).get("next_cursor", "")
        if not cursor:
            return items


def resolve_slack_channel_id(target: str) -> str:
    target = target.strip()
    if not target:
        raise ValueError("Missing Slack target. Add a Slack user, user ID, channel ID, or #channel to the delegate assignment.")
    mention_match = re.match(r"<[#@]([A-Z0-9]+)(?:\|[^>]+)?>", target)
    if mention_match:
        return mention_match.group(1)
    if re.match(r"^[CDGU][A-Z0-9]{7,}$", target):
        return target
    if target.startswith("#"):
        channel_name = target[1:].strip().lower()
        channels = slack_paginated_request(
            "conversations.list",
            {"types": "public_channel,private_channel", "exclude_archived": True, "limit": 200},
        )
        for channel in channels:
            if str(channel.get("name", "")).lower() == channel_name:
                return str(channel["id"])
        raise ValueError(f"Slack channel not found: {target}")
    if target.startswith("@"):
        user_name = target[1:].strip().lower()
        users = slack_paginated_request("users.list", {"limit": 200})
        for user in users:
            profile = user.get("profile", {})
            candidates = {
                str(user.get("name", "")).lower(),
                str(profile.get("display_name", "")).lower(),
                str(profile.get("real_name", "")).lower(),
            }
            if user_name in candidates:
                return str(user["id"])
        raise ValueError(f"Slack user not found: {target}")
    raise ValueError(f"Unsupported Slack target: {target}. Use a channel/user ID, #channel, @user, or Slack mention.")


def upsert_slack_assignment(record: dict[str, Any]) -> None:
    timestamp = now_iso()
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO slack_assignments (
              id, task_date, delegate_name, slack_target, channel_id, message_ts, message_link, status,
              companion_ids_json, slack_message, slack_draft_path, prompt_file_path,
              latest_reply_ts, latest_reply_text, error, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              slack_target = excluded.slack_target,
              channel_id = excluded.channel_id,
              message_ts = excluded.message_ts,
              message_link = excluded.message_link,
              status = excluded.status,
              companion_ids_json = excluded.companion_ids_json,
              slack_message = excluded.slack_message,
              slack_draft_path = excluded.slack_draft_path,
              prompt_file_path = excluded.prompt_file_path,
              latest_reply_ts = excluded.latest_reply_ts,
              latest_reply_text = excluded.latest_reply_text,
              error = excluded.error,
              updated_at = excluded.updated_at
            """,
            (
                record["id"],
                record["task_date"],
                record["delegate_name"],
                record.get("slack_target", ""),
                record.get("channel_id", ""),
                record.get("message_ts", ""),
                record.get("message_link", ""),
                record.get("status", "drafted"),
                json.dumps(record.get("companion_ids", []), ensure_ascii=True),
                record.get("slack_message", ""),
                record.get("slack_draft_path", ""),
                record.get("prompt_file_path", ""),
                record.get("latest_reply_ts", ""),
                record.get("latest_reply_text", ""),
                record.get("error", ""),
                record.get("created_at", timestamp),
                timestamp,
            ),
        )
        conn.commit()


def list_slack_assignments(limit: int = 20) -> dict[str, Any]:
    init_db()
    with connect() as conn:
        rows = conn.execute(
            "SELECT * FROM slack_assignments ORDER BY updated_at DESC LIMIT ?",
            (max(min(limit, 200), 1),),
        ).fetchall()
    items = []
    for row in rows:
        item = dict(row)
        item["companion_ids"] = json.loads(item.pop("companion_ids_json") or "[]")
        items.append(item)
    return {"items": items, "total": len(items), "slack_enabled": bool(SLACK_BOT_TOKEN)}


def post_slack_assignments() -> dict[str, Any]:
    generated = generate_delegate_tasks()
    posted: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    for task in generated["tasks"]:
        assignment_id = task["assignment_id"]
        try:
            channel_id = resolve_slack_channel_id(task["slack"])
            result = slack_api_request(
                "chat.postMessage",
                {
                    "channel": channel_id,
                    "text": task["slack_message"],
                    "unfurl_links": False,
                    "unfurl_media": False,
                },
            )
            record = {
                **task,
                "id": assignment_id,
                "task_date": generated["date"],
                "delegate_name": task["delegate"],
                "slack_target": task["slack"],
                "channel_id": channel_id,
                "message_ts": result.get("ts", ""),
                "message_link": result.get("message", {}).get("permalink", ""),
                "status": "posted",
                "slack_draft_path": task["slack_draft"],
                "prompt_file_path": task["prompt_file"],
                "error": "",
            }
            upsert_slack_assignment(record)
            posted.append(record)
        except Exception as exc:
            record = {
                **task,
                "id": assignment_id,
                "task_date": generated["date"],
                "delegate_name": task["delegate"],
                "slack_target": task["slack"],
                "status": "post_failed",
                "slack_draft_path": task["slack_draft"],
                "prompt_file_path": task["prompt_file"],
                "error": str(exc),
            }
            upsert_slack_assignment(record)
            errors.append({"delegate": task["delegate"], "error": str(exc)})
    return {"posted": len(posted), "failed": len(errors), "assignments": posted, "errors": errors, "drafts": generated}


def monitor_slack_assignments() -> dict[str, Any]:
    init_db()
    checked = 0
    updated = 0
    errors: list[dict[str, Any]] = []
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT * FROM slack_assignments
            WHERE channel_id != '' AND message_ts != '' AND status IN ('posted', 'in_progress')
            ORDER BY updated_at DESC
            LIMIT 50
            """
        ).fetchall()
    for row in rows:
        checked += 1
        try:
            result = slack_api_request(
                "conversations.replies",
                {"channel": row["channel_id"], "ts": row["message_ts"], "limit": 20},
            )
            replies = [message for message in result.get("messages", []) if message.get("ts") != row["message_ts"]]
            if not replies:
                continue
            latest = replies[-1]
            latest_text = str(latest.get("text", "")).strip()
            status = "in_progress"
            lower_text = latest_text.lower()
            if any(marker in lower_text for marker in ["done", "complete", "uploaded", "finished"]):
                status = "worker_reported_done"
            with connect() as conn:
                conn.execute(
                    """
                    UPDATE slack_assignments
                    SET status = ?, latest_reply_ts = ?, latest_reply_text = ?, updated_at = ?
                    WHERE id = ?
                    """,
                    (status, latest.get("ts", ""), latest_text, now_iso(), row["id"]),
                )
                conn.commit()
            updated += 1
        except Exception as exc:
            errors.append({"assignment_id": row["id"], "error": str(exc)})
    return {"checked": checked, "updated": updated, "errors": errors, "assignments": list_slack_assignments(limit=50)}


PHOTO_PACK_PROMPT_VARIATIONS = [
    "messy bedroom mirror selfie, phone covers 40 percent of her face, eyes looking down at phone, slouchy sweater, unmade bed",
    "friend-taken full-body walking photo from 8-12 feet away, side profile, looking across the street, motion blur in one hand",
    "cafe table photo from across the table, wider crop, both hands around a cup, looking down and smiling, hair partly covering face",
    "city-street candid from behind/side, three-quarter back view, turning her head only slightly, face partly hidden by hair",
    "at-home bed photo, sitting cross-legged, oversized tee, looking down at an open book or mug, face small in frame",
    "night-out flash photo, side profile, laughing at someone outside frame, other people blurred in background, not centered",
    "car passenger-seat selfie from a high awkward angle, sunglasses on head or face partly cropped, looking out the window",
    "hobby/personality photo, hands busy with makeup, sketchbook, coffee, or camera, face off-center and not looking at camera",
    "avatar crop, different hair placement, chin slightly down, eyes looking left or right, asymmetrical framing",
]


FEMALE_REFERENCE_STYLE = (
            "Style: fictional woman, 21-24 clearly adult, natural Instagram/iPhone beauty, soft face, healthy skin, expressive eyes, full lips, slim/toned figure. "
            "Tasteful sensuality okay. Ignore text overlays. Do not copy a real face."
)

FEMALE_CAST_VARIATIONS = [
    {
        "ethnicity": "East Asian or mixed East Asian visual direction",
        "hair": "long dark brunette wavy hair",
        "wardrobe": "white tank, soft cardigan, clean denim, delicate gold jewelry",
        "situations": "sunlit bedroom mirror selfie, cafe table, car selfie, warm apartment morning",
    },
    {
        "ethnicity": "Latina or mixed Latina visual direction",
        "hair": "deep brunette glossy waves",
        "wardrobe": "black fitted dress, small hoops, simple rings, summer terrace styling",
        "situations": "coastal cafe, golden-hour street photo, dinner table, vacation balcony",
    },
    {
        "ethnicity": "Black or mixed Black visual direction",
        "hair": "soft black curls or long protective style",
        "wardrobe": "cream knit top, fitted denim, minimal jewelry, polished casual style",
        "situations": "bright cafe, plant-filled apartment, bookstore corner, low-light restaurant",
    },
    {
        "ethnicity": "white European or Mediterranean visual direction",
        "hair": "dark blonde or honey blonde layered hair",
        "wardrobe": "white linen, black trousers, ballet flats, understated jewelry",
        "situations": "old-city street, hotel bathroom mirror, coffee shop, sunny window seat",
    },
    {
        "ethnicity": "South Asian or mixed South Asian visual direction",
        "hair": "long dark brown glossy hair",
        "wardrobe": "navy fitted dress, gold earrings, soft makeup, elegant evening styling",
        "situations": "warm restaurant booth, rooftop night-out, mirror selfie, cafe table",
    },
    {
        "ethnicity": "Middle Eastern or Mediterranean visual direction",
        "hair": "thick espresso-brown waves",
        "wardrobe": "black off-shoulder top, tailored denim, gold bracelets, soft glam makeup",
        "situations": "cream bathroom mirror, dinner lounge, car selfie, night street candid",
    },
    {
        "ethnicity": "Southeast Asian or Pacific Islander visual direction",
        "hair": "dark brown beachy waves",
        "wardrobe": "fitted white tee, linen skirt, simple necklace, clean vacation style",
        "situations": "coastal terrace, bedroom morning, outdoor cafe, sunlit market street",
    },
    {
        "ethnicity": "Brazilian, Italian, or mixed Latin European visual direction",
        "hair": "voluminous dark curls with warm highlights",
        "wardrobe": "red or cream fitted top, denim, hoops, glossy natural makeup",
        "situations": "music bar, cafe counter, mirror selfie, golden-hour sidewalk",
    },
    {
        "ethnicity": "white or mixed Slavic visual direction",
        "hair": "cool blonde or light brown hair",
        "wardrobe": "soft grey cardigan, white tank, black jeans, silver jewelry",
        "situations": "minimal bedroom, car selfie, coffee shop, rainy-window apartment",
    },
    {
        "ethnicity": "mixed Brazilian or Portuguese visual direction",
        "hair": "sun-kissed brunette hair with loose waves",
        "wardrobe": "blue fitted dress, sandals, delicate rings, warm vacation styling",
        "situations": "terrace lunch, beach-town street, cafe table, evening balcony",
    },
    {
        "ethnicity": "British, Portuguese, or Mediterranean visual direction",
        "hair": "long sleek black hair or long dark waves",
        "wardrobe": "cream sleeveless top, tailored skirt, minimal gold jewelry",
        "situations": "gallery cafe, hotel mirror, city street, candlelit restaurant",
    },
    {
        "ethnicity": "mixed European and Asian visual direction",
        "hair": "chestnut brown layered hair",
        "wardrobe": "black tank, oversized shirt, clean denim, understated jewelry",
        "situations": "messy bed morning, elevator mirror, cafe booth, bookstore selfie",
    },
]


def female_cast_variation(companion: dict[str, Any]) -> dict[str, str]:
    rank = int(companion.get("starter_rank") or 1)
    index = ((rank - 1) // 2) % len(FEMALE_CAST_VARIATIONS)
    return FEMALE_CAST_VARIATIONS[index]


def simple_iphone_prompts(companion: dict[str, Any]) -> list[str]:
    visual = str(companion.get("visual_direction", "")).replace("Primary visual language:", "").strip().rstrip(".")
    brief = str(companion.get("character_brief", "")).strip()
    anchor = brief or visual or "attractive, realistic, memorable, and emotionally magnetic"
    is_female = str(companion.get("gender", "")).lower() == "female"
    age_line = "Age: looks 21-24 and clearly adult." if is_female else "Age: looks 25-35."
    if is_female:
        variation = female_cast_variation(companion)
        style_line = (
            f"{FEMALE_REFERENCE_STYLE} "
            f"Cast: {variation['ethnicity']}; {variation['hair'].replace('long ', '').replace('soft ', '')}; "
            f"outfits: {variation['wardrobe']}; situations: {variation['situations']}."
        )
    else:
        style_line = "Make the person attractive, realistic, memorable, and emotionally magnetic."
    prompts: list[str] = [
        (
            f"1. Create a new fictional adult person named {companion['display_name']}. "
            f"Gender/presentation: {companion['gender']}. {age_line} "
            "Make a realistic iPhone close face portrait with relaxed eye contact. Use natural asymmetry, tiny skin texture, and a real phone-photo feel. "
            "This first image creates the identity. "
            f"{style_line} "
            f"Visual feel: {anchor}. "
            "Avoid a perfect centered AI-model face. No text, logo, celebrity look, nudity, or explicit pose."
        )
    ]
    for index, prompt_type in enumerate(PHOTO_PACK_PROMPT_VARIATIONS, start=2):
        prompts.append(
            f"{index}. Same fictional person from image 1: {companion['display_name']}. "
            f"New candid iPhone photo: {prompt_type}. "
            "Same person, but no front-facing beauty pose. Change gaze, outfit, crop, distance, and body. Face turned/hidden/down/sideways/farther. Imperfect. No text or nudity."
        )
    return prompts


def generate_delegate_tasks() -> dict[str, Any]:
    init_db()
    task_date = datetime.now().strftime("%Y-%m-%d")
    task_dir = DAILY_TASKS_DIR / task_date
    task_dir.mkdir(parents=True, exist_ok=True)
    prompt_sheet, prompt_map = latest_batch_prompt_map()
    with connect() as conn:
        rows = conn.execute(
            """
            SELECT *
            FROM companions
            WHERE is_starter = 1
              AND (photo_count < target_photo_count OR target_photo_count < 1)
            ORDER BY delegate_name, starter_rank
            """
        ).fetchall()
    grouped: dict[str, list[dict[str, Any]]] = {}
    for row in rows:
        companion = companion_from_row(row)
        delegate = companion.get("delegate_name") or "Unassigned"
        cloud_path = companion.get("cloud_folder_path") or str(CLOUD_DROP_DIR / slugify(delegate) / companion["id"])
        Path(cloud_path).mkdir(parents=True, exist_ok=True)
        companion["cloud_folder_path"] = cloud_path
        grouped.setdefault(delegate, []).append(companion)

    task_files: list[dict[str, Any]] = []
    summary = {
        "date": task_date,
        "task_directory": str(task_dir),
        "prompt_sheet": prompt_sheet,
        "delegates": [],
    }
    for delegate, companions in grouped.items():
        companions = companions[:1]
        delegate_slug = slugify(delegate) or "unassigned"
        first_slack = next((item.get("delegate_slack") for item in companions if item.get("delegate_slack")), "")
        slack_path = task_dir / f"{delegate_slug}-slack.md"
        prompts_path = task_dir / f"{delegate_slug}-prompts.md"
        slack_lines = [
            f"To: {first_slack or '[add Slack @handle or #channel]'}",
            "",
            f"*Simastry Factory task - {task_date}*",
            f"Hi {delegate},",
            "",
            "Do this character.",
            "",
            "*Use your iPhone.*",
            "1. Open the ChatGPT app.",
            "2. Start a new chat.",
            "3. Choose image generation.",
            "4. Paste prompt 1 and save image 1.",
            "5. Prompts 2-10: same chat. Attach image 1 only if face drifts.",
            "6. Paste the next prompt and save each image.",
            "7. Reply here with all 10 images, then type `done`.",
            "",
            "*Important rules*",
            "- Upload here.",
            "- Make 10 separate images.",
            "- Prompt 1 creates the person.",
            "- Prompts 2-10 keep identity, not pose.",
            "- Must look adult, 21+.",
            "- Make the person attractive and real.",
            "- Do not add words, logos, or watermarks.",
            "- No nudity or explicit poses.",
            "",
            "*Character*",
        ]
        prompt_lines = [
            f"# {delegate} prompts - {task_date}",
            "",
            f"Style reference folder: `{REFERENCES_DIR}`",
            "",
        ]
        for companion in companions:
            remaining = companion["remaining_photo_count"]
            slack_lines.extend(
                [
                    f"Name: {companion['display_name']}",
                    f"Factory ID: `{companion['id']}`",
                    f"Need: {remaining}",
                    "",
                    "*Copy and paste these 10 prompts one at a time*",
                ]
            )
            prompts = simple_iphone_prompts(companion)
            slack_lines.extend(prompts)
            if companion.get("character_brief"):
                slack_lines.append(f"Character note: {companion['character_brief']}")
            if companion.get("identity_reference_count"):
                slack_lines.append("There are saved reference images for this character. Ask before changing the face.")
            prompt_lines.extend(
                [
                    f"## {companion['display_name']} - {companion['id']}",
                    "",
                    "Upload destination: the Slack assignment thread.",
                    f"Factory import folder for owner review: `{companion['cloud_folder_path']}`",
                    "",
                    "\n".join(prompts),
                    "",
                ]
            )
        slack_lines.extend(
            [
                "",
                "When you upload the 10 images, reply `done` in this thread.",
            ]
        )
        slack_path.write_text("\n".join(slack_lines), encoding="utf-8")
        prompts_path.write_text("\n".join(prompt_lines), encoding="utf-8")
        task_record = {
            "assignment_id": f"{task_date}-{delegate_slug}",
            "delegate": delegate,
            "slack": first_slack,
            "companion_count": len(companions),
            "companion_ids": [companion["id"] for companion in companions],
            "slack_message": "\n".join(slack_lines),
            "slack_draft": str(slack_path),
            "prompt_file": str(prompts_path),
        }
        task_files.append(task_record)
        summary["delegates"].append(task_record)
        upsert_slack_assignment(
            {
                "id": task_record["assignment_id"],
                "task_date": task_date,
                "delegate_name": delegate,
                "slack_target": first_slack,
                "status": "drafted",
                "companion_ids": task_record["companion_ids"],
                "slack_message": task_record["slack_message"],
                "slack_draft_path": str(slack_path),
                "prompt_file_path": str(prompts_path),
                "error": "",
            }
        )
    summary_path = task_dir / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return {"date": task_date, "created": len(task_files), "task_directory": str(task_dir), "summary": str(summary_path), "tasks": task_files}


def prompt_for_kind(companion: sqlite3.Row, kind: str) -> str:
    combo_label = f"{companion['sun_sign']} Sun / {companion['moon_sign']} Moon / {companion['rising_sign']} Rising"
    app_character_name = companion["app_character_name"] if "app_character_name" in companion.keys() else ""
    app_sources = companion["app_sources"] if "app_sources" in companion.keys() else ""
    character_source = companion["character_source"] if "character_source" in companion.keys() else "generated_from_scratch"
    character_brief = companion["character_brief"] if "character_brief" in companion.keys() else ""
    identity_dir = identity_reference_dir(companion)
    identity_count = len(list_identity_reference_files(companion))
    if character_source == "existing_character":
        character_instruction = (
            "This Starter 24 companion already has an intended character. Use any provided character reference or brief "
            "as the identity anchor. Preserve the same face, age range, hair, body type, and personal style across the set."
        )
        if character_brief:
            character_instruction += f"\nExisting character brief: {character_brief}"
        if app_character_name:
            character_instruction += (
                f"\nExisting Simastry app character anchor: {app_character_name}. "
                f"Detected source surfaces: {app_sources or 'Factory app sync'}. "
                "Use this as the naming and app-continuity bridge, while preserving this companion variant's own gender, face, and identity references."
            )
        character_instruction += (
            f"\nIdentity reference folder: {identity_dir}. "
            f"{identity_count} reference image(s) are currently saved there. "
            "Attach 1-3 of those images when available so GPT Image 2 keeps the existing character's identity."
        )
    else:
        character_instruction = (
            "This companion can be generated from scratch. Invent a believable original person and keep that identity "
            "consistent across the full set."
        )
    reference_hint = (
        "Before generating, attach 2-4 style reference images from Factory's style board if you want GPT Image 2 "
        f"to match the look. Local style-board folder: {REFERENCES_DIR}. "
        "Use those only as aesthetic references for lighting, realism, camera feel, outfit taste, and social-photo style; "
        "do not copy the identity of any person in a reference image."
    )
    base = companion["prompt_core"]
    assigned_folder = companion["cloud_folder_path"] or str(IMPORTS_DIR / companion["id"])
    app_anchor_line = f"App-facing character anchor: {app_character_name}.\n" if app_character_name else ""
    female_standard = f"{FEMALE_PORTRAIT_STANDARD}\n\n" if companion["gender"] == "female" else ""
    male_standard = f"{MALE_PORTRAIT_STANDARD}\n\n" if companion["gender"] == "male" else ""
    if kind == "photo-pack":
        return (
            "Use GPT Image 2 to generate 10 individual realistic pictures of the same fictional person.\n\n"
            f"Person: {companion['display_name']}, {companion['gender']}, {combo_label}.\n"
            f"{app_anchor_line}"
            f"Visual direction: {companion['visual_direction']}\n\n"
            f"{character_instruction}\n\n"
            f"{reference_hint}\n\n"
            f"{IMAGE_REALISM_STANDARD}\n\n"
            f"{POSE_VARIATION_STANDARD}\n\n"
            f"{CAST_DISTINCTION_STANDARD}\n\n"
            f"{female_standard}"
            f"{male_standard}"
            "The output should feel like a strong dating-app and Instagram profile set: casual, natural, varied, and believable. "
            "Do not make the person look like a polished model, AI influencer, or fashion editorial subject. "
            "Keep the same face, age, hair, body type, and overall identity across all 10 images. "
            "Make each image a separate photo, not a collage, and avoid near-duplicate poses or repeated selfie angles.\n\n"
            f"After downloading, save the files into the assigned folder `{assigned_folder}`. "
            f"The local imports folder `workspace/imports/{companion['id']}/` also works. Use names like "
            f"`{companion['id']}__photo_pack__01.png` through `{companion['id']}__photo_pack__10.png`.\n\n"
            "Generate exactly these 10 distinct images:\n"
            "1. Close portrait with relaxed eye contact, available light, casual dating-app first-photo energy.\n"
            "2. Mirror selfie or elevator selfie, realistic phone-photo framing, slight framing imperfection.\n"
            "3. Outdoor candid walking photo, full-body or three-quarter crop, natural movement.\n"
            "4. Cafe or dinner-table photo, warm social setting, believable lifestyle detail.\n"
            "5. Travel or city-street photo, environmental but still focused on the person.\n"
            "6. At-home candid, comfortable and ordinary, not staged like a studio portrait.\n"
            "7. Night-out photo, real low light and phone-camera grain, believable Instagram feel.\n"
            "8. Hobby or personality photo, subtle story, no props that feel random or costume-like.\n"
            "9. Clean profile/avatar crop suitable for Astrogram.\n"
            "10. Primary Simastry card portrait, vertical 2:3 crop, phone-photo realistic rather than cinematic.\n\n"
            "Constraints: no text, no captions, no UI, no zodiac glyphs, no logos, no watermarks, no extra people as the focus, "
            "no celebrity resemblance, no plastic AI skin, no fantasy costume, no corporate headshot, no generic model face."
        )
    if kind == "card":
        return (
            f"{base}\n\n"
            f"{reference_hint}\n\n"
            f"{IMAGE_REALISM_STANDARD}\n\n"
            f"{CAST_DISTINCTION_STANDARD}\n\n"
            f"{female_standard}"
            f"{male_standard}"
            "Use a distinct pose and setting from other approved images for this companion.\n\n"
            "Asset target: primary companion card portrait. "
            "Vertical 2:3 crop, face and upper body clear, app-ready, phone-photo realistic, not overproduced."
        )
    if kind == "profile":
        return (
            f"{base}\n\n"
            f"{reference_hint}\n\n"
            f"{IMAGE_REALISM_STANDARD}\n\n"
            f"{CAST_DISTINCTION_STANDARD}\n\n"
            f"{female_standard}"
            f"{male_standard}"
            "Use a distinct pose and setting from other approved images for this companion.\n\n"
            "Asset target: Astrogram profile portrait. "
            "Square crop, approachable social profile energy, same person and identity, casual phone-photo realism."
        )
    if kind == "social-photo":
        return (
            f"{base}\n\n"
            f"{reference_hint}\n\n"
            f"{IMAGE_REALISM_STANDARD}\n\n"
            f"{POSE_VARIATION_STANDARD}\n\n"
            f"{CAST_DISTINCTION_STANDARD}\n\n"
            f"{female_standard}"
            f"{male_standard}"
            "Asset target: Astrogram feed photo set. "
            "Make a candid iPhone-style lifestyle image that still clearly matches the same companion. "
            "No phone screenshots, captions, UI, text, or visible brand marks."
        )
    if kind == "video-brief":
        return (
            "Create a short video concept brief for this companion. "
            f"Companion: {companion['title']}. Personality: {companion['voice']} "
            f"Visual direction: {companion['visual_direction']} "
            "Target: quiet premium Astrogram video, 5-8 seconds, one person only, intimate movement, no text, no logo."
        )
    raise ValueError(f"Unknown batch kind: {kind}")


def create_batch(kind: str = "photo-pack", count: int = 24, status_filter: str = "active", scope: str = "starter") -> dict[str, Any]:
    init_db()
    allowed_kinds = {"photo-pack", "card", "profile", "social-photo", "video-brief"}
    if kind not in allowed_kinds:
        raise ValueError(f"Unknown batch kind: {kind}")
    if scope not in {"starter", "all"}:
        raise ValueError(f"Unknown batch scope: {scope}")
    count = min(max(int(count), 1), 500)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    batch_id = f"{timestamp}-{scope}-{kind}"
    batch_dir = BATCHES_DIR / batch_id
    batch_dir.mkdir(parents=True, exist_ok=True)
    scope_sql = "AND is_starter = 1" if scope == "starter" else ""
    if status_filter == "active":
        status_sql = "status IN ('todo', 'queued', 'generated', 'reviewed')"
        query_args: list[Any] = [count]
    else:
        status_sql = "status = ?"
        query_args = [status_filter, count]
    with connect() as conn:
        rows = conn.execute(
            f"""
            SELECT *
            FROM companions
            WHERE {status_sql}
            {scope_sql}
            ORDER BY CASE WHEN is_starter = 1 THEN 0 ELSE 1 END,
                     COALESCE(NULLIF(starter_rank, 0), index_number),
                     index_number ASC
            LIMIT ?
            """,
            query_args,
        ).fetchall()
        if not rows and status_filter == "todo":
            rows = conn.execute(
                f"""
                SELECT *
                FROM companions
                WHERE status IN ('queued', 'generated', 'reviewed')
                {scope_sql}
                ORDER BY CASE WHEN is_starter = 1 THEN 0 ELSE 1 END,
                         COALESCE(NULLIF(starter_rank, 0), index_number),
                         index_number ASC
                LIMIT ?
                """,
                (count,),
            ).fetchall()
        prompts: list[dict[str, Any]] = []
        prompt_sheet_lines = [
            f"# Factory Batch: {batch_id}",
            "",
            f"Kind: {kind}",
            f"Scope: {'Starter 24' if scope == 'starter' else 'All companions'}",
            f"Companions: {len(rows)}",
            f"Reference style board: `{REFERENCES_DIR}`",
            "",
            "Save outputs into `workspace/imports/<companion-id>/` so the scanner can place them correctly. "
            "If GPT gives 10 files for one companion, save all 10 into that companion's import folder.",
            "",
        ]
        for batch_index, row in enumerate(rows, start=1):
            prompt = prompt_for_kind(row, kind)
            suggested_name = f"{row['id']}__{kind.replace('-', '_')}__01"
            import_folder = IMPORTS_DIR / row["id"]
            import_folder.mkdir(parents=True, exist_ok=True)
            prompt_record = {
                "batch_id": batch_id,
                "sequence": batch_index,
                "companion_id": row["id"],
                "slug": row["slug"],
                "title": row["title"],
                "gender": row["gender"],
                "signs": {
                    "sun": row["sun_sign"],
                    "moon": row["moon_sign"],
                    "rising": row["rising_sign"],
                },
                "folder_path": row["folder_path"],
                "suggested_import_folder": f"workspace/imports/{row['id']}/",
                "suggested_file_stem": suggested_name,
                "prompt": prompt,
            }
            prompts.append(prompt_record)
            prompt_filename = f"{batch_index:03d}__{row['id']}__{kind}.txt"
            (batch_dir / prompt_filename).write_text(prompt + "\n", encoding="utf-8")
            companion_prompt = Path(row["folder_path"]) / "prompts" / f"{batch_id}.txt"
            companion_prompt.parent.mkdir(parents=True, exist_ok=True)
            companion_prompt.write_text(prompt + "\n", encoding="utf-8")
            prompt_sheet_lines.extend(
                [
                    f"## {batch_index:03d}. {row['title']}",
                    "",
                    f"Companion id: `{row['id']}`",
                    f"Import folder: `workspace/imports/{row['id']}/`",
                    f"Suggested file stem: `{suggested_name}`",
                    "",
                    "```text",
                    prompt,
                    "```",
                    "",
                ]
            )
        (batch_dir / "prompts.jsonl").write_text(
            "\n".join(json.dumps(item, ensure_ascii=True) for item in prompts) + ("\n" if prompts else ""),
            encoding="utf-8",
        )
        (batch_dir / "prompt_sheet.md").write_text("\n".join(prompt_sheet_lines), encoding="utf-8")
        with (batch_dir / "prompt_index.csv").open("w", encoding="utf-8", newline="") as csv_file:
            writer = csv.DictWriter(
                csv_file,
                fieldnames=[
                    "sequence",
                    "companion_id",
                    "title",
                    "gender",
                    "sun",
                    "moon",
                    "rising",
                    "suggested_import_folder",
                    "suggested_file_stem",
                ],
            )
            writer.writeheader()
            for item in prompts:
                writer.writerow(
                    {
                        "sequence": item["sequence"],
                        "companion_id": item["companion_id"],
                        "title": item["title"],
                        "gender": item["gender"],
                        "sun": item["signs"]["sun"],
                        "moon": item["signs"]["moon"],
                        "rising": item["signs"]["rising"],
                        "suggested_import_folder": item["suggested_import_folder"],
                        "suggested_file_stem": item["suggested_file_stem"],
                    }
                )
        if rows:
            conn.executemany(
                "UPDATE companions SET status = 'queued', last_batch_id = ?, updated_at = ? WHERE id = ?",
                [(batch_id, now_iso(), row["id"]) for row in rows],
            )
        conn.execute(
            "INSERT OR REPLACE INTO batches (id, kind, label, scope, companion_count, directory, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (batch_id, kind, f"{scope} {kind} batch", scope, len(rows), str(batch_dir), now_iso()),
        )
        conn.commit()
    return {
        "id": batch_id,
        "kind": kind,
        "scope": scope,
        "count": len(rows),
        "directory": str(batch_dir),
        "prompt_sheet": str(batch_dir / "prompt_sheet.md"),
        "jsonl": str(batch_dir / "prompts.jsonl"),
        "csv": str(batch_dir / "prompt_index.csv"),
    }


def infer_asset_type(path: Path) -> str:
    name = path.name.lower()
    suffix = path.suffix.lower()
    if suffix in VIDEO_EXTENSIONS:
        return "video"
    if "card" in name:
        return "card"
    if "profile" in name or "avatar" in name:
        return "profile"
    return "photo"


def target_subdir_for_asset(asset_type: str) -> str:
    if asset_type == "card":
        return "card"
    if asset_type == "profile":
        return "astrogram/profile"
    if asset_type == "video":
        return "astrogram/videos"
    return "astrogram/photos"


def scan_imports() -> dict[str, Any]:
    init_db()
    imported = 0
    skipped = 0
    unmatched: list[str] = []
    with connect() as conn:
        rows = conn.execute("SELECT id, slug, folder_path, cloud_folder_path FROM companions").fetchall()
        lookup: dict[str, sqlite3.Row] = {}
        for row in rows:
            lookup[row["id"].lower()] = row
            lookup[row["slug"].lower()] = row
        source_entries: list[tuple[Path, str | None]] = [(IMPORTS_DIR, None), (CLOUD_DROP_DIR, None)]
        for row in rows:
            if row["cloud_folder_path"]:
                source_entries.append((Path(row["cloud_folder_path"]), row["id"]))
        files: list[tuple[Path, Path, str | None]] = []
        for root, forced_companion_id in source_entries:
            if not root.exists():
                continue
            files.extend(
                (root, path, forced_companion_id)
                for path in root.rglob("*")
                if path.is_file() and path.suffix.lower() in ASSET_EXTENSIONS and "README" not in path.name
            )
        for root, source, forced_companion_id in files:
            if conn.execute("SELECT 1 FROM assets WHERE source_path = ? LIMIT 1", (str(source),)).fetchone():
                skipped += 1
                continue
            if forced_companion_id:
                matched = lookup.get(forced_companion_id.lower())
            else:
                parts = [part.lower() for part in source.relative_to(root).parts]
                matched = None
                for key, row in lookup.items():
                    if key in parts or key in source.name.lower():
                        matched = row
                        break
            if not matched:
                unmatched.append(str(source))
                skipped += 1
                continue
            asset_type = infer_asset_type(source)
            destination_dir = Path(matched["folder_path"]) / target_subdir_for_asset(asset_type)
            destination_dir.mkdir(parents=True, exist_ok=True)
            destination = destination_dir / source.name
            if destination.exists():
                stem = destination.stem
                suffix = destination.suffix
                destination = destination_dir / f"{stem}-{int(time.time())}{suffix}"
            shutil.copy2(source, destination)
            try:
                conn.execute(
                    """
                    INSERT INTO assets (companion_id, asset_type, local_path, source_path, batch_id, created_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        matched["id"],
                        asset_type,
                        str(destination),
                        str(source),
                        None,
                        now_iso(),
                    ),
                )
            except sqlite3.IntegrityError:
                skipped += 1
                continue
            imported += 1
        conn.execute(
            """
            UPDATE companions
            SET
              card_count = (SELECT COUNT(*) FROM assets WHERE assets.companion_id = companions.id AND asset_type = 'card'),
              photo_count = (SELECT COUNT(*) FROM assets WHERE assets.companion_id = companions.id AND asset_type IN ('photo', 'profile')),
              video_count = (SELECT COUNT(*) FROM assets WHERE assets.companion_id = companions.id AND asset_type = 'video'),
              status = CASE
                WHEN status IN ('todo', 'queued') AND EXISTS (SELECT 1 FROM assets WHERE assets.companion_id = companions.id)
                THEN 'generated'
                ELSE status
              END,
              updated_at = ?
            """,
            (now_iso(),),
        )
        conn.commit()
    return {
        "imported": imported,
        "skipped": skipped,
        "unmatched": unmatched[:30],
        "imports": str(IMPORTS_DIR),
        "cloud_drop": str(CLOUD_DROP_DIR),
    }


def export_catalog_csv() -> Path:
    init_db()
    export_path = WORKSPACE_DIR / "simastry_companion_catalog.csv"
    with connect() as conn, export_path.open("w", encoding="utf-8", newline="") as csv_file:
        rows = conn.execute("SELECT * FROM companions ORDER BY index_number ASC").fetchall()
        fieldnames = [
            "id",
            "is_starter",
            "starter_rank",
            "display_name",
            "gender",
            "sun_sign",
            "moon_sign",
            "rising_sign",
            "title",
            "archetype",
            "status",
            "card_count",
            "photo_count",
            "video_count",
            "folder_path",
        ]
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row[field] for field in fieldnames})
    return export_path


class AssetFactoryHandler(BaseHTTPRequestHandler):
    server_version = "SimastryAssetFactory/0.1"

    def log_message(self, format: str, *args: Any) -> None:
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), format % args))

    def read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("content-length", "0") or "0")
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        return json.loads(raw.decode("utf-8"))

    def send_json(self, payload: Any, status_code: int = 200) -> None:
        body = json.dumps(payload, indent=2, ensure_ascii=True).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_error_json(self, message: str, status_code: int = 400) -> None:
        self.send_json({"error": message}, status_code)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = unquote(parsed.path)
        try:
            if path == "/api/stats":
                self.send_json(stats())
                return
            if path == "/api/references":
                self.send_json(list_references())
                return
            if path.startswith("/api/references/file/"):
                filename = safe_filename(path.removeprefix("/api/references/file/").strip("/"))
                reference_path = (REFERENCES_DIR / filename).resolve()
                if not str(reference_path).startswith(str(REFERENCES_DIR.resolve())) or not reference_path.exists():
                    self.send_error_json("Reference not found", 404)
                    return
                mime_type = mimetypes.guess_type(str(reference_path))[0] or "application/octet-stream"
                body = reference_path.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", mime_type)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            if path == "/api/companions":
                self.send_json(list_companions(parse_qs(parsed.query)))
                return
            if path == "/api/app-characters":
                self.send_json(list_app_characters())
                return
            if path == "/api/slack-assignments":
                query = parse_qs(parsed.query)
                limit = int((query.get("limit") or ["20"])[0])
                self.send_json(list_slack_assignments(limit=limit))
                return
            if path == "/api/visual-production/sessions":
                query = parse_qs(parsed.query)
                limit = int((query.get("limit") or ["40"])[0])
                self.send_json(list_visual_sessions(limit=limit))
                return
            if path.startswith("/api/visual-production/sessions/"):
                session_id = path.removeprefix("/api/visual-production/sessions/").strip("/")
                session = get_visual_session(session_id)
                if not session:
                    self.send_error_json("Visual production session not found", 404)
                    return
                self.send_json(session)
                return
            if path.startswith("/api/companions/") and "/identity-references/file/" in path:
                rest = path.removeprefix("/api/companions/")
                companion_id, filename = rest.split("/identity-references/file/", 1)
                companion = get_companion(companion_id)
                if not companion:
                    self.send_error_json("Companion not found", 404)
                    return
                reference_path = (identity_reference_dir(companion) / safe_filename(filename)).resolve()
                reference_root = identity_reference_dir(companion).resolve()
                if not str(reference_path).startswith(str(reference_root)) or not reference_path.exists():
                    self.send_error_json("Reference not found", 404)
                    return
                mime_type = mimetypes.guess_type(str(reference_path))[0] or "application/octet-stream"
                body = reference_path.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", mime_type)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            if path.startswith("/api/companions/"):
                companion_id = path.removeprefix("/api/companions/").strip("/")
                companion = get_companion(companion_id)
                if not companion:
                    self.send_error_json("Companion not found", 404)
                    return
                self.send_json(companion)
                return
            if path == "/api/export/catalog.csv":
                export_path = export_catalog_csv()
                body = export_path.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "text/csv; charset=utf-8")
                self.send_header("Content-Disposition", 'attachment; filename="simastry_companion_catalog.csv"')
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return
            self.serve_static(path)
        except Exception as exc:
            self.send_error_json(str(exc), 500)

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = unquote(parsed.path)
        try:
            payload = self.read_json()
            if path == "/api/seed":
                self.send_json(seed_catalog(create_folders=True))
                return
            if path == "/api/batches":
                self.send_json(
                    create_batch(
                        kind=payload.get("kind", "photo-pack"),
                        count=int(payload.get("count", 24)),
                        status_filter=payload.get("status", "active"),
                        scope=payload.get("scope", "starter"),
                    )
                )
                return
            if path == "/api/references/upload":
                self.send_json(save_reference_uploads(payload.get("files", [])))
                return
            if path in {"/api/slack-tasks/generate", "/api/delegate-tasks/generate"}:
                self.send_json(generate_delegate_tasks())
                return
            if path == "/api/slack-assignments/push":
                self.send_json(post_slack_assignments())
                return
            if path == "/api/slack-assignments/monitor":
                self.send_json(monitor_slack_assignments())
                return
            if path == "/api/simastry/sync":
                self.send_json(sync_simastry_apps())
                return
            if path == "/api/linear/drafts":
                self.send_json(generate_linear_drafts())
                return
            if path == "/api/imports/scan":
                self.send_json(scan_imports())
                return
            if path == "/api/visual-production/sessions":
                self.send_json(create_visual_session(payload))
                return
            if path.startswith("/api/visual-production/sessions/") and path.endswith("/events"):
                session_id = path.removeprefix("/api/visual-production/sessions/").removesuffix("/events").strip("/")
                self.send_json(log_visual_event(session_id, payload.get("event_type", "note"), payload))
                return
            if path.startswith("/api/companions/") and path.endswith("/identity-references/upload"):
                companion_id = path.removeprefix("/api/companions/").removesuffix("/identity-references/upload").strip("/")
                self.send_json(save_identity_reference_uploads(companion_id, payload.get("files", [])))
                return
            if path.startswith("/api/companions/") and path.endswith("/production"):
                companion_id = path.removeprefix("/api/companions/").removesuffix("/production").strip("/")
                self.send_json(update_production(companion_id, payload))
                return
            if path.startswith("/api/companions/") and path.endswith("/status"):
                companion_id = path.removeprefix("/api/companions/").removesuffix("/status").strip("/")
                self.send_json(set_status(companion_id, payload.get("status", "todo"), payload.get("notes")))
                return
            self.send_error_json("Route not found", 404)
        except KeyError:
            self.send_error_json("Companion not found", 404)
        except Exception as exc:
            self.send_error_json(str(exc), 500)

    def serve_static(self, path: str) -> None:
        if path == "/":
            path = "/index.html"
        requested = (STATIC_DIR / path.lstrip("/")).resolve()
        if not str(requested).startswith(str(STATIC_DIR.resolve())):
            self.send_error(403)
            return
        if not requested.exists() or not requested.is_file():
            self.send_error(404)
            return
        mime_type = mimetypes.guess_type(str(requested))[0] or "application/octet-stream"
        body = requested.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", mime_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def serve(port: int) -> None:
    init_db()
    address = ("127.0.0.1", port)
    httpd = ThreadingHTTPServer(address, AssetFactoryHandler)
    print(f"Factory running at http://127.0.0.1:{port}")
    print(f"Workspace: {WORKSPACE_DIR}")
    httpd.serve_forever()


def main() -> None:
    parser = argparse.ArgumentParser(description="Local Simastry Factory manager")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--seed", action="store_true", help="Seed 3,456 companions before serving")
    parser.add_argument("--seed-only", action="store_true", help="Seed companions and exit")
    parser.add_argument("--scan-imports", action="store_true", help="Scan imports and exit")
    parser.add_argument("--batch", choices=["photo-pack", "card", "profile", "social-photo", "video-brief"], help="Create a batch and exit")
    parser.add_argument("--count", type=int, default=24, help="Batch size")
    parser.add_argument("--scope", choices=["starter", "all"], default="starter", help="Batch scope")
    parser.add_argument("--status", default="active", help="Batch status filter")
    args = parser.parse_args()

    init_db()
    if args.seed or args.seed_only:
        result = seed_catalog(create_folders=True)
        print(json.dumps(result, indent=2))
    if args.scan_imports:
        print(json.dumps(scan_imports(), indent=2))
        return
    if args.batch:
        print(json.dumps(create_batch(args.batch, args.count, status_filter=args.status, scope=args.scope), indent=2))
        return
    if args.seed_only:
        return
    serve(args.port)


if __name__ == "__main__":
    main()
