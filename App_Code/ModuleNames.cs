using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Text.RegularExpressions;

/// <summary>
/// Readable names for the "module" strings in error files.
///
/// A file can carry two different module values: block 1 holds ex.Source, the assembly that threw (often mscorlib,
/// System.Web, System.Data.OracleClient), and block 2 holds whatever the application passed to its logging helper,
/// or request.RawUrl for errors caught in Application_Error (/app/Services/orders_Service.asmx/GetOpenOrders).
///
/// Describe() turns that into a main name ("Orders web service", "Order processing") and a small detail line
/// ("Shop web · orders_Service.asmx · GetOpenOrders"). The raw value is never changed: grouping, filters and
/// background rules keep using it. Your own names come from web.config "ModuleDisplayNames"
/// ("pattern,pattern=Name;..."); only general .NET names are built in.
/// </summary>
public static class ModuleNames
{
    private sealed class Rule { public Regex Rx; public string Name; }

    // Built-in rules are only the general .NET ones. Add your applications in web.config "ModuleDisplayNames", e.g.
    //   <add key="ModuleDisplayNames" value="Shop_Orders*,OrderService=Order processing;Shop_Sync*=Nightly sync" />
    // Format: pattern,pattern=Name;  "*" matches anything; case does not matter; first match wins.
    private const string BuiltIn =
        "System.Data.OracleClient,Oracle.*=Oracle database driver;" +
        "System.Data.SqlClient,Microsoft.Data.SqlClient=SQL Server driver;" +
        "System.Web,System.Web.*=ASP.NET;" +
        "System.ServiceModel,System.ServiceModel.*=WCF;" +
        "mscorlib,System,System.*=.NET runtime";

    private static volatile List<Rule> _rules;
    private static readonly object Gate = new object();
    private static readonly ConcurrentDictionary<string, string> Looked = new ConcurrentDictionary<string, string>(StringComparer.OrdinalIgnoreCase);

    private static readonly Regex Frame = new Regex(@"\bat\s+([A-Za-z_][\w]*(?:\.[\w`<>\[\],]+)+?)\s*\(", RegexOptions.Compiled);
    private static readonly Regex OurCode = new Regex(@"^(?!(System|Microsoft|mscorlib|Oracle|Newtonsoft|SAP\.Middleware|sapnco)\b)[A-Za-z_]", RegexOptions.Compiled | RegexOptions.IgnoreCase);   // any namespace that is not a library
    private static readonly Regex ShortPrefix = new Regex(@"^[A-Za-z]{2,8}_", RegexOptions.Compiled);   // a short product prefix such as "Shop_"
    private static readonly Regex GenericWord = new Regex(@"^(service|services|svc|ws|webservice)$", RegexOptions.Compiled | RegexOptions.IgnoreCase);
    private static readonly Regex Camel = new Regex(@"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", RegexOptions.Compiled);
    private static readonly Regex Spaces = new Regex(@"\s+", RegexOptions.Compiled);
    private static readonly Regex CompilerName = new Regex(@"^<([^>]+)>", RegexOptions.Compiled);   // <Load>b__0, <Load>d__5

    /// <summary>Forget the rules (after web.config changes the app restarts anyway; this is for tests).</summary>
    public static void Reload() { lock (Gate) { _rules = null; Looked.Clear(); } }

    private static List<Rule> Rules()
    {
        var r = _rules;
        if (r != null) return r;
        lock (Gate)
        {
            if (_rules != null) return _rules;
            var list = new List<Rule>();
            Parse(ConfigurationManager.AppSettings["ModuleDisplayNames"], list);
            Parse(BuiltIn, list);
            _rules = list;
            return list;
        }
    }

    private static void Parse(string text, List<Rule> into)
    {
        if (string.IsNullOrWhiteSpace(text)) return;
        foreach (var entry in text.Split(';'))
        {
            int eq = entry.LastIndexOf('=');
            if (eq <= 0) continue;
            string name = entry.Substring(eq + 1).Trim();
            if (name.Length == 0) continue;
            foreach (var p in entry.Substring(0, eq).Split(','))
            {
                string pat = p.Trim();
                if (pat.Length == 0) continue;
                into.Add(new Rule
                {
                    Rx = new Regex("^" + Regex.Escape(pat).Replace("\\*", ".*") + "$", RegexOptions.IgnoreCase | RegexOptions.CultureInvariant),
                    Name = name
                });
            }
        }
    }

