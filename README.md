# PhotoCraft Web (selfhosted)

Docker-Image für den WebAssembly-Build von PhotoCraft. Das Image lädt beim Build das
offizielle Release-Zip von GitHub, prüft es gegen `SHA256SUMS.txt`, entpackt es und
liefert es über nginx (Port 8080, läuft ohne root) aus.

## Starten

Fertiges Image von Docker Hub:

    docker compose up -d

oder lokal bauen:

    docker build -t photocraft-web:0.8.2 .
    docker run -d --name photocraft-web --restart unless-stopped \
      -p 8080:8080 photocraft-web:0.8.2

Danach: http://localhost:8080/ bzw. `http://<server-ip>:8080/`

Der Port wird an alle Netzwerk-Interfaces gebunden. Soll die App nur lokal (z. B. hinter
einem Reverse Proxy auf demselben Host) erreichbar sein, stattdessen `127.0.0.1:8080:8080`
verwenden (in `docker-compose.yml` bzw. bei `-p`).

## Veröffentlichung auf Docker Hub (GitHub Actions)

Der Workflow `.github/workflows/docker-image.yml` baut das Image für `linux/amd64` und
`linux/arm64` und veröffentlicht es auf Docker Hub:

- Push auf `main` (bei Änderung an Dockerfile, nginx.conf, docker-compose.yml oder Workflow):
  Build und Push
- Pull Request: nur Build zur Kontrolle, kein Push
- Wöchentlich (Montag, 04:00 UTC): Neubau, damit Sicherheitsupdates der Basis-Images ankommen
- Manuell (Actions > "Docker Hub veröffentlichen" > Run workflow): optional mit anderer
  PhotoCraft-Version

Tags: `<version>` (z. B. `0.8.2`), `<major.minor>` (z. B. `0.8`) und `latest`. Bei manuell
gewählter Version wird nur `<version>` gesetzt, `latest` zusätzlich nur auf `main`. Die Version
stammt aus dem `ARG PHOTOCRAFT_VERSION` im Dockerfile.

Einrichtung im GitHub-Repository unter Settings > Secrets and variables > Actions:

| Art      | Name                  | Inhalt                                                          |
| -------- | --------------------- | --------------------------------------------------------------- |
| Variable | `DOCKERHUB_USERNAME`  | Docker-Hub-Benutzername (bzw. Organisation für das Repository)  |
| Secret   | `DOCKERHUB_TOKEN`     | Access Token mit Schreibrechten (Docker Hub > Account Settings > Personal access tokens) |

Der Benutzername ist bewusst eine Variable und kein Secret, sonst wird er in den Logs
(und damit im Image-Namen) als `***` maskiert.

Dependabot (`.github/dependabot.yml`) schlägt wöchentlich Updates für Basis-Images und
Actions vor. Den Wechsel auf einen neuen nginx-Stable-Zweig (gerade Minor-Version) bitte
von Hand vornehmen.

Das Docker-Hub-Repository `<benutzername>/photocraft` wird beim ersten Push automatisch
angelegt.

### Neue PhotoCraft-Releases automatisch übernehmen

Der Workflow `.github/workflows/photocraft-release.yml` prüft stündlich (jeweils Minute 17, auch
manuell startbar) das neueste Release von `storytold/photocraft`. Ist es neuer als die Version im
Dockerfile und sind Zip und `SHA256SUMS.txt` bereits hochgeladen, hebt er die Version in
`Dockerfile` und `docker-compose.yml` an, committet direkt auf `main` und startet den
Docker-Hub-Workflow. Voraussetzung: `main` darf keinen Branch-Schutz haben, der direkte
Pushes von `github-actions[bot]` verbietet.

Von Hand geht es ebenso: `ARG PHOTOCRAFT_VERSION` im Dockerfile und den
Image-Tag in `docker-compose.yml` auf dieselbe Version anheben, committen, auf `main` pushen.
Der Workflow bricht ab, wenn die beiden Versionen nicht übereinstimmen.

## Andere Version

    docker build --build-arg PHOTOCRAFT_VERSION=0.8.3 -t photocraft-web:0.8.3 .

## Hinweise

- Für den Einsatz im Netz einen HTTPS-Reverse-Proxy davorsetzen. WebGPU und Zwischenablage
  funktionieren nur in einem Secure Context (HTTPS oder localhost); sonst fällt die App auf
  WebGL2 zurück.
- Die Bilder werden im Browser bearbeitet und nie hochgeladen, es gibt kein Backend und
  keine Daten-Volumes.
- Unter einem Unterpfad (z. B. /photocraft/) lässt sich die App ebenfalls betreiben, weil
  alle URLs relativ sind: im Reverse Proxy den Pfad entfernen oder einen entsprechenden
  location-Block verwenden.
- Flags für die URL: `?webgl` erzwingt WebGL2, `?cpu` die CPU-Darstellung.
