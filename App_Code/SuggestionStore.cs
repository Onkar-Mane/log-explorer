using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Configuration;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Script.Serialization;

/// <summary>One suggestion. Who sent it (address, computer name, Windows user, browser) is only ever shown to admins.</summary>
public class Suggestion
{
    public string Id { get; set; }
    public DateTime CreatedUtc { get; set; }
    public string Category { get; set; }       // idea | problem | other
    public string Title { get; set; }
    public string Text { get; set; }
    public string Name { get; set; }           // optional, typed by the sender (not verified)

    public string Ip { get; set; }
    public string Host { get; set; }           // computer name from the office DNS, when it knows the address
    public string WinUser { get; set; }        // only when IIS Windows Authentication is on
    public string Agent { get; set; }

    public string Status { get; set; }         // new | planned | done | declined
    public string Reply { get; set; }
    public string ReplyBy { get; set; }
    public DateTime? ReplyUtc { get; set; }
    public bool Hidden { get; set; }           // hidden by an admin: only admins still see it
    public List<string> Voters { get; set; }   // one vote per account ("u:" + id), or per address when sign-in is off
    public string UserId { get; set; }         // the account that sent it (kept as sent, even if the account is deleted later)
    public string Username { get; set; }
    public string Device { get; set; }         // random id the browser keeps; the same browser behind several accounts stands out
}

/// <summary>Limits and switches. web.config gives the defaults; the super admin can override them on the Settings page.</summary>
public class SuggestionConfig
{
    public bool Enabled;
    public bool VisibleToUsers;    // false: people only see their own suggestions
    public bool NeedSignIn;        // sending and voting need a user account
    public int MaxChars;           // details
    public int TitleMaxChars;
    public int PerHour;            // per network address
    public bool ResolveHostNames;
    public bool TrustProxyHeaders;
    public int MaxStored;

    public const int MinTitle = 3, MinText = 10, MaxName = 60, MaxReply = 1000;

    public static SuggestionConfig Current()
    {
        var ui = UiSettings.Load();
        return new SuggestionConfig
        {
            Enabled = ui.SuggestionsEnabled ?? Flag("SuggestionsEnabled", true),
            VisibleToUsers = ui.SuggestionsVisible ?? Flag("SuggestionsVisibleToUsers", true),
            MaxChars = Clamp(ui.SuggestionMaxChars ?? Num("SuggestionMaxChars", 1000), 100, 5000),
            TitleMaxChars = Clamp(Num("SuggestionTitleMaxChars", 120), 20, 200),
            PerHour = Clamp(ui.SuggestionsPerHour ?? Num("SuggestionsPerHour", 5), 1, 50),
            NeedSignIn = ui.SuggestionsNeedSignIn ?? Flag("SuggestionsNeedSignIn", true),
            ResolveHostNames = Flag("SuggestionResolveHostNames", true),
            TrustProxyHeaders = Flag("TrustProxyHeaders", false),
            MaxStored = Clamp(Num("SuggestionsMaxStored", 5000), 100, 50000)
        };
    }

    private static bool Flag(string key, bool dflt)
    {
        string v = (ConfigurationManager.AppSettings[key] ?? "").Trim().ToLowerInvariant();
        return v.Length == 0 ? dflt : (v == "true" || v == "1" || v == "yes");
    }
    private static int Num(string key, int dflt)
    {
        int n; return int.TryParse(ConfigurationManager.AppSettings[key], out n) ? n : dflt;
    }
    public static int Clamp(int v, int lo, int hi) { return Math.Max(lo, Math.Min(hi, v)); }
}

/// <summary>
/// Suggestions live in App_Data/suggestions.json (the site already needs write access there for Settings).
/// All changes go through one lock and are written in one step (File.Replace), so a crash never leaves half a file.
/// </summary>
public static class SuggestionStore
{
    public static readonly string[] Categories = { "idea", "problem", "other" };
    public static readonly string[] Statuses = { "new", "planned", "done", "declined" };

    private static readonly object Gate = new object();
    private static List<Suggestion> _items;
    private static readonly ConcurrentDictionary<string, string> HostCache = new ConcurrentDictionary<string, string>();
    private static readonly Regex BlankRuns = new Regex(@"\n{3,}", RegexOptions.Compiled);

    private static string PathOnDisk { get { return HttpContext.Current.Server.MapPath("~/App_Data/suggestions.json"); } }

    private static DateTime _stamp = DateTime.MinValue;

    private static DateTime Stamp(string p) { return File.Exists(p) ? File.GetLastWriteTimeUtc(p) : DateTime.MinValue; }

