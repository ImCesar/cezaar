// The rooms mod: hears @-mentions in this session's rooms and wakes the session.
// Room files are written only by scripts/room; this module reads them and calls the CLI.
import type { EngineInterface, Register } from 'claude-code'
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

export const CHECK_MS = 3_000
export const HEARTBEAT_MS = 30_000
export const SILENCE_MS = 120_000
export const STALE_MS = 120_000

type RoomState = {
  offset: number
  rest: string
  mtimeMs: number
  membersMtime: number
  members: Member[]
  cursor?: string
  msgs: Msg[] // everything read so far, for the silence check
}

type State = {
  id: string
  root: string
  only?: Set<string>
  cli: string
  operator: string
  quietMinutes: number
  rooms: Map<string, RoomState>
  turn: 'idle' | 'working'
  inflight: boolean
  blocked: boolean // a wake was refused; wait for the person or the next turn
  pausePosted: boolean
  rootMissingLogged: boolean
  watchAll: boolean
  lastTick?: number
  lastSilenceTick?: number
  graceUntil: number
  flagged: Map<string, { at: number; reason: 'stale' | 'quiet' }> // key: room/id
}

let st: State | undefined

async function readConfig($: EngineInterface): Promise<{ operator: string; quietMinutes: number }> {
  const dir = (await $.env.get('ROOMS_CONFIG_DIR')) ?? `${(await $.env.get('HOME')) ?? ''}/.config/rooms`
  try {
    const cfg = JSON.parse(String(await $.fs.read(`${dir}/config.json`)))
    return { operator: String(cfg.operator ?? 'cesar'), quietMinutes: Number(cfg.quietMinutes ?? 10) }
  } catch {
    return { operator: 'cesar', quietMinutes: 10 }
  }
}

export async function room(s: State, $: EngineInterface, args: string[]) {
  try {
    return await $.process.run([s.cli, ...args], { env: { ROOMS_ROOT: s.root } })
  } catch {
    return undefined
  }
}

