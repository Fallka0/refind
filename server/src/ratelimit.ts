//
// ratelimit.ts — sliding window per user per bucket.
//
// Limits are in docs/API.md. Offer creation is the one that matters: it reaches
// another person's notifications, so it is the obvious spam surface.
//

import { sql } from './db.js'

export type Bucket = keyof typeof LIMITS

const LIMITS = {
  'offers.create':   [{ max: 10, windowSeconds: 3600 }, { max: 30, windowSeconds: 86_400 }],
  'wants.create':    [{ max: 20, windowSeconds: 86_400 }],
  'messages.send':   [{ max: 60, windowSeconds: 60 }],
  'reports.create':  [{ max: 10, windowSeconds: 86_400 }],
  'verification':    [{ max: 5,  windowSeconds: 86_400 }],
} as const

/**
 * Records the attempt and returns how long to wait, or null when allowed.
 * Counting before deciding means a burst of parallel requests cannot all read
 * a stale count and slip through together.
 */
export async function rateLimit(
  userId: string, bucket: Bucket
): Promise<number | null> {
  const windows = LIMITS[bucket]
  const longest = Math.max(...windows.map((w) => w.windowSeconds))

  await sql`insert into rate_events (user_id, bucket) values (${userId}, ${bucket})`

  const rows = await sql<{ at: Date }[]>`
    select at from rate_events
     where user_id = ${userId} and bucket = ${bucket}
       and at > now() - (${longest} || ' seconds')::interval
     order by at desc
  `

  const now = Date.now()
  for (const window of windows) {
    const cutoff = now - window.windowSeconds * 1000
    const inWindow = rows.filter((r) => new Date(r.at).getTime() > cutoff)
    if (inWindow.length > window.max) {
      // Wait until the oldest event in this window falls out of it.
      const oldest = inWindow[inWindow.length - 1]
      const retryAfter = oldest
        ? (new Date(oldest.at).getTime() + window.windowSeconds * 1000 - now) / 1000
        : window.windowSeconds
      return Math.max(1, retryAfter)
    }
  }
  return null
}

/** Housekeeping — call from a cron, not from a request. */
export async function pruneRateEvents(): Promise<void> {
  await sql`delete from rate_events where at < now() - interval '2 days'`
}
