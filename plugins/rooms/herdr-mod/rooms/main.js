// Rooms: watch every agent room and post into them. Reads the files `room` writes;
// posts only through the room CLI. Never sends anything to a terminal.
import { View, div } from "gpui-kit";
import { v_flex, h_flex, TextareaState, Textarea, Scrollbar } from "gpui-base";
import { exec, home, notify, readTextFile, setBadge, theme, watchFolder, writeTextFile } from "herdr";
import { liveRoots, newOperatorMentions, parseLog, parseTail, roomSummary, shouldReload, sortRooms } from "./model.js";

const CONFIG_DIR = () => `${home()}/.config/rooms`;
const KIND_LABEL = { done: "done", system: "system", pause: "paused" };

async function readJson(path, fallback) {
  try {
    const text = await readTextFile(path);
    return text == null ? fallback : JSON.parse(text);
  } catch {
    return fallback;
  }
}

async function exists(path) {
  const r = await exec("/bin/test", ["-d", path]);
  return r.code === 0;
}

// readTextFile stops at 1 MiB: past that, read the last part of the log only.
async function readLog(path) {
  try {
    const text = await readTextFile(path);
    if (text != null) return parseLog(text);
  } catch {
    // too big or unreadable as UTF-8: fall through to the tail
  }
  const r = await exec("/usr/bin/tail", ["-c", "524288", path]);
  return r.code === 0 ? parseTail(r.stdout) : { msgs: [], bad: 0 };
}

async function listDirs(path) {
  const r = await exec("/bin/ls", ["-1", path]);
  return r.code === 0 ? r.stdout.split("\n").filter(Boolean) : [];
}

export default class Rooms extends View {
  init(_props, cx) {
    this.config = { operator: "cesar", cli: null };
    this.rooms = []; // [{ key, root, name, msgs, members, presences, archived, summary }]
    this.state = { lastRead: {}, lastNotified: {} };
    this.savedText = null;
    this.selected = null;
    this.showArchived = false;
    this.note = null;
    this.watching = new Set();
    this.draft = TextareaState.new({ placeholder: "Message this room… (@name to mention)", rows: 3 });
    this.draft.set_auto_grow(2, 8);
    this.draft.on("submit", (_e, cx) => this.post(cx));
    cx.spawn(async (cx) => {
      this.savedText = await readTextFile(`${CONFIG_DIR()}/panel-state.json`).catch(() => null);
      try { if (this.savedText) this.state = { ...this.state, ...JSON.parse(this.savedText) }; } catch { /* start fresh */ }
      this.requestReload(cx);
    });
    cx.timer.every(10000, (cx) => this.requestReload(cx));
  }

  // One reload at a time; changes that arrive meanwhile fold into one more pass.
  requestReload(cx) {
    if (this.reloading) { this.dirty = true; return; }
    this.reloading = true;
    cx.spawn(async (cx) => {
      try { await this.reload(cx); } catch (e) { this.note = `Reload failed: ${e.message ?? e}`; }
      finally {
        this.reloading = false;
        if (this.dirty) { this.dirty = false; this.requestReload(cx); }
        cx.notify();
      }
    });
  }

  async reload(cx) {
    const cfg = await readJson(`${CONFIG_DIR()}/config.json`, {});
    this.config = { operator: String(cfg.operator ?? "cesar"), cli: cfg.cli ?? null };
    const roots = await readJson(`${CONFIG_DIR()}/roots.json`, []);
    const alive = [];
    for (const r of roots) if (r && typeof r.path === "string" && (await exists(r.path))) alive.push(r.path);
    const live = liveRoots(roots, (p) => alive.includes(p));
    const rooms = [];
    for (const root of live) {
      this.watch(root.path, cx);
      for (const name of await listDirs(root.path)) {
        // One unreadable room must not stop the others from updating.
        try {
          const dir = `${root.path}/${name}`;
          const members = await readJson(`${dir}/members.json`, null);
          if (!Array.isArray(members)) continue;
          const { msgs } = await readLog(`${dir}/log.jsonl`);
          const presences = {};
          for (const m of members) {
            const p = await readJson(`${dir}/presence/${m.id}.json`, null);
            if (p) presences[m.id] = p;
          }
          const archived = (await readTextFile(`${dir}/archived`).catch(() => null)) != null;
          const key = `${root.path}#${name}`;
          const summary = roomSummary(msgs, members, presences, this.config.operator, this.state.lastRead[key]);
          rooms.push({ key, root: root.path, name, msgs, members, presences, archived, summary });
        } catch {
          continue;
        }
      }
    }
    this.rooms = rooms;
    this.alert();
    if (this.selected) this.markRead(this.selected);
    cx.notify();
  }