    /// <summary>The friendly name a rule gives this exact value, or null.</summary>
    public static string Lookup(string raw)
    {
        raw = (raw ?? "").Trim();
        if (raw.Length == 0) return null;
        string hit;
        if (Looked.TryGetValue(raw, out hit)) return hit.Length == 0 ? null : hit;
        hit = "";
        foreach (var rule in Rules()) { if (rule.Rx.IsMatch(raw)) { hit = rule.Name; break; } }
        if (Looked.Count < 20000) Looked[raw] = hit;
        return hit.Length == 0 ? null : hit;
    }

    private static bool IsLibrary(string m)
    {
        if (m.Length == 0) return true;
        string l = m.ToLowerInvariant();
        return l == "mscorlib" || l == "system" || l.StartsWith("system.") || l.StartsWith("microsoft.") || l.StartsWith("sapnco")
            || l.StartsWith("oracle.") || l.StartsWith("newtonsoft");
    }

    /// <summary>"Shop_SchedulingService" -> "Scheduling Service", "ERPDataFetcher" -> "ERP Data Fetcher".</summary>
    public static string Humanize(string s)
    {
        s = (s ?? "").Trim();
        if (s.Length == 0) return s;
        var pfx = ShortPrefix.Match(s); if (pfx.Success && s.Length > pfx.Length) s = s.Substring(pfx.Length);   // "Shop_" in "Shop_OrderService"
        s = Spaces.Replace(Camel.Replace(s.Replace('_', ' ').Replace('.', ' '), " "), " ").Trim();
        return s.Length > 0 ? char.ToUpperInvariant(s[0]) + s.Substring(1) : s;      // "shop" -> "Shop"
    }

    // "shop_OrdersService" -> "Orders"
    private static string ServiceStem(string file)
    {
        // "orders_Service" -> "Orders", "shop_OrdersService" -> "Orders": drop words that only say "service", keep the last real one
        var words = file.Split('_').Where(w => w.Length > 0 && !GenericWord.IsMatch(w)).ToList();
        string s = words.Count > 0 ? words[words.Count - 1] : file;
        if (s.EndsWith("Service", StringComparison.Ordinal) && s.Length > 7) s = s.Substring(0, s.Length - 7);
        s = Humanize(s);
        return s.Length == 0 ? file : s;
    }

    /// <summary>A short form of the "page" a developer passed: a URL keeps its file, a class keeps its last name,
    /// an async delegate becomes "Class › Job".</summary>
    public static string ShortCaller(string caller)
    {
        caller = (caller ?? "").Trim();
        if (caller.Length == 0) return "";
        if (caller.StartsWith("/"))
        {
            var segs = caller.Split(new[] { '/' }, StringSplitOptions.RemoveEmptyEntries);
            return segs.Length == 0 ? caller : segs[segs.Length - 1];
        }
        if (caller.StartsWith("System.Func", StringComparison.Ordinal) || caller.StartsWith("System.Action", StringComparison.Ordinal)) return "async call";
        string outer = caller, inner = "";
        int plus = caller.IndexOf('+');
        if (plus > 0) { outer = caller.Substring(0, plus); inner = caller.Substring(plus + 1); }
        if (!outer.EndsWith(".cs", StringComparison.OrdinalIgnoreCase))
        {
            int dot = outer.LastIndexOf('.');
            if (dot >= 0 && dot < outer.Length - 1) outer = outer.Substring(dot + 1);
        }
        if (inner.EndsWith("Delegate", StringComparison.Ordinal) && inner.Length > 8) inner = inner.Substring(0, inner.Length - 8);
        return inner.Length > 0 ? outer + " \u203A " + inner : outer;   // escaped on purpose: the site compiles .cs files without a BOM
    }

