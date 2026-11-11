"""Peach sunucusu: link -> video / fotograf dosyalari.

yt-dlp (video) ve gallery-dl (fotografli gonderiler) kullanir.
Ortam degiskenleri:
  API_KEY      Uygulamanin gonderecegi anahtar (mutlaka ayarla)
  COOKIES_B64  Netscape bicimli cookies.txt dosyasinin base64 hali (istege bagli)
  PROXY        yt-dlp / gallery-dl icin proxy adresi (istege bagli)
  ALLOW_ALL    "1" ise alan adi kisitlamasi kalkar
"""
import base64
import hmac
import json
import os
import shutil
import subprocess
import sys
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlparse

import yt_dlp
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel

API_KEY = os.environ.get("API_KEY", "")
PROXY = os.environ.get("PROXY", "")
ALLOW_ALL = os.environ.get("ALLOW_ALL", "") == "1"
WORK = Path(os.environ.get("WORK_DIR", "/tmp/peach"))
JOB_TTL = 30 * 60  # saniye
GALLERY_TIMEOUT = 600

ALLOWED = (
    "instagram.com", "twitter.com", "x.com", "t.co", "tiktok.com",
    "youtube.com", "youtu.be", "facebook.com", "fb.watch", "reddit.com",
    "redd.it", "pinterest.com", "pin.it", "vimeo.com", "dailymotion.com",
    "twitch.tv", "threads.net", "threads.com", "bsky.app", "tumblr.com",
    "snapchat.com", "linkedin.com", "soundcloud.com",
)
VIDEO_EXT = {".mp4", ".mov", ".m4v", ".webm", ".mkv"}
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".gif"}
AUDIO_EXT = {".m4a", ".mp3", ".opus", ".aac", ".ogg"}

WORK.mkdir(parents=True, exist_ok=True)
COOKIES = ""
if os.environ.get("COOKIES_B64"):
    try:
        p = WORK / "cookies.txt"
        p.write_bytes(base64.b64decode(os.environ["COOKIES_B64"]))
        COOKIES = str(p)
    except Exception as e:  # bozuk deger sunucuyu dusurmesin
        print("COOKIES_B64 okunamadi:", e, file=sys.stderr)
elif os.environ.get("COOKIES_FILE") and Path(os.environ["COOKIES_FILE"]).exists():
    COOKIES = os.environ["COOKIES_FILE"]

app = FastAPI(title="Peach")
jobs: dict[str, dict] = {}
lock = threading.Lock()
pool = ThreadPoolExecutor(max_workers=2)


# ---------- yardimcilar ----------

def auth(x_api_key: str | None = Header(default=None)):
    if API_KEY and not hmac.compare_digest(x_api_key or "", API_KEY):
        raise HTTPException(401, "API anahtarı geçersiz.")


def host_of(url: str) -> str:
    return (urlparse(url).hostname or "").lower().removeprefix("www.").removeprefix("m.").removeprefix("mobile.")


def check_url(url: str) -> str:
    url = url.strip()
    u = urlparse(url)
    if u.scheme not in ("http", "https") or not u.hostname:
        raise HTTPException(400, "Geçerli bir bağlantı değil.")
    h = host_of(url)
    if not ALLOW_ALL and not any(h == d or h.endswith("." + d) for d in ALLOWED):
        raise HTTPException(400, "Bu site desteklenmiyor.")
    return url


def platform_of(url: str) -> str:
    h = host_of(url)
    for key, name in (
        ("instagram", "instagram"), ("tiktok", "tiktok"), ("youtu", "youtube"),
        ("twitter", "x"), ("x.com", "x"), ("t.co", "x"), ("facebook", "facebook"),
        ("fb.watch", "facebook"), ("redd", "reddit"), ("pin", "pinterest"),
        ("threads", "threads"), ("vimeo", "vimeo"),
    ):
        if key in h:
            return name
    return "other"


def gallery_first(url: str) -> bool:
    """Fotograf icerebilen gonderilerde once gallery-dl denenir."""
    h, path = host_of(url), urlparse(url).path
    if "youtu" in h:
        return False
    if h.endswith("twitter.com") or h.endswith("x.com"):
        return True
    if h.endswith("instagram.com"):
        return not path.startswith(("/reel", "/tv"))
    if h.endswith("tiktok.com"):
        return "/photo/" in path
    if h.endswith(("pinterest.com", "pin.it", "threads.net", "threads.com", "bsky.app", "tumblr.com")):
        return True
    return False


def ydl_base() -> dict:
    o = {
        "quiet": True, "no_warnings": True, "noplaylist": True,
        "socket_timeout": 30, "retries": 3, "playlist_items": "1-20",
    }
    if COOKIES:
        o["cookiefile"] = COOKIES
    if PROXY:
        o["proxy"] = PROXY
    return o


