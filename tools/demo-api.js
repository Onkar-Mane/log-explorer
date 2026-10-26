/*
 * The GitHub Pages demo has no server. This file answers the page's server calls (fetch "Default.aspx/<Method>")
 * in the browser, from made-up data (tools/sample-data.js). It mirrors what App_Code/LogService.cs and friends
 * return, closely enough for every screen to work. Nothing is sent anywhere; changes last until the tab is closed.
 *
 * Demo sign-in:  demo / demo  (super admin)   or   admin / demo  (admin)
 */
(function () {
    'use strict';
    const SD = window.SampleData;
    const NOW = Date.now();
    const pad = (n) => String(n).padStart(2, '0');
    const Ts = (ms) => SD.localIso(ms);
    const lower = (s) => String(s || '').toLowerCase();

    // ---------------- data ----------------
    const RECS = SD.generate(NOW, { days: 7 });
    RECS.forEach((r) => {
        const t = r.t;
        r.ts = Ts(r.ms);
        r.bg = !!t.bg;
        r.module = t.module;
        r.method = t.async ? t.caller.split('+').pop() : (t.method || '');
        r.msg = t.async ? r.message.replace(/^Exception has been thrown by the target of an invocation\.\s*/, '') : r.message;
    });
    const L4N = SD.log4net(NOW, { days: 2 });
    const textOf = (r) => r._text || (r._text = SD.fileText(r));

    // what survives a page reload inside this tab (sign-ins, accounts, suggestions, settings)
    const KEY = 'logExplorerDemo';
    const fresh = () => ({
        role: null, userId: null,
        ui: { appStyle: 'slate', adminStyle: '', superStyle: '', allowUserStyles: true, userStyles: ['slate', 'teal', 'web', 'midnight'],
              defaultRange: '24h', defaultZone: 'server', defaultMode: 'dark' },
        sg: { enabled: true, visibleToUsers: true, needSignIn: true, signUpOpen: true, passwordMin: 6, maxChars: 1000, perHour: 5 },
        users: [
            { id: 'u1', username: 'maria', name: 'Maria (sample user)', password: 'not-a-real-account', ip: '10.0.0.21', host: 'DESK-021', device: 'a1b2c3d4e5f60718', created: NOW - 5 * 86400000, last: NOW - 3600000, disabled: false },
            { id: 'u2', username: 'ravi', name: 'Ravi (sample user)', password: 'not-a-real-account', ip: '10.0.0.34', host: 'DESK-034', device: '9f8e7d6c5b4a3921', created: NOW - 3 * 86400000, last: NOW - 7200000, disabled: false }
        ],
        suggestions: [
            { id: 's1', created: NOW - 4 * 86400000, category: 'idea', title: 'Email the team when a module starts failing', text: 'A short email when Health shows "Failing now" for more than 10 minutes would save a lot of checking.', userId: 'u1', name: 'Maria (sample user)', status: 'planned', reply: 'Good idea. Planned for the next release.', replyBy: 'demo', replyAt: NOW - 3 * 86400000, hidden: false, voters: ['u2'] },
            { id: 's2', created: NOW - 2 * 86400000, category: 'problem', title: 'Module filter is forgotten after a refresh', text: 'When I press F5 the module filter is gone. Remembering it would help.', userId: 'u2', name: 'Ravi (sample user)', status: 'new', reply: '', hidden: false, voters: ['u1'] },
            { id: 's3', created: NOW - 26 * 3600000, category: 'idea', title: 'Show the shift next to each error', text: 'Morning, evening or night shift next to the time would help the support team.', userId: 'u1', name: 'Maria (sample user)', status: 'done', reply: 'Added as a column.', replyBy: 'demo', replyAt: NOW - 20 * 3600000, hidden: false, voters: [] }
        ],
        audit: [Ts(NOW - 3600000).replace('T', ' ') + 'Z\t10.0.0.5\tdemo\tsigned in\trole: superadmin']
    });
    let S;
    try { S = JSON.parse(sessionStorage.getItem(KEY)) || fresh(); } catch (e) { S = fresh(); }
    const persist = () => { try { sessionStorage.setItem(KEY, JSON.stringify(S)); } catch (e) { } };
    const audit = (who, what, detail) => { S.audit.unshift(Ts(Date.now()).replace('T', ' ') + 'Z\t10.0.0.5\t' + who + '\t' + what + '\t' + (detail || '')); S.audit = S.audit.slice(0, 15); };
    const isAdmin = () => !!S.role, isSuper = () => S.role === 'superadmin';
    const me = () => S.users.find((u) => u.id === S.userId && !u.disabled) || null;

    // ---------------- helpers that mirror the server ----------------
    function bound(s, isTo) {
        const m = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?/.exec(s || '');
        if (!m) return isTo ? Infinity : -Infinity;
        let v = new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] || 0)).getTime();
        if (isTo) v += m[6] ? 999 : 59999;
        return v;
    }
    const inRange = (b) => RECS.filter((r) => r.ms >= bound(b.from) && r.ms <= bound(b.to, true));
    function applyFilters(list, b) {
        const mods = new Set((b.modules || []).filter(Boolean).map(lower));
        return list.filter((r) => (!b.server || r.server === b.server)
            && (!b.errorType || r.t.type === b.errorType)
            && (!mods.size || mods.has(lower(r.module)))
            && (!b.caller || r.t.caller === b.caller)
            && (!b.customMessage || lower(r.t.custom).indexOf(lower(b.customMessage).trim()) >= 0)
            && (!b.asyncOnly || !!r.t.async));
    }
    const facet = (vals) => Array.from(new Set(vals.filter(Boolean))).sort((a, b) => a.localeCompare(b));
    const labels = (list) => { const m = {}; list.forEach((r) => { m[r.module] = r.t.app; }); return m; };
    const SEV = { error: 3, warning: 2, info: 1 };

    function getLogs(b) {
        let list = inRange(b);
        if (b.search) { const q = lower(b.search).trim(); list = list.filter((r) => lower(textOf(r)).indexOf(q) >= 0); }
        const facets = { servers: facet(list.map((r) => r.server)), errorTypes: facet(list.map((r) => r.t.type)), modules: facet(list.map((r) => r.module)),
                         callers: facet(list.map((r) => r.t.caller)), moduleLabels: labels(list) };
        const filtered = applyFilters(list, b);
        const bgTotal = filtered.filter((r) => r.bg).length;
        const shown = b.showBackground ? filtered : filtered.filter((r) => !r.bg);
        const groups = {};
        shown.forEach((r) => { (groups[r.t.id] = groups[r.t.id] || []).push(r); });
        const out = Object.keys(groups).map((id) => {
            const g = groups[id], latest = g[0], t = latest.t;          // RECS is newest first
            return { Id: id, Message: latest.msg, ErrorType: t.type, ErrorModule: t.module, App: t.app, AppDetail: t.detail, ErrorMethod: latest.method,
                     Caller: t.caller, CustomMessage: t.custom || '', IsAsync: !!t.async, Category: t.cat, Severity: t.sev, ParseNote: null,
                     Count: g.length, BackgroundCount: g.filter((r) => r.bg).length, First: g[g.length - 1].ts, Last: latest.ts,
                     SiteIds: Array.from(new Set(g.map((r) => String(r.site)))), Servers: Array.from(new Set(g.map((r) => r.server))) };
        }).sort((a, b) => (a.Last < b.Last ? 1 : -1));
        return { groups: out, facets: facets, totalRecords: shown.length, filesInRange: list.length, filesExamined: list.length, truncated: false,
                 warnings: [], backgroundTotal: bgTotal, backgroundHidden: b.showBackground ? 0 : bgTotal, hideBackgroundByDefault: true };
    }

    function getDetails(b) {
        let list = inRange(b);
        if (b.search) { const q = lower(b.search).trim(); list = list.filter((r) => lower(textOf(r)).indexOf(q) >= 0); }
        const matches = applyFilters(list, b).filter((r) => (b.showBackground || !r.bg) && r.t.id === b.groupId);
        const size = Math.min(50, Math.max(1, b.pageSize || 10)), pages = Math.max(1, Math.ceil(matches.length / size));
        const page = Math.min(pages, Math.max(1, b.page || 1));
        const occ = matches.slice((page - 1) * size, page * size).map((r) => ({
            Timestamp: r.ts, ServerName: r.server, Source: '', FileName: r.file, Message: r.msg, Caller: r.t.caller, CustomMessage: r.t.custom || '',
            ContextDetails: 'SiteID: ' + r.site, Category: r.t.cat, Severity: r.t.sev, IsAsync: !!r.t.async, IsBackground: r.bg, Module: r.module,
            App: r.t.app, AppDetail: r.t.detail, SiteID: r.site, ParseNote: null, RawText: textOf(r) }));
        return { total: matches.length, page: page, pageSize: size, shown: occ.length, occurrences: occ };
    }

    function getLog4Net(b) {
        const from = bound(b.from), to = bound(b.to, true), q = lower(b.search).trim();
        let list = L4N.filter((e) => e.ms >= from && e.ms <= to && (!b.channel || e.channel === b.channel)
            && (!q || lower(e.message).indexOf(q) >= 0 || lower(e.logger).indexOf(q) >= 0 || lower(e.notes).indexOf(q) >= 0));
        const loggers = facet(list.map((e) => e.logger));
        const levels = (b.levels || '').split(',').map((s) => s.trim().toUpperCase()).filter(Boolean);
        if (levels.length > 0 && levels.length < 6) list = list.filter((e) => levels.indexOf(e.level) >= 0);
        if (b.logger) list = list.filter((e) => lower(e.logger) === lower(b.logger));
        const truncated = list.length > 2000;
        return {
            entries: list.slice(0, 2000).map((e) => ({ Timestamp: '/Date(' + e.ms + ')/', Message: e.message, ServerName: '', ErrorType: '', ErrorModule: '', ErrorMethod: '',
                                                       Notes: e.notes, SiteID: 0, Level: e.level, Thread: e.thread, Logger: e.logger, Channel: e.channel })),
            loggers: loggers, channels: ['Orders', 'SignalR', 'Sync'], truncated: truncated, newest: L4N.length ? Ts(L4N[0].ms) : null
        };
    }

    function buckets(b) {
        const from = bound(b.from), to = Math.min(bound(b.to, true), Date.now());
        const hourly = (to - from) <= 3.01 * 86400000;
        const floor = (ms) => { const d = new Date(ms); if (hourly) d.setMinutes(0, 0, 0); else d.setHours(0, 0, 0, 0); return d.getTime(); };
        const keys = [];
        for (let k = floor(from); k <= floor(to) && keys.length < 400; k = hourly ? k + 3600000 : new Date(new Date(k).setDate(new Date(k).getDate() + 1)).getTime()) keys.push(k);
        const slot = (ms) => { const f = floor(ms); const i = keys.indexOf(f); return i >= 0 ? i : (ms < keys[0] ? 0 : keys.length - 1); };
        return { hourly: hourly, keys: keys, slot: slot };
    }
    const top = (vals, n) => { const m = {}; vals.forEach((v) => { const k = v || '(none)'; m[k] = (m[k] || 0) + 1; }); return Object.keys(m).map((k) => ({ name: k, count: m[k] })).sort((a, b) => b.count - a.count || a.name.localeCompare(b.name)).slice(0, n); };

    function getDashboard(b) {
        if (!isAdmin()) return { error: 'Sign in as admin first.' };
        const all = inRange(b), key = (b.module || '').trim();
        const recs = key ? all.filter((r) => lower(r.module) === lower(key)) : all;
        const B = buckets(b), user = B.keys.map(() => 0), bg = B.keys.map(() => 0), userRecs = [], jobs = {};
        recs.forEach((r) => {
            const i = B.slot(r.ms);
            if (r.bg) {
                bg[i]++;
                const name = r.t.caller || r.module;
                const j = jobs[name] = jobs[name] || { name: name, module: r.module, count: 0, first: r.ms, last: r.ms, perBucket: B.keys.map(() => 0), msgs: {} };
                j.count++; j.perBucket[i]++; j.first = Math.min(j.first, r.ms); j.last = Math.max(j.last, r.ms); j.msgs[r.msg] = (j.msgs[r.msg] || 0) + 1;
            } else { user[i]++; userRecs.push(r); }
        });
        let busiest = 0; user.forEach((n, i) => { if (n > user[busiest]) busiest = i; });
        const byGroup = {}; userRecs.forEach((r) => { (byGroup[r.t.id] = byGroup[r.t.id] || []).push(r); });
        const topGroups = Object.keys(byGroup).map((id) => { const g = byGroup[id], l = g[0]; return { id: id, message: l.msg, module: l.module, app: l.t.app, caller: l.t.caller, category: l.t.cat, severity: l.t.sev, count: g.length, last: l.ts }; })
            .sort((a, b) => b.count - a.count).slice(0, 10);
        const nonBg = all.filter((r) => !r.bg), mx = {};
        nonBg.forEach((r) => { const m = mx[r.module] = mx[r.module] || { module: r.module, total: 0, cats: {} }; m.total++; m.cats[r.t.cat] = (m.cats[r.t.cat] || 0) + 1; });
        return {
            hourly: B.hourly, buckets: B.keys.map(Ts), user: user, background: bg,
            kpi: { userTotal: userRecs.length, backgroundTotal: bg.reduce((s, n) => s + n, 0), groups: Object.keys(byGroup).length,
                   servers: new Set(userRecs.map((r) => r.server)).size, busiestBucket: Ts(B.keys[busiest]), busiestCount: user[busiest] || 0 },
            topGroups: topGroups, byModule: top(userRecs.map((r) => r.module), 10), byCategory: top(userRecs.map((r) => r.t.cat), 10),
            byServer: top(userRecs.map((r) => r.server), 10), byCaller: top(userRecs.map((r) => r.t.caller).filter(Boolean), 10),
            jobs: Object.keys(jobs).map((k) => { const j = jobs[k]; return { name: j.name, module: j.module, count: j.count, first: Ts(j.first), last: Ts(j.last), perBucket: j.perBucket,
                                                                            topMessage: Object.keys(j.msgs).sort((a, b) => j.msgs[b] - j.msgs[a])[0] }; }),
            modules: facet(all.map((r) => r.module)), module: key,
            categoryTotals: top(nonBg.map((r) => r.t.cat), 50),
            moduleMatrix: Object.keys(mx).map((k) => ({ module: k, total: mx[k].total, cats: Object.keys(mx[k].cats).map((c) => ({ name: c, count: mx[k].cats[c] })).sort((a, b) => b.count - a.count) }))
                .sort((a, b) => b.total - a.total).slice(0, 15),
            moduleLabels: labels(all), filesInRange: all.length, filesExamined: all.length, truncated: false, partial: false, maxFiles: 100000, warnings: []
        };
    }

    function getHealth(b) {
        if (!isAdmin()) return { error: 'Sign in as admin first.' };
        const all = inRange(b), B = buckets(b), mods = {}, jobs = {}, servers = {};
        const add = (map, name, r) => { const h = map[name] = map[name] || { name: name, count: 0, last: 0, per: B.keys.map(() => 0) }; h.count++; h.per[B.slot(r.ms)]++; h.last = Math.max(h.last, r.ms); };
        all.forEach((r) => { if (r.bg) add(jobs, r.t.caller || r.module, r); else add(mods, r.module, r); add(servers, r.server, r); });
        const shape = (m) => Object.keys(m).map((k) => m[k]).sort((a, b) => b.last - a.last).map((h) => ({ name: h.name, count: h.count, last: Ts(h.last), per: h.per }));
        const jobLabels = {}; all.filter((r) => r.bg).forEach((r) => { jobLabels[r.t.caller || r.module] = r.t.app; });
        return { hourly: B.hourly, buckets: B.keys.map(Ts), modules: shape(mods), jobs: shape(jobs), servers: shape(servers), thresholds: { warn: 1, critical: 20 },
                 moduleLabels: labels(all), jobLabels: jobLabels, filesInRange: all.length, filesExamined: all.length, truncated: false, partial: false, maxFiles: 100000, warnings: [] };
    }

    // ---------------- settings ----------------
    const settingsDto = () => Object.assign({}, S.ui, { role: S.role, hideBackground: true, adminConfigured: true });
    const folderStatus = () => ({ exists: true, canRead: true, fileCount: RECS.length, newestFile: RECS[0].file, newestFileTime: RECS[0].ts });
    function adminState() {
        if (!isSuper()) return { ok: false, error: 'This needs the super admin sign-in.' };
        const rules = { pages: ['SyncService'], modules: ['Shop_SyncService'], alwaysShow: [], hide: true };
        return {
            ok: true, settings: settingsDto(),
            rules: Object.assign({ fromWebConfig: true, webConfig: rules }, rules),
            folders: { fromWebConfig: true, folders: ['D:\\Logs\\Errors'], log4net: 'D:\\Logs\\log4net', webConfig: { folders: ['D:\\Logs\\Errors'], log4net: 'D:\\Logs\\log4net' } },
            limits: { fromWebConfig: true, maxFiles: 20000, maxSearchFiles: 30000, webConfig: { maxFiles: 20000, maxSearchFiles: 30000 } },
            status: { folders: [{ label: '', path: 'D:\\Logs\\Errors (demo data)', status: folderStatus() }], cachedFiles: RECS.length,
                      serverTimeLocal: Ts(Date.now()).replace('T', ' '), serverTimeUtc: new Date().toISOString().slice(0, 19).replace('T', ' '), maxFiles: 20000, maxSearchFiles: 30000 },
            audit: S.audit
        };
    }
    function saveUi(b) {
        if (!isSuper()) return { ok: false, error: 'This needs the super admin sign-in.' };
        const styles = ['slate', 'teal', 'web', 'midnight'], pick = (v, d) => (styles.indexOf(v) >= 0 ? v : d);
        S.ui = { appStyle: pick(b.appStyle, 'slate'), adminStyle: pick(b.adminStyle, ''), superStyle: pick(b.superStyle, ''), allowUserStyles: !!b.allowUserStyles,
                 userStyles: (b.userStyles || []).filter((s) => styles.indexOf(s) >= 0), defaultRange: b.defaultRange || '24h', defaultZone: b.defaultZone || 'server', defaultMode: b.defaultMode || 'dark' };
        audit('demo', 'saved settings', 'style=' + S.ui.appStyle); persist();
        return { ok: true, settings: settingsDto(), folderCheck: { folders: [], log4net: null } };
    }

    // ---------------- suggestions and accounts ----------------
    const sgCfg = () => ({ enabled: S.sg.enabled, visibleToUsers: S.sg.visibleToUsers, needSignIn: S.sg.needSignIn, signUpOpen: S.sg.signUpOpen, passwordMin: S.sg.passwordMin,
                           maxChars: S.sg.maxChars, titleMax: 120, perHour: S.sg.perHour, nameMax: 60, replyMax: 1000 });
    const pub = (u) => (u ? { id: u.id, username: u.username, name: u.name } : null);
    function sgDto(s, u) {
        const a = isAdmin(), owner = S.users.find((x) => x.id === s.userId);
        return { id: s.id, created: Ts(s.created), category: s.category, title: s.title, text: s.text, name: s.name || '', status: s.status, reply: s.reply || '', replyBy: s.replyBy || '',
                 replyAt: s.replyAt ? Ts(s.replyAt) : '', votes: s.voters.length, voted: !!u && s.voters.indexOf(u.id) >= 0, mine: !!u && s.userId === u.id, hidden: s.hidden,
                 ip: a ? (owner ? owner.ip : '10.0.0.5') : null, host: a ? (owner ? owner.host : 'ADMIN-PC') : null, winUser: a ? '' : null,
                 agent: a ? navigator.userAgent : null, username: a ? (owner ? owner.username : '(admin) demo') : null, device: a ? (owner ? owner.device : '') : null,
                 accountGone: a && !!s.userId && !owner };
    }
    function getSuggestions() {
        if (!S.sg.enabled && !isAdmin()) return { ok: false, error: 'Suggestions are switched off.' };
        const u = me(), gated = S.sg.needSignIn && !u && !isAdmin();
        let items = gated ? [] : S.suggestions.filter((s) => isAdmin() || (!s.hidden && (S.sg.visibleToUsers || (u && s.userId === u.id))));
        items = items.slice().sort((a, b) => b.created - a.created).map((s) => sgDto(s, u));
        return { ok: true, config: sgCfg(), items: items, user: pub(u), newCount: isAdmin() ? S.suggestions.filter((s) => s.status === 'new' && !s.hidden).length : 0, gated: gated };
    }
    const clean = (s, multi) => String(s || '').replace(/\r\n?/g, '\n').replace(multi ? /[\u0000-\u0009\u000B-\u001F]/g : /[\u0000-\u001F]/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
    function addSuggestion(b) {
        if (!S.sg.enabled) return { ok: false, error: 'Suggestions are switched off.' };
        const u = me();
        if (S.sg.needSignIn && !u && !isAdmin()) return { ok: false, error: 'Sign in to send a suggestion.', needSignIn: true };
        const title = clean(b.title), text = clean(b.text, true);
        if (title.length < 3) return { ok: false, error: 'Give the suggestion a short title (at least 3 characters).' };
        if (title.length > 120) return { ok: false, error: 'The title is too long.' };
        if (text.length < 10) return { ok: false, error: 'Please describe it in a few more words (at least 10 characters).' };
        if (text.length > S.sg.maxChars) return { ok: false, error: 'The details are too long: ' + text.length + ' characters, the limit is ' + S.sg.maxChars + '.' };
        const s = { id: 's' + Date.now(), created: Date.now(), category: ['idea', 'problem', 'other'].indexOf(b.category) >= 0 ? b.category : 'idea', title: title, text: text,
                    userId: u ? u.id : null, name: u ? u.name : (clean(b.name) || 'demo'), status: 'new', reply: '', hidden: false, voters: [] };
        S.suggestions.push(s); persist();
        return { ok: true, id: s.id };
    }
    function vote(b) {
        const u = me();
        if (S.sg.needSignIn && !u) return { ok: false, error: 'Sign in to vote.', needSignIn: true };
        const s = S.suggestions.find((x) => x.id === b.id && !x.hidden); if (!s) return { ok: false, error: 'That suggestion is no longer there.' };
        const k = u ? u.id : 'anon', i = s.voters.indexOf(k);
        if (i >= 0) s.voters.splice(i, 1); else s.voters.push(k);
        persist();
        return { ok: true, voted: i < 0, votes: s.voters.length };
    }
    function pwProblem(pw, username) {
        pw = pw || '';
        if (pw.length < S.sg.passwordMin) return 'The password needs at least ' + S.sg.passwordMin + ' characters.';
        if (username && lower(pw).indexOf(username) >= 0) return 'The password must not contain your username.';
        if (new Set(pw).size < Math.min(4, S.sg.passwordMin)) return 'Choose a less simple password (not the same character again and again).';
        return null;
    }
    function signUp(b) {
        if (!S.sg.signUpOpen) return { ok: false, error: 'New accounts are switched off. Ask an admin.' };
        const username = lower(b.username).trim(), name = clean(b.name);
        if (!/^[a-z0-9][a-z0-9._-]{2,31}$/.test(username)) return { ok: false, error: 'The username needs 3 to 32 letters or digits (dots, dashes and underscores are fine, no spaces).' };
        if (name.length < 2 || name.length > 60) return { ok: false, error: 'Please give your name (2 to 60 characters).' };
        const bad = pwProblem(b.password, username); if (bad) return { ok: false, error: bad };
        if (S.users.some((u) => u.username === username)) return { ok: false, error: 'That username is taken. Choose another.' };
        const u = { id: 'u' + Date.now(), username: username, name: name, password: b.password, ip: '10.0.0.77', host: 'YOUR-PC', device: (b.device || '').slice(0, 32), created: Date.now(), last: Date.now(), disabled: false };
        S.users.push(u); S.userId = u.id; audit(u.username, 'created a user account', 'name: ' + u.name); persist();
        return { ok: true, user: pub(u) };
    }
    function signIn(b) {
        const u = S.users.find((x) => x.username === lower(b.username).trim());
        if (!u || u.password !== b.password) return { ok: false, error: 'Wrong username or password. (In this demo, create an account first.)' };
        if (u.disabled) return { ok: false, error: 'This account is switched off. Ask an admin.' };
        u.last = Date.now(); S.userId = u.id; persist();
        return { ok: true, user: pub(u) };
    }

    // ---------------- the "server" ----------------
    const API = {
        GetLogs: getLogs, GetLogDetails: getDetails, GetLog4NetLogs: getLog4Net,
        AdminStatus: () => ({ admin: isAdmin(), role: S.role, configured: true }),
        AdminLogin: (b) => {
            const user = lower(b.username).trim();
            if (b.password === 'demo' && (user === 'demo' || user === 'admin')) { S.role = user === 'demo' ? 'superadmin' : 'admin'; audit(user, 'signed in', 'role: ' + S.role); persist(); return { ok: true, role: S.role }; }
            return { ok: false, error: 'Wrong username or password. In this demo use demo / demo (super admin) or admin / demo.' };
        },
        AdminLogout: () => { S.role = null; persist(); return { ok: true }; },
        GetDashboard: getDashboard, GetServiceHealth: getHealth,
        AdminState: adminState, SaveUiSettings: saveUi,
        AdminTestFolders: (b) => ({ ok: true, result: { folders: (b.folders || []).map((p) => ({ label: '', path: p, status: folderStatus() })), log4net: b.log4netFolder ? { path: b.log4netFolder, status: folderStatus() } : null } }),
        AdminClearCache: () => ({ ok: isSuper() }),
        GetHealth: () => ({ error: 'Not available in the demo.' }),
        GetSuggestions: getSuggestions, AddSuggestion: addSuggestion, VoteSuggestion: vote,
        AdminUpdateSuggestion: (b) => {
            if (!isAdmin()) return { ok: false, error: 'Sign in as admin first.' };
            const s = S.suggestions.find((x) => x.id === b.id); if (!s) return { ok: false, error: 'That suggestion is no longer there.' };
            if (['new', 'planned', 'done', 'declined'].indexOf(b.status) < 0) return { ok: false, error: 'Unknown status.' };
            if ((s.reply || '') !== (b.reply || '')) { s.reply = clean(b.reply, true); s.replyBy = 'demo'; s.replyAt = Date.now(); }
            s.status = b.status; s.hidden = !!b.hidden; audit('demo', 'updated a suggestion', s.title); persist(); return { ok: true };
        },
        AdminDeleteSuggestion: (b) => { if (!isSuper()) return { ok: false, error: 'This needs the super admin sign-in.' }; S.suggestions = S.suggestions.filter((x) => x.id !== b.id); persist(); return { ok: true }; },
        SaveSuggestionSettings: (b) => {
            if (!isSuper()) return { ok: false, error: 'This needs the super admin sign-in.' };
            S.sg = { enabled: !!b.enabled, visibleToUsers: !!b.visibleToUsers, needSignIn: !!b.needSignIn, signUpOpen: !!b.signUpOpen,
                     passwordMin: Math.max(2, Math.min(64, b.passwordMin || 6)), maxChars: Math.max(100, Math.min(5000, b.maxChars || 1000)), perHour: Math.max(1, Math.min(50, b.perHour || 5)) };
            persist(); return { ok: true, config: sgCfg() };
        },
        UserSignUp: signUp, UserSignIn: signIn,
        UserSignOut: () => { S.userId = null; persist(); return { ok: true }; },
        UserChangePassword: (b) => { const u = me(); if (!u) return { ok: false, error: 'Sign in first.' }; if (u.password !== b.oldPassword) return { ok: false, error: 'The current password is not right.' };
                                    const bad = pwProblem(b.newPassword, u.username); if (bad) return { ok: false, error: bad }; u.password = b.newPassword; persist(); return { ok: true }; },
        UserResetWithCode: (b) => { const u = S.users.find((x) => x.username === lower(b.username).trim());
                                    if (!u || !u.code || u.code !== String(b.code || '').toUpperCase().replace(/[-\s]/g, '')) return { ok: false, error: 'The username or the reset code is not right, or the code has expired.' };
                                    const bad = pwProblem(b.newPassword, u.username); if (bad) return { ok: false, error: bad }; u.password = b.newPassword; u.code = null; u.disabled = false; persist(); return { ok: true }; },
        UserDeleteSelf: (b) => { const u = me(); if (!u) return { ok: false, error: 'Sign in first.' }; if (u.password !== b.password) return { ok: false, error: 'The password is not right.' };
                                 S.users = S.users.filter((x) => x.id !== u.id); S.userId = null; persist(); return { ok: true }; },
        AdminListUsers: () => {
            if (!isSuper()) return { ok: false, error: 'This needs the super admin sign-in.' };
            return { ok: true, users: S.users.slice().sort((a, b) => b.created - a.created).map((u) => ({ id: u.id, username: u.username, name: u.name, disabled: u.disabled,
                created: Ts(u.created), createdIp: u.ip, createdHost: u.host, createdDevice: u.device, lastSignIn: Ts(u.last), lastIp: u.ip, lastHost: u.host, lastDevice: u.device, resetPending: !!u.code })) };
        },
        AdminUserAction: (b) => {
            if (!isSuper()) return { ok: false, error: 'This needs the super admin sign-in.' };
            const u = S.users.find((x) => x.id === b.id); if (!u) return { ok: false, error: 'That account is no longer there.' };
            let code = null;
            if (b.action === 'disable') u.disabled = true;
            else if (b.action === 'enable') u.disabled = false;
            else if (b.action === 'reset') { const c = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; u.code = Array.from({ length: 10 }, () => c[Math.floor(Math.random() * c.length)]).join(''); code = u.code.slice(0, 5) + '-' + u.code.slice(5); }
            else if (b.action === 'delete') S.users = S.users.filter((x) => x.id !== u.id);
            else return { ok: false, error: 'Unknown action.' };
            persist(); return { ok: true, code: code };
        }
    };

    // every page call goes to "Default.aspx/<Method>"; answer it here, a moment later, like a server would
    const SLOW = { GetLogs: 650, GetDashboard: 700, GetServiceHealth: 500 };
    const realFetch = window.fetch.bind(window);
    window.fetch = function (input, init) {
        const url = typeof input === 'string' ? input : (input && input.url) || '';
        const m = /(?:^|\/)Default\.aspx\/(\w+)$/.exec(url);
        if (!m) return realFetch(input, init);
        let body = {};
        try { body = JSON.parse((init && init.body) || '{}'); } catch (e) { }
        let d;
        try { d = API[m[1]] ? API[m[1]](body) : { error: 'Not available in the demo.' }; }
        catch (e) { console.error('demo api', m[1], e); d = { error: 'The demo could not answer this.' }; }
        const wait = (SLOW[m[1]] || 120) + Math.random() * 200;
        return new Promise((resolve) => setTimeout(() => resolve(new Response(JSON.stringify({ d: d }), { status: 200, headers: { 'Content-Type': 'application/json' } })), wait));
    };
    window.__DEMO = true;
}());
