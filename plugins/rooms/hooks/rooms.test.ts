import { expect, mock, test } from 'claude-code/testing'

// An in-memory rooms root the tests' hooks serve to the mod, standing for the engine.
type World = {
  files: Record<string, string>
  mtimes: Record<string, number>
  runs: string[][]
  submits: { text: string; asUser?: boolean }[]
  logs: string[]
  dropNext: number
  rootMissing: boolean
}

const JOINED = '2026-11-23T05:00:00.000000Z'

function line(id: string, from: string, text: string, mentions: string[], kind = 'msg') {
  return JSON.stringify({ id, ts: JOINED, room: 'r', from, kind, text, mentions }) + '\n'
}

function world(on: any, opts: { env?: Record<string, string>; log?: string; readLimit?: number; runHook?: (argv: string[]) => any } = {}): World {
  const w: World = {
    files: {
      '/cfg/config.json': JSON.stringify({ operator: 'cesar', quietMinutes: 10 }),
      '/rooms/r/members.json': JSON.stringify([
        { id: 'a', role: 'builder', joinedAt: JOINED },
        { id: 'b', role: 'reviewer', joinedAt: JOINED },
      ]),
      '/rooms/r/log.jsonl': opts.log ?? '',
    },
    mtimes: {},
    runs: [],
    submits: [],
    logs: [],
    dropNext: 0,
    rootMissing: false,
  }
  mock.env(on, opts.env ?? { ROOM_ID: 'b', ROOMS_ROOT: '/rooms', ROOMS_CONFIG_DIR: '/cfg', HOME: '/home' })
  mock.store(on)
  on('session.start', (_: any, e: any) => ({ cwd: e.cwd }))
  on('turn.start', (_: any, e: any) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  on('fs.list', (_: any, e: any) => {
    if (w.rootMissing && e.path === '/rooms') throw new Error('ENOENT: no such directory')
    const prefix = e.path.endsWith('/') ? e.path : e.path + '/'
    const names = new Set<string>()
    for (const p of Object.keys(w.files)) if (p.startsWith(prefix)) names.add(p.slice(prefix.length).split('/')[0] ?? '')
    return { value: [...names].map(name => ({ name, kind: w.files[prefix + name] === undefined ? 'dir' : 'file' })) }
  })
  on('fs.stat', (_: any, e: any) => {
    const body = w.files[e.path]
    if (body === undefined) throw new Error('ENOENT')
    return { value: { kind: 'file', size: body.length, mtimeMs: w.mtimes[e.path] ?? 1, isLink: false } }
  })
  on('fs.read', (_: any, e: any) => {
    const body = w.files[e.path]
    if (opts.readLimit !== undefined && (e.length ?? body?.length ?? 0) > opts.readLimit) throw new Error('read over the limit')
    if (body === undefined) throw new Error('ENOENT')
    const start = e.offset ?? 0
    return { value: body.slice(start, e.length === undefined ? undefined : start + e.length) }
  })
  on('process.run', async (_: any, e: any) => {
    w.runs.push([...e.argv])
    const custom = opts.runHook ? await opts.runHook([...e.argv]) : undefined
    if (custom) return { value: custom }
    const out = e.argv[1] === 'presence-get' ? '{}\n' : ''
    return { value: { exitCode: 0, stdout: out, stderr: '' } }
  })
  on('prompt.submit', (_: any, e: any) => {
    w.submits.push({ text: e.text, asUser: e.asUser })
    if (w.dropNext > 0) {
      w.dropNext--
      return { drop: 'the session was stopped and nobody has sent input since' }
    }
    return { text: e.text }
  })
  on('ui.log', (_: any, e: any) => {
    w.logs.push(String(e.text ?? e))
    return { value: undefined }
  })
  return w
}

const append = (w: World, text: string) => {
  w.files['/rooms/r/log.jsonl'] += text
  w.mtimes['/rooms/r/log.jsonl'] = (w.mtimes['/rooms/r/log.jsonl'] ?? 1) + 1
}
const roomRuns = (w: World, verb: string) => w.runs.filter(a => a[1] === verb)
const heartbeats = (w: World) => roomRuns(w, 'presence').filter(a => !a.includes('--delivered'))

test('no ROOM_ID: no timers, no calls', async ($: any, on: any) => {
  const clock = mock.clock(on)
  const w = world(on, { env: { ROOMS_ROOT: '/rooms', ROOMS_CONFIG_DIR: '/cfg' }, log: line('20261123T050100.000000Z-aaaaaa', 'a', '@b hi', ['b']) })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(10_000)
  expect(w.runs.length).toBe(0)
  expect(w.submits.length).toBe(0)
})

test('non-interactive session does nothing even with ROOM_ID', async ($: any, on: any) => {
  const clock = mock.clock(on)
  const w = world(on, { log: line('20261123T050100.000000Z-aaaaaa', 'a', '@b hi', ['b']) })
  await $.session.start({ cwd: '/', surface: null, isInteractive: false })
  await clock.advance(10_000)
  expect(w.runs.length).toBe(0)
  expect(w.submits.length).toBe(0)
})

test('a mention wakes the session once and records delivery', async ($: any, on: any) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  append(w, line('20261123T050100.000000Z-aaaaaa', 'a', '@b ping', ['b']))
  await clock.advance(3_000)
  expect(w.submits.length).toBe(1)
  expect(w.submits[0]!.text).toContain('#r a: @b ping')
  expect(w.submits[0]!.asUser).toBeUndefined()
  const delivered = roomRuns(w, 'presence').filter(a => a.includes('--delivered'))
  expect(delivered.length).toBe(1)
  expect(delivered[0]).toContain('20261123T050100.000000Z-aaaaaa')
  await clock.advance(3_000)
  expect(w.submits.length).toBe(1)
})

