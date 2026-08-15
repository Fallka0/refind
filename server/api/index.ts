//
// api/index.ts — the Vercel entry point.
//
// A Hono app is a fetch handler, so hosting it is an adapter and nothing else:
// the same `app` object serves locally, in the self-test, and here.
//

import { handle } from 'hono/vercel'
import app from '../src/index.js'

export const config = { runtime: 'nodejs' }

export default handle(app)
