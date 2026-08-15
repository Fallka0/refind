//
// auth.ts — passwords, tokens, and the middleware that reads them.
//
// Sign in with Apple is the better fit for an iOS app, but it needs the
// com.apple.developer.applesignin entitlement, which a free personal team
// cannot provision. Email + password keeps device testing possible today;
// the token half below does not change when Apple sign-in is added.
//

import { randomBytes, scrypt as _scrypt, timingSafeEqual, createHash } from 'node:crypto'
import { promisify } from 'node:util'
import { SignJWT, jwtVerify } from 'jose'
import type { Context, Next } from 'hono'
import { sql } from './db.js'

const scrypt = promisify(_scrypt) as (
  password: string, salt: Buffer, keylen: number
) => Promise<Buffer>

// scrypt from node:crypto rather than bcrypt/argon2: no native build, so it
// works identically on a laptop and on Vercel's runtime.
const KEYLEN = 64

export async function hashPassword(password: string): Promise<string> {
  const salt = randomBytes(16)
  const key = await scrypt(password, salt, KEYLEN)
  return `${salt.toString('base64')}:${key.toString('base64')}`
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const [saltB64, keyB64] = stored.split(':')
  if (!saltB64 || !keyB64) return false
  const key = Buffer.from(keyB64, 'base64')
  const candidate = await scrypt(password, Buffer.from(saltB64, 'base64'), KEYLEN)
  // Constant-time: a length mismatch must not short-circuit either.
  if (candidate.length !== key.length) return false
  return timingSafeEqual(candidate, key)
}

// Tokens ------------------------------------------------------------------

const ACCESS_TTL_SECONDS = 15 * 60
const REFRESH_TTL_DAYS = 60

function secret(): Uint8Array {
  const raw = process.env.JWT_SECRET
  if (!raw || raw === 'replace-me') {
    throw new Error('JWT_SECRET is unset. See .env.example.')
  }
  return new TextEncoder().encode(raw)
}

export async function issueAccessToken(userId: string): Promise<string> {
  return new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setIssuer('refind')
    .setExpirationTime(`${ACCESS_TTL_SECONDS}s`)
    .sign(secret())
}

/**
 * Refresh tokens are opaque random strings. Only their hash is stored, so a
 * database leak cannot mint sessions, and each is single-use — refreshing
 * revokes the old row and issues a new one.
 */
export async function issueRefreshToken(userId: string): Promise<string> {
  const token = randomBytes(32).toString('base64url')
  const expires = new Date(Date.now() + REFRESH_TTL_DAYS * 86_400_000)
  await sql`
    insert into refresh_tokens (user_id, token_hash, expires_at)
    values (${userId}, ${sha256(token)}, ${expires})
  `
  return token
}

export async function rotateRefreshToken(
  token: string
): Promise<{ userId: string; accessToken: string; refreshToken: string } | null> {
  const rows = await sql<{ id: string; user_id: string }[]>`
    update refresh_tokens
       set revoked_at = now()
     where token_hash = ${sha256(token)}
       and revoked_at is null
       and expires_at > now()
    returning id, user_id
  `
  const row = rows[0]
  if (!row) return null
  return {
    userId: row.user_id,
    accessToken: await issueAccessToken(row.user_id),
    refreshToken: await issueRefreshToken(row.user_id),
  }
}

export async function revokeAllSessions(userId: string): Promise<void> {
  await sql`
    update refresh_tokens set revoked_at = now()
     where user_id = ${userId} and revoked_at is null
  `
}

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex')
}

// Middleware --------------------------------------------------------------

export type Vars = { userId: string }

/** Requires a valid access token. */
export async function requireAuth(c: Context<{ Variables: Vars }>, next: Next) {
  const userId = await userIdFrom(c)
  if (!userId) {
    return c.json(
      { code: 'unauthorized', message: 'Bitte melde dich neu an.', field: null },
      401
    )
  }
  c.set('userId', userId)
  await next()
}

/**
 * Reads the token when present but does not demand one — wants are public to
 * view, and the owner still needs to be recognised for unreadOfferCount.
 */
export async function optionalAuth(c: Context<{ Variables: Partial<Vars> }>, next: Next) {
  const userId = await userIdFrom(c)
  if (userId) c.set('userId', userId)
  await next()
}

async function userIdFrom(c: Context): Promise<string | null> {
  const header = c.req.header('Authorization')
  if (!header?.startsWith('Bearer ')) return null
  try {
    const { payload } = await jwtVerify(header.slice(7), secret(), { issuer: 'refind' })
    return typeof payload.sub === 'string' ? payload.sub : null
  } catch {
    return null
  }
}
