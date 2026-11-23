// Wake-gate probe (Task 1). Replaced by the real mod in Task 5.
import type { Register } from 'claude-code'

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const id = await $.env.get('ROOM_ID')
    if (!e.isInteractive || !id) return next(e)
    const path = `/tmp/rooms-wake-${id}`
    let seen: number | undefined
    $.clock.every(3000, () => {
      void $.fs
        .stat(path)
        .then(st => {
          const m = Number((st as { mtimeMs?: number }).mtimeMs ?? 0)
          if (seen === undefined) { seen = m; return }
          if (m === seen) return
          seen = m
          void $.prompt
            .submit({ text: `rooms probe: wake file changed at ${new Date().toISOString()}` })
            .then(r => { if (r && 'drop' in r) $.ui.log(`rooms probe drop: ${r.drop}`) })
        })
        .catch(() => { seen = seen ?? 0 })
    })
    return next(e)
  })
}
