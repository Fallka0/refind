# refind server

TypeScript + Hono + Postgres, implementing [`../docs/API.md`](../docs/API.md).

## Running it

Postgres, either way:

```bash
docker compose up -d          # from the repo root, port 5433
```

```bash
pg_ctl -D /opt/homebrew/var/postgresql@14 -l /tmp/pg.log start   # local install, port 5432
createdb refind
```

Then:

```bash
cd server
npm install
cp .env.example .env          # set DATABASE_URL and generate a JWT_SECRET
npm run migrate
npm run dev                   # http://localhost:3000
```

## Self-test

Exercises the real app object — routing, validation, auth middleware, Postgres —
without opening a socket, because a Hono app is just a fetch handler:

```bash
DATABASE_URL=... JWT_SECRET=... npx tsx src/selftest.ts
```

It covers the things that are wrong-in-silence: that rotation actually
invalidates the old refresh token, that sign-out kills every session, that a
wrong password and an unknown address are indistinguishable, and that the
password never lands in the database in the clear.

## Auth

Email and password, not Sign in with Apple. Apple's flow is the better fit for
an iOS app but needs the `com.apple.developer.applesignin` entitlement, which a
free personal Apple team cannot provision — it would break device builds today.
The token half below is unchanged when Apple sign-in is added later.

- **Passwords**: scrypt from `node:crypto`. No native dependency, so it behaves
  the same on a laptop and on a serverless runtime.
- **Access tokens**: HS256 JWT, 15 minutes.
- **Refresh tokens**: opaque random strings, 60 days, **single-use**. Only the
  SHA-256 hash is stored, so a database leak cannot mint sessions. Refreshing
  revokes the presented token and issues a new one; replaying the old one is a
  401.

## What exists

| | |
|---|---|
| `POST /v1/auth/register` · `login` · `refresh` · `signout` | done |
| `GET /v1/me` · `/me/stats` · `PUT /me/devices` · verification | done |
| wants, offers, chat, deals, escrow, safety | schema only |

The schema in `sql/001_init.sql` covers the whole model — including the German
full-text index on wants, since "Rennvelo" has to find "Velo" and a substring
match will not.

## Deploying to Vercel

`api/index.ts` adapts the same `app` object with `hono/vercel`, and
`vercel.json` rewrites every path to it. Nothing else differs from local.

**Set the project root to `server/`** — the repo also contains an iOS app, and
Vercel would otherwise try to build that.

### 1. A hosted Postgres

Any Postgres works; the connection just has to be reachable from Vercel and
speak TLS (the client requires it for non-local hosts). Through the Vercel
dashboard, **Storage → Create → Neon** is the shortest path and has a free
tier. Whatever you use, put the pooled connection string in `DATABASE_URL`.

The client opens **one connection per invocation** on Vercel. Hosted Postgres
sits behind a pooler, and a lambda opening ten each would exhaust it under any
real load.

### 2. Environment variables

```bash
vercel env add DATABASE_URL production
vercel env add JWT_SECRET production
```

Generate the secret with:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64'))"
```

`JWT_SECRET` signs every access token — **rotating it signs everyone out.**

### 3. Migrate, then deploy

Migrations run from your machine against the hosted database:

```bash
DATABASE_URL="postgres://…" npm run migrate
vercel --prod
```

### 4. Point the app at it

Set `RefindEnvironment.production` in `refind/Repository/Live/RefindAPI.swift`
to `https://<deployment>/v1`. Release builds use it automatically; debug builds
still default to localhost, and `RF_API_BASE` overrides either.

### Checking a deployment

```bash
curl https://<deployment>/health
```

The self-test can also run against it, though it writes real rows:

```bash
DATABASE_URL="postgres://…" JWT_SECRET="…" npx tsx src/selftest.ts
```
