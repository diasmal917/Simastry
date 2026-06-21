#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import posixpath
import re
import shutil
import subprocess
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, quote, unquote, urlparse


ROOT = Path(__file__).resolve().parent
APP_ROOT = ROOT.parent
WORKSPACE = ROOT / "workspace"
ORIGINALS_DIR = WORKSPACE / "originals"
CROPS_FILE = WORKSPACE / "app-preview-crops.json"
EXPORTS_DIR = WORKSPACE / "ios-companion-exports"
STATIC_DIR = ROOT / "static"
ASSET_CATALOG = APP_ROOT / "Simastry" / "SimastryApp" / "Assets.xcassets"
APP_MODELS = APP_ROOT / "Simastry" / "SimastryApp" / "Models" / "AppModels.swift"
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
APP_SLOTS = [
    "profile_avatar",
    "card_portrait",
    "astrogram_01",
    "astrogram_02",
    "astrogram_03",
    "astrogram_04",
    "astrogram_05",
    "astrogram_06",
    "astrogram_07",
    "astrogram_08",
    "astrogram_09",
    "astrogram_10",
]
SIGN_ORDER = {
    "Aries": 1,
    "Taurus": 2,
    "Gemini": 3,
    "Cancer": 4,
    "Leo": 5,
    "Virgo": 6,
    "Libra": 7,
    "Scorpio": 8,
    "Sagittarius": 9,
    "Capricorn": 10,
    "Aquarius": 11,
    "Pisces": 12,
}


def read_json(path: Path, fallback):
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (FileNotFoundError, json.JSONDecodeError):
        return fallback


def write_json(path: Path, payload) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")
    tmp.replace(path)


def clamp_float(value, low: float, high: float, fallback: float) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        parsed = fallback
    return round(max(low, min(high, parsed)), 3)


