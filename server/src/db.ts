//
// db.ts — one Postgres connection for the process.
//

import postgres from 'postgres'
import type { Sql } from 'postgres'

let client: Sql | undefined

function connect(): Sql {
  const url = process.env.DATABASE_URL
  if (!url) throw new Error('DATABASE_URL is unset. See .env.example.')
  return postgres(url, {
    // Serverless gets one connection per invocation. Hosted Postgres sits
    // behind a pooler; opening ten per lambda exhausts it under any load.
    max: process.env.VERCEL ? 1 : 10,
    idle_timeout: 20,
    // Money is integer minor units end to end; never let a driver coerce to float.
    transform: { undefined: null },
    // Neon and Vercel Postgres require TLS; a local socket does not offer it.
    ssl: url.includes('localhost') || url.includes('127.0.0.1') ? false : 'require',
  })
}

/**
 * Connects on first use rather than at import. A missing environment variable
 * then fails one request with a clear message instead of the whole deployment.
 */
export const sql: Sql = new Proxy((() => {}) as unknown as Sql, {
  apply(_target, _thisArg, args: Parameters<Sql>) {
    client ??= connect()
    return (client as unknown as (...a: Parameters<Sql>) => unknown)(...args)
  },
  get(_target, prop) {
    client ??= connect()
    return Reflect.get(client as object, prop)
  },
})
