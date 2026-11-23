// Pure logic for the rooms mod: no `$`, no I/O. rooms.ts wires it to the engine.

export type Msg = {
  id: string
  ts: string
  room: string
  from: string
  kind: 'msg' | 'done' | 'system' | 'pause'
  text: string
  mentions: string[]
  links?: string[]
}

export type Member = { id: string; role?: string | null; joinedAt: string; watchAll?: boolean }

export type Presence = {
  id: string
  state: 'working' | 'idle' | 'gone'
  ts: string
  delivered?: string
  session?: string
}

export type QuietReason = 'stale' | 'quiet' | 'never'

export const BATCH_CAP = 20
export const SLEEP_GRACE_MS = 180_000

/** Split newly read log text into messages. A trailing partial line is kept in `rest`. */
export function parseLines(chunk: string): { msgs: Msg[]; rest: string; bad: number } {
  const parts = chunk.split('\n')
  const rest = parts.pop() ?? ''
  const msgs: Msg[] = []
  let bad = 0
  for (const line of parts) {
    if (line.trim() === '') continue
    try {
      const m = JSON.parse(line)
      if (m && typeof m === 'object' && typeof m.id === 'string') {
        msgs.push(m as Msg)
        continue
      }
    } catch {
      // counted below
    }
    bad++
  }
  return { msgs, rest, bad }
}

/** Messages after `after` that mention `me` or @all, not sent by `me`. */
export function mentionsFor(msgs: Msg[], me: string, after?: string): Msg[] {
  return msgs.filter(
    m =>
      (after === undefined || m.id > after) &&
      m.from !== me &&
      Array.isArray(m.mentions) &&
      (m.mentions.includes(me) || m.mentions.includes('all')),
  )
}

/** The compact, sortable form of an ISO time: message ids begin with it. */
export function toIdPrefix(iso: string): string {
  return iso.replace(/[-:]/g, '')
}

/** Where a member starts reading: what it was last handed, else the moment it joined. */
export function startCursor(member: Member, presence: Presence | undefined): string {
  return presence?.delivered ?? toIdPrefix(member.joinedAt)
}

/** One prompt for a batch of mentions: the newest `cap`, with a pointer to the rest. */
export function formatBatch(msgs: Msg[], cap = BATCH_CAP): string {
  const lines = ['Room messages for you (reply with: room post <room> "<text>")']
  const dropped = msgs.slice(0, Math.max(0, msgs.length - cap))
  if (dropped.length > 0) {
    const rooms = [...new Set(dropped.map(m => m.room))]
    const where = rooms.length === 1 ? rooms[0] : '<room>'
    lines.push(`${dropped.length} earlier — run room read ${where} --mentions-only`)
  }
  for (const m of msgs.slice(-cap)) {
    const links = (m.links ?? []).map(l => ` <${l}>`).join('')
    // Continuation lines are indented: no line of a message can pass for another sender's.
    const text = String(m.text).split('\n').join('\n    ')
    lines.push(`#${m.room} ${m.from}: ${text}${links}`)
  }
  return lines.join('\n')
}

/**
 * Members to report as gone quiet: a stale heartbeat, an unanswered mention for too long, or
 * no heartbeat at all `neverMs` after joining (its session never came online).
 */
export function quietVerdicts(args: {
  now: number
  members: Member[]
  presences: Record<string, Presence>
  lastPostTs: Record<string, number>
  lastMentionTs: Record<string, number>
  done: Set<string>
  quietMs: number
  staleMs: number
  neverMs: number
  alreadyFlagged: Set<string>
}): { id: string; reason: QuietReason }[] {
  const out: { id: string; reason: QuietReason }[] = []
  for (const m of args.members) {
    if (args.done.has(m.id) || args.alreadyFlagged.has(m.id)) continue
    const p = args.presences[m.id]
    if (!p) {
      if (args.now - Date.parse(m.joinedAt) > args.neverMs) out.push({ id: m.id, reason: 'never' })
      continue
    }
    const beat = Date.parse(p.ts)
    if (args.now - beat > args.staleMs) {
      out.push({ id: m.id, reason: 'stale' })
      continue
    }
    // Quiet means asked and not answered: mentioned, idle, and no post since the mention.
    const asked = args.lastMentionTs[m.id]
    const said = args.lastPostTs[m.id] ?? 0
    if (p.state === 'idle' && asked !== undefined && asked > said && args.now - asked > args.quietMs) {
      out.push({ id: m.id, reason: 'quiet' })
    }
  }
  return out
}

/** A timer gap over twice its interval means the machine slept: open a grace window. */
export function sleptRecently(
  prevTick: number,
  now: number,
  intervalMs: number,
  graceUntil: number,
): { slept: boolean; graceUntil: number } {
  if (now - prevTick > 2 * intervalMs) return { slept: true, graceUntil: now + SLEEP_GRACE_MS }
  return { slept: false, graceUntil }
}