def gdl_cmd(*args: str) -> list[str]:
    cmd = [sys.executable, "-m", "gallery_dl"]
    if COOKIES:
        cmd += ["--cookies", COOKIES]
    if PROXY:
        cmd += ["--proxy", PROXY]
    return cmd + list(args)


def clean_error(e: Exception) -> str:
    msg = str(e).replace("ERROR: ", "").strip()
    low = msg.lower()
    if "sign in to confirm" in low or "not a bot" in low:
        return "YouTube bu sunucuyu engelledi (bot kontrolü). Çerez ya da proxy gerekli."
    if "login" in low or "log in" in low or "cookies" in low or "private" in low:
        return "Bu içerik giriş gerektiriyor ya da gizli. Sunucuya çerez (cookies) eklenmeli."
    if "unsupported url" in low:
        return "Bu bağlantı desteklenmiyor."
    return msg[:300] or "Bilinmeyen hata."


def kind_of(p: Path) -> str:
    e = p.suffix.lower()
    if e in VIDEO_EXT:
        return "video"
    if e in IMAGE_EXT:
        return "image"
    if e in AUDIO_EXT:
        return "audio"
    return "other"


# ---------- bilgi (onizleme) ----------

def info_ytdlp(url: str) -> dict:
    with yt_dlp.YoutubeDL({**ydl_base(), "skip_download": True}) as y:
        info = y.extract_info(url, download=False)
    entries = [e for e in (info.get("entries") or []) if e]
    first = entries[0] if entries else info
    heights = sorted({f.get("height") for f in (first.get("formats") or []) if f.get("height")}, reverse=True)
    qualities = ["best"] + [str(h) for h in (1080, 720, 480) if any(x >= h for x in heights)] + ["audio"]
    return {
        "title": info.get("title") or first.get("title") or "Video",
        "author": info.get("uploader") or first.get("uploader") or info.get("channel") or "",
        "thumbnail": first.get("thumbnail") or info.get("thumbnail") or "",
        "duration": first.get("duration"),
        "kind": "video",
        "count": max(1, len(entries)),
        "qualities": qualities,
    }


def info_gallery(url: str) -> dict:
    r = subprocess.run(gdl_cmd("-j", "--range", "1-30", url), capture_output=True, text=True, timeout=90)
    try:
        data = json.loads(r.stdout or "[]")
    except json.JSONDecodeError:
        data = []
    items = [d for d in data if isinstance(d, list) and len(d) >= 3 and d[0] == 3]
    if not items:
        err = next((str(d[1:]) for d in data if isinstance(d, list) and d and d[0] == -1), r.stderr.strip())
        raise RuntimeError(err or "İçerik bulunamadı.")
    meta = items[0][2] if isinstance(items[0][2], dict) else {}
    author = meta.get("username") or meta.get("uploader") or ""
    for key in ("author", "user", "owner"):
        v = meta.get(key)
        if not author and isinstance(v, dict):
            author = v.get("name") or v.get("username") or v.get("nick") or ""
    title = meta.get("description") or meta.get("content") or meta.get("title") or meta.get("desc") or ""
    exts = {str((d[2] or {}).get("extension", "")).lower() for d in items if isinstance(d[2], dict)}
    only_video = exts and all("." + e in VIDEO_EXT for e in exts)
    thumb = next((d[1] for d in items if "." + str((d[2] or {}).get("extension", "")).lower() in IMAGE_EXT), "")
    return {
        "title": (str(title).strip().splitlines() or ["Gönderi"])[0][:120] or "Gönderi",
        "author": str(author),
        "thumbnail": thumb if isinstance(thumb, str) and thumb.startswith("http") else "",
        "duration": None,
        "kind": "video" if only_video else "gallery",
        "count": len(items),
        "qualities": ["best"],
    }


def get_info(url: str) -> dict:
    order = [info_gallery, info_ytdlp] if gallery_first(url) else [info_ytdlp, info_gallery]
    first_err = None
    for fn in order:
        try:
            out = fn(url)
            out["platform"] = platform_of(url)
            return out
        except Exception as e:
            first_err = first_err or e
    raise HTTPException(422, clean_error(first_err))


# ---------- indirme ----------

