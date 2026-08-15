//
// errors.ts — the problem shape from docs/API.md.
//
// Messages are German, du-form, and shown to the user verbatim. Validation
// lives here, so its wording does too.
//

import type { Context } from 'hono'
import type { ContentfulStatusCode } from 'hono/utils/http-status'

export function problem(
  c: Context, status: ContentfulStatusCode, code: string, message: string, field?: string
) {
  return c.json({ code, message, field: field ?? null }, status)
}

export const Problems = {
  notFound: (c: Context, message = 'Das gibt es nicht mehr.') =>
    problem(c, 404, 'not_found', message),
  invalid: (c: Context, message: string, field?: string) =>
    problem(c, 400, 'invalid_input', message, field),
  conflict: (c: Context, code: string, message: string) =>
    problem(c, 409, code, message),
  unauthorized: (c: Context) =>
    problem(c, 401, 'unauthorized', 'Bitte melde dich neu an.'),
  rateLimited: (c: Context, retryAfter: number) => {
    c.header('Retry-After', String(Math.ceil(retryAfter)))
    return problem(c, 429, 'rate_limited', 'Zu viele Versuche. Probier es später nochmal.')
  },
  server: (c: Context) => problem(c, 500, 'server_error', 'Das hat nicht geklappt.'),
}
