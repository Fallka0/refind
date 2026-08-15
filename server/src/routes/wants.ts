//
// routes/wants.ts
//
// Wants are public to read (that decision is in docs/API.md), so the read
// endpoints use optionalAuth: anyone can see a want, but the owner sees their
// own unread counts and a signed-in reader gets their saved state.
//

import { Hono } from 'hono'
import { z } from 'zod'
import { sql } from '../db.js'
import { Problems } from '../errors.js'
import { requireAuth, optionalAuth, type Vars } from '../auth.js'
import { rateLimit } from '../ratelimit.js'
import { money } from '../money.js'

export const wantRoutes = new Hono<{ Variables: Partial<Vars> }>()

const CATEGORIES = ['uhren', 'moebel', 'velo', 'vinyl', 'kameras', 'werkzeug'] as const
const CONDITIONS = ['original', 'serviced', 'any'] as const

const draft = z.object({
  title: z.string().trim().min(3).max(140),
  category: z.enum(CATEGORIES),
  budgetMax: z.object({
    minorUnits: z.number().int().positive().max(10_000_000),
    currency: z.string().default('CHF'),
  }),
  condition: z.enum(CONDITIONS),
  region: z.string().trim().min(1).max(80),
  radiusKm: z.number().int().min(1).max(500).default(30),
  durationDays: z.number().int().min(1).max(90).default(14),
})

// Reads --------------------------------------------------------------------

wantRoutes.get('/mine', requireAuth, async (c) => {
  const userId = c.get('userId')!
  const rows = await sql`
    ${baseSelect(userId)}
     where w.owner_id = ${userId}
     order by case w.status when 'live' then 0 when 'paused' then 1
                            when 'fulfilled' then 2 else 3 end,
              w.created_at desc
  `
  return c.json({ items: rows.map(toWant), nextCursor: null })
})

wantRoutes.get('/saved', requireAuth, async (c) => {
  const userId = c.get('userId')!
  const rows = await sql`
    ${baseSelect(userId)}
      join saved_wants s on s.want_id = w.id and s.user_id = ${userId}
     order by s.saved_at desc
  `
  return c.json({ items: rows.map(toWant), nextCursor: null })
})

wantRoutes.get('/discover', optionalAuth, async (c) => {
  const userId = c.get('userId') ?? null
  const category = c.req.query('category') ?? ''
  const q = (c.req.query('q') ?? '').trim()
  const limit = Math.min(Number(c.req.query('limit') ?? 20) || 20, 100)

  // Two matchers, because they catch different things. Full-text ranks and
  // handles inflection; trigrams catch German compounds, which stemming does
  // not decompose ("Velo" has to find "Rennvelo"). See sql/002.
  const rows = await sql`
    ${baseSelect(userId)}
     where w.status = 'live'
       and (${userId}::text is null or w.owner_id <> ${userId})
       and (${category} = '' or w.category = ${category})
       and (${q} = ''
             or w.search @@ websearch_to_tsquery('german', ${q})
             or lower(w.title) like '%' || lower(${q}) || '%'
             or lower(coalesce(w.description, '')) like '%' || lower(${q}) || '%')
       and not exists (
         select 1 from blocks b
          where (b.blocker_id = ${userId} and b.blocked_id = w.owner_id)
             or (b.blocked_id = ${userId} and b.blocker_id = w.owner_id)
       )
     order by
       -- A full-text hit outranks a mere substring hit.
       case when ${q} = '' then 0
            else ts_rank(w.search, websearch_to_tsquery('german', ${q}))
                 + case when lower(w.title) like '%' || lower(${q}) || '%'
                        then 0.1 else 0 end
       end desc,
       w.created_at desc
     limit ${limit}
  `
  return c.json({ items: rows.map(toWant), nextCursor: null })
})

wantRoutes.get('/suggestions', async (c) => {
  const q = (c.req.query('q') ?? '').trim()
  if (q.length < 2) return c.json({ items: [] })
  // Distinct titles from live wants. A real catalogue would back this; the
  // index is the same either way.
  const rows = await sql<{ title: string }[]>`
    select distinct title from wants
     where status = 'live'
       and (search @@ websearch_to_tsquery('german', ${q})
            or lower(title) like '%' || lower(${q}) || '%')
     order by title limit 3
  `
  return c.json({ items: rows.map((r) => r.title) })
})

wantRoutes.get('/:id', optionalAuth, async (c) => {
  const userId = c.get('userId') ?? null
  const rows = await sql`${baseSelect(userId)} where w.id = ${c.req.param('id') ?? ''}`
  const want = rows[0]
  if (!want) return Problems.notFound(c, 'Dieses Gesuch gibt es nicht mehr.')
  return c.json(toWant(want))
})

// Writes -------------------------------------------------------------------

