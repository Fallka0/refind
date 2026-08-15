//
// migrate.ts — applies sql/*.sql in order. Small enough that a migration
// framework would be more machinery than the problem needs.
//

import { readdir, readFile } from 'node:fs/promises'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { sql } from './db.js'

const here = dirname(fileURLToPath(import.meta.url))
const dir = join(here, '..', 'sql')

const files = (await readdir(dir)).filter((f) => f.endsWith('.sql')).sort()
for (const file of files) {
  process.stdout.write(`applying ${file} … `)
  await sql.unsafe(await readFile(join(dir, file), 'utf8'))
  console.log('ok')
}
await sql.end()
