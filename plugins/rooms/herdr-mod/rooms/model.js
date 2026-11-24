// Pure logic for the Rooms panel: no herdr imports, so node can test it.

export const GONE_MS = 120_000

/** Parse a room log; garbled lines are counted and skipped. */
export function parseLog(text) {
  const msgs = []
  let bad = 0
  for (const line of String(text ?? '').split('\n')) {
    if (!line.trim()) continue
    try {
      const m = JSON.parse(line)
      if (m && typeof m === 'object' && typeof m.id === 'string') {
        msgs.push(m)
        continue
      }
    } catch {
      // counted below
    }
    bad++
  }
  return { msgs, bad }
}

const mentionsMe = (m, operator) =>
  Array.isArray(m.mentions) && (m.mentions.includes(operator) || m.mentions.includes('all'))

/** What one room looks like to the operator. */
export function roomSummary(msgs, members, presences, operator, lastRead, now = Date.now()) {
  const fresh = msgs.filter(m => (lastRead === undefined || m.id > lastRead) && m.from !== operator)
  const presence = members
    .filter(m => m.id !== operator)
    .map(m => {
      const p = presences[m.id]
      const alive = p && now - Date.parse(p.ts) <= GONE_MS
      return { id: m.id, state: alive ? p.state : 'gone' }
    })
  return {
    needsYou: fresh.filter(m => mentionsMe(m, operator)).length,
    unread: fresh.length,
    lastTs: msgs.length ? msgs[msgs.length - 1].ts : null,
    presence,
  }
}

/** Needs-you first, then unread, then quiet; newest first within each group. */
export function sortRooms(rows) {
  const group = r => (r.needsYou > 0 ? 0 : r.unread > 0 ? 1 : 2)
  return [...rows].sort((a, b) => group(a) - group(b) || String(b.lastTs ?? '').localeCompare(String(a.lastTs ?? '')))
}

/** Mentions of the operator by others, newer than the last one notified. */
export function newOperatorMentions(prevLastNotified, msgs, operator) {
  return msgs.filter(m => (prevLastNotified === undefined || m.id > prevLastNotified) && m.from !== operator && mentionsMe(m, operator))
}

/** Registered roots whose folder still exists. */
export function liveRoots(roots, exists) {
  return (Array.isArray(roots) ? roots : []).filter(r => r && typeof r.path === 'string' && exists(r.path))
}

/** Parse the tail of a big log: its first line is usually cut, so drop it. */
export function parseTail(text) {
  const s = String(text ?? '')
  const nl = s.indexOf('\n')
  return parseLog(nl < 0 ? '' : s.slice(nl + 1))
}

/**
 * Whether a watch batch needs a full reload. Heartbeats (presence files) change every 30 s per
 * session; the panel's 10 s timer picks those up, so a batch of only presence changes is skipped.
 * An empty batch, or one naming the root itself, means "refresh everything".
 */
export function shouldReload(paths, root) {
  if (!Array.isArray(paths) || paths.length === 0) return true
  return paths.some(p => p === root || !String(p).includes('/presence/'))
}

/** Rooms grouped by the root (run) they live in, labelled by the root's last two path parts. */
export function groupByRoot(rows) {
  const groups = new Map()
  for (const r of rows) {
    if (!groups.has(r.root)) {
      const label = String(r.root).split('/').filter(Boolean).slice(-2).join('/')
      groups.set(r.root, { root: r.root, label, rooms: [] })
    }
    groups.get(r.root).rooms.push(r)
  }
  return [...groups.values()]
}

/**
 * Mentions of the operator to notify about. With a mark, everything after it; on a room's
 * first sighting, only what was posted after the panel started (history stays quiet).
 */
export function toNotify(mark, msgs, operator, startedIso) {
  if (mark !== undefined) return newOperatorMentions(mark, msgs, operator)
  return newOperatorMentions(undefined, msgs, operator).filter(m => String(m.ts) >= startedIso)
}

/**
 * A compare-and-swap file saver: one write in flight, later states fold into one more write.
 * `write(text, expected)` must reject when the file no longer holds `expected`.
 */
export function createSaver(write, read, initial) {
  let saved = initial
  let pending
  let running = false
  async function drain() {
    running = true
    while (pending !== undefined) {
      const text = pending
      pending = undefined
      try {
        await write(text, saved)
        saved = text
      } catch {
        try {
          saved = await read()
          await write(text, saved)
          saved = text
        } catch {
          // leave it; the next save tries again from what is on disk
        }
      }
    }
    running = false
  }
  return function save(text) {
    pending = text
    if (!running) drain()
  }
}

/**
 * The live terminals that belong to a room: those labelled rooms.root / rooms.room / rooms.id
 * (app-fleet labels its members this way). Ordered as the room's members.json lists them,
 * unknown ids last. `status` is Herdr's word for the terminal (working, idle, blocked, ...).
 */
export function roomTerminals(terminals, root, room, members) {
  const order = new Map((Array.isArray(members) ? members : []).map((m, i) => [m.id, i]))
  const rank = id => (order.has(id) ? order.get(id) : Infinity)
  return (Array.isArray(terminals) ? terminals : [])
    .filter(t => t && (t.state === undefined || t.state === 'live') && t.labels &&
      t.labels['rooms.root'] === root && t.labels['rooms.room'] === room)
    .map(t => ({
      address: t.address,
      id: t.labels['rooms.id'] ?? t.address,
      status: typeof t.status === 'string' ? t.status : t.status?.state ?? 'unknown',
    }))
    .sort((a, b) => rank(a.id) - rank(b.id) || String(a.address).localeCompare(String(b.address)))
}

