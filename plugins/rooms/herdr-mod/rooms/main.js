// Rooms: watch every agent room and post into them. Reads the files `room` writes;
// posts only through the room CLI. Never sends anything to a terminal.
//
// The same mod draws the pieces of a room's window (props().view): "title" (drag bar and close),
// "member" (one member's name and Herdr status) and "room" (one room's timeline and composer).
// The window puts the room's live member terminals (labelled rooms.root/room/id) beside the room.
import { View, div } from "gpui-kit";
import { v_flex, h_flex, TextareaState, Textarea, Scrollbar } from "gpui-base";
import { closeOverlay, exec, home, notify, openOverlay, props, readTextFile, setBadge, terminals, theme, watchFolder, writeTextFile } from "herdr";
import { createSaver, groupByRoot, liveRoots, parseLog, parseTail, roomSummary, roomTerminals, shouldReload, sortRooms, toNotify } from "./model.js";

const CONFIG_DIR = () => `${home()}/.config/rooms`;
const KIND_LABEL = { done: "done", system: "system", pause: "paused" };
const MOD = "rooms";
// A room's run: rooms live in <home>/runs/<run>/rooms for app-fleet; otherwise the root's folder name.
const runLabel = (root) => { const parts = String(root).split("/").filter(Boolean); return parts.at(-1) === "rooms" ? parts.at(-2) : parts.at(-1); };
const statusColor = (t, s) => t[s] ?? (s === "gone" ? t.ansi1 : t.dim);

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
    const p = props() ?? {};
    this.view = p.view ?? "panel";
    // A window's room view shows one room: no list, no alerts, no saved read state.
    this.only = this.view === "room" ? { root: String(p.root), room: String(p.room) } : null;
    this.config = { operator: "cesar", cli: null };
    this.rooms = []; // [{ key, root, name, msgs, members, presences, archived, summary }]
    this.state = { lastRead: {}, lastNotified: {} };
    // Message ids and times carry microseconds; match that so "after start" compares cleanly.
    this.startedIso = new Date().toISOString().replace("Z", "000Z");
    this.saver = null;
    this.selected = null;
    this.showArchived = false;
    this.note = null;
    this.watching = new Set();
    this.draft = TextareaState.new({ placeholder: "Message this room… (@name to mention)", rows: 3 });
    this.draft.set_auto_grow(2, 8);
    this.draft.on("submit", (_e, cx) => this.post(cx));
    if (this.view === "title" || this.view === "member") return;
    if (this.only) {
      this.selected = `${this.only.root}#${this.only.room}`;
      this.requestReload(cx);
      cx.timer.every(10000, (cx) => this.requestReload(cx));
      return;
    }
    cx.spawn(async (cx) => {
      const path = `${CONFIG_DIR()}/panel-state.json`;
      const savedText = await readTextFile(path).catch(() => null);
      try { if (savedText) this.state = { ...this.state, ...JSON.parse(savedText) }; } catch { /* start fresh */ }
      this.saver = createSaver(
        (text, expected) => writeTextFile(path, text, expected ?? null),
        () => readTextFile(path).catch(() => null),
        savedText,
      );
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
    const roots = this.only ? [{ path: this.only.root }] : await readJson(`${CONFIG_DIR()}/roots.json`, []);
    const alive = [];
    for (const r of roots) if (r && typeof r.path === "string" && (await exists(r.path))) alive.push(r.path);
    const live = liveRoots(roots, (p) => alive.includes(p));
    const rooms = [];
    for (const root of live) {
      this.watch(root.path, cx);
      for (const name of this.only ? [this.only.room] : await listDirs(root.path)) {
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
    if (this.only) return; // the panel alerts; a window would only repeat it
    let total = 0;
    let changed = false;
    for (const r of this.rooms) {
      if (r.archived) continue;
      total += r.summary.needsYou;
      for (const m of toNotify(this.state.lastNotified[r.key], r.msgs, this.config.operator, this.startedIso)) {
        notify({ title: `#${r.name} · ${m.from}`, body: m.text, level: m.kind === "pause" || m.kind === "system" ? "warning" : "info" });
      }
      const newest = r.msgs.length ? r.msgs[r.msgs.length - 1].id : "";
      if (this.state.lastNotified[r.key] !== newest) { this.state.lastNotified[r.key] = newest; changed = true; }
    }
    setBadge(total > 0 ? String(total) : null);
    if (changed) this.save();
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

  // One write at a time (writeTextFile is compare-and-swap); later states fold into one more write.
  save() {
    if (this.saver) this.saver(JSON.stringify(this.state));
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

  // One window per room: its live member terminals on the left, the room on the right.
  openWindow(r) {
    const members = roomTerminals(terminals(), r.root, r.name, r.members);
    if (!members.length) return;
    const block = (props, px) => ({ type: "block", ...(px ? { size: { px } } : {}), content: { mod: MOD, props } });
    openOverlay({
      kind: "window", key: `room:${r.key}`, width: 0.85, height: 0.85,
      layout: { type: "column", children: [
        block({ view: "title", root: r.root, room: r.name }, 30),
        { type: "row", children: [
          { type: "column", size: { weight: 3 }, children: members.flatMap((m) => [
            block({ view: "member", id: m.id, address: m.address }, 24),
            { type: "block", content: { terminal: m.address } },
          ]) },
          { type: "block", size: { weight: 2 }, content: { mod: MOD, props: { view: "room", root: r.root, room: r.name } } },
        ] },
      ] },
    });
  }

  renderTitle(t) {
    const p = props() ?? {};
    return h_flex().id("room-title").size_full().px(12).gap(8).items_center().bg(t.surface ?? t.background).text_color(t.foreground).text_size(13)
      .child(div().font_semibold().child(`#${p.room}`))
      .child(div().text_size(11).text_color(t.muted).child(runLabel(p.root)))
      .child(div().flex_1())
      .child(div().id("room-close").px(8).rounded(6).text_color(t.muted).cursor_pointer().hover((st) => st.bg(t.hover))
        .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
        .on_click(() => closeOverlay(p.overlay)).child("✕"));
  }

  renderMember(t) {
    const p = props() ?? {};
    const term = terminals().find((x) => x.address === p.address);
    const status = term ? (typeof term.status === "string" ? term.status : term.status?.state ?? "unknown") : "gone";
    return h_flex().id(`member-${p.address}`).size_full().px(10).gap(6).items_center().bg(t.background).border_t(1).border_color(t.border).text_size(12)
      .child(div().size(7).rounded(4).flex_none().bg(statusColor(t, status)))
      .child(div().font_semibold().text_color(t.foreground).child(String(p.id)))
      .when(status !== "unknown", (e) => e.child(div().text_size(11).text_color(t.muted).child(status)));
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

  // The open room: presence, timeline, composer. The panel and a window's room view share it.
  roomBody(el, current, t) {
    const presence = current.summary.presence;
    const live = this.only ? [] : roomTerminals(terminals(), current.root, current.name, current.members);
    return el
      .child(h_flex().flex_none().px(12).py(6).gap(10).flex_wrap().items_center().border_b(1).border_color(t.border)
        .children(presence.map((p) => h_flex().gap(4).items_center()
          .child(div().size(7).rounded(4).bg(p.state === "working" ? t.working : p.state === "idle" ? t.idle ?? t.dim : t.ansi1))
          .child(div().text_size(11).text_color(t.muted).child(`${p.id} ${p.state}`))))
        .when(live.length > 0, (e) => e.child(div().flex_1()).child(div().id("rooms-window").px(8).py(2).rounded(6).border_1().border_color(t.border)
          .text_size(11).text_color(t.foreground).cursor_pointer().hover((st) => st.bg(t.hover))
          .on_click(() => this.openWindow(current)).child("window"))))
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
          .text_size(12).cursor_pointer().on_click((_e, cx) => this.post(cx)).child(this.busy ? "Sending…" : "Send"))));
  }

  render(cx) {
    const t = theme();
    if (this.view === "title") return this.renderTitle(t);
    if (this.view === "member") return this.renderMember(t);
    if (this.only) {
      const current = this.rooms.find((r) => r.key === this.selected);
      const el = v_flex().id("room-view").size_full().min_h(0).overflow_hidden().bg(t.background).text_color(t.foreground).text_size(13);
      return current ? this.roomBody(el, current, t) : el.child(div().p(12).text_color(t.dim).child("Loading…"));
    }
    const visible = sortRooms(this.rooms.filter((r) => this.showArchived || !r.archived).map((r) => ({ ...r, ...r.summary })));
    const current = this.rooms.find((r) => r.key === this.selected);
    return v_flex().id("rooms").size_full().min_h(0).overflow_hidden().bg(t.background).text_color(t.foreground).text_size(13)
      .child(h_flex().h(40).flex_none().px(12).gap(8).items_center().border_b(1).border_color(t.border)
        .child(div().font_semibold().child("Rooms"))
        .child(div().flex_1())
        .child(div().id("rooms-archived").text_size(11).text_color(t.muted).cursor_pointer()
          .on_click((_e, cx) => { this.showArchived = !this.showArchived; cx.notify(); })
          .child(this.showArchived ? "hide archived" : "show archived")))
      .child(div().h(Math.min(260, 12 + visible.length * 30 + groupByRoot(visible).length * 22)).min_h(42).flex_none().relative().border_b(1).border_color(t.border)
        .child(v_flex().id("rooms-list").absolute().inset_0().overflow_y_scroll().p(6)
          .children(groupByRoot(visible).flatMap((g) => [
            div().h(22).flex_none().px(10).pt(4).text_size(10).text_color(t.dim).truncate().child(g.label),
            ...g.rooms.map((r) => this.roomRow(r, t)),
          ]))
          .when(visible.length === 0, (e) => e.child(div().p(8).text_color(t.dim).child("No rooms yet. Agents create them with `room create`."))))
        .child(Scrollbar.vertical("rooms-list").absolute().inset_0()))
      .when(Boolean(current), (e) => this.roomBody(e, current, t))
      .when(!current, (e) => e.child(div().flex_1().p(12).text_color(t.dim).child(visible.length ? "Pick a room to read it." : "")));
  }
}
