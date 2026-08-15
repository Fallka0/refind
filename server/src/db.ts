//
// db.ts — one Postgres connection for the process.
//

import postgres from 'postgres'

const url = process.env.DATABASE_URL
if (!url) throw new Error('DATABASE_URL is unset. See .env.example.')

export const sql = postgres(url, {
  // Serverless: one connection per invocation, closed by the platform.
  max: process.env.VERCEL ? 1 : 10,
  idle_timeout: 20,
  // Money is integer minor units end to end; never let a driver coerce to float.
  transform: { undefined: null },
})