async function readMembers($: EngineInterface, dir: string): Promise<Member[]> {
  try {
    const parsed = JSON.parse(String(await $.fs.read(`${dir}/members.json`)))
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

/** Find the rooms this member watches and read what is new in each. */
async function refresh(s: State, $: EngineInterface): Promise<boolean> {
  let entries: { name: string; kind: string }[]
  try {
    entries = (await $.fs.list(s.root)) as { name: string; kind: string }[]
  } catch {
    if (!s.rootMissingLogged) $.ui.log(`rooms: ${s.root} is not there; waiting for it`)
    s.rootMissingLogged = true
    return false
  }
  s.rootMissingLogged = false
  for (const ent of entries) {
    if (ent.kind !== 'dir') continue
    if (s.only && !s.only.has(ent.name)) continue
    const dir = `${s.root}/${ent.name}`
    let r = s.rooms.get(ent.name)
    try {
      const ms = await $.fs.stat(`${dir}/members.json`)
      if (!r || ms.mtimeMs !== r.membersMtime) {
        const members = await readMembers($, dir)
        if (!r) r = { offset: 0, rest: '', mtimeMs: -1, membersMtime: ms.mtimeMs, members, msgs: [] }
        r.members = members
        r.membersMtime = ms.mtimeMs
        s.rooms.set(ent.name, r)
      }
    } catch {
      continue
    }
    const me = r.members.find(m => m.id === s.id)
    if (me?.watchAll) s.watchAll = true
    if (r.cursor === undefined && me) {
      const got = await room(s, $, ['presence-get', ent.name, s.id])
      let pres: Presence | undefined
      try {
        const parsed = got ? JSON.parse(got.stdout || '{}') : {}
        pres = parsed && parsed.id ? (parsed as Presence) : undefined
      } catch {
        pres = undefined
      }
      r.cursor = startCursor(me, pres)
    }
    try {
      const ls = await $.fs.stat(`${dir}/log.jsonl`)
      if (ls.mtimeMs === r.mtimeMs && ls.size === r.offset) continue
      if (ls.size < r.offset) {
        r.offset = 0
        r.rest = ''
      }
      if (ls.size > r.offset) {
        const chunk = String(await $.fs.read(`${dir}/log.jsonl`, { offset: r.offset, length: ls.size - r.offset }))
        r.offset = ls.size
        const out = parseLines(r.rest + chunk)
        r.rest = out.rest
        r.msgs.push(...out.msgs)
      }
      r.mtimeMs = ls.mtimeMs
    } catch {
      // the log may not exist yet
    }
  }
  return true
}

function isMember(s: State, r: RoomState) {
  return s.watchAll || r.members.some(m => m.id === s.id)
}

/** Hand new mentions to the model as one prompt; advance cursors only once it is accepted. */
async function deliver(s: State, $: EngineInterface) {
  if (s.inflight || s.blocked) return
  const batch: Msg[] = []
  const newest = new Map<string, string>()
  for (const [name, r] of s.rooms) {
    if (!isMember(s, r)) continue
    const cursor = r.cursor ?? (s.watchAll ? '' : undefined)
    if (cursor === undefined) continue
    const mine = mentionsFor(r.msgs, s.id, cursor)
    if (mine.length === 0) continue
    batch.push(...mine)
    newest.set(name, mine[mine.length - 1]!.id)
  }
  if (batch.length === 0) return
  batch.sort((x, y) => (x.id < y.id ? -1 : 1))
  s.inflight = true
  void $.prompt
    .submit({ text: formatBatch(batch) })
    .then(async res => {
      s.inflight = false
      if (res && typeof res === 'object' && 'drop' in res) {
        s.blocked = true
        if (!s.pausePosted) {
          s.pausePosted = true
          const where = [...newest.keys()][0] ?? ''
          await room(s, $, ['post', where, '--as', s.id, '--kind', 'pause',
            `@${s.operator} ${s.id} is paused (stopped with Esc); type anything in its pane to resume`])
        }
        return
      }
      s.pausePosted = false
      for (const [name, id] of newest) {
        const r = s.rooms.get(name)
        if (r) r.cursor = id
        await room(s, $, ['presence', name, s.id, s.turn, '--delivered', id])
      }
    })
    .catch(() => {
      s.inflight = false
    })
}

async function heartbeat(s: State, $: EngineInterface) {
  for (const [name, r] of s.rooms) {
    if (!r.members.some(m => m.id === s.id)) continue
    await room(s, $, ['presence', name, s.id, s.turn])
  }
}

async function readPresence($: EngineInterface, dir: string, id: string): Promise<Presence | undefined> {
  try {
    const p = JSON.parse(String(await $.fs.read(`${dir}/presence/${id}.json`)))
    return p && typeof p.ts === 'string' ? (p as Presence) : undefined
  } catch {
    return undefined
  }
}

/** Watch-all members only: report members that crashed (stale heartbeat) or went quiet. */
async function silenceCheck(s: State, $: EngineInterface, now: number) {
  if (!s.watchAll || now < s.graceUntil) return
  for (const [name, r] of s.rooms) {
    const dir = `${s.root}/${name}`
    const judged = r.members.filter(m => m.id !== s.id && !m.watchAll && m.id !== s.operator)
    const presences: Record<string, Presence> = {}
    for (const m of judged) {
      const p = await readPresence($, dir, m.id)
      if (p) presences[m.id] = p
    }
    const lastPostTs: Record<string, number> = {}
    const done = new Set<string>()
    for (const m of r.msgs) {
      const t = Date.parse(m.ts)
      if (!(lastPostTs[m.from]! >= t)) lastPostTs[m.from] = t
      if (m.kind === 'done') done.add(m.from)
    }
    // Clear flags for members heard from since they were flagged.
    for (const m of judged) {
      const key = `${name}/${m.id}`
      const f = s.flagged.get(key)
      if (!f) continue
      const p = presences[m.id]
      const posted = (lastPostTs[m.id] ?? 0) > f.at
      const beating = f.reason === 'stale' && p !== undefined && now - Date.parse(p.ts) <= STALE_MS
      const working = f.reason === 'quiet' && p?.state === 'working'
      if (posted || beating || working) s.flagged.delete(key)
    }
    const alreadyFlagged = new Set(judged.map(m => m.id).filter(id => s.flagged.has(`${name}/${id}`)))
    const verdicts = quietVerdicts({
      now, members: judged, presences, lastPostTs, done, alreadyFlagged,
      quietMs: s.quietMinutes * 60_000, staleMs: STALE_MS,
    })
    for (const v of verdicts) {
      s.flagged.set(`${name}/${v.id}`, { at: now, reason: v.reason })
      const why = v.reason === 'stale'
        ? 'no heartbeat for over 2 minutes: crashed or closed?'
        : `idle with no post for over ${s.quietMinutes} minutes`
      await room(s, $, ['post', name, '--as', s.id, '--kind', 'system', `@${s.id} ${v.id} went quiet (${why})`])
    }
  }
}

function unblock(s: State | undefined) {
  if (s) s.blocked = false
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const id = await $.env.get('ROOM_ID')
    if (!e.isInteractive || !id) return next(e)
    const root = (await $.env.get('ROOMS_ROOT')) ?? `${(await $.env.get('HOME')) ?? ''}/.rooms/default`
    const only = await $.env.get('ROOMS')
    const cfg = await readConfig($)
    const s: State = {
      id,
      root,
      only: only ? new Set(only.split(',').map(x => x.trim()).filter(Boolean)) : undefined,
      cli: `${$.plugin.root}/scripts/room`,
      operator: cfg.operator,
      quietMinutes: cfg.quietMinutes,
      rooms: new Map(),
      turn: 'idle',
      inflight: false,
      blocked: false,
      pausePosted: false,
      rootMissingLogged: false,
      watchAll: false,
      graceUntil: 0,
      flagged: new Map(),
    }
    st = s
    const t0 = await $.clock.now()
    s.lastTick = t0
    s.lastSilenceTick = t0
    // Put `room` on PATH for this session and everything it starts (the Bash tool included).
    const path = (await $.env.get('PATH')) ?? ''
    const scripts = `${$.plugin.root}/scripts`
    if (!path.split(':').includes(scripts)) {
      try {
        await $.env.set('PATH', path ? `${scripts}:${path}` : scripts)
      } catch {
        // best effort: agents can still call the CLI by its full path
      }
    }
    $.clock.every(CHECK_MS, () => {
      void $.clock.now().then(now => {
        s.graceUntil = sleptRecently(s.lastTick ?? now, now, CHECK_MS, s.graceUntil).graceUntil
        s.lastTick = now
      })
      void refresh(s, $).then(ok => (ok ? deliver(s, $) : undefined))
    })
    $.clock.every(SILENCE_MS, () => {
      void $.clock.now().then(async now => {
        s.graceUntil = sleptRecently(s.lastSilenceTick ?? now, now, SILENCE_MS, s.graceUntil).graceUntil
        s.lastSilenceTick = now
        await refresh(s, $)
        await silenceCheck(s, $, now)
      })
    })
    $.clock.every(HEARTBEAT_MS, () => {
      void heartbeat(s, $)
    })
    return next(e)
  })

  on('turn.start', ($, e, next) => {
    if (st && e.agentId === undefined) st.turn = 'working'
    return next(e)
  })

  on('turn.complete', ($, e, next) => {
    if (st && e.agentId === undefined) {
      st.turn = 'idle'
      unblock(st)
      void deliver(st, $)
    }
    return next(e)
  })

  on('prompt.submit', ($, e, next) => {
    if (e.origin?.kind !== 'plugin') unblock(st)
    return next(e)
  })
}
