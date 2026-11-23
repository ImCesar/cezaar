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
