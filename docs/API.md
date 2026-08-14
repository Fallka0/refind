# refind API v1 — proposed contract

This is a **proposal**, not a description of something that exists. It is shaped
by what `RefindRepository` actually needs, so the client in
`Repository/Live/LiveRefindRepository.swift` compiles against it today and the
server can be built to match.

Base URL comes from `RefindEnvironment` (`https://api.refind.ch/v1` in
production). Everything is JSON, UTF-8.

## Conventions

**Money is minor units.** Every amount is an integer of Rappen plus a currency
code. `CHF 1'650.00` is `{"minorUnits": 165000, "currency": "CHF"}`. No floats
anywhere — a rounding error in a marketplace is a bug users can see.

**Dates are RFC 3339 with an offset**: `2026-08-14T12:41:00+02:00`. The client
formats for display in `de_CH`; the server never sends display strings.

**Ids are opaque strings.** The client treats them as tokens, never parses them.

**Pagination** is cursor-based. List responses are
`{"items": [...], "nextCursor": "..."}`; `nextCursor` is `null` on the last page.
Requests take `?cursor=&limit=` (default 20, max 100).

**Errors** use the problem shape below with the HTTP status carrying the class:

```json
{ "code": "want_not_found", "message": "Dieses Gesuch gibt es nicht mehr.", "field": null }
```

| Status | Meaning | Maps to |
|---|---|---|
| 400 | Validation failed (`field` names the offender) | `.invalidInput(message)` |
| 401 | Token missing or expired | triggers refresh, then `.server` |
| 404 | Gone | `.notFound` |
| 409 | Conflict (offer already accepted, escrow already released) | `.invalidInput(message)` |
| 429 | Rate limited (`Retry-After` honoured) | `.server` |
| 5xx | Server | `.server` |

`message` is **German, du-form**, and is shown to the user verbatim. That is a
deliberate coupling: validation rules live server-side, so their wording must
too. The client only writes copy for failures it detects itself (offline).

## Auth

Bearer tokens in `Authorization`. Access token ~15 min, refresh token 60 days,
rotated on use.

```
POST /auth/refresh   { "refreshToken": "…" }
  → { "accessToken": "…", "refreshToken": "…", "expiresIn": 900 }
```

A 401 triggers one refresh and one retry. A second 401 signs the user out.

## Core resources

### Session

```
GET  /me                → User
GET  /me/stats          → { "rating": 4.8, "dealCount": 11, "liveWantCount": 2 }
PATCH /me               { "city": "Bern", "radiusKm": 30 }
```

```json
// User
{
  "id": "usr_8f2a", "displayName": "Marc B.", "city": "Zürich",
  "memberSince": "2023-04-02T00:00:00+02:00",
  "rating": 4.9, "dealCount": 23, "verified": true,
  "avatarURL": "https://cdn.refind.ch/u/8f2a.jpg"
}
```

### Wants

```
GET    /wants/mine?status=live,paused,expired
GET    /wants/saved
GET    /wants/discover?category=&q=&cursor=&limit=
GET    /wants/{id}
POST   /wants                    WantDraft → Want
PATCH  /wants/{id}               WantDraft → Want
POST   /wants/{id}/republish     → Want
POST   /wants/{id}/pause         { "paused": true } → Want
PUT    /wants/{id}/saved         { "saved": true } → 204
GET    /wants/suggestions?q=     → { "items": ["Omega Seamaster 300", …] }
```

```json
// Want
{
  "id": "wnt_31c", "ownerId": "usr_8f2a",
  "title": "Omega Seamaster 166.062", "category": "uhren",
  "budgetMax": { "minorUnits": 200000, "currency": "CHF" },
  "condition": "original", "region": "Zürich", "radiusKm": 30,
  "description": null,
  "createdAt": "2026-08-11T09:12:00+02:00",
  "expiresAt": "2026-08-25T09:12:00+02:00",
  "status": "live",
  "offerCount": 4, "unreadOfferCount": 4
}
```

`category` ∈ `uhren | moebel | velo | vinyl | kameras | werkzeug`.
`condition` ∈ `original | serviced | any`.
`status` ∈ `live | paused | expired | fulfilled`.

**The category is the client's guess** (see `Category.inferred(from:)`) and the
server should treat it as a hint it may correct — it has the whole catalogue,
the client has a keyword table.

### Offers

```
GET  /wants/{id}/offers?sort=price_asc|price_desc|newest
POST /wants/{id}/offers          OfferDraft → Offer
POST /offers/{id}/accept         → { "thread": Thread }
```

Accepting is **atomic server-side**: it marks the offer accepted, declines the
others on that want, notifies those sellers, and returns the thread. The client
cannot do this in steps without a window where two offers are accepted.

```json
// Offer
{
  "id": "ofr_77b", "wantId": "wnt_31c", "seller": User,
  "price": { "minorUnits": 172000, "currency": "CHF" },
  "message": "166.062, Service 2024, mit Box und Papieren.",
  "photos": [{ "id": "pho_1", "url": "https://cdn.refind.ch/p/1.jpg" }],
  "createdAt": "2026-08-14T12:29:00+02:00",
  "status": "sent"
}
```

Over-budget offers are **accepted by the server**, not rejected — the design
shows them as `ÜBER BUDGET`. Only `price > 0` is enforced.

### Photo upload

Two-step, so image bytes never pass through the JSON API:

```
POST /uploads          { "contentType": "image/jpeg", "byteSize": 184320 }
  → { "photoId": "pho_9", "uploadURL": "https://…", "headers": {…}, "expiresAt": … }
PUT  {uploadURL}       (raw bytes, headers as given)
```