test('a message that does not mention me is silent', async ($: any, on: any) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  append(w, line('20261123T050100.000000Z-aaaaaa', 'a', 'just talking', []))
  append(w, line('20261123T050101.000000Z-bbbbbb', 'b', '@all from me', ['all']))
  await clock.advance(6_000)
  expect(w.submits.length).toBe(0)
})

test('a refused wake posts one pause notice and retries after the next turn', async ($: any, on: any) => {
  const clock = mock.clock(on)
  const w = world(on)
  w.dropNext = 1
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  append(w, line('20261123T050100.000000Z-aaaaaa', 'a', '@b ping', ['b']))
  await clock.advance(3_000)
  expect(w.submits.length).toBe(1)
  const pauses = roomRuns(w, 'post').filter(a => a.includes('pause'))
  expect(pauses.length).toBe(1)
  expect(pauses[0]!.join(' ')).toContain('@cesar')
  await clock.advance(9_000)
  expect(w.submits.length).toBe(1)
  await $.turn.complete({ answer: 'ok', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })
  await clock.settle()
  expect(w.submits.length).toBe(2)
  expect(roomRuns(w, 'post').filter(a => a.includes('pause')).length).toBe(1)
})

test('heartbeat every 30 s carries the turn state', async ($: any, on: any) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(60_000)
  expect(heartbeats(w).length).toBe(2)
  expect(heartbeats(w)[1]).toEqual(expect.arrayContaining(['presence', 'r', 'b', 'idle']))
  await $.turn.start({ text: 'go', turnId: 't2' })
  await clock.advance(30_000)
  expect(heartbeats(w)[2]).toEqual(expect.arrayContaining(['presence', 'r', 'b', 'working']))
})

test('the room CLI is put on PATH for the session', async ($: any, on: any) => {
  mock.clock(on)
  world(on, { env: { ROOM_ID: 'b', ROOMS_ROOT: '/rooms', ROOMS_CONFIG_DIR: '/cfg', HOME: '/home', PATH: '/usr/bin:/bin' } })
  const sets: { name: string; value?: string }[] = []
  on('env.set', (_: any, e: any) => {
    sets.push({ name: e.name, value: e.value })
    return { value: {} }
  })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const path = sets.find(x => x.name === 'PATH')
  expect(path?.value?.endsWith('/scripts:/usr/bin:/bin')).toBe(true)
})

test('a missing root stays quiet', async ($: any, on: any) => {
  const clock = mock.clock(on)
  const w = world(on)
  w.rootMissing = true
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(9_000)
  expect(w.submits.length).toBe(0)
  expect(w.logs.length <= 1).toBe(true)
})

// ---- silence check (watch-all members) ----

const T = Date.parse('2026-11-23T06:00:00.000Z')
const iso = (ms: number) => new Date(ms).toISOString()
const systemPosts = (w: World) => roomRuns(w, 'post').filter(a => a.includes('system'))

