# BookLogr (physical book catalog + wishlist)

**Status: staged, not deployed.** No hardware dependency. Needs one
generated secret and two NPM hosts (details below). Replaces the
**Bookshelf** Android app.

Images, ports, volumes, and environment variables confirmed against
BookLogr's own
[docker-compose.yml](https://github.com/Mozzo1000/booklogr/blob/main/docker-compose.yml)
and [Docker install docs](https://booklogr.app/docs/Install/Docker/).

## What This Is

A self-hosted personal library tracker: look up books by title or ISBN
(via OpenLibrary), file them into **Reading / Already Read / To Be Read
(the wishlist) / Did Not Finish**, manually add books OpenLibrary lacks,
and track current-page progress. This tracks **physical** books -- it does
not overlap Kavita or Audiobookshelf, which serve digital ebooks/audiobooks.

**Two containers** (this is the only real wrinkle of the three V2.4 items):

| Container | Image | Role | Port |
|-----------|-------|------|------|
| `booklogr-api` | `mozzo/booklogr:v1.11.1` | Flask API + SQLite | 5000 |
| `booklogr-web` | `mozzo/booklogr-web:v1.11.1` | Browser SPA frontend | 80 |

**Backend**: SQLite embedded (`DATABASE_URL=sqlite:///books.db`), stored in
the API's `/app/instance` volume. No Postgres sidecar.

### Three things that bite if you get them wrong

1. **`BL_API_ENDPOINT` must be the URL the *browser* can reach, not the
   container name.** The web frontend is a client-side SPA, so it calls the
   API from the user's browser, not server-to-server. Point it at the
   public NPM hostname for the API (`https://booklogr-api.home.example.com/`),
   and give the API its **own** NPM proxy host. An internal
   `http://booklogr-api:5000` value will fail for every real user.
2. **Both images are pinned to the same version (`v1.11.1`) and Watchtower
   is deliberately not enabled on them.** API and web are released as a
   matched pair; letting Watchtower bump one independently can break the
   pairing. Update both together, manually, bumping the tag in the compose
   file.
3. **Mesh access carries a DNS dependency the other two V2.4 services
   don't.** Both containers are bound on `MESHNET_IP` as well as
   `VLAN11_IP`, but because `BL_API_ENDPOINT` is a single URL pointing at
   `booklogr-api.home.example.com`, a mesh client that opens the web UI
   directly at `http://<MESHNET_IP>:3006` still sends its API calls to that
   hostname. So mesh access only works if mesh clients resolve
   `*.home.example.com` (use Pi-hole as their resolver) and can reach NPM.
   If they can't, reach BookLogr over the mesh via the NPM hostname
   (`https://booklogr.home.example.com`) rather than the raw
   `MESHNET_IP:3006` address.

## What's In This Folder

| File | Purpose |
|------|---------|
| `compose/booklogr-service-addition.yaml` | New `booklogr-api` + `booklogr-web` services to add to `tools`' `compose.yaml` |
| `compose/env-additions.txt` | New `.env` / `.env.example` variable (`BOOKLOGR_AUTH_SECRET_KEY`) |

## Setup

1. Generate the auth secret:
   ```bash
   openssl rand -hex 32
   ```
   Add it as `BOOKLOGR_AUTH_SECRET_KEY` in `tools`' `.env` (real value) and
   as a blank entry in `.env.example` (see `compose/env-additions.txt`).
   (Alternatively, run single-user: set `SINGLE_USER_MODE=true` on the API
   and `BL_SINGLE_USER_MODE=true` on the web container, and no secret is
   needed. The compose file below uses multi-user + secret.)
2. Add both service blocks from `compose/booklogr-service-addition.yaml`
   into `Docker/stacks/tools/compose.yaml`.
3. `docker compose up -d booklogr-api booklogr-web` in `tools`.
4. Add **two** NPM proxy hosts (manual -- NPM config isn't a repo file):
   - `booklogr.home.example.com` -> `booklogr-web:80`
   - `booklogr-api.home.example.com` -> `booklogr-api:5000`
   The `BL_API_ENDPOINT` in the compose file must match the second one.

## Verify

- `booklogr.home.example.com` loads the web UI.
- In the browser devtools Network tab, API calls go to
  `booklogr-api.home.example.com` and return 200 (not connection errors --
  this is the `BL_API_ENDPOINT` check).
- Search a book by ISBN, add it to **To Be Read**, and confirm it persists
  after `docker compose restart booklogr-api` (proves the SQLite volume).
- Over the mesh: the web UI loads, and its API calls to
  `booklogr-api.home.example.com` still return 200 (this is the bite #3
  DNS check -- if they fail, use the NPM hostname over the mesh instead).

## Promotion

Once verified:
- Merge both `booklogr-api` and `booklogr-web` services into
  `Docker/stacks/tools/compose.yaml`, and `BOOKLOGR_AUTH_SECRET_KEY` into
  that stack's `.env.example`.
- Update this repo's root `CLAUDE.md` architecture table (`tools` row) to
  list BookLogr and its ports (web 3006, API 8087).
- Add a section to `stacks/tools-guide.md` in the `Homelab-wiki` repo,
  covering the two-container topology and the `BL_API_ENDPOINT` gotcha.
- Remove `Migrations/V2.4/booklogr/` and its row in
  `Migrations/V2.4/README.md`.