Then reference `photoId` when creating the offer or message. The client already
downscales to 1200 px before upload.

### Chat

```
GET  /threads?cursor=&limit=
GET  /threads/{id}/messages?cursor=&limit=
POST /threads/{id}/messages      { "kind": "text", "body": "…" }
                                 { "kind": "photo", "photoId": "pho_9" }
POST /threads/{id}/read          → 204
```

Live updates over WebSocket at `/threads/{id}/socket`, one frame per event:

```json
{ "type": "message", "message": Message }
{ "type": "typing", "userId": "usr_8f2a", "isTyping": true }
{ "type": "read", "userId": "usr_8f2a", "at": "2026-08-14T12:41:00+02:00" }
```

Typing is ephemeral and never persisted. The client's `partnerActivity` stream
maps straight onto the `typing` frames.

### Deals and escrow

```
GET  /threads/{id}/deal          → Deal | 404
POST /threads/{id}/deal          { "price": Money, "handoverAt": …, "handoverPlace": "Zürich HB" }
POST /deals/{id}/escrow          { "method": "escrow|card|cash" } → Escrow
POST /escrows/{id}/authorise     { "paymentToken": "…" } → Escrow
POST /escrows/{id}/handover      → Escrow
POST /escrows/{id}/release       → Escrow
POST /escrows/{id}/dispute       { "reason": "…", "detail": "…" } → Escrow
POST /deals/{id}/rating          { "stars": 5 } → 204
```

```json
// Escrow
{
  "id": "esc_4d", "dealId": "del_2a", "method": "escrow",
  "amount": { "minorUnits": 165000, "currency": "CHF" },
  "fee":    { "minorUnits": 4125,   "currency": "CHF" },
  "feeRate": "0.025",
  "receiptNumber": "RF-2026-0114",
  "paidAt": "2026-08-14T12:41:00+02:00",
  "stage": "paid",
  "autoRefundAt": "2026-08-17T12:41:00+02:00"
}
```

`stage` ∈ `paid | handover | released | disputed | refunded`.

**The fee is computed and returned by the server.** The client shows
`Escrow.fee(on:)` while composing, but the authoritative number is whatever the
escrow object carries — the two must not be allowed to disagree on a receipt.

`autoRefundAt` is the 72-hour promise made on screen 15. The server enforces it;
the client only displays it.

### Safety

```
POST /reports        { "subjectType": "user|want|offer|message", "subjectId": "…",
                       "reason": "…", "detail": "…" }  → 204
PUT  /blocks/{userId}    → 204
DELETE /blocks/{userId}  → 204
GET  /blocks             → { "items": [User] }
```

Blocking is symmetric and immediate: neither side sees the other's wants, offers
or threads afterwards. Existing threads are hidden, not deleted — an open escrow
still needs a paper trail.

### Verification

```
GET  /me/verification            → { "status": "unverified|pending|verified|rejected", "reason": … }
POST /me/verification/session    → { "sessionId": "…", "providerURL": "https://…" }
```

Identity documents **never touch refind's servers**. The app opens the
provider's flow at `providerURL`; the provider calls a server webhook, and the
app polls `GET /me/verification`. That keeps document handling inside a vendor
built for it.

### Push

```
PUT  /me/devices    { "token": "apns-hex", "environment": "sandbox|production",
                      "locale": "de-CH" }  → 204
DELETE /me/devices/{token}                 → 204
```

Payload carries a `type` and the ids to route to, never display copy — the
strings live in the app so they localise and can change without a server deploy:

```json
{ "aps": { "alert": { "loc-key": "push.offer.received", "loc-args": ["Marc B.", "CHF 1’720"] },
           "sound": "default", "badge": 3 },
  "type": "offer_received", "wantId": "wnt_31c", "offerId": "ofr_77b" }
```

## Decided

**Wants are public to view.** `GET /wants/discover`, `GET /wants/{id}` and
`GET /wants/{id}/offers` serve without a token, so a want can be linked and read
by anyone — which is what makes the "Teilen" button worth having. Budgets are
public by consequence; that is accepted. Everything that *acts* (offering,
saving, chatting, paying) still requires auth, and `unreadOfferCount` is only
populated for the owner.

**Search is properly indexed, not a substring scan.** `q` hits a search index
over title, description and category with per-language stemming (German
compounds matter here: "Rennvelo" must find "Velo"). `GET /wants/suggestions` is
backed by the same index against a curated product catalogue, so the typeahead
on screen 04 proposes real models rather than other users' typos. Ranking:
exact model match, then prefix, then fuzzy within an edit distance of 1.

**Rate limits.** Per user, sliding window, `429` with `Retry-After` in seconds:

| Endpoint | Limit |
|---|---|
| `POST /wants/{id}/offers` | 10 / hour, 30 / day |
| `POST /wants` | 20 / day |
| `POST /threads/{id}/messages` | 60 / minute |
| `POST /reports` | 10 / day |
| `POST /me/verification/session` | 5 / day |
| `GET` endpoints | 120 / minute |

Offer creation is the spam surface that matters: it reaches another person's
notifications. The client honours `Retry-After` and shows the server's message
rather than retrying blindly.

## Still open

**The escrow provider.** `POST /escrows/{id}/authorise` takes a `paymentToken`
on the assumption of a tokenised card (Stripe-style), which keeps card data out
of both the app and refind's servers. Deferred until a provider is chosen — that
choice dictates the request's real shape and is the one thing here that should
not be guessed.
