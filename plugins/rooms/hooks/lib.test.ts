import { expect, test } from 'claude-code/testing'
import {
  formatBatch,
  mentionsFor,
  parseLines,
  quietVerdicts,
  sleptRecently,
  startCursor,
  type Member,
  type Msg,
  type Presence,
} from './lib'

const msg = (id: string, from: string, text: string, mentions: string[], room = 'r'): Msg => ({
  id, ts: '2026-11-23T05:00:00.000000Z', room, from, kind: 'msg', text, mentions,
})

test('parseLines keeps a partial line and skips a bad one', async () => {
  const a = JSON.stringify(msg('1', 'a', 'one', []))
  const b = JSON.stringify(msg('2', 'b', 'two', []))
  const out = parseLines(`${a}\n{"bro\n${b}\n{"par`)
  expect(out.msgs.map(m => m.id)).toEqual(['1', '2'])
  expect(out.bad).toBe(1)
  expect(out.rest).toBe('{"par')
})

test('mentionsFor excludes my own messages, @all included', async () => {
  const msgs = [
    msg('1', 'a', '@a note to self', ['a']),
    msg('2', 'a', '@all from a', ['all']),
    msg('3', 'b', '@all from b', ['all']),
    msg('4', 'b', '@a direct', ['a']),
    msg('5', 'b', 'no mention', []),
  ]
  expect(mentionsFor(msgs, 'a').map(m => m.id)).toEqual(['3', '4'])
  expect(mentionsFor(msgs, 'a', '3').map(m => m.id)).toEqual(['4'])
})

test('startCursor prefers delivered, then joinedAt', async () => {
  const member: Member = { id: 'b', joinedAt: '2026-11-23T05:39:20.443123Z' }
  const pres: Presence = { id: 'b', state: 'idle', ts: '2026-11-23T05:40:00.000000Z', delivered: 'X' }
  expect(startCursor(member, pres)).toBe('X')
  expect(startCursor(member, undefined)).toBe('20261123T053920.443123Z')
  expect('20261123T053920.443123Z-a1b2c3' > startCursor(member, undefined)).toBe(true)
})

test('formatBatch caps at 20 and says how many were left out', async () => {
  const msgs = Array.from({ length: 25 }, (_, i) => msg(String(100 + i), 'a', `m${i} @b`, ['b']))
  const lines = formatBatch(msgs).split('\n')
  expect(lines[0]).toBe('Room messages for you (reply with: room post <room> "<text>")')
  expect(lines[1]).toBe('5 earlier — run room read r --mentions-only')
  expect(lines.length).toBe(22)
  expect(lines[21]).toBe('#r a: m24 @b')
})

test('quietVerdicts flags stale and quiet members, skips done and flagged', async () => {
  const now = Date.parse('2026-11-23T06:00:00.000Z')
  const iso = (msAgo: number) => new Date(now - msAgo).toISOString()
  const members: Member[] = ['s', 'q', 'd', 'f', 'ok', 'never'].map(id => ({ id, joinedAt: iso(3_600_000) }))
  const presences: Record<string, Presence> = {
    s: { id: 's', state: 'working', ts: iso(121_000) },
    q: { id: 'q', state: 'idle', ts: iso(5_000) },
    d: { id: 'd', state: 'idle', ts: iso(121_000) },
    f: { id: 'f', state: 'idle', ts: iso(121_000) },
    ok: { id: 'ok', state: 'idle', ts: iso(5_000) },
  }
  const lastPostTs = { q: now - 601_000, ok: now - 60_000 }
  const out = quietVerdicts({
    now, members, presences, lastPostTs, done: new Set(['d']), quietMs: 600_000, staleMs: 120_000,
    alreadyFlagged: new Set(['f']),
  })
  expect(out).toEqual([{ id: 's', reason: 'stale' }, { id: 'q', reason: 'quiet' }])
})

test('sleptRecently detects a timer gap and sets a grace window', async () => {
  const now = 1_000_000
  expect(sleptRecently(now - 7000, now, 3000, 0)).toEqual({ slept: true, graceUntil: now + 180_000 })
  expect(sleptRecently(now - 3100, now, 3000, 5)).toEqual({ slept: false, graceUntil: 5 })
})
