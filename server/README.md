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

## Deploying

Nothing is deployed yet. The app is a plain fetch handler exported as default,
so it runs on Vercel unchanged; it needs `DATABASE_URL` (Neon or Vercel
Postgres) and `JWT_SECRET` as environment variables.