    // Read once and keep in memory; read again only when someone changed or removed the file outside the site.
    private static List<Suggestion> Items()
    {
        string p = PathOnDisk;
        if (_items != null && Stamp(p) == _stamp) return _items;
        try
        {
            _items = File.Exists(p)
                ? (new JavaScriptSerializer { MaxJsonLength = int.MaxValue }.Deserialize<List<Suggestion>>(File.ReadAllText(p)) ?? new List<Suggestion>())
                : new List<Suggestion>();
        }
        catch (Exception ex)
        {
            // never overwrite a file we could not read: keep a copy and start a fresh list
            DebugLogger.Error("Suggestions file could not be read; a copy is kept next to it", ex);
            try { File.Copy(p, p + ".unreadable-" + DateTime.Now.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture), true); } catch { }
            _items = new List<Suggestion>();
        }
        foreach (var s in _items) { if (s.Voters == null) s.Voters = new List<string>(); }
        _stamp = Stamp(p);
        return _items;
    }

    private static void Persist()
    {
        string p = PathOnDisk;
        Directory.CreateDirectory(Path.GetDirectoryName(p));
        string tmp = p + ".tmp";
        File.WriteAllText(tmp, new JavaScriptSerializer { MaxJsonLength = int.MaxValue }.Serialize(_items), Encoding.UTF8);
        if (File.Exists(p)) File.Replace(tmp, p, null); else File.Move(tmp, p);
        _stamp = Stamp(p);
    }

    // ---- who is asking -----------------------------------------------------------------------

    public static string ClientIp(HttpRequest r, SuggestionConfig cfg)
    {
        string ip = "";
        if (cfg.TrustProxyHeaders)
        {
            string fwd = r.Headers["X-Forwarded-For"] ?? "";
            ip = fwd.Split(',')[0].Trim();
        }
        if (ip.Length == 0) ip = r.UserHostAddress ?? "";
        return ip.Length > 64 ? ip.Substring(0, 64) : ip;
    }

    /// <summary>The computer's name from the office DNS (reverse lookup). Waits at most 1.5 s; remembered for the day.</summary>
    public static string HostName(string ip, SuggestionConfig cfg)
    {
        if (!cfg.ResolveHostNames || string.IsNullOrEmpty(ip)) return "";
        if (ip == "::1" || ip == "127.0.0.1") return Environment.MachineName + " (this server)";
        string key = DateTime.UtcNow.ToString("yyyyMMdd", CultureInfo.InvariantCulture) + "|" + ip, hit;
        if (HostCache.TryGetValue(key, out hit)) return hit;
        string name = "";
        try
        {
            IPAddress addr;
            if (IPAddress.TryParse(ip, out addr))
            {
                var ar = Dns.BeginGetHostEntry(addr, null, null);
                if (ar.AsyncWaitHandle.WaitOne(1500)) name = Dns.EndGetHostEntry(ar).HostName ?? "";
            }
        }
        catch { name = ""; }
        if (name == ip) name = "";
        if (HostCache.Count > 5000) HostCache.Clear();
        HostCache[key] = name;
        return name;
    }

    public static string WindowsUser(HttpContext ctx)
    {
        try
        {
            if (ctx.User != null && ctx.User.Identity != null && ctx.User.Identity.IsAuthenticated) return ctx.User.Identity.Name ?? "";
        }
        catch { }
        return "";
    }

    // ---- text cleaning -------------------------------------------------------------------------

    /// <summary>Control characters out, line breaks kept (at most two empty lines), trimmed.</summary>
    public static string Clean(string s, bool multiLine)
    {
        if (string.IsNullOrEmpty(s)) return "";
        s = s.Replace("\r\n", "\n").Replace('\r', '\n');
        var sb = new StringBuilder(s.Length);
        foreach (char ch in s)
        {
            if (ch == '\n') sb.Append(multiLine ? '\n' : ' ');
            else if (ch == '\t') sb.Append(' ');
            else if (!char.IsControl(ch) && ch != '\u200B' && ch != '\uFEFF') sb.Append(ch);   // zero-width space and BOM out
        }
        string t = sb.ToString().Trim();
        return multiLine ? BlankRuns.Replace(t, "\n\n") : t;
    }

    // ---- reading --------------------------------------------------------------------------------

    private static string Local(DateTime utc) { return utc.ToLocalTime().ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture); }

    private static string VoterKey(UserAccount user, string ip) { return user != null ? "u:" + user.Id : ip; }

    private static bool IsMine(Suggestion s, UserAccount user, string ip)
    {
        if (user != null) return s.UserId == user.Id;
        return string.IsNullOrEmpty(s.UserId) && !string.IsNullOrEmpty(ip) && string.Equals(s.Ip, ip, StringComparison.OrdinalIgnoreCase);
    }

    private static object Dto(Suggestion s, string viewerIp, UserAccount viewer, bool admin)
    {
        bool mine = IsMine(s, viewer, viewerIp);
        string voterKey = VoterKey(viewer, viewerIp);
        return new
        {
            id = s.Id, created = Local(s.CreatedUtc), category = s.Category, title = s.Title, text = s.Text, name = s.Name ?? "",
            status = s.Status, reply = s.Reply ?? "", replyBy = s.ReplyBy ?? "", replyAt = s.ReplyUtc.HasValue ? Local(s.ReplyUtc.Value) : "",
            votes = s.Voters.Count, voted = !string.IsNullOrEmpty(voterKey) && s.Voters.Contains(voterKey), mine = mine, hidden = s.Hidden,
            // who sent it: admins only
            ip = admin ? s.Ip : null, host = admin ? s.Host : null, winUser = admin ? s.WinUser : null, agent = admin ? s.Agent : null,
            username = admin ? s.Username : null, device = admin ? s.Device : null,
            accountGone = admin && !string.IsNullOrEmpty(s.UserId) && UserStore.Find(s.UserId) == null
        };
    }

    public static object List(string viewerIp, UserAccount viewer, bool admin)
    {
        var cfg = SuggestionConfig.Current();
        lock (Gate)
        {
            var all = Items();
            IEnumerable<Suggestion> q = all;
            bool gated = cfg.NeedSignIn && viewer == null && !admin;   // sign in first; the list comes after
            if (gated) q = Enumerable.Empty<Suggestion>();
            else if (!admin)
            {
                q = q.Where(s => !s.Hidden);
                if (!cfg.VisibleToUsers) q = q.Where(s => IsMine(s, viewer, viewerIp));
            }
            return new
            {
                ok = true,
                config = new { enabled = cfg.Enabled, visibleToUsers = cfg.VisibleToUsers, needSignIn = cfg.NeedSignIn, signUpOpen = UserStore.SignUpOpen, passwordMin = UserStore.MinPassword, maxChars = cfg.MaxChars, titleMax = cfg.TitleMaxChars, perHour = cfg.PerHour, nameMax = SuggestionConfig.MaxName, replyMax = SuggestionConfig.MaxReply },
                items = q.OrderByDescending(s => s.CreatedUtc).Select(s => Dto(s, viewerIp, viewer, admin)).ToList(),
                user = UserStore.Public(viewer),
                newCount = admin ? all.Count(s => s.Status == "new" && !s.Hidden) : 0,
                gated = gated
            };
        }
    }

    // ---- writing ---------------------------------------------------------------------------------

    public static object Add(HttpContext ctx, string category, string title, string text, string name, string device, UserAccount user, string adminName)
    {
        var cfg = SuggestionConfig.Current();
        if (!cfg.Enabled) return new { ok = false, error = "Suggestions are switched off." };
        if (cfg.NeedSignIn && user == null && adminName == null) return new { ok = false, error = "Sign in to send a suggestion.", needSignIn = true };
        if (user != null) name = user.Name; else if (adminName != null && string.IsNullOrWhiteSpace(name)) name = adminName;

        category = (category ?? "").Trim().ToLowerInvariant();
        if (!Categories.Contains(category)) category = "idea";
        title = Clean(title, false); text = Clean(text, true); name = Clean(name, false);

        if (title.Length < SuggestionConfig.MinTitle) return new { ok = false, error = "Give the suggestion a short title (at least " + SuggestionConfig.MinTitle + " characters)." };
        if (title.Length > cfg.TitleMaxChars) return new { ok = false, error = "The title is too long: " + title.Length + " characters, the limit is " + cfg.TitleMaxChars + "." };
        if (text.Length < SuggestionConfig.MinText) return new { ok = false, error = "Please describe it in a few more words (at least " + SuggestionConfig.MinText + " characters)." };
        if (text.Length > cfg.MaxChars) return new { ok = false, error = "The details are too long: " + text.Length + " characters, the limit is " + cfg.MaxChars + "." };
        if (name.Length > SuggestionConfig.MaxName) name = name.Substring(0, SuggestionConfig.MaxName);

        var req = ctx.Request;
        string ip = ClientIp(req, cfg);
        string host = HostName(ip, cfg);          // outside the lock: it can wait on DNS
        string agent = req.UserAgent ?? "";
        if (agent.Length > 300) agent = agent.Substring(0, 300);

        lock (Gate)
        {
            var all = Items();
            DateTime now = DateTime.UtcNow;
            int lastHour = all.Count(s => (user != null ? s.UserId == user.Id : s.Ip == ip) && s.CreatedUtc > now.AddHours(-1));
            if (lastHour >= cfg.PerHour)
                return new { ok = false, error = "You have sent " + lastHour + " suggestions in the last hour. Please try again later." };
            if (all.Any(s => s.Ip == ip && s.CreatedUtc > now.AddDays(-1)
                             && string.Equals(s.Title, title, StringComparison.OrdinalIgnoreCase) && string.Equals(s.Text, text, StringComparison.OrdinalIgnoreCase)))
                return new { ok = false, error = "You already sent this suggestion today." };
            if (all.Count >= cfg.MaxStored)
                return new { ok = false, error = "The suggestion box is full. Ask an admin to tidy it up." };

            var s2 = new Suggestion
            {
                Id = Guid.NewGuid().ToString("N").Substring(0, 12), CreatedUtc = now, Category = category, Title = title, Text = text, Name = name,
                Ip = ip, Host = host, WinUser = WindowsUser(ctx), Agent = agent, Status = "new", Voters = new List<string>(),
                UserId = user != null ? user.Id : null, Username = user != null ? user.Username : (adminName != null ? "(admin) " + adminName : null),
                Device = UserStore.CleanDevice(device)
            };
            all.Add(s2);
            try { Persist(); }
            catch (Exception ex)
            {
                all.Remove(s2);
                DebugLogger.Error("Saving a suggestion failed", ex);
                return new { ok = false, error = "Could not save the suggestion (the site needs write access to App_Data)." };
            }
            return new { ok = true, id = s2.Id };
        }
    }

    public static object Vote(HttpContext ctx, string id, UserAccount user)
    {
        var cfg = SuggestionConfig.Current();
        if (!cfg.Enabled) return new { ok = false, error = "Suggestions are switched off." };
        if (cfg.NeedSignIn && user == null) return new { ok = false, error = "Sign in to vote.", needSignIn = true };
        string ip = VoterKey(user, ClientIp(ctx.Request, cfg));
        if (ip.Length == 0) return new { ok = false, error = "Your address could not be read." };
        lock (Gate)
        {
            var s = Items().FirstOrDefault(x => x.Id == id && !x.Hidden);
            if (s == null) return new { ok = false, error = "That suggestion is no longer there." };
            bool on;
            if (s.Voters.Contains(ip)) { s.Voters.Remove(ip); on = false; } else { s.Voters.Add(ip); on = true; }
            try { Persist(); } catch (Exception ex) { DebugLogger.Error("Saving a vote failed", ex); return new { ok = false, error = "Could not save the vote." }; }
            return new { ok = true, voted = on, votes = s.Voters.Count };
        }
    }

    /// <summary>Admin: set the status, write a reply, hide or show. Returns the old and new values for the audit log.</summary>
    public static object Update(string id, string status, string reply, bool hidden, string who, out string change)
    {
        change = "";
        status = (status ?? "").Trim().ToLowerInvariant();
        if (!Statuses.Contains(status)) return new { ok = false, error = "Unknown status." };
        reply = Clean(reply, true);
        if (reply.Length > SuggestionConfig.MaxReply) return new { ok = false, error = "The reply is too long (limit " + SuggestionConfig.MaxReply + " characters)." };
        lock (Gate)
        {
            var s = Items().FirstOrDefault(x => x.Id == id);
            if (s == null) return new { ok = false, error = "That suggestion is no longer there." };
            change = "\"" + s.Title + "\": status " + s.Status + " -> " + status + (s.Hidden != hidden ? (hidden ? ", hidden" : ", shown again") : "")
                     + ((s.Reply ?? "") != reply ? ", reply changed" : "");
            if ((s.Reply ?? "") != reply) { s.Reply = reply; s.ReplyBy = reply.Length > 0 ? who : null; s.ReplyUtc = reply.Length > 0 ? (DateTime?)DateTime.UtcNow : null; }
            s.Status = status; s.Hidden = hidden;
            try { Persist(); } catch (Exception ex) { DebugLogger.Error("Saving a suggestion change failed", ex); return new { ok = false, error = "Could not save the change." }; }
            return new { ok = true };
        }
    }

    public static object Delete(string id, out string title)
    {
        title = "";
        lock (Gate)
        {
            var all = Items();
            var s = all.FirstOrDefault(x => x.Id == id);
            if (s == null) return new { ok = false, error = "That suggestion is no longer there." };
            title = s.Title + " (from " + s.Ip + (string.IsNullOrEmpty(s.Host) ? "" : " / " + s.Host) + ")";
            all.Remove(s);
            try { Persist(); } catch (Exception ex) { all.Add(s); DebugLogger.Error("Deleting a suggestion failed", ex); return new { ok = false, error = "Could not delete it." }; }
            return new { ok = true };
        }
    }

    /// <summary>For tests: forget what was read, so the file is read again.</summary>
    public static void Reset() { lock (Gate) { _items = null; } }
}
