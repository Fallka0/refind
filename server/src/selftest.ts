//
// selftest.ts — exercises the real app object without opening a socket.
//
//   DATABASE_URL=… JWT_SECRET=… npx tsx src/selftest.ts
//
// Hono apps are just fetch handlers, so this is the whole request path:
// routing, validation, auth middleware, Postgres. No HTTP client, no ports.
//

import app from './index.js'
import { sql } from './db.js'

let failures = 0

function check(label: string, ok: boolean, detail?: unknown) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}`)
  if (!ok) {
    failures++
    if (detail !== undefined) console.log('     ', detail)
  }
}

const call = (path: string, init?: RequestInit) =>
  app.fetch(new Request(`http://local${path}`, init))

const json = (body: unknown): RequestInit => ({
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
})

// A fresh address each run so re-running does not trip the uniqueness check.
const email = `selftest-${Date.now()}@refind.ch`
const password = 'correct-horse-battery-staple'

// Health -------------------------------------------------------------------
check('GET /health', (await call('/health')).status === 200)

// Register -----------------------------------------------------------------
const registered = await call('/v1/auth/register', json({ email, password }))
const session = await registered.json() as Record<string, string>
check('POST /v1/auth/register → 201', registered.status === 201, session)
check('register returns an access token', typeof session.accessToken === 'string')
check('register returns a refresh token', typeof session.refreshToken === 'string')

// Duplicate registration ---------------------------------------------------
const dupe = await call('/v1/auth/register', json({ email, password }))
check('duplicate email → 409', dupe.status === 409, await dupe.clone().text())

// Weak password ------------------------------------------------------------
const weak = await call('/v1/auth/register', json({ email: `w${email}`, password: 'short' }))
check('short password → 400', weak.status === 400)

// Login --------------------------------------------------------------------
const good = await call('/v1/auth/login', json({ email, password }))
check('login with correct password → 200', good.status === 200)

const bad = await call('/v1/auth/login', json({ email, password: 'wrong-password-here' }))
check('login with wrong password → 400', bad.status === 400)

const unknown = await call('/v1/auth/login', json({ email: 'nobody@refind.ch', password }))
const badBody = await bad.clone().json() as { message: string }
const unknownBody = await unknown.clone().json() as { message: string }
// Same wording either way, or this endpoint reveals which addresses exist.
check('unknown address is indistinguishable from wrong password',
      badBody.message === unknownBody.message,
      { wrongPassword: badBody.message, unknownEmail: unknownBody.message })

// Authenticated access -----------------------------------------------------
const me = await call('/v1/me', { headers: { Authorization: `Bearer ${session.accessToken}` } })
const meBody = await me.json() as Record<string, unknown>
check('GET /v1/me with token → 200', me.status === 200, meBody)
check('/me carries a display name derived from the address',
      typeof meBody.displayName === 'string' && (meBody.displayName as string).length > 0,
      meBody.displayName)

check('GET /v1/me without token → 401', (await call('/v1/me')).status === 401)
check('GET /v1/me with a junk token → 401',
      (await call('/v1/me', { headers: { Authorization: 'Bearer not-a-jwt' } })).status === 401)

// Stats --------------------------------------------------------------------
const stats = await call('/v1/me/stats', {
  headers: { Authorization: `Bearer ${session.accessToken}` },
})
check('GET /v1/me/stats → 200', stats.status === 200, await stats.clone().text())

// Refresh rotation ---------------------------------------------------------
const refreshed = await call('/v1/auth/refresh', json({ refreshToken: session.refreshToken }))
const rotated = await refreshed.json() as Record<string, string>
check('refresh → 200', refreshed.status === 200, rotated)
check('refresh returns a different refresh token (rotation)',
      typeof rotated.refreshToken === 'string' && rotated.refreshToken !== session.refreshToken)

// The old refresh token must be dead — that is what makes rotation worth doing.
const replay = await call('/v1/auth/refresh', json({ refreshToken: session.refreshToken }))
check('replaying the old refresh token → 401', replay.status === 401)

// Sign out kills every session --------------------------------------------
const signedOut = await call('/v1/auth/signout', {
  method: 'POST',
  headers: { Authorization: `Bearer ${rotated.accessToken}` },
})
check('POST /v1/auth/signout → 204', signedOut.status === 204)

const afterSignOut = await call('/v1/auth/refresh', json({ refreshToken: rotated.refreshToken }))
check('refresh after sign-out → 401', afterSignOut.status === 401)

// Password storage ---------------------------------------------------------
const stored = await sql<{ password_hash: string }[]>`
  select password_hash from users where email = ${email}
`
check('password is not stored in the clear',
      !!stored[0] && !stored[0].password_hash.includes(password))

// 404 shape ----------------------------------------------------------------
const missing = await call('/v1/nope')
const missingBody = await missing.json() as Record<string, unknown>
check('unknown route returns the problem shape',
      missing.status === 404 && typeof missingBody.code === 'string'
        && typeof missingBody.message === 'string' && 'field' in missingBody,
      missingBody)

await sql.end()
console.log(failures === 0 ? '\nall checks passed' : `\n${failures} check(s) failed`)
process.exit(failures === 0 ? 0 : 1)