wantRoutes.post('/', requireAuth, async (c) => {
  const userId = c.get('userId')!
  const retryAfter = await rateLimit(userId, 'wants.create')
  if (retryAfter) return Problems.rateLimited(c, retryAfter)

  const parsed = draft.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) return invalidDraft(c, parsed.error.issues[0])
  const d = parsed.data

  const rows = await sql`
    insert into wants (owner_id, title, category, budget_minor, currency,
                       condition, region, radius_km, expires_at)
    values (${userId}, ${d.title}, ${d.category}, ${d.budgetMax.minorUnits},
            ${d.budgetMax.currency}, ${d.condition}, ${d.region}, ${d.radiusKm},
            now() + (${d.durationDays} || ' days')::interval)
    returning id
  `
  return single(c, userId, rows[0]!.id, 201)
})

wantRoutes.patch('/:id', requireAuth, async (c) => {
  const userId = c.get('userId')!
  const id = c.req.param('id') ?? ''
  const parsed = draft.safeParse(await c.req.json().catch(() => ({})))
  if (!parsed.success) return invalidDraft(c, parsed.error.issues[0])
  const d = parsed.data

  const updated = await sql`
    update wants
       set title = ${d.title}, category = ${d.category},
           budget_minor = ${d.budgetMax.minorUnits}, condition = ${d.condition},
           region = ${d.region}, radius_km = ${d.radiusKm}
     where id = ${id} and owner_id = ${userId}
    returning id
  `
  if (updated.length === 0) return Problems.notFound(c)
  return single(c, userId, id)
})

wantRoutes.post('/:id/republish', requireAuth, async (c) => {
  const userId = c.get('userId')!
  const id = c.req.param('id') ?? ''
  const rows = await sql`
    update wants
       set status = 'live', created_at = now(),
           expires_at = now() + interval '14 days'
     where id = ${id} and owner_id = ${userId}
    returning id
  `
  if (rows.length === 0) return Problems.notFound(c)
  return single(c, userId, id)
})

wantRoutes.post('/:id/pause', requireAuth, async (c) => {
  const userId = c.get('userId')!
  const id = c.req.param('id') ?? ''
  const body = await c.req.json().catch(() => ({})) as { paused?: unknown }
  const paused = body.paused === true
  const rows = await sql`
    update wants set status = ${paused ? 'paused' : 'live'}
     where id = ${id} and owner_id = ${userId} and status in ('live','paused')
    returning id
  `
  if (rows.length === 0) return Problems.notFound(c)
  return single(c, userId, id)
})

wantRoutes.put('/:id/saved', requireAuth, async (c) => {
  const userId = c.get('userId')!
  const id = c.req.param('id') ?? ''
  const body = await c.req.json().catch(() => ({})) as { saved?: unknown }
  if (body.saved === true) {
    await sql`
      insert into saved_wants (user_id, want_id) values (${userId}, ${id})
      on conflict do nothing
    `
  } else {
    await sql`delete from saved_wants where user_id = ${userId} and want_id = ${id}`
  }
  return c.body(null, 204)
})

// Helpers ------------------------------------------------------------------

/**
 * One projection for every read. `unread` is only meaningful to the owner —
 * a stranger reading a want must not learn how much attention it is getting.
 */
function baseSelect(userId: string | null) {
  return sql`
    select w.*,
           (select count(*) from offers o
             where o.want_id = w.id and o.status <> 'withdrawn') as offer_count,
           (case when w.owner_id = ${userId} then (
              select count(*) from offers o
               where o.want_id = w.id and o.status = 'sent'
            ) else 0 end) as unread_count
      from wants w
  `
}

async function single(c: any, userId: string | null, id: string, status = 200) {
  const rows = await sql`${baseSelect(userId)} where w.id = ${id}`
  return c.json(toWant(rows[0]!), status)
}

function invalidDraft(c: any, issue?: { path: (string | number)[]; message: string }) {
  const field = issue?.path.join('.')
  const message = field?.startsWith('title')
    ? 'Der Titel braucht mindestens 3 Zeichen.'
    : field?.startsWith('budgetMax')
      ? "Setz ein Budget zwischen CHF 1 und CHF 100'000."
      : 'Prüf deine Angaben.'
  return Problems.invalid(c, message, field)
}

function toWant(w: Record<string, any>) {
  const expired = new Date(w.expires_at).getTime() < Date.now()
  return {
    id: w.id,
    ownerId: w.owner_id,
    title: w.title,
    category: w.category,
    budgetMax: money(w.budget_minor, w.currency),
    condition: w.condition,
    region: w.region,
    radiusKm: w.radius_km,
    description: w.description ?? null,
    createdAt: new Date(w.created_at).toISOString(),
    expiresAt: new Date(w.expires_at).toISOString(),
    // Expiry is a fact about the clock; a row does not have to be touched for
    // a want to be over.
    status: expired && w.status === 'live' ? 'expired' : w.status,
    offerCount: Number(w.offer_count ?? 0),
    unreadOfferCount: Number(w.unread_count ?? 0),
  }
}
