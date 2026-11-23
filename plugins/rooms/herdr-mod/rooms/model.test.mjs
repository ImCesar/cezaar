import { test } from 'node:test'
import assert from 'node:assert/strict'
import { liveRoots, newOperatorMentions, parseLog, parseTail, roomSummary, shouldReload, sortRooms } from './model.js'

const m = (id, from, text, mentions = [], kind = 'msg') => ({ id, ts: `2026-11-23T05:00:0${id.slice(-1)}.000000Z`, room: 'r', from, kind, text, mentions })

test('parseLog skips a garbled line', () => {
  const text = `${JSON.stringify(m('1', 'a', 'one'))}\n{"broken\n${JSON.stringify(m('2', 'b', 'two'))}\n`
  const out = parseLog(text)
  assert.deepEqual(out.msgs.map(x => x.id), ['1', '2'])
  assert.equal(out.bad, 1)
})

test('roomSummary counts needs-you and unread, ignoring my own messages', () => {
  const msgs = [m('1', 'a', 'old @cesar', ['cesar']), m('2', 'a', 'new @cesar', ['cesar']), m('3', 'cesar', 'me @cesar', ['cesar']), m('4', 'b', 'chat')]
  const s = roomSummary(msgs, [], {}, 'cesar', '1', Date.parse('2026-11-23T05:01:00Z'))
  assert.equal(s.needsYou, 1)
  assert.equal(s.unread, 2)
  assert.equal(s.lastTs, msgs[3].ts)
})

test('sortRooms orders needs-you, then unread, then quiet, newest first within a group', () => {
  const rows = [
    { room: 'quiet-old', needsYou: 0, unread: 0, lastTs: '2026-11-23T01:00:00Z' },
    { room: 'unread', needsYou: 0, unread: 3, lastTs: '2026-11-23T02:00:00Z' },
    { room: 'quiet-new', needsYou: 0, unread: 0, lastTs: '2026-11-23T03:00:00Z' },
    { room: 'needs', needsYou: 1, unread: 1, lastTs: '2026-11-23T00:00:00Z' },
  ]
  assert.deepEqual(sortRooms(rows).map(r => r.room), ['needs', 'unread', 'quiet-new', 'quiet-old'])
})

test('presence is gone after 120 s without a heartbeat', () => {
  const now = Date.parse('2026-11-23T06:00:00Z')
  const members = [{ id: 'a', joinedAt: '' }, { id: 'b', joinedAt: '' }, { id: 'c', joinedAt: '' }, { id: 'cesar', joinedAt: '' }]
  const presences = {
    a: { id: 'a', state: 'working', ts: new Date(now - 30_000).toISOString() },
    b: { id: 'b', state: 'idle', ts: new Date(now - 121_000).toISOString() },
  }
  const s = roomSummary([], members, presences, 'cesar', undefined, now)
  assert.deepEqual(s.presence, [{ id: 'a', state: 'working' }, { id: 'b', state: 'gone' }, { id: 'c', state: 'gone' }])
})

test('newOperatorMentions returns only new mentions of the operator by others', () => {
  const msgs = [m('1', 'a', '@cesar old', ['cesar']), m('2', 'a', '@all hi', ['all']), m('3', 'cesar', '@cesar', ['cesar']), m('4', 'b', 'no')]
  assert.deepEqual(newOperatorMentions('1', msgs, 'cesar').map(x => x.id), ['2'])
})

test('liveRoots drops roots whose folder is gone', () => {
  const roots = [{ path: '/a', lastUsed: 'x' }, { path: '/gone', lastUsed: 'y' }]
  assert.deepEqual(liveRoots(roots, p => p !== '/gone').map(r => r.path), ['/a'])
})

test('shouldReload ignores heartbeat-only changes but not logs, members or a root refresh', () => {
  const root = '/r'
  assert.equal(shouldReload(['/r/k/presence/a.json', '/r/k/presence/b.json.123.tmp'], root), false)
  assert.equal(shouldReload(['/r/k/presence/a.json', '/r/k/log.jsonl'], root), true)
  assert.equal(shouldReload(['/r/k/members.json'], root), true)
  assert.equal(shouldReload(['/r'], root), true)
  assert.equal(shouldReload([], root), true)
})

test('parseTail drops the partial first line of a tail read', () => {
  const tail = `xt":"cut off"}\n${JSON.stringify(m('5', 'a', 'whole'))}\n`
  const out = parseTail(tail)
  assert.deepEqual(out.msgs.map(x => x.id), ['5'])
  assert.equal(out.bad, 0)
})
