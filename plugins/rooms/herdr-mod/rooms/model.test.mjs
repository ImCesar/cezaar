import { test } from 'node:test'
import assert from 'node:assert/strict'
import { applyMention, createSaver, mentionCandidates, mentionQuery, groupByRoot, mergeRead, roomTerminals, liveRoots, newOperatorMentions, parseLog, parseTail, roomSummary, shouldReload, sortRooms, toNotify } from './model.js'

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

test('groupByRoot keeps same-named rooms from two runs apart, labelled by run', () => {
  const rows = [
    { room: 'kernel', root: '/x/runs/20261122-ravo/rooms', needsYou: 1 },
    { room: 'kernel', root: '/x/runs/20261123-pog/rooms', needsYou: 0 },
    { room: 'store', root: '/x/runs/20261122-ravo/rooms', needsYou: 0 },
  ]
  const groups = groupByRoot(rows)
  assert.deepEqual(groups.map(g => [g.label, g.rooms.map(r => r.room)]), [
    ['20261122-ravo/rooms', ['kernel', 'store']],
    ['20261123-pog/rooms', ['kernel']],
  ])
})

test("toNotify: a new room's first mention is notified; history from before the panel started is not", () => {
  const started = '2026-11-23T05:00:05.000000Z'
  const msgs = [m('1', 'a', '@cesar old', ['cesar']), m('7', 'a', '@cesar new', ['cesar']), m('8', 'b', '@cesar newer', ['cesar'])]
  assert.deepEqual(toNotify(undefined, msgs, 'cesar', started).map(x => x.id), ['7', '8'])
  assert.deepEqual(toNotify('7', msgs, 'cesar', started).map(x => x.id), ['8'])
})

test('createSaver runs one write at a time and lands the latest state', async () => {
  let disk = null
  let writes = 0
  let inFlight = 0
  const write = async (text, expected) => {
    inFlight++
    assert.equal(inFlight, 1, 'two writes overlapped')
    await new Promise(r => setTimeout(r, 5))
    if (expected !== disk) { inFlight--; throw new Error('stale') }
    disk = text
    writes++
    inFlight--
  }
  const save = createSaver(write, async () => disk, null)
  save('a'); save('b'); save('c')
  await new Promise(r => setTimeout(r, 60))
  assert.equal(disk, 'c')
  assert.ok(writes <= 2, `writes=${writes}`)
})

const term = (address, room, id, extra = {}) => ({ address, state: 'live', status: 'idle', labels: { 'rooms.root': '/r', 'rooms.room': room, 'rooms.id': id }, ...extra })

test('roomTerminals keeps live terminals of this root and room, in members order', () => {
  const members = [{ id: 'auth-builder' }, { id: 'auth-reviewer' }, { id: 'cesar' }]
  const ts = [
    term('t3', 'auth', 'auth-reviewer', { status: { state: 'working', app: 'claude-code' } }),
    term('t2', 'auth', 'auth-builder'),
    term('t4', 'billing', 'billing-builder'),
    { ...term('t5', 'auth', 'auth-builder'), labels: { 'rooms.root': '/other', 'rooms.room': 'auth', 'rooms.id': 'auth-builder' } },
    term('t6', 'auth', 'auth-builder', { state: 'finished' }),
    { address: 't7', state: 'live' },
  ]
  assert.deepEqual(roomTerminals(ts, '/r', 'auth', members), [
    { address: 't2', id: 'auth-builder', status: 'idle' },
    { address: 't3', id: 'auth-reviewer', status: 'working' },
  ])
})

test('roomTerminals puts ids not in members last, and returns [] when nothing matches', () => {
  const ts = [term('t9', 'auth', 'stranger'), term('t2', 'auth', 'auth-builder', { status: null })]
  assert.deepEqual(roomTerminals(ts, '/r', 'auth', [{ id: 'auth-builder' }]).map(x => [x.id, x.status]), [['auth-builder', 'unknown'], ['stranger', 'idle']])
  assert.deepEqual(roomTerminals(ts, '/r', 'nope', []), [])
  assert.deepEqual(roomTerminals(undefined, '/r', 'auth', []), [])
})

test('mergeRead keeps the newer mark per room and reports whether anything moved', () => {
  const mine = { a: '20261123T01', b: '20261123T05' }
  const out = mergeRead(mine, { a: '20261123T03', b: '20261123T02', c: '20261123T09', bad: 7 })
  assert.deepEqual(out.lastRead, { a: '20261123T03', b: '20261123T05', c: '20261123T09' })
  assert.equal(out.changed, true)
  assert.equal(mergeRead(out.lastRead, { a: '20261123T00' }).changed, false)
  assert.deepEqual(mergeRead(undefined, null), { lastRead: {}, changed: false })
})

test('mentionQuery finds the @-word at the cursor', () => {
  assert.deepEqual(mentionQuery('hi @su', 6), { start: 3, end: 6, query: 'su' })
  assert.equal(mentionQuery('a@b', 3), null)
  assert.deepEqual(mentionQuery('@', 1), { start: 0, end: 1, query: '' })
  assert.equal(mentionQuery('@ab cd', 6), null)
  assert.deepEqual(mentionQuery('x @abc', 4), { start: 2, end: 4, query: 'a' })
  assert.deepEqual(mentionQuery('a\n@b', 4), { start: 2, end: 4, query: 'b' })
})

test('mentionCandidates orders members then first posters, drops the operator and duplicates', () => {
  const members = [{ id: 'store-builder' }, { id: 'store-reviewer' }, { id: 'cesar' }]
  const msgs = [{ from: 'lead' }, { from: 'store-builder' }, { from: 'cesar' }, { from: 'judge' }, { from: 'lead' }]
  assert.deepEqual(mentionCandidates(members, msgs, 'cesar', ''), ['store-builder', 'store-reviewer', 'lead', 'judge'])
})

test('mentionCandidates filters ignoring case, starts-with before contains, keeping order', () => {
  const members = [{ id: 'store-reviewer' }, { id: 'Reviewer' }, { id: 'x-rev' }, { id: 'lead' }]
  assert.deepEqual(mentionCandidates(members, [{ from: 'revisor' }], 'cesar', 'REV'), ['Reviewer', 'revisor', 'store-reviewer', 'x-rev'])
})

test('mentionCandidates tolerates missing and bad entries', () => {
  assert.deepEqual(mentionCandidates(undefined, null, 'cesar', ''), [])
  assert.deepEqual(mentionCandidates([null, {}, { id: 7 }, { id: 'a' }], [null, {}, { from: {} }, { from: 'b' }], 'cesar', ''), ['a', 'b'])
  assert.deepEqual(mentionCandidates([{ id: 'cesar' }], [], undefined, ''), ['cesar'])
})

test('applyMention replaces the query and places the cursor after it', () => {
  assert.deepEqual(applyMention('hi @su there', 3, 6, 'store', true), { text: 'hi @store  there', cursor: 10 })
  assert.deepEqual(applyMention('hi @su', 3, 6, 'store', false), { text: 'hi @store', cursor: 9 })
})