  watch(root, cx) {
    if (this.watching.has(root)) return;
    this.watching.add(root);
    cx.spawn(async (cx) => {
      try {
        for (;;) {
          const paths = await watchFolder(root);
          if (shouldReload(paths, root)) this.requestReload(cx);
        }
      } catch {
        this.watching.delete(root);
      }
    });
  }

  alert() {
    let total = 0;
    for (const r of this.rooms) {
      if (r.archived) continue;
      total += r.summary.needsYou;
      const fresh = newOperatorMentions(this.state.lastNotified[r.key], r.msgs, this.config.operator);
      if (fresh.length) {
        const last = fresh[fresh.length - 1];
        // The first sighting of a room only sets the mark: no burst for history.
        if (this.state.lastNotified[r.key] !== undefined) {
          notify({ title: `#${r.name} · ${last.from}`, body: last.text, level: last.kind === "pause" || last.kind === "system" ? "warning" : "info" });
        }
        this.state.lastNotified[r.key] = last.id;
        this.save();
      } else if (this.state.lastNotified[r.key] === undefined) {
        this.state.lastNotified[r.key] = r.msgs.length ? r.msgs[r.msgs.length - 1].id : "";
        this.save();
      }
    }
    setBadge(total > 0 ? String(total) : null);
  }

  markRead(key) {
    const r = this.rooms.find((x) => x.key === key);
    if (!r || !r.msgs.length) return;
    const last = r.msgs[r.msgs.length - 1].id;
    if (this.state.lastRead[key] === last) return;
    this.state.lastRead[key] = last;
    r.summary = roomSummary(r.msgs, r.members, r.presences, this.config.operator, last);
    this.save();
  }

  // writeTextFile replaces a file only when handed its current text, so keep what was last written.
  save() {
    const path = `${CONFIG_DIR()}/panel-state.json`;
    const text = JSON.stringify(this.state);
    writeTextFile(path, text, this.savedText ?? null)
      .then(() => { this.savedText = text; })
      .catch(async () => {
        this.savedText = await readTextFile(path).catch(() => null);
        await writeTextFile(path, text, this.savedText ?? null).then(() => { this.savedText = text; }).catch(() => {});
      });
  }

  pick(key, cx) {
    this.selected = key;
    this.markRead(key);
    this.alert();
    cx.notify();
  }

  post(cx) {
    const r = this.rooms.find((x) => x.key === this.selected);
    const text = this.draft.value().trim();
    if (!r || !text || this.busy) return;
    if (!this.config.cli) {
      this.note = "Run `room herdr-install` first: the panel does not know where the room CLI is.";
      cx.notify();
      return;
    }
    this.busy = true;
    this.note = null;
    cx.spawn(async (cx) => {
      try {
        const res = await exec("/usr/bin/env", [`ROOMS_ROOT=${r.root}`, this.config.cli, "post", r.name, "--as", this.config.operator, text]);
        if (res.code !== 0) throw new Error((res.stderr || res.stdout).trim());
        this.draft.set_value("");
      } catch (e) {
        this.note = `Post failed: ${e.message ?? e}`;
      } finally {
        this.busy = false;
        this.requestReload(cx);
      }
    });
    cx.notify();
  }

  roomRow(r, t) {
    const s = r.summary;
    const dot = s.needsYou > 0 ? t.blocked : s.unread > 0 ? t.accent : t.dim;
    return h_flex().id(`room-${r.key}`).h(30).flex_none().px(10).gap(8).items_center().rounded(7).cursor_pointer()
      .when(this.selected === r.key, (e) => e.bg(t.selected)).hover((st) => st.bg(t.hover))
      .on_click((_e, cx) => this.pick(r.key, cx))
      .child(div().size(8).rounded(4).flex_none().bg(dot))
      .child(div().flex_1().min_w(0).truncate().text_color(r.archived ? t.dim : t.foreground).child(`#${r.name}`))
      .when(s.needsYou > 0, (e) => e.child(div().px(6).rounded(4).bg(t.blocked).text_color(t.solid_foreground).text_size(11).child(`${s.needsYou} for you`)))
      .when(s.needsYou === 0 && s.unread > 0, (e) => e.child(div().text_size(11).text_color(t.muted).child(String(s.unread))));
  }

