FROM python:3.12-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg curl unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# yt-dlp, YouTube icin bir JavaScript calistiricisina (deno) ihtiyac duyar
RUN curl -fsSL https://deno.land/install.sh | DENO_INSTALL=/usr/local sh

WORKDIR /app
COPY requirements.txt .
# Surum sabitlenmedi: her yeniden derlemede yt-dlp / gallery-dl guncellenir
RUN pip install --no-cache-dir -U -r requirements.txt
COPY app.py .

ENV PORT=8000
CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT}"]
