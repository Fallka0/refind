//
// routes/auth.ts — register, login, refresh, sign out.
//

import { Hono } from 'hono'
import { z } from 'zod'
import { sql } from '../db.js'
import { Problems } from '../errors.js'
import {
  hashPassword, verifyPassword, issueAccessToken, issueRefreshToken,
  rotateRefreshToken, revokeAllSessions, requireAuth, type Vars,
} from '../auth.js'

export const authRoutes = new Hono<{ Variables: Vars }>()

const credentials = z.object({
  email: z.string().email().max(320),
  // 8 is the floor, not a recommendation. Length beats character classes, so
  // there is no punctuation rule here.
  password: z.string().min(8).max(200),
  displayName: z.string().trim().min(2).max(60).optional(),
})

authRoutes.post('/register', async (c) => {
  const parsed = credentials.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) {
    return Problems.invalid(
      c, 'Prüf deine E-Mail und ein Passwort mit mindestens 8 Zeichen.',
      parsed.error.issues[0]?.path.join('.')
    )
  }
  const { email, password, displayName } = parsed.data

  const existing = await sql`select id from users where lower(email) = lower(${email})`
  if (existing.length > 0) {
    return Problems.conflict(c, 'email_taken', 'Diese E-Mail ist schon registriert.')
  }

  const rows = await sql<{ id: string }[]>`
    insert into users (email, password_hash, display_name)
    values (${email}, ${await hashPassword(password)}, ${displayName ?? defaultName(email)})
    returning id
  `
  const id = rows[0]!.id
  return c.json({
    accessToken: await issueAccessToken(id),
    refreshToken: await issueRefreshToken(id),
    expiresIn: 900,
  }, 201)
})

authRoutes.post('/login', async (c) => {
  const parsed = credentials.omit({ displayName: true })
    .safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) {
    return Problems.invalid(c, 'Prüf deine E-Mail und dein Passwort.')
  }
  const { email, password } = parsed.data

  const rows = await sql<{ id: string; password_hash: string }[]>`
    select id, password_hash from users where lower(email) = lower(${email})
  `
  const user = rows[0]
  // Same response whether the address is unknown or the password is wrong —
  // otherwise this endpoint tells you which addresses have accounts.
  const ok = user ? await verifyPassword(password, user.password_hash) : false
  if (!user || !ok) {
    return Problems.invalid(c, 'E-Mail oder Passwort stimmt nicht.')
  }

  return c.json({
    accessToken: await issueAccessToken(user.id),
    refreshToken: await issueRefreshToken(user.id),
    expiresIn: 900,
  })
})

authRoutes.post('/refresh', async (c) => {
  const body = await c.req.json().catch(() => ({})) as { refreshToken?: unknown }
  if (typeof body.refreshToken !== 'string') return Problems.unauthorized(c)

  const rotated = await rotateRefreshToken(body.refreshToken)
  if (!rotated) return Problems.unauthorized(c)

  return c.json({
    accessToken: rotated.accessToken,
    refreshToken: rotated.refreshToken,
    expiresIn: 900,
  })
})

authRoutes.post('/signout', requireAuth, async (c) => {
  await revokeAllSessions(c.get('userId'))
  return c.body(null, 204)
})

/** "marc.b@example.ch" → "Marc B." — the display shape the designs use. */
function defaultName(email: string): string {
  const local = email.split('@')[0] ?? 'refind'
  const parts = local.split(/[._-]+/).filter(Boolean)
  const first = parts[0] ?? local
  const initial = parts[1]?.[0]
  const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1).toLowerCase()
  return initial ? `${cap(first)} ${initial.toUpperCase()}.` : cap(first)
}
