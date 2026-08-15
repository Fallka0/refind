//
// money.ts — the wire shape for every amount.
//

export type Money = { minorUnits: number; currency: string }

export const money = (minorUnits: number, currency = 'CHF'): Money => ({
  minorUnits,
  currency,
})

/** 2.5%, rounded to the nearest Rappen. Must agree with the client's estimate. */
export const escrowFee = (amountMinor: number): number =>
  Math.round(amountMinor * 0.025)
