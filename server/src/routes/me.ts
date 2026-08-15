//
// routes/me.ts — session, stats, devices, verification.
//

import { Hono } from 'hono'
import { sql } from '../db.js'
import { Problems } from '../errors.js'
import { requireAuth, type Vars } from '../auth.js'

export const meRoutes = new Hono<{ Variables: Vars }>()

meRoutes.use('*', requireAuth)

meRoutes.get('/', async (c) => {
  const rows = await sql`
    select id, display_name, city, member_since, rating, deal_count, verified, avatar_url
      from users where id = ${c.get('userId')}
  `
  const u = rows[0]
  if (!u) return Problems.notFound(c)
  return c.json(toUser(u))
})

meRoutes.get('/stats', async (c) => {
  const userId = c.get('userId')
  const rows = await sql<{ rating: string; deal_count: number; live: string }[]>`
    select u.rating, u.deal_count,
           (select count(*) from wants w
             where w.owner_id = u.id and w.status = 'live') as live
      from users u where u.id = ${userId}
  `
  const r = rows[0]
  if (!r) return Problems.notFound(c)
  return c.json({
    rating: Number(r.rating),
    dealCount: r.deal_count,
    liveWantCount: Number(r.live),
  })
})

meRoutes.put('/devices', async (c) => {
  const body = await c.req.json().catch(() => ({})) as Record<string, unknown>
  if (typeof body.token !== 'string') return Problems.invalid(c, 'Kein Gerätetoken.')
  const environment = body.environment === 'production' ? 'production' : 'sandbox'
  await sql`
    insert into devices (token, user_id, environment, locale)
    values (${body.token}, ${c.get('userId')}, ${environment},
            ${typeof body.locale === 'string' ? body.locale : 'de-CH'})
    on conflict (token) do update
      set user_id = excluded.user_id,
          environment = excluded.environment,
          locale = excluded.locale,
          updated_at = now()
  `
  return c.body(null, 204)
})

meRoutes.get('/verification', async (c) => {
  const rows = await sql<{ verification_status: string }[]>`
    select verification_status from users where id = ${c.get('userId')}
  `
  return c.json({ status: rows[0]?.verification_status ?? 'unverified', reason: null })
})

meRoutes.post('/verification/session', async (c) => {
  // Documents never touch refind: the app opens the provider's hosted flow and
  // the provider calls a webhook. Until one is chosen this records intent only.
  await sql`
    update users set verification_status = 'pending'
     where id = ${c.get('userId')} and verification_status <> 'verified'
  `
  return c.json({
    sessionId: 'ver_pending',
    providerURL: process.env.VERIFICATION_URL ?? 'https://verify.refind.ch/session/pending',
  })
})

export function toUser(u: Record<string, any>) {
  return {
    id: u.id,
    displayName: u.display_name,
    city: u.city,
    memberSince: new Date(u.member_since).toISOString(),
    rating: Number(u.rating),
    dealCount: u.deal_count,
    verified: u.verified,
    avatarURL: u.avatar_url ?? null,
  }
}
