//
// index.ts — the app. Routes are mounted under /v1 to match RefindEnvironment.
//

import { Hono } from 'hono'
import { serve } from '@hono/node-server'
import { pathToFileURL } from 'node:url'
import { authRoutes } from './routes/auth.js'
import { meRoutes } from './routes/me.js'
import { wantRoutes } from './routes/wants.js'
import type { Vars } from './auth.js'

const app = new Hono<{ Variables: Vars }>()

app.get('/health', (c) => c.json({ ok: true }))

const v1 = new Hono<{ Variables: Vars }>()
v1.route('/auth', authRoutes)
v1.route('/me', meRoutes)
v1.route('/wants', wantRoutes)
app.route('/v1', v1)

app.onError((err, c) => {
  // Never leak internals to a client; the message a user sees is always ours.
  console.error(err)
  return c.json({ code: 'server_error', message: 'Das hat nicht geklappt.', field: null }, 500)
})

app.notFound((c) =>
  c.json({ code: 'not_found', message: 'Das gibt es nicht mehr.', field: null }, 404)
)

export default app

// Only listen when run directly. Importing this module — the self-test does,
// and so does Vercel — must not bind a port.
const isEntrypoint =
  process.argv[1] !== undefined &&
  import.meta.url === pathToFileURL(process.argv[1]).href

if (isEntrypoint && !process.env.VERCEL) {
  const port = Number(process.env.PORT ?? 3000)
  serve({ fetch: app.fetch, port })
  console.log(`refind api on http://localhost:${port}`)
}