    /// <summary>The first stack frame that belongs to our own code: its root namespace and "Class.Method".</summary>
    private static bool OwnFrame(string stack, out string root, out string where)
    {
        root = null; where = null;
        if (string.IsNullOrEmpty(stack)) return false;
        foreach (Match m in Frame.Matches(stack))
        {
            string full = m.Groups[1].Value;
            var parts = full.Split('.');
            if (parts.Length < 2) continue;
            string first = parts[0];
            if (IsLibrary(first) || !(OurCode.IsMatch(first) || Lookup(first) != null)) continue;
            root = first;
            var seg = parts.ToList();
            if (seg.Count > 2 && seg[seg.Count - 1] == "MoveNext") seg.RemoveAt(seg.Count - 1);   // async state machine
            for (int i = 0; i < seg.Count; i++) { var g = CompilerName.Match(seg[i]); if (g.Success) seg[i] = g.Groups[1].Value; }
            string cls = seg.Count >= 3 ? seg[seg.Count - 2] : "";
            string meth = seg[seg.Count - 1];
            if (cls == meth) cls = seg.Count >= 4 ? seg[seg.Count - 3] : "";
            int tick = cls.IndexOf('`'); if (tick > 0) cls = cls.Substring(0, tick);
            where = cls.Length > 0 ? cls + "." + meth : meth;
            return true;
        }
        return false;
    }

    /// <summary>A name for a value on its own (a module, a job, a caller) when there is no record to look into.</summary>
    public static string NameFor(string value)
    {
        string app, detail;
        Describe(value, value, "", null, out app, out detail);
        return app;
    }

    public static void Describe(string module, string caller, string method, string stack, out string app, out string detail)
    {
        module = (module ?? "").Trim(); caller = (caller ?? "").Trim(); method = (method ?? "").Trim();
        if (method.Equals("send", StringComparison.OrdinalIgnoreCase)) method = "";   // the async callback's own name says nothing
        var parts = new List<string>();

        if (module.StartsWith("/"))
        {
            // request.RawUrl from GlobalHandler: /<app>/<folders>/<file.asmx|.aspx>/<method>
            var segs = module.Split(new[] { '/' }, StringSplitOptions.RemoveEmptyEntries);
            string root = segs.Length > 0 ? segs[0] : "";
            string rootName = Lookup(root) ?? (root.Length > 0 ? Humanize(root) + " web" : "Web");
            int fileAt = -1;
            for (int i = 0; i < segs.Length; i++) { if (Regex.IsMatch(segs[i], @"\.(asmx|aspx|ashx|svc|axd)$", RegexOptions.IgnoreCase)) { fileAt = i; break; } }
            if (fileAt >= 0)
            {
                string file = segs[fileAt];
                string ext = file.Substring(file.LastIndexOf('.') + 1).ToLowerInvariant();
                string stem = file.Substring(0, file.LastIndexOf('.'));
                string rest = string.Join("/", segs.Skip(fileAt + 1).ToArray());
                if (ext == "asmx" || ext == "svc") { app = ServiceStem(stem) + " web service"; parts.Add(rootName); }
                else app = rootName;
                parts.Add(file);
                if (rest.Length > 0) parts.Add(rest);
            }
            else
            {
                app = rootName;
                // the address had no file (e.g. /app/); the page the request ended on is in the caller (request.FilePath)
                string page = caller.StartsWith("/") ? ShortCaller(caller) : "";
                parts.Add(page.Length > 0 ? page : (segs.Length <= 1 ? "home page" : string.Join("/", segs.Skip(1).ToArray())));
            }
        }
        else
        {
            string root, where;
            if (IsLibrary(module) && OwnFrame(stack, out root, out where))
            {
                // the error was thrown inside .NET; the first frame of our code says whose it is
                app = Lookup(root) ?? Humanize(root);
                parts.Add(where);
                if (module.Length > 0) parts.Add("thrown in " + module);
            }
            else
            {
                app = module.Length == 0 ? "No module recorded" : (Lookup(module) ?? Humanize(module));
                string c = ShortCaller(caller);
                if (c.Length > 0 && !c.Equals(module, StringComparison.OrdinalIgnoreCase)) parts.Add(c);
                string bare = method.EndsWith("Delegate", StringComparison.Ordinal) && method.Length > 8 ? method.Substring(0, method.Length - 8) : method;
                if (bare.Length > 0 && !c.EndsWith(bare, StringComparison.OrdinalIgnoreCase)) parts.Add(method);   // an async job already names it
                if (parts.Count == 0 && module.Length > 0 && !app.Equals(module, StringComparison.OrdinalIgnoreCase)) parts.Add(module);
            }
        }

        detail = string.Join(" \u00B7 ", parts.Where(p => !string.IsNullOrEmpty(p)).Distinct(StringComparer.OrdinalIgnoreCase).ToArray());
        if (string.IsNullOrEmpty(app)) app = module.Length > 0 ? module : "No module recorded";
    }
}
