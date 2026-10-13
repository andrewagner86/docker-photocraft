# syntax=docker/dockerfile:1

# Einzige Stelle mit Standardwert für die PhotoCraft-Version.
# Der GitHub-Workflow liest sie von hier aus. Beim Build überschreibbar:
#   docker build --build-arg PHOTOCRAFT_VERSION=0.8.3 -t photocraft-web .
ARG PHOTOCRAFT_VERSION=0.8.2

# ---------------------------------------------------------------------------
# Stage 1: offizielles Release-Zip laden, SHA-256 prüfen, entpacken
# (läuft immer auf der Build-Plattform, damit Multi-Arch-Builds ohne Emulation laden)
# ---------------------------------------------------------------------------
FROM --platform=$BUILDPLATFORM alpine:3.24 AS fetch

ARG PHOTOCRAFT_VERSION

RUN apk add --no-cache curl unzip gzip

WORKDIR /tmp/dl

RUN set -eux; \
    base="https://github.com/storytold/photocraft/releases/download/v${PHOTOCRAFT_VERSION}"; \
    curl -fsSL -O "${base}/photocraft-web-${PHOTOCRAFT_VERSION}.zip"; \
    curl -fsSL -O "${base}/SHA256SUMS.txt"; \
    # Schritt 1 der Anleitung: Prüfsumme des Zips kontrollieren
    # (BusyBox-sha256sum kennt --ignore-missing nicht, daher gezielt die passende Zeile prüfen)
    line="$(grep " photocraft-web-${PHOTOCRAFT_VERSION}.zip\$" SHA256SUMS.txt)"; \
    test -n "$line"; \
    echo "$line" | sha256sum -c -; \
    # Schritt 2: entpacken (Zip enthält einen Ordner photocraft-web-<ver>/)
    unzip -q "photocraft-web-${PHOTOCRAFT_VERSION}.zip" -d /tmp/unzipped; \
    mkdir -p /site; \
    cp -a "/tmp/unzipped/photocraft-web-${PHOTOCRAFT_VERSION}/." /site/; \
    # Hosting-Beispieldateien für andere Server werden nicht benötigt
    rm -f /site/_headers /site/.htaccess; \
    test -f /site/index.html; \
    # Schritt 3: vorkomprimierte .gz-Dateien für gzip_static erzeugen,
    # damit nginx die ~23 MiB .wasm nicht bei jedem Abruf neu komprimiert
    find /site -type f -size +1k \( -name '*.wasm' -o -name '*.js' -o -name '*.mjs' \
        -o -name '*.html' -o -name '*.css' -o -name '*.json' -o -name '*.svg' \
        -o -name '*.webmanifest' \) -exec gzip -9 -k -n {} +

# ---------------------------------------------------------------------------
# Stage 2: statische Auslieferung mit nginx (läuft als Nicht-root auf Port 8080)
# ---------------------------------------------------------------------------
FROM nginxinc/nginx-unprivileged:1.30-alpine

ARG PHOTOCRAFT_VERSION

LABEL org.opencontainers.image.title="PhotoCraft Web" \
      org.opencontainers.image.description="Self-hosted PhotoCraft WebAssembly build served by nginx" \
      org.opencontainers.image.version="${PHOTOCRAFT_VERSION}" \
      org.opencontainers.image.source="https://github.com/storytold/photocraft"

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=fetch /site/ /usr/share/nginx/html/

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q --spider http://127.0.0.1:8080/healthz || exit 1