def git_output(args: list[str]) -> str:
    try:
        result = subprocess.run(
            ["git", *args],
            cwd=APP_ROOT,
            text=True,
            capture_output=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return ""
    return result.stdout.strip()


def sha256_file(path: Path) -> str | None:
    if not path.exists():
        return None
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def safe_workspace_rel(path: Path) -> str:
    resolved = path.resolve()
    workspace = WORKSPACE.resolve()
    if not str(resolved).startswith(str(workspace) + os.sep):
        raise ValueError("Path is outside Factory workspace")
    return resolved.relative_to(workspace).as_posix()


def resolve_media(rel: str) -> Path:
    rel = unquote(rel).lstrip("/")
    path = (WORKSPACE / rel).resolve()
    workspace = WORKSPACE.resolve()
    if not str(path).startswith(str(workspace) + os.sep):
        raise ValueError("Path is outside Factory workspace")
    if not path.is_file():
        raise FileNotFoundError(rel)
    return path


def media_url(path: Path) -> str:
    return "/media?file=" + quote(safe_workspace_rel(path), safe="")


def slot_asset_name(app_key: str, slot: str) -> str:
    if slot == "profile_avatar":
        suffix = "profile"
    elif slot == "card_portrait":
        suffix = "card"
    else:
        suffix = f"post{int(slot.removeprefix('astrogram_'))}"
    return f"Factory_{app_key}_{suffix}"


def normalize_slot(slot: str) -> str:
    if slot == "profile_avatar":
        return "Profile"
    if slot == "card_portrait":
        return "Card"
    return "Post " + slot.removeprefix("astrogram_")


def output_size_for_slot(slot: str) -> tuple[int, int]:
    if slot == "card_portrait":
        return (1200, 1600)
    if slot == "profile_avatar":
        return (1024, 1024)
    return (1400, 1400)


def default_crop_for_slot(slot: str) -> dict:
    if slot == "profile_avatar":
        return {"x": 50, "y": 34, "zoom": 1}
    if slot == "card_portrait":
        return {"x": 50, "y": 36, "zoom": 1}
    return {"x": 50, "y": 38, "zoom": 1}


def app_profiles() -> list[dict]:
    if not APP_MODELS.exists():
        return []
    text = APP_MODELS.read_text(encoding="utf-8")
    pattern = re.compile(
        r'profile\("([^"]+)",\s*"([^"]+)",\s*\.([a-z]+),\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)"',
        re.MULTILINE,
    )
    profiles = []
    for match in pattern.finditer(text):
        app_key, name, sign, presentation, age, city = match.groups()
        profiles.append(
            {
                "app_key": app_key,
                "name": name,
                "sign": sign.title(),
                "presentation": presentation,
                "age": age,
                "city": city,
            }
        )
    return profiles


def asset_image_file(asset_name: str) -> Path | None:
    imageset = ASSET_CATALOG / f"{asset_name}.imageset"
    if not imageset.exists():
        return None
    files = [item for item in imageset.iterdir() if item.is_file() and item.suffix.lower() in IMAGE_EXTENSIONS]
    if not files:
        return None
    return sorted(files, key=lambda item: (item.suffix.lower() != ".jpg", item.name))[0]


def ensure_original(asset_name: str, source: Path) -> Path:
    ORIGINALS_DIR.mkdir(parents=True, exist_ok=True)
    destination = ORIGINALS_DIR / f"{asset_name}{source.suffix.lower()}"
    if not destination.exists():
        shutil.copy2(source, destination)
    return destination


def slot_payload(app_key: str, slot: str, crops: dict) -> dict:
    asset = slot_asset_name(app_key, slot)
    source = asset_image_file(asset)
    if not source:
        return {"slot": slot, "asset": asset, "missing": True, "label": normalize_slot(slot)}
    original = ensure_original(asset, source)
    rel = safe_workspace_rel(original)
    return {
        "slot": slot,
        "asset": asset,
        "label": normalize_slot(slot),
        "missing": False,
        "rel": rel,
        "url": media_url(original),
        "current_file": str(source),
        "crop": crops.get(asset) or default_crop_for_slot(slot),
    }


def load_app_preview() -> dict:
    crops = read_json(CROPS_FILE, {})
    characters = []
    for profile in app_profiles():
        app_key = profile["app_key"]
        slots = [slot_payload(app_key, slot, crops) for slot in APP_SLOTS]
        missing = [slot["slot"] for slot in slots if slot.get("missing")]
        thumbnail = next((slot for slot in slots if slot["slot"] == "profile_avatar"), None)
        characters.append(
            {
                **profile,
                "id": app_key,
                "missing": missing,
                "slots": slots,
                "thumbnail": "" if not thumbnail or thumbnail.get("missing") else thumbnail["url"],
                "thumbnail_crop": (thumbnail or {}).get("crop") or default_crop_for_slot("profile_avatar"),
            }
        )
    characters.sort(key=lambda item: (SIGN_ORDER.get(item["sign"], 99), item["presentation"], item["name"]))
    return {"characters": characters, "preflight": app_preview_preflight()}


def crop_box_for_image(width: int, height: int, out_width: int, out_height: int, crop: dict) -> tuple[int, int, int, int]:
    target_aspect = out_width / out_height
    image_aspect = width / height
    x_percent = clamp_float(crop.get("x"), 0, 100, 50) / 100
    y_percent = clamp_float(crop.get("y"), 0, 100, 38) / 100
    zoom = clamp_float(crop.get("zoom"), 1, 2.5, 1)

    if image_aspect >= target_aspect:
        crop_height = height / zoom
        crop_width = crop_height * target_aspect
        if crop_width > width:
            crop_width = width
            crop_height = crop_width / target_aspect
    else:
        crop_width = width / zoom
        crop_height = crop_width / target_aspect
        if crop_height > height:
            crop_height = height
            crop_width = crop_height * target_aspect

    focus_x = width * x_percent
    focus_y = height * y_percent
    left = focus_x - crop_width * x_percent
    top = focus_y - crop_height * y_percent
    left = max(0, min(left, width - crop_width))
    top = max(0, min(top, height - crop_height))
    return (round(left), round(top), round(left + crop_width), round(top + crop_height))


def render_app_asset(source_path: Path, crop: dict, slot: str, destination: Path) -> None:
    try:
        from PIL import Image, ImageOps
    except ImportError as exc:
        raise RuntimeError("Pillow is required to render app-ready crops") from exc

    resample = getattr(getattr(Image, "Resampling", Image), "LANCZOS")
    out_width, out_height = output_size_for_slot(slot)
    with Image.open(source_path) as image:
        image = ImageOps.exif_transpose(image)
        if image.mode not in {"RGB", "L"}:
            background = Image.new("RGB", image.size, (255, 255, 255))
            if "A" in image.getbands():
                background.paste(image, mask=image.getchannel("A"))
                image = background
            else:
                image = image.convert("RGB")
        elif image.mode == "L":
            image = image.convert("RGB")

        box = crop_box_for_image(image.width, image.height, out_width, out_height, crop)
        rendered = image.crop(box).resize((out_width, out_height), resample)
        destination.parent.mkdir(parents=True, exist_ok=True)
        rendered.save(destination, "JPEG", quality=93, optimize=True, progressive=True)


def write_imageset(asset_name: str, source_path: Path, crop: dict, slot: str, backup_root: Path) -> dict:
    imageset = ASSET_CATALOG / f"{asset_name}.imageset"
    if not imageset.exists():
        raise RuntimeError(f"Missing image set: {asset_name}")

    old_files = [item for item in imageset.iterdir() if item.is_file() and item.suffix.lower() in IMAGE_EXTENSIONS]
    old_hashes = {item.name: sha256_file(item) for item in old_files}
    backup_dir = backup_root / f"{asset_name}.imageset"
    backup_dir.mkdir(parents=True, exist_ok=True)
    for item in imageset.iterdir():
        if item.is_file():
            shutil.copy2(item, backup_dir / item.name)
    for old_file in old_files:
        old_file.unlink()

    filename = f"{asset_name}.jpg"
    destination = imageset / filename
    render_app_asset(source_path, crop, slot, destination)
    write_json(
        imageset / "Contents.json",
        {
            "images": [{"filename": filename, "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        },
    )
    new_hash = sha256_file(destination)
    return {
        "asset": asset_name,
        "slot": slot,
        "source": str(source_path),
        "destination": str(destination),
        "changed": new_hash not in set(old_hashes.values()),
    }


def export_to_ios_app() -> dict:
    if not ASSET_CATALOG.exists():
        raise RuntimeError(f"iOS asset catalog was not found at {ASSET_CATALOG}")

    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    export_dir = EXPORTS_DIR / timestamp
    backup_root = export_dir / "previous-ios-assets"
    crops = read_json(CROPS_FILE, {})
    exported = []
    missing = []

    for profile in app_profiles():
        app_key = profile["app_key"]
        for slot in APP_SLOTS:
            asset = slot_asset_name(app_key, slot)
            source = asset_image_file(asset)
            if not source:
                missing.append({"character": app_key, "slot": slot})
                continue
            original = ensure_original(asset, source)
            crop = crops.get(asset) or default_crop_for_slot(slot)
            exported.append(write_imageset(asset, original, crop, slot, backup_root))

    report = {
        "summary": {
            "characters": len(app_profiles()),
            "exported": len(exported),
            "changed": sum(1 for item in exported if item["changed"]),
            "missing": len(missing),
            "destination": str(ASSET_CATALOG),
        },
        "exported": exported,
        "missing": missing,
        "manifest_path": str(export_dir / "ios-push-manifest.json"),
        "backup_path": str(backup_root),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    write_json(export_dir / "ios-push-manifest.json", report)
    write_json(EXPORTS_DIR / "latest-ios-push.json", report)
    return report


def app_preview_preflight() -> dict:
    profiles = app_profiles()
    ready = 0
    missing = []
    for profile in profiles:
        for slot in APP_SLOTS:
            asset = slot_asset_name(profile["app_key"], slot)
            if asset_image_file(asset):
                ready += 1
            else:
                missing.append({"character": profile["app_key"], "slot": slot})

    status_lines = [
        line for line in git_output(["status", "--porcelain"]).splitlines()
        if not line[3:].startswith("Factory/")
    ]
    latest_push = read_json(EXPORTS_DIR / "latest-ios-push.json", {})
    return {
        "target": {
            "name": APP_ROOT.name,
            "repo": "https://github.com/diasmal917/Simastry",
            "app_root": str(APP_ROOT),
            "asset_catalog": str(ASSET_CATALOG),
            "exists": APP_ROOT.exists() and ASSET_CATALOG.exists(),
        },
        "git": {
            "branch": git_output(["branch", "--show-current"]) or "unknown",
            "commit": git_output(["rev-parse", "--short", "HEAD"]) or "unknown",
            "subject": git_output(["log", "-1", "--pretty=%s"]) or "",
            "dirty_count": len(status_lines),
            "dirty_sample": status_lines[:8],
        },
        "images": {
            "characters": len(profiles),
            "expected": len(profiles) * len(APP_SLOTS),
            "ready": ready,
            "missing": len(missing),
            "missing_sample": missing[:10],
        },
        "latest_push": {
            "manifest_path": latest_push.get("manifest_path", ""),
            "summary": latest_push.get("summary", {}),
        },
        "checked_at": datetime.now(timezone.utc).isoformat(),
    }


class FactoryHandler(BaseHTTPRequestHandler):
    server_version = "SimastryFactory/2.0"

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        if path in {"/", "/app-preview", "/app-preview/"}:
            return self.serve_static("app-preview/index.html")
        if path == "/api/app-preview":
            return self.send_json(load_app_preview())
        if path == "/api/app-preview/preflight":
            return self.send_json(app_preview_preflight())
        if path == "/media":
            return self.serve_media(parse_qs(parsed.query).get("file", [""])[0])
        if path.startswith("/static/"):
            return self.serve_static(path.removeprefix("/static/"))
        self.send_error(HTTPStatus.NOT_FOUND, "Not Found")

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/app-preview/crops":
            return self.save_crop()
        if parsed.path == "/api/app-preview/crops/reset":
            return self.reset_crop()
        if parsed.path == "/api/app-preview/push-to-ios-app":
            return self.push_to_ios_app()
        self.send_error(HTTPStatus.NOT_FOUND, "Not Found")

    def serve_static(self, rel: str):
        rel = posixpath.normpath(unquote(rel)).lstrip("/")
        path = (STATIC_DIR / rel).resolve()
        if not str(path).startswith(str(STATIC_DIR.resolve()) + os.sep):
            return self.send_error(HTTPStatus.FORBIDDEN, "Forbidden")
        if not path.is_file():
            return self.send_error(HTTPStatus.NOT_FOUND, "Not Found")
        payload = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", mimetypes.guess_type(path.name)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def serve_media(self, rel: str):
        try:
            path = resolve_media(rel)
        except (ValueError, FileNotFoundError):
            return self.send_error(HTTPStatus.NOT_FOUND, "Not Found")
        if path.suffix.lower() not in IMAGE_EXTENSIONS:
            return self.send_error(HTTPStatus.FORBIDDEN, "Forbidden")
        payload = path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", mimetypes.guess_type(path.name)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def save_crop(self):
        payload = self.read_body_json()
        asset = str(payload.get("asset", ""))
        slot = str(payload.get("slot", ""))
        if not asset.startswith("Factory_") or slot not in APP_SLOTS:
            return self.send_json({"ok": False, "error": "Invalid image"}, HTTPStatus.BAD_REQUEST)
        crop = {
            "x": clamp_float(payload.get("x"), 0, 100, 50),
            "y": clamp_float(payload.get("y"), 0, 100, 38),
            "zoom": clamp_float(payload.get("zoom"), 1, 2.5, 1),
        }
        crops = read_json(CROPS_FILE, {})
        crops[asset] = crop
        write_json(CROPS_FILE, crops)
        return self.send_json({"ok": True, "asset": asset, "crop": crop})

    def reset_crop(self):
        payload = self.read_body_json()
        asset = str(payload.get("asset", ""))
        crops = read_json(CROPS_FILE, {})
        crops.pop(asset, None)
        write_json(CROPS_FILE, crops)
        return self.send_json({"ok": True, "asset": asset})

    def push_to_ios_app(self):
        try:
            report = export_to_ios_app()
        except Exception as exc:
            return self.send_json({"ok": False, "error": str(exc)}, HTTPStatus.INTERNAL_SERVER_ERROR)
        return self.send_json({"ok": True, **report})

    def read_body_json(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b"{}"
        try:
            return json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            return {}

    def send_json(self, payload, status=HTTPStatus.OK):
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args))


def main():
    parser = argparse.ArgumentParser(description="Run the local Simastry Factory app.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8765, type=int)
    args = parser.parse_args()
    WORKSPACE.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((args.host, args.port), FactoryHandler)
    print(f"Factory running at http://{args.host}:{args.port}/")
    server.serve_forever()


if __name__ == "__main__":
    main()