function leadWorld(on: any, me = 'lead', log = '') {
  const w = world(on, { env: { ROOM_ID: me, ROOMS_ROOT: '/rooms', ROOMS_CONFIG_DIR: '/cfg', HOME: '/home' }, log })
  w.files['/rooms/r/members.json'] = JSON.stringify([
    { id: 'lead', role: 'orchestrator', joinedAt: JOINED, watchAll: true },
    { id: 'a', role: 'builder', joinedAt: JOINED },
    { id: 'b', role: 'reviewer', joinedAt: JOINED },
    { id: 'cesar', role: 'operator', joinedAt: JOINED },
  ])
  return w
}
const presence = (w: World, id: string, ms: number, state = 'working') => {
  w.files[`/rooms/r/presence/${id}.json`] = JSON.stringify({ id, state, ts: iso(ms) })
}

test('a member whose heartbeat stopped is reported once', async ($: any, on: any) => {
  const clock = mock.clock(on, { now: T })
  const w = leadWorld(on)
  presence(w, 'a', T + 200_000)
  presence(w, 'b', T - 180_000)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(120_000)
  expect(systemPosts(w).length).toBe(1)
  expect(systemPosts(w)[0]!.join(' ')).toContain('@lead b went quiet')
  await clock.advance(120_000)
  expect(systemPosts(w).length).toBe(1)
})

test('an idle member with no post past the threshold is reported', async ($: any, on: any) => {
  const clock = mock.clock(on, { now: T })
  const w = leadWorld(on)
  presence(w, 'a', T + 200_000)
  presence(w, 'b', T + 60_000, 'idle')
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(120_000)
  expect(systemPosts(w).map(a => a.join(' ')).filter(t => t.includes('b went quiet')).length).toBe(1)
})

test('a member that posted done is not judged', async ($: any, on: any) => {
  const clock = mock.clock(on, { now: T })
  const w = leadWorld(on, 'lead', line('20261123T055000.000000Z-dddddd', 'b', '@lead done', ['lead'], 'done'))
  presence(w, 'a', T + 200_000)
  presence(w, 'b', T - 180_000)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(120_000)
  expect(systemPosts(w).length).toBe(0)
})

test('only watch-all members run the silence check', async ($: any, on: any) => {
  const clock = mock.clock(on, { now: T })
  const w = leadWorld(on, 'b')
  presence(w, 'a', T - 180_000)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(240_000)
  expect(systemPosts(w).length).toBe(0)
})

test('a sleep gap holds off silence reports for the grace window', async ($: any, on: any) => {
  // A clock of the test's own: each timer period waits until the test releases it, so a jump
  // fires each timer once, as a Mac waking from sleep does.
  let now = T
  const waits: { due: number; go: () => void }[] = []
  on('clock.now', () => ({ value: now }))
  const hold = (_: any, e: any) => new Promise(res => waits.push({ due: now + e.ms, go: () => res({ value: undefined }) }))
  on('clock.every', hold)
  on('clock.after', hold)
  const later = (globalThis as any).setTimeout as (fn: () => void, ms: number) => unknown
  const settle = () => new Promise<void>(r => { later(() => r(), 2) })
  const jump = async (ms: number) => {
    now += ms
    for (const w of waits.splice(0).filter(x => (x.due <= now ? true : (waits.push(x), false)))) w.go()
    await settle()
  }
  const w = leadWorld(on)
  presence(w, 'a', T + 3_600_000)
  presence(w, 'b', T)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await settle()
  await jump(30 * 60_000)
  for (let t = 0; t < 170_000; t += 3_000) await jump(3_000)
  expect(systemPosts(w).length).toBe(0)
  for (let t = 0; t < 140_000; t += 3_000) await jump(3_000)
  expect(systemPosts(w).map(a => a.join(' ')).filter(x => x.includes('b went quiet')).length).toBe(1)
})

test('a silence report is sent as rooms, so the watcher itself is woken by it', async ($: any, on: any) => {
  const clock = mock.clock(on, { now: T })
  const w = leadWorld(on)
  presence(w, 'a', T + 200_000)
  presence(w, 'b', T - 180_000)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(120_000)
  const post = systemPosts(w)[0]!
  expect(post.slice(1, 5)).toEqual(['post', 'r', '--as', 'rooms'])
  // the CLI would have written it: feed it back and the lead hears it
  append(w, line('20261123T060200.000000Z-ffffff', 'rooms', '@lead b went quiet', ['lead'], 'system'))
  await clock.advance(3_000)
  expect(w.submits.map(s => s.text).join('\n')).toContain('#r rooms: @lead b went quiet')
})

test('a root that vanishes stops heartbeats too', async ($: any, on: any) => {
  const clock = mock.clock(on)
  const w = world(on)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(30_000)
  const before = heartbeats(w).length
  expect(before).toBe(1)
  w.rootMissing = true
  for (const p of Object.keys(w.files)) if (p.startsWith('/rooms/')) delete w.files[p]
  await clock.advance(90_000)
  expect(heartbeats(w).length).toBe(before)
})

