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

function world(on: any, opts: { env?: Record<string, string>; log?: string } = {}): World {
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
    if (body === undefined) throw new Error('ENOENT')
    const start = e.offset ?? 0
    return { value: body.slice(start, e.length === undefined ? undefined : start + e.length) }
  })
  on('process.run', (_: any, e: any) => {
    w.runs.push([...e.argv])
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