def dl_ytdlp(url: str, quality: str, out: Path, job: dict):
    def hook(d):
        if d.get("status") == "downloading":
            total = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
            if total:
                job["progress"] = max(job["progress"], min(0.95, d.get("downloaded_bytes", 0) / total * 0.95))

    opts = {
        **ydl_base(),
        "outtmpl": str(out / "%(title).60B [%(id)s].%(ext)s"),
        "windowsfilenames": True,
        "progress_hooks": [hook],
        "merge_output_format": "mp4",
    }
    if quality == "audio":
        opts["format"] = "ba[ext=m4a]/ba/b"
        opts["postprocessors"] = [{"key": "FFmpegExtractAudio", "preferredcodec": "m4a"}]
    else:
        # h264 + aac: iPhone Fotograflar uygulamasinin kabul ettigi bicim
        sort = ["vcodec:h264"]
        if quality.isdigit():
            sort.append(f"res:{quality}")
        sort += ["res", "acodec:m4a"]
        opts["format"] = "bv*+ba/b"
        opts["format_sort"] = sort
    with yt_dlp.YoutubeDL(opts) as y:
        y.download([url])


def dl_gallery(url: str, out: Path):
    r = subprocess.run(gdl_cmd("-D", str(out), "--range", "1-30", url),
                       capture_output=True, text=True, timeout=GALLERY_TIMEOUT)
    if not any(out.iterdir()):
        raise RuntimeError(r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "İçerik bulunamadı.")


def webp_to_jpg(out: Path):
    for p in list(out.glob("*.webp")):
        try:
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(p), str(p.with_suffix(".jpg"))],
                           check=True, timeout=60)
            p.unlink()
        except Exception:
            pass


def run_job(job_id: str, url: str, quality: str):
    job = jobs[job_id]
    out = WORK / job_id
    out.mkdir(parents=True, exist_ok=True)
    job["status"] = "downloading"
    steps = ["gallery", "ytdlp"] if gallery_first(url) and quality != "audio" else ["ytdlp", "gallery"]
    first_err = None
    for step in steps:
        try:
            if step == "ytdlp":
                dl_ytdlp(url, quality, out, job)
            else:
                dl_gallery(url, out)
            if any(p.is_file() and not p.name.endswith(".part") for p in out.iterdir()):
                first_err = None
                break
        except Exception as e:
            first_err = first_err or e
            for p in out.iterdir():
                p.unlink(missing_ok=True)
    files = []
    if first_err is None:
        webp_to_jpg(out)
        files = sorted(p for p in out.iterdir() if p.is_file() and kind_of(p) != "other")
    if not files:
        job["status"] = "error"
        job["error"] = clean_error(first_err or RuntimeError("İndirilecek dosya bulunamadı."))
        return
    job["paths"] = [str(p) for p in files]
    job["files"] = [{"index": i, "name": p.name, "size": p.stat().st_size, "kind": kind_of(p)}
                    for i, p in enumerate(files)]
    job["progress"] = 1.0
    job["status"] = "done"


def cleaner():
    while True:
        time.sleep(60)
        now = time.time()
        with lock:
            old = [k for k, j in jobs.items() if now - j["created"] > JOB_TTL]
            for k in old:
                jobs.pop(k, None)
        for k in old:
            shutil.rmtree(WORK / k, ignore_errors=True)


threading.Thread(target=cleaner, daemon=True).start()


# ---------- API ----------

class InfoReq(BaseModel):
    url: str


class JobReq(BaseModel):
    url: str
    quality: str = "best"


@app.get("/health")
def health():
    return {"ok": True, "yt_dlp": yt_dlp.version.__version__, "cookies": bool(COOKIES), "locked": bool(API_KEY)}


@app.get("/api/ping", dependencies=[Depends(auth)])
def ping():
    return {"ok": True}


@app.post("/api/info", dependencies=[Depends(auth)])
def api_info(req: InfoReq):
    return get_info(check_url(req.url))


@app.post("/api/jobs", dependencies=[Depends(auth)])
def api_create(req: JobReq):
    url = check_url(req.url)
    quality = req.quality if req.quality in ("best", "1080", "720", "480", "audio") else "best"
    job_id = uuid.uuid4().hex
    with lock:
        jobs[job_id] = {"id": job_id, "status": "queued", "progress": 0.0, "error": None,
                        "files": [], "paths": [], "created": time.time()}
    pool.submit(run_job, job_id, url, quality)
    return {"id": job_id}


@app.get("/api/jobs/{job_id}", dependencies=[Depends(auth)])
def api_status(job_id: str):
    job = jobs.get(job_id)
    if not job:
        raise HTTPException(404, "İş bulunamadı (süresi dolmuş olabilir).")
    return {k: job[k] for k in ("id", "status", "progress", "error", "files")}


@app.get("/api/jobs/{job_id}/files/{index}", dependencies=[Depends(auth)])
def api_file(job_id: str, index: int):
    job = jobs.get(job_id)
    if not job or job["status"] != "done" or not 0 <= index < len(job["paths"]):
        raise HTTPException(404, "Dosya bulunamadı.")
    path = Path(job["paths"][index])
    if not path.exists():
        raise HTTPException(404, "Dosya silinmiş.")
    return FileResponse(path, filename=path.name)