  messageRow(m, t) {
    const label = KIND_LABEL[m.kind];
    const mine = m.from === this.config.operator;
    const color = m.kind === "done" ? t.done : m.kind === "pause" || m.kind === "system" ? t.blocked : t.foreground;
    return v_flex().w_full().flex_none().px(12).py(6).gap(2)
      .child(h_flex().gap(6).items_center()
        .child(div().font_semibold().text_size(12).text_color(mine ? t.accent : t.foreground).child(m.from))
        .when(Boolean(label), (e) => e.child(div().px(5).rounded(4).border_1().border_color(color).text_size(10).text_color(color).child(label)))
        .child(div().text_size(10).text_color(t.dim).child(String(m.ts ?? "").slice(11, 16))))
      .child(div().text_size(12).text_color(t.foreground).child(m.text))
      .when(Array.isArray(m.links) && m.links.length > 0, (e) => e.child(div().text_size(11).text_color(t.muted).child(m.links.join("  "))));
  }

  render(cx) {
    const t = theme();
    const visible = sortRooms(this.rooms.filter((r) => this.showArchived || !r.archived).map((r) => ({ ...r, ...r.summary })));
    const current = this.rooms.find((r) => r.key === this.selected);
    const presence = current ? current.summary.presence : [];
    return v_flex().id("rooms").size_full().min_h(0).overflow_hidden().bg(t.background).text_color(t.foreground).text_size(13)
      .child(h_flex().h(40).flex_none().px(12).gap(8).items_center().border_b(1).border_color(t.border)
        .child(div().font_semibold().child("Rooms"))
        .child(div().flex_1())
        .child(div().id("rooms-archived").text_size(11).text_color(t.muted).cursor_pointer()
          .on_click((_e, cx) => { this.showArchived = !this.showArchived; cx.notify(); })
          .child(this.showArchived ? "hide archived" : "show archived")))
      .child(div().h(Math.min(220, 12 + visible.length * 30)).min_h(42).flex_none().relative().border_b(1).border_color(t.border)
        .child(v_flex().id("rooms-list").absolute().inset_0().overflow_y_scroll().p(6)
          .children(visible.map((r) => this.roomRow(r, t)))
          .when(visible.length === 0, (e) => e.child(div().p(8).text_color(t.dim).child("No rooms yet. Agents create them with `room create`."))))
        .child(Scrollbar.vertical("rooms-list").absolute().inset_0()))
      .when(Boolean(current), (e) => e
        .child(h_flex().flex_none().px(12).py(6).gap(10).flex_wrap().border_b(1).border_color(t.border)
          .children(presence.map((p) => h_flex().gap(4).items_center()
            .child(div().size(7).rounded(4).bg(p.state === "working" ? t.working : p.state === "idle" ? t.idle ?? t.dim : t.ansi1))
            .child(div().text_size(11).text_color(t.muted).child(`${p.id} ${p.state}`)))))
        .child(div().flex_1().min_h(0).relative()
          .child(v_flex().id("rooms-timeline").absolute().inset_0().overflow_y_scroll().py(4)
            .children(current.msgs.slice(-200).map((m) => this.messageRow(m, t))))
          .child(Scrollbar.vertical("rooms-timeline").absolute().inset_0()))
        .when(Boolean(this.note), (e) => e.child(div().px(12).py(4).text_size(11).text_color(t.ansi1).child(this.note)))
        .when(!current.archived, (e) => e.child(h_flex().flex_none().p(10).gap(8).items_end().border_t(1).border_color(t.border)
          .child(div().flex_1().min_w(0).rounded(8).border_1().border_color(t.border).p(6).cursor_text()
            .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
            .child(Textarea.new(this.draft).w_full().text_size(12).text_color(t.foreground)))
          .child(div().id("rooms-send").h(30).px(12).flex().items_center().rounded(8).bg(t.solid).text_color(t.solid_foreground)
            .text_size(12).cursor_pointer().on_click((_e, cx) => this.post(cx)).child(this.busy ? "Sending…" : "Send")))))
      .when(!current, (e) => e.child(div().flex_1().p(12).text_color(t.dim).child(visible.length ? "Pick a room to read it." : "")));
  }
}