/**
 * Fold read marks from elsewhere (a room window, through Herdr's shared state) into the panel's:
 * per room the newer message id wins. Returns the merged marks and whether any moved.
 */
export function mergeRead(lastRead, other) {
  const out = { ...(lastRead ?? {}) }
  let changed = false
  for (const [key, id] of Object.entries(other ?? {})) {
    if (typeof id !== 'string') continue
    if (out[key] === undefined || id > out[key]) { out[key] = id; changed = true }
  }
  return { lastRead: out, changed }
}

/**
 * The @-mention being typed at `cursor`, or null. Active when `@` sits at the start of the text or
 * after whitespace and only id characters lie between it and the cursor. Offsets are UTF-16 indexes.
 */
export function mentionQuery(text, cursor) {
  const before = String(text ?? '').slice(0, cursor)
  const m = /(?:^|\s)@([A-Za-z0-9_-]*)$/.exec(before)
  if (!m) return null
  return { start: cursor - m[1].length - 1, end: cursor, query: m[1] }
}

/**
 * Ids to suggest for `@query`: members in order, then other posters in first-post order, never the
 * operator, no duplicates. Ids starting with the query (any case) come before ids only containing it.
 */
export function mentionCandidates(members, msgs, operator, query) {
  const ids = []
  const add = id => { if (typeof id === 'string' && id && id !== operator && !ids.includes(id)) ids.push(id) }
  for (const m of Array.isArray(members) ? members : []) add(m?.id)
  for (const m of Array.isArray(msgs) ? msgs : []) add(m?.from)
  const q = String(query ?? '').toLowerCase()
  const starts = ids.filter(id => id.toLowerCase().startsWith(q))
  const contains = ids.filter(id => !id.toLowerCase().startsWith(q) && id.toLowerCase().includes(q))
  return [...starts, ...contains]
}

/** Replace `text[start, end)` with `@id` (plus a space when `trailingSpace`); cursor lands after it. */
export function applyMention(text, start, end, id, trailingSpace) {
  const insert = `@${id}${trailingSpace ? ' ' : ''}`
  const s = String(text ?? '')
  return { text: s.slice(0, start) + insert + s.slice(end), cursor: start + insert.length }
}

/**
 * Turn each `@id` whose id is in `ids` into the Markdown link `[@id](rooms-member:id)`. Code spans and
 * fenced code blocks are left as they are, and so is an `@` inside a word (an email address).
 */
export function linkMentions(text, ids) {
  const known = new Set(Array.isArray(ids) ? ids : [])
  const link = s => s.replace(/(^|[^\w@/[`-])@([\w-]+)/g, (all, pre, id) => {
    let name = id
    while (name && !known.has(name) && /-$/.test(name)) name = name.slice(0, -1)
    return known.has(name) ? `${pre}[@${name}](rooms-member:${name})${id.slice(name.length)}` : all
  })
  // Odd pieces between backtick runs are code spans.
  return outsideFences(text, line => line.split(/(`+[^`]*`+)/).map((p, i) => (i % 2 ? p : link(p))).join(''))
}

/** Apply `fn` to each line of `text` that is not inside a fenced code block (fence lines included). */
function outsideFences(text, fn) {
  const out = []
  let fence = null
  for (const line of String(text ?? '').split('\n')) {
    const open = line.match(/^\s*(`{3,}|~{3,})/)
    if (fence) {
      if (open && open[1][0] === fence[0] && open[1].length >= fence.length && !line.trim().slice(open[1].length).trim()) fence = null
      out.push(line)
    } else if (open) {
      fence = open[1]
      out.push(line)
    } else {
      out.push(fn(line))
    }
  }
  return out.join('\n')
}

/** Demote `#` and `##` headings to `###` outside fenced code, so no heading outgrows the panel's text. */
export function demoteHeadings(text) {
  const atx = outsideFences(text, line => line.replace(/^( {0,3})#{1,2}(?=\s|$)/, '$1###'))
  // Underlined headings (Title, then === or ---) render large too. A --- after a blank line is a rule.
  const out = []
  let fence = null
  for (const line of atx.split('\n')) {
    const open = line.match(/^\s*(`{3,}|~{3,})/)
    if (fence) {
      if (open && open[1][0] === fence[0] && open[1].length >= fence.length) fence = null
      out.push(line)
      continue
    }
    if (open) { fence = open[1]; out.push(line); continue }
    const prev = out.length ? out[out.length - 1] : ''
    if (/^ {0,3}(=+|-+)\s*$/.test(line) && prev.trim() && !/^\s*(#|\||[-*+] |>|`{3,}|~{3,})/.test(prev)) {
      out[out.length - 1] = `### ${prev.trim()}`
      continue
    }
    out.push(line)
  }
  return out.join('\n')
}

/** The role `members.json` gives `id`, or "unknown". */
export function roleOf(members, id, fallback = {}) {
  const m = (Array.isArray(members) ? members : []).find(x => x?.id === id)
  if (typeof m?.role === 'string' && m.role) return m.role
  const r = fallback && typeof fallback === 'object' ? fallback[id] : undefined
  return typeof r === 'string' && r ? r : 'unknown'
}

/**
 * Each member id's role across every room of one root, the first room that lists it winning.
 * roleOf falls back to it for an id a room doesn't list, such as app-fleet's lead posting in thread rooms.
 */
export function rootRoles(memberLists) {
  const roles = {}
  for (const list of Array.isArray(memberLists) ? memberLists : []) {
    for (const m of Array.isArray(list) ? list : []) {
      if (typeof m?.id === 'string' && typeof m?.role === 'string' && m.role && !(m.id in roles)) roles[m.id] = m.role
    }
  }
  return roles
}