test('a watch-all member does not replay history in rooms it never joined', async ($: any, on: any) => {
  const clock = mock.clock(on, { now: T })
  const w = leadWorld(on)
  presence(w, 'a', T + 3_600_000)
  presence(w, 'b', T + 3_600_000)
  w.files['/rooms/r2/members.json'] = JSON.stringify([{ id: 'x', joinedAt: JOINED }, { id: 'y', joinedAt: JOINED }])
  w.files['/rooms/r2/log.jsonl'] = JSON.stringify({ id: '20200101T000000.000000Z-aaaaaa', ts: '2020-01-01T00:00:00Z', room: 'r2', from: 'x', kind: 'msg', text: '@lead ancient', mentions: ['lead'] }) + '\n'
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.advance(3_000)
  expect(w.submits.length).toBe(0)
  w.files['/rooms/r2/log.jsonl'] += JSON.stringify({ id: '20261123T060005.000000Z-bbbbbb', ts: iso(T + 5_000), room: 'r2', from: 'x', kind: 'msg', text: '@lead fresh', mentions: ['lead'] }) + '\n'
  w.mtimes['/rooms/r2/log.jsonl'] = 2
  await clock.advance(3_000)
  expect(w.submits.length).toBe(1)
  expect(w.submits[0]!.text).toContain('#r2 x: @lead fresh')
  expect(w.submits[0]!.text).not.toContain('ancient')
})

test('a log over 4 MiB is read in chunks and still delivers', async ($: any, on: any) => {
  const clock = mock.clock(on)
  const filler = line('20261123T050000.000000Z-000000', 'a', 'x'.repeat(1000), [])
  const w = world(on, { log: filler.repeat(Math.ceil((4.5 * 1024 * 1024) / filler.length)), readLimit: 4 * 1024 * 1024 })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  append(w, line('20261123T050100.000000Z-aaaaaa', 'a', '@b after the backlog', ['b']))
  await clock.advance(3_000)
  expect(w.submits.map(s => s.text).join('\n')).toContain('#r a: @b after the backlog')
})

test('archived rooms are not polled, heartbeated or judged', async ($: any, on: any) => {
  const clock = mock.clock(on, { now: T })
  const w = leadWorld(on)
  w.files['/rooms/r/archived'] = ''
  presence(w, 'a', T - 180_000)
  presence(w, 'b', T - 180_000)
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  append(w, line('20261123T060001.000000Z-aaaaaa', 'a', '@lead late note', ['lead']))
  await clock.advance(240_000)
  expect(systemPosts(w).length).toBe(0)
  expect(heartbeats(w).length).toBe(0)
  expect(w.submits.length).toBe(0)
})

test('a slow delivery record does not deliver the same mentions twice', async ($: any, on: any) => {
  const clock = mock.clock(on)
  const w = world(on, {
    runHook: async argv => (argv.includes('--delivered') ? (await clock.sleep(5_000), { exitCode: 0, stdout: '', stderr: '' }) : undefined),
  })
  w.files['/rooms/r2/members.json'] = w.files['/rooms/r/members.json']!
  w.files['/rooms/r2/log.jsonl'] = ''
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  append(w, line('20261123T050100.000000Z-aaaaaa', 'a', '@b one', ['b']))
  w.files['/rooms/r2/log.jsonl'] += JSON.stringify({ id: '20261123T050101.000000Z-bbbbbb', ts: JOINED, room: 'r2', from: 'a', kind: 'msg', text: '@b two', mentions: ['b'] }) + '\n'
  w.mtimes['/rooms/r2/log.jsonl'] = 2
  await clock.advance(3_000)
  await clock.advance(3_000)
  await clock.advance(6_000)
  expect(w.submits.length).toBe(1)
})

test('a pause notice that fails to post is tried again on the next refusal', async ($: any, on: any) => {
  const clock = mock.clock(on)
  let postFails = 1
  const w = world(on, {
    runHook: argv => (argv[1] === 'post' && postFails-- > 0 ? { exitCode: 3, stdout: '', stderr: 'archived' } : undefined),
  })
  w.dropNext = 2
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  append(w, line('20261123T050100.000000Z-aaaaaa', 'a', '@b ping', ['b']))
  await clock.advance(3_000)
  await $.turn.complete({ answer: 'ok', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })
  await clock.settle()
  expect(roomRuns(w, 'post').filter(a => a.includes('pause')).length).toBe(2)
})
