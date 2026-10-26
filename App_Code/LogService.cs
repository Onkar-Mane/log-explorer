using System;
using System.Collections;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Configuration;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Diagnostics;
using System.Text.RegularExpressions;
using System.Threading;
using System.Web;
using System.Web.Caching;

/// <summary>Optional filters for the error-file view. Empty values mean "no filter".</summary>
public class IpasFilter
{
    public string Search { get; set; }
    public string Server { get; set; }
    public string ErrorType { get; set; }
    public string[] Modules { get; set; }        // multi-select; empty = all modules
    public string Caller { get; set; }           // block-2 page name / caller ("Source/Caller")
    public string CustomMessage { get; set; }
    public bool AsyncOnly { get; set; }
    public bool ShowBackground { get; set; }     // false hides background/sync errors when HideBackgroundLogsByDefault=true
}

public class LogService
{
    private sealed class LogSource
    {
        public string Label;   // "" when the folder has no label
        public string Path;
    }

    private sealed class IpasFile
    {
        public DateTime Time;
        public string Path;
        public LogSource Source;
    }

    private sealed class IpasLoad
    {
        public List<IpasRecord> Records = new List<IpasRecord>();
        public int FilesInRange;
        public int FilesExamined;
        public bool Truncated;
        public bool Partial;       // stopped early on time: older files are still waiting to be read
        public List<string> Warnings = new List<string>();
    }

    private readonly List<LogSource> _sources;
    private readonly string _logDirectory;   // first error-file folder (also the log4net fallback)
    private readonly LogParser _parser = new LogParser();

    // Parsed records are kept per file: a file never changes once written, so repeated queries
    // (and growing date ranges) only parse files that are new.
    private static readonly ConcurrentDictionary<string, IpasRecord> FileCache =
        new ConcurrentDictionary<string, IpasRecord>(StringComparer.OrdinalIgnoreCase);

    // Cold loads and searches are the expensive part. At most MaxConcurrentLoads run at once; other users wait
    // their turn (and then usually hit the cache) instead of all reading the disk together.
    private static SemaphoreSlim _loadGate;
    private static readonly object GateInit = new object();
    // Each file is parsed once, even when many users arrive together on a cold cache.
    private static readonly object ParseLock = new object();

    private readonly bool _enableTimeLimit;
    private readonly bool _enableDayLimit;
    private readonly bool _enableFileLimit;

    private readonly int _maxHours;
    private readonly int _maxDays;
    private readonly int _maxFiles;
    private readonly int _maxSearchFiles;
    private readonly int _maxCachedFiles;
    private readonly int _dashMaxFiles;      // the dashboard reads far more than the list (it only adds numbers up)
    private readonly int _dashSeconds;       // stop reading NEW files after this long and show what is ready
    private readonly int _cacheHours;        // a remembered file nobody used for this long is forgotten
    private long _stamp;
    private readonly int _gateWaitSeconds;

    // Background / sync error classification (web.config). Records are tagged, never dropped from reading.
    private readonly HashSet<string> _bgPages;
    private readonly HashSet<string> _bgModules;
    private readonly HashSet<string> _bgAlwaysShow;
    private readonly bool _hideBackgroundByDefault;

    // Scale guards / caching
    private readonly int _maxScanFiles;     // hard cap on directory enumeration per request
    private readonly int _maxTotalEntries;  // hard cap on entries parsed per request
    private readonly bool _enableCache;
    private readonly int _cacheSeconds;

    public LogService()
    {
        var ui = UiSettings.Load();
        // folders saved by an admin win, otherwise web.config
        _sources = ParseSources(ui.LogFolders != null ? string.Join(";", ui.LogFolders.ToArray()) : ConfigurationManager.AppSettings["LogDirectoryPath"]);
        _logDirectory = _sources.Count > 0 ? _sources[0].Path : null;

        _enableTimeLimit = GetBool("EnableTimeLimit");
        _enableDayLimit = GetBool("EnableDayLimit");
        _enableFileLimit = GetBool("EnableFileLimit") || ui.MaxFiles.HasValue;

        _maxHours = GetInt("MaxHours", 4);
        _maxDays = GetInt("MaxDays", 2);
        // limits saved by an admin win, otherwise web.config
        _maxFiles = ui.MaxFiles.HasValue ? ui.MaxFiles.Value : GetInt("MaxFiles", 20000);
        _maxSearchFiles = ui.MaxSearchFiles.HasValue ? ui.MaxSearchFiles.Value : GetInt("MaxSearchFiles", 30000);
        _maxCachedFiles = GetInt("MaxCachedFiles", 150000);
        _dashMaxFiles = GetInt("DashboardMaxFiles", 100000);
        _dashSeconds = GetInt("DashboardLoadSeconds", 60);
        _cacheHours = GetInt("CacheHours", 12);
        _gateWaitSeconds = GetInt("LoadWaitSeconds", 90);
        lock (GateInit)
        {
            if (_loadGate == null)
            {
                int n = GetInt("MaxConcurrentLoads", 3);
                _loadGate = new SemaphoreSlim(n < 1 ? 1 : n);
            }
        }

        _maxScanFiles = GetInt("MaxScanFiles", 300000);
        _maxTotalEntries = GetInt("MaxTotalEntries", 50000);
        // Cache defaults ON unless explicitly disabled in web.config.
        _enableCache = (ConfigurationManager.AppSettings["EnableCache"] ?? "true").ToLower() == "true";
        _cacheSeconds = GetInt("CacheSeconds", 30);

        _bgPages = ui.BackgroundPages != null ? new HashSet<string>(ui.BackgroundPages, StringComparer.OrdinalIgnoreCase)
                 : ToSet(ConfigurationManager.AppSettings["BackgroundLogPageNames"], new[] { ',', ';' });
        _bgModules = ui.BackgroundModules != null ? new HashSet<string>(ui.BackgroundModules, StringComparer.OrdinalIgnoreCase)
                 : ToSet(ConfigurationManager.AppSettings["BackgroundLogModules"], new[] { ',', ';' });
        if (ui.AlwaysShowMessages != null)
        {
            _bgAlwaysShow = new HashSet<string>(ui.AlwaysShowMessages, StringComparer.OrdinalIgnoreCase);
        }
        else
        {
            // Custom messages may contain commas, so the whole value is also kept as one candidate.
            _bgAlwaysShow = ToSet(ConfigurationManager.AppSettings["BackgroundLogAlwaysShowCustomMessages"], new[] { '|', ';' });
            string alwaysRaw = (ConfigurationManager.AppSettings["BackgroundLogAlwaysShowCustomMessages"] ?? "").Trim();
            if (alwaysRaw.Length > 0) _bgAlwaysShow.Add(alwaysRaw);
            foreach (var part in alwaysRaw.Split(',')) { var t = part.Trim(); if (t.Length > 0) _bgAlwaysShow.Add(t); }
        }
        _hideBackgroundByDefault = ui.HideBackgroundByDefault.HasValue ? ui.HideBackgroundByDefault.Value : GetBool("HideBackgroundLogsByDefault");

        DebugLogger.Info("LogService initialized, error-file folders: " + _sources.Count);
    }

    private static HashSet<string> ToSet(string config, char[] separators)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        if (string.IsNullOrWhiteSpace(config)) return set;
        foreach (var part in config.Split(separators, StringSplitOptions.RemoveEmptyEntries))
        {
            var t = part.Trim();
            if (t.Length > 0) set.Add(t);
        }
        return set;
    }

    public bool HideBackgroundByDefault { get { return _hideBackgroundByDefault; } }

    private static List<string> ConfigList(string key, char[] separators)
    {
        return (ConfigurationManager.AppSettings[key] ?? "")
            .Split(separators, StringSplitOptions.RemoveEmptyEntries)
            .Select(x => x.Trim()).Where(x => x.Length > 0).ToList();
    }

    /// <summary>The rules in force, and the web.config values they would fall back to.</summary>
    public object GetRules()
    {
        var ui = UiSettings.Load();
        var cfg = new
        {
            pages = ConfigList("BackgroundLogPageNames", new[] { ',', ';' }),
            modules = ConfigList("BackgroundLogModules", new[] { ',', ';' }),
            alwaysShow = ConfigList("BackgroundLogAlwaysShowCustomMessages", new[] { '|', ';' }),
            hide = GetBool("HideBackgroundLogsByDefault")
        };
        return new
        {
            fromWebConfig = ui.BackgroundPages == null && ui.BackgroundModules == null && ui.AlwaysShowMessages == null && !ui.HideBackgroundByDefault.HasValue,
            pages = ui.BackgroundPages ?? cfg.pages,
            modules = ui.BackgroundModules ?? cfg.modules,
            alwaysShow = ui.AlwaysShowMessages ?? cfg.alwaysShow,
            hide = ui.HideBackgroundByDefault.HasValue ? ui.HideBackgroundByDefault.Value : cfg.hide,
            webConfig = cfg
        };
    }

    /// <summary>The read limits in force, and the web.config values they would fall back to.</summary>
    public object GetLimits()
    {
        var ui = UiSettings.Load();
        var cfg = new { maxFiles = GetInt("MaxFiles", 20000), maxSearchFiles = GetInt("MaxSearchFiles", 30000) };
        return new
        {
            fromWebConfig = !ui.MaxFiles.HasValue && !ui.MaxSearchFiles.HasValue,
            maxFiles = _maxFiles,
            maxSearchFiles = _maxSearchFiles,
            webConfig = cfg
        };
    }

    /// <summary>Folder settings in force, and the web.config values they would fall back to.</summary>
    public object GetFolderConfig()
    {
        var ui = UiSettings.Load();
        var cfg = new
        {
            folders = (ConfigurationManager.AppSettings["LogDirectoryPath"] ?? "").Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries).Select(x => x.Trim()).Where(x => x.Length > 0).ToList(),
            log4net = (ConfigurationManager.AppSettings["Log4NetDirectoryPath"] ?? "").Trim()
        };
        return new
        {
            fromWebConfig = ui.LogFolders == null && ui.Log4NetFolder == null,
            folders = ui.LogFolders ?? cfg.folders,
            log4net = ui.Log4NetFolder ?? cfg.log4net,
            webConfig = cfg
        };
    }

    /// <summary>Checks folders without saving anything: reachable? how many files? newest file?</summary>
    public static object TestFolders(string[] lines, string log4net)
    {
        var list = new List<object>();
        foreach (var src in ParseSources(string.Join(";", (lines ?? new string[0]).Where(x => !string.IsNullOrWhiteSpace(x)).ToArray())))
            list.Add(new { label = src.Label, path = src.Path, status = DirStatus(src.Path, true) });
        object l4n = string.IsNullOrWhiteSpace(log4net) ? null : (object)new { path = log4net.Trim(), status = DirStatus(log4net.Trim(), false) };
        return new { folders = list, log4net = l4n };
    }

    /// <summary>Forget everything read so far, so the next request reads the log files again.</summary>
    public static void ClearCaches()
    {
        FileCache.Clear();
        LogParser.ClearPool();
        var cache = HttpRuntime.Cache;
        if (cache == null) return;
        var keys = new List<string>();
        foreach (DictionaryEntry e in cache)
        {
            string k = e.Key as string;
            if (k != null && (k.StartsWith("ipas2|", StringComparison.Ordinal) || k.StartsWith("l4n-", StringComparison.Ordinal))) keys.Add(k);
        }
        foreach (var k in keys) cache.Remove(k);
    }

    private sealed class JobAgg { public string Name; public string Module; public int Count; public DateTime First = DateTime.MaxValue, Last = DateTime.MinValue; public int[] Per; public Dictionary<string, int> Msgs = new Dictionary<string, int>(); }

    private static object TopCounts(IEnumerable<string> values, int take)
    {
        return values.GroupBy(x => string.IsNullOrWhiteSpace(x) ? "(none)" : x.Trim())
                     .Select(g => new { name = g.Key, count = g.Count() })
                     .OrderByDescending(x => x.count).ThenBy(x => x.name).Take(take).ToList();
    }

    /// <summary>
    /// Numbers for the admin dashboard: where errors come from, how they move over time, and (separately) how the
    /// background / sync jobs are doing. Uses the same records and rules as the error list, so the numbers agree.
    /// </summary>
    public object GetDashboard(DateTime from, DateTime to, string module)
    {
        // the dashboard only adds numbers up, so it reads much more than the list does (see DashboardMaxFiles)
        var load = LoadIpasCached(from, to, null, _dashMaxFiles);
        var all = load.Records;

        // "(none)" is how the page names records without a module
        string moduleKey = (module ?? "").Trim();
        List<IpasRecord> recs = moduleKey.Length == 0 ? all
            : all.Where(r => string.Equals(string.IsNullOrWhiteSpace(r.ErrorModule) ? "(none)" : r.ErrorModule.Trim(), moduleKey, StringComparison.OrdinalIgnoreCase)).ToList();

        bool hourly = (to - from).TotalDays <= 3.01;
        Func<DateTime, DateTime> bucket = t => hourly ? new DateTime(t.Year, t.Month, t.Day, t.Hour, 0, 0) : t.Date;
        TimeSpan step = hourly ? TimeSpan.FromHours(1) : TimeSpan.FromDays(1);

        var keys = new List<DateTime>();
        for (DateTime t = bucket(from); t <= bucket(to) && keys.Count < 400; t = t.Add(step)) keys.Add(t);
        if (keys.Count == 0) keys.Add(bucket(from));
        var index = new Dictionary<DateTime, int>();
        for (int i = 0; i < keys.Count; i++) index[keys[i]] = i;
        Func<DateTime, int> slot = t =>
        {
            int i;
            if (index.TryGetValue(bucket(t), out i)) return i;
            return t < keys[0] ? 0 : keys.Count - 1;
        };

        var user = new int[keys.Count];
        var bg = new int[keys.Count];
        var userRecs = new List<IpasRecord>();
        var jobs = new Dictionary<string, JobAgg>(StringComparer.OrdinalIgnoreCase);

        foreach (var r in recs)
        {
            int i = slot(r.Timestamp);
            if (IsBackground(r))
            {
                bg[i]++;
                string job = !string.IsNullOrEmpty(r.Caller) ? r.Caller : (!string.IsNullOrEmpty(r.ContextModule) ? r.ContextModule : "(unknown)");
                JobAgg j;
                if (!jobs.TryGetValue(job, out j)) { j = new JobAgg { Name = job, Module = r.ErrorModule, Per = new int[keys.Count] }; jobs[job] = j; }
                j.Count++; j.Per[i]++;
                if (r.Timestamp < j.First) j.First = r.Timestamp;
                if (r.Timestamp > j.Last) j.Last = r.Timestamp;
                int c; j.Msgs.TryGetValue(r.Message ?? "", out c); j.Msgs[r.Message ?? ""] = c + 1;
            }
            else
            {
                user[i]++;
                userRecs.Add(r);
            }
        }

        int busiest = 0;
        for (int i = 1; i < user.Length; i++) if (user[i] > user[busiest]) busiest = i;

        var topGroups = userRecs.GroupBy(r => r.GroupId).Select(g =>
        {
            var latest = g.OrderByDescending(x => x.Timestamp).First();
            return new { id = g.Key, message = latest.Message, module = latest.ErrorModule, app = latest.App, caller = latest.Caller, category = latest.Category,
                         severity = g.Select(x => x.Severity).OrderByDescending(SevRank).First(), count = g.Count(), last = Ts(latest.Timestamp) };
        }).OrderByDescending(x => x.count).Take(10).ToList();

        return new
        {
            hourly = hourly,
            buckets = keys.Select(Ts).ToList(),
            user = user,
            background = bg,
            kpi = new
            {
                userTotal = user.Sum(), backgroundTotal = bg.Sum(),
                groups = userRecs.Select(r => r.GroupId).Distinct().Count(),
                servers = userRecs.Select(r => r.ServerName).Where(s => !string.IsNullOrEmpty(s)).Distinct(StringComparer.OrdinalIgnoreCase).Count(),
                busiestBucket = Ts(keys[busiest]), busiestCount = user.Length == 0 ? 0 : user[busiest]
            },
            topGroups = topGroups,
            byModule = TopCounts(userRecs.Select(r => r.ErrorModule), 10),
            byCategory = TopCounts(userRecs.Select(r => r.Category), 10),
            byServer = TopCounts(userRecs.Select(r => r.ServerName), 10),
            byCaller = TopCounts(userRecs.Where(r => !string.IsNullOrEmpty(r.Caller)).Select(r => r.Caller), 10),
            jobs = jobs.Values.OrderByDescending(j => j.Last).Select(j => new
            {
                name = j.Name, module = j.Module, count = j.Count, first = Ts(j.First), last = Ts(j.Last), perBucket = j.Per,
                topMessage = j.Msgs.OrderByDescending(m => m.Value).First().Key
            }).ToList(),
            // every module, and which kinds of error each one has (always from the whole range, so you can switch modules)
            modules = all.Select(x => string.IsNullOrWhiteSpace(x.ErrorModule) ? "(none)" : x.ErrorModule.Trim()).Distinct(StringComparer.OrdinalIgnoreCase)
                         .OrderBy(x => x, StringComparer.OrdinalIgnoreCase).Take(500).ToList(),
            module = moduleKey,
            categoryTotals = all.Where(x => !IsBackground(x)).GroupBy(x => x.Category).Select(g => new { name = g.Key, count = g.Count() }).OrderByDescending(x => x.count).ToList(),
            moduleMatrix = all.Where(x => !IsBackground(x))
                .GroupBy(x => string.IsNullOrWhiteSpace(x.ErrorModule) ? "(none)" : x.ErrorModule.Trim(), StringComparer.OrdinalIgnoreCase)
                .Select(g => new
                {
                    module = g.Key, total = g.Count(),
                    cats = g.GroupBy(x => x.Category).Select(cg => new { name = cg.Key, count = cg.Count() }).OrderByDescending(x => x.count).ToList()
                }).OrderByDescending(x => x.total).Take(15).ToList(),
            moduleLabels = ModuleLabels(all),
            filesInRange = load.FilesInRange, filesExamined = load.FilesExamined, truncated = load.Truncated, partial = load.Partial,
            maxFiles = _dashMaxFiles, warnings = load.Warnings
        };
    }

    // raw module (or "(none)") -> readable name for lists, dropdowns and the dashboard
    private static Dictionary<string, string> ModuleLabels(IEnumerable<IpasRecord> recs)
    {
        var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var r in recs)
        {
            string key = string.IsNullOrWhiteSpace(r.ErrorModule) ? "(none)" : r.ErrorModule.Trim();
            // the name of the raw value itself: a .NET-only module (mscorlib, System.Data.OracleClient) keeps its own name here,
            // because each record behind it may belong to a different project (that one is shown per error group)
            if (!map.ContainsKey(key)) map[key] = key == "(none)" ? "No module recorded" : ModuleNames.NameFor(key);
            if (map.Count >= 1000) break;
        }
        return map;
    }

    private sealed class HealthAgg { public string Name; public int Count; public DateTime Last = DateTime.MinValue; public int[] Per; }

    /// <summary>
    /// Status-page style numbers: for every module, every background job and every server, how many errors were logged in
    /// each hour (or day), and when the last one was. Only components that logged at least one error in the range appear,
    /// so "no errors" means quiet, not proof that something is running.
    /// </summary>
    public object GetServiceHealth(DateTime from, DateTime to)
    {
        var load = LoadIpasCached(from, to, null, _dashMaxFiles);

        bool hourly = (to - from).TotalDays <= 3.01;
        Func<DateTime, DateTime> bucket = t => hourly ? new DateTime(t.Year, t.Month, t.Day, t.Hour, 0, 0) : t.Date;
        TimeSpan step = hourly ? TimeSpan.FromHours(1) : TimeSpan.FromDays(1);
        var keys = new List<DateTime>();
        for (DateTime t = bucket(from); t <= bucket(to) && keys.Count < 400; t = t.Add(step)) keys.Add(t);
        if (keys.Count == 0) keys.Add(bucket(from));
        var index = new Dictionary<DateTime, int>();
        for (int i = 0; i < keys.Count; i++) index[keys[i]] = i;
        Func<DateTime, int> slot = t => { int i; if (index.TryGetValue(bucket(t), out i)) return i; return t < keys[0] ? 0 : keys.Count - 1; };

        var mods = new Dictionary<string, HealthAgg>(StringComparer.OrdinalIgnoreCase);
        var jobs = new Dictionary<string, HealthAgg>(StringComparer.OrdinalIgnoreCase);
        var servers = new Dictionary<string, HealthAgg>(StringComparer.OrdinalIgnoreCase);
        Action<Dictionary<string, HealthAgg>, string, IpasRecord> add = (map, name, r) =>
        {
            HealthAgg h;
            if (!map.TryGetValue(name, out h)) { h = new HealthAgg { Name = name, Per = new int[keys.Count] }; map[name] = h; }
            h.Count++; h.Per[slot(r.Timestamp)]++;
            if (r.Timestamp > h.Last) h.Last = r.Timestamp;
        };

        foreach (var r in load.Records)
        {
            if (IsBackground(r))
                add(jobs, !string.IsNullOrEmpty(r.Caller) ? r.Caller : (!string.IsNullOrEmpty(r.ContextModule) ? r.ContextModule : "(unknown)"), r);
            else
                add(mods, string.IsNullOrWhiteSpace(r.ErrorModule) ? "(none)" : r.ErrorModule.Trim(), r);
            if (!string.IsNullOrWhiteSpace(r.ServerName)) add(servers, r.ServerName.Trim(), r);
        }

        Func<Dictionary<string, HealthAgg>, object> shape = map => map.Values.OrderByDescending(h => h.Last).Select(h => new { name = h.Name, count = h.Count, last = Ts(h.Last), per = h.Per }).ToList();
        return new
        {
            hourly = hourly,
            buckets = keys.Select(Ts).ToList(),
            modules = shape(mods),
            jobs = shape(jobs),
            servers = shape(servers),
            thresholds = new { warn = 1, critical = Math.Max(2, GetInt("HealthCriticalPerHour", 20)) },
            moduleLabels = ModuleLabels(load.Records),
            jobLabels = jobs.Keys.ToDictionary(k => k, k => ModuleNames.NameFor(k), StringComparer.OrdinalIgnoreCase),
            filesInRange = load.FilesInRange, filesExamined = load.FilesExamined, truncated = load.Truncated, partial = load.Partial,
            maxFiles = _dashMaxFiles, warnings = load.Warnings
        };
    }

    public object GetAdminStatus()
    {
        return new
        {
            folders = _sources.Select(s => new { label = s.Label, path = s.Path, status = DirStatus(s.Path, true) }).ToList(),
            cachedFiles = FileCache.Count,
            serverTimeLocal = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
            serverTimeUtc = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss"),
            maxFiles = _maxFiles,
            maxSearchFiles = _maxSearchFiles
        };
    }

    /// <summary>
    /// Background = the file has a block 2 AND its page name or module is on the configured lists,
    /// unless its Custom Message is on the always-show list. Files without block 2 can't be classified: NOT background.
    /// </summary>
    private bool IsBackground(IpasRecord r)
    {
        if (!r.HasContext) return false;
        bool listed = (!string.IsNullOrEmpty(r.Caller) && _bgPages.Contains(r.Caller.Trim()))
                   || (!string.IsNullOrEmpty(r.ContextModule) && _bgModules.Contains(r.ContextModule.Trim()));
        if (!listed) return false;
        if (!string.IsNullOrEmpty(r.CustomMessage))
        {
            foreach (var cm in r.CustomMessage.Split(new[] { " | " }, StringSplitOptions.RemoveEmptyEntries))
                if (_bgAlwaysShow.Contains(cm.Trim())) return false;
        }
        return true;
    }

    // "LogDirectoryPath" may hold several folders separated by ';'. Each can be "Label=Path",
    // e.g.  SERVER1=\\SERVER1\D$\Logs\Errors;SERVER2=\\SERVER2\D$\Logs\Errors
    private static readonly Regex LabelPathRegex = new Regex(@"^(?<l>[^\\/:=]+)=(?<p>.+)$", RegexOptions.Compiled);

    private static List<LogSource> ParseSources(string config)
    {
        var list = new List<LogSource>();
        if (string.IsNullOrWhiteSpace(config)) return list;

        foreach (var raw in config.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries))
        {
            var part = raw.Trim();
            if (part.Length == 0) continue;
            var m = LabelPathRegex.Match(part);
            if (m.Success)
                list.Add(new LogSource { Label = m.Groups["l"].Value.Trim(), Path = m.Groups["p"].Value.Trim() });
            else
                list.Add(new LogSource { Label = "", Path = part });
        }
        return list;
    }

    // ---- error files: loading --------------------------------------------------------

    private IpasLoad LoadIpasCached(DateTime from, DateTime to, string search, int dashCap = 0)
    {
        string key = "ipas2|" + from.Ticks + "|" + to.Ticks + "|" + (search ?? "").Trim().ToLowerInvariant() + "|" + dashCap;
        return GetCached(key, () => LoadIpasGated(from, to, search, dashCap));
    }

    private IpasLoad LoadIpasGated(DateTime from, DateTime to, string search, int dashCap)
    {
        if (!_loadGate.Wait(TimeSpan.FromSeconds(_gateWaitSeconds)))
            throw new Exception("The log viewer is busy reading logs for other users. Try again in a moment.");
        try { return LoadIpas(from, to, search, dashCap); }
        finally { _loadGate.Release(); }
    }

    private IpasLoad LoadIpas(DateTime from, DateTime to, string search, int dashCap)
    {
        _stamp = DateTime.UtcNow.Ticks;
        TrimCache(false);
        var sw = Stopwatch.StartNew();
        double budget = dashCap > 0 ? _dashSeconds : 0;
        DebugLogger.Info("LoadIpas START from=" + from.ToString("o") + " to=" + to.ToString("o"));

        if (_sources.Count == 0)
            throw new Exception("Log directory path is not configured in web.config (LogDirectoryPath).");

        ValidateLimits(from, to);

        var load = new IpasLoad();
        var inRange = new List<IpasFile>();
        int scanned = 0;
        bool scanCapped = false;
        int reachable = 0;

        // Discover files by PER-DAY filename wildcard. error-file names start with MM-dd-yyyy, so the
        // filesystem returns only the days in range instead of walking the whole folder.
        foreach (var src in _sources)
        {
            if (!Directory.Exists(src.Path))
            {
                load.Warnings.Add("Folder not reachable: " + Describe(src));
                continue;
            }
            reachable++;

            int dayGuard = 0;
            for (DateTime day = from.Date; day <= to.Date; day = day.AddDays(1))
            {
                if (++dayGuard > 400)
                {
                    load.Warnings.Add("Date range spans more than 400 days; only the first 400 days were scanned.");
                    break;
                }

                string pattern = day.ToString("MM-dd-yyyy", CultureInfo.InvariantCulture) + "-*";
                IEnumerable<string> dayFiles;
                try { dayFiles = Directory.EnumerateFiles(src.Path, pattern); }
                catch (Exception ex)
                {
                    DebugLogger.Error("ERROR enumerating " + pattern + " in " + src.Path, ex);
                    load.Warnings.Add("Cannot read " + Describe(src) + ": " + ex.Message);
                    break;
                }

                bool listFailed = false;
                try
                {
                    foreach (var path in dayFiles)
                    {
                        if (++scanned > _maxScanFiles) { scanCapped = true; break; }

                        // The file-name time is SERVER time, like the TimeStamp inside the file.
                        DateTime t = ExtractFileTime(Path.GetFileNameWithoutExtension(path));
                        if (t == DateTime.MinValue) continue;
                        if (t < from || t > to) continue;

                        inRange.Add(new IpasFile { Time = t, Path = path, Source = src });
                    }
                }
                catch (Exception ex)
                {
                    DebugLogger.Error("ERROR listing " + pattern + " in " + src.Path, ex);
                    load.Warnings.Add("Cannot read " + Describe(src) + ": " + ex.Message);
                    listFailed = true;
                }
                if (scanCapped || listFailed) break;
            }
            if (scanCapped) break;
        }

        if (reachable == 0)
            throw new Exception(load.Warnings.Count > 0 ? string.Join(" ", load.Warnings.ToArray()) : "Log directory not found.");

        if (scanCapped)
        {
            load.Truncated = true;
            load.Warnings.Add("The folder scan hit MaxScanFiles (" + _maxScanFiles + "). Narrow the time range.");
        }

        inRange.Sort((a, b) =>
        {
            int c = b.Time.CompareTo(a.Time);
            return c != 0 ? c : string.CompareOrdinal(a.Path, b.Path);
        });
        load.FilesInRange = inRange.Count;

        bool hasSearch = !string.IsNullOrWhiteSpace(search);
        int cap = dashCap > 0 ? dashCap : (hasSearch ? _maxSearchFiles : (_enableFileLimit ? _maxFiles : int.MaxValue));

        // With a search term the RAW text of every file in range is checked (both blocks, stack trace,
        // everything) BEFORE any cap on parsed results, so a match is never lost to the cap.
        foreach (var f in inRange)
        {
            if (load.FilesExamined >= cap) { load.Truncated = true; break; }
            load.FilesExamined++;

            try
            {
                IpasRecord rec;
                if (hasSearch)
                {
                    string text = LogParser.ReadText(f.Path);
                    if (text == null || text.IndexOf(search.Trim(), StringComparison.OrdinalIgnoreCase) < 0) continue;
                    rec = _parser.ParseText(text, f.Path, f.Source.Label, f.Time);
                }
                else
                {
                    // dashboard: after the time budget, keep using files already remembered but start no new ones
                    if (budget > 0 && sw.Elapsed.TotalSeconds > budget && !FileCache.ContainsKey(f.Path)) { load.Partial = true; load.FilesExamined--; continue; }
                    rec = ParseCached(f);
                }
                load.Records.Add(rec);
            }
            catch (Exception ex)
            {
                DebugLogger.Error("ERROR parsing file: " + f.Path, ex);
            }

            if (dashCap == 0 && load.Records.Count >= _maxTotalEntries) { load.Truncated = true; break; }
        }

        DebugLogger.Info("LoadIpas scanned=" + scanned + " inRange=" + load.FilesInRange + " examined=" + load.FilesExamined + " records=" + load.Records.Count);
        return load;
    }

    private IpasRecord ParseCached(IpasFile f)
    {
        IpasRecord rec;
        if (FileCache.TryGetValue(f.Path, out rec)) { rec.LastUsed = _stamp; return rec; }

        lock (ParseLock)
        {
            if (FileCache.TryGetValue(f.Path, out rec)) { rec.LastUsed = _stamp; return rec; }   // another request parsed it while we waited
            rec = _parser.ParseFile(f.Path, f.Source.Label, f.Time);

            // A file written in the last few seconds may still be incomplete: don't remember it yet.
            bool settled = true;
            try { settled = (DateTime.UtcNow - File.GetLastWriteTimeUtc(f.Path)).TotalSeconds > 10; } catch { }
            if (settled)
            {
                rec.LastUsed = _stamp;
                if (FileCache.Count >= _maxCachedFiles) TrimCache(true);
                FileCache[f.Path] = rec;      // stored before the lock is released, so a waiting request finds it
            }
        }
        return rec;
    }

    // Remembered files live in the website's memory (RAM) only; nothing is written to disk. They are dropped when
    // unused for CacheHours, when the cache is full (the least recently used quarter goes), when an admin clicks
    // "Re-read logs now", and whenever IIS recycles or idles the site.
    private static long _lastTrim;
    private void TrimCache(bool force)
    {
        long now = DateTime.UtcNow.Ticks;
        if (!force && now - Interlocked.Read(ref _lastTrim) < TimeSpan.FromMinutes(10).Ticks) return;
        Interlocked.Exchange(ref _lastTrim, now);

        long oldest = now - TimeSpan.FromHours(Math.Max(1, _cacheHours)).Ticks;
        foreach (var kv in FileCache)
        {
            if (kv.Value.LastUsed < oldest) { IpasRecord gone; FileCache.TryRemove(kv.Key, out gone); }
        }
        if (FileCache.Count >= _maxCachedFiles)
        {
            var victims = FileCache.OrderBy(kv => kv.Value.LastUsed).Take(Math.Max(1, FileCache.Count / 4)).Select(kv => kv.Key).ToList();
            foreach (var k in victims) { IpasRecord gone; FileCache.TryRemove(k, out gone); }
        }
    }

    private static string Describe(LogSource s)
    {
        return s.Label.Length > 0 ? s.Label + " (" + s.Path + ")" : s.Path;
    }

    // ---- caching / shared helpers -----------------------------------------

    private T GetCached<T>(string key, Func<T> loader) where T : class
    {
        if (!_enableCache) return loader();

        var cache = HttpRuntime.Cache;
        if (cache == null) return loader();

        var hit = cache[key] as T;
        if (hit != null) { DebugLogger.Info("Cache HIT " + key); return hit; }

        var data = loader();
        try
        {
            cache.Insert(key, data, null,
                DateTime.UtcNow.AddSeconds(_cacheSeconds),
                Cache.NoSlidingExpiration);
        }
        catch { /* caching is best-effort */ }
        return data;
    }

    // Truncate Notes WITHOUT mutating cached entries (clone only the oversized ones).
    private static List<LogEntry> TruncateNotes(List<LogEntry> entries, int maxNotesChars)
    {
        if (maxNotesChars <= 0) return entries;
        var outList = new List<LogEntry>(entries.Count);
        foreach (var e in entries)
        {
            if (e.Notes != null && e.Notes.Length > maxNotesChars)
                outList.Add(CloneWithNotes(e, e.Notes.Substring(0, maxNotesChars) + "..."));
            else
                outList.Add(e);
        }
        return outList;
    }

    private static LogEntry CloneWithNotes(LogEntry e, string notes)
    {
        return new LogEntry
        {
            Timestamp = e.Timestamp,
            Message = e.Message,
            ServerName = e.ServerName,
            ErrorType = e.ErrorType,
            ErrorModule = e.ErrorModule,
            ErrorMethod = e.ErrorMethod,
            Notes = notes,
            SiteID = e.SiteID,
            Level = e.Level,
            Thread = e.Thread,
            Logger = e.Logger,
            Channel = e.Channel
        };
    }

    // ---- error files: grouping, filters, details --------------------------------------------

    private static bool Blank(string s) { return string.IsNullOrWhiteSpace(s); }
    private static bool Eq(string a, string b) { return string.Equals((a ?? "").Trim(), (b ?? "").Trim(), StringComparison.OrdinalIgnoreCase); }

    private static IEnumerable<IpasRecord> ApplyFilters(IEnumerable<IpasRecord> q, IpasFilter f)
    {
        if (!Blank(f.Server)) q = q.Where(r => Eq(r.ServerName, f.Server) || Eq(r.Source, f.Server));
        if (!Blank(f.ErrorType)) q = q.Where(r => Eq(r.ErrorType, f.ErrorType));
        if (f.Modules != null && f.Modules.Any(m => !Blank(m)))
        {
            var mods = new HashSet<string>(f.Modules.Where(m => !Blank(m)).Select(m => m.Trim()), StringComparer.OrdinalIgnoreCase);
            q = q.Where(r => mods.Contains((r.ErrorModule ?? "").Trim()));
        }
        if (!Blank(f.Caller)) q = q.Where(r => Eq(r.Caller, f.Caller));
        if (!Blank(f.CustomMessage))
            q = q.Where(r => (r.CustomMessage ?? "").IndexOf(f.CustomMessage.Trim(), StringComparison.OrdinalIgnoreCase) >= 0);
        if (f.AsyncOnly) q = q.Where(r => r.IsAsync);
        return q;
    }

    private static string Ts(DateTime d) { return d.ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture); }

    private static int SevRank(string s) { return s == "error" ? 3 : (s == "warning" ? 2 : 1); }

    private static List<string> Facet(IEnumerable<string> values)
    {
        return values.Where(v => !string.IsNullOrWhiteSpace(v)).Select(v => v.Trim())
                     .Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(v => v, StringComparer.OrdinalIgnoreCase).Take(500).ToList();
    }

    public object GetIpasGroups(DateTime from, DateTime to, IpasFilter f)
    {
        var load = LoadIpasCached(from, to, f.Search);

        var facets = new
        {
            servers = Facet(load.Records.Select(r => r.ServerName)),
            errorTypes = Facet(load.Records.Select(r => r.ErrorType)),
            modules = Facet(load.Records.Select(r => r.ErrorModule)),
            callers = Facet(load.Records.Select(r => r.Caller)),
            moduleLabels = ModuleLabels(load.Records)
        };

        var afterFilters = ApplyFilters(load.Records, f).ToList();
        bool hide = _hideBackgroundByDefault && !f.ShowBackground;
        int backgroundTotal = afterFilters.Count(IsBackground);
        var filtered = hide ? afterFilters.Where(r => !IsBackground(r)).ToList() : afterFilters;

        var groups = filtered
            .GroupBy(r => r.GroupId)
            .Select(g =>
            {
                var latest = g.OrderByDescending(x => x.Timestamp).First();
                string sev = g.Select(x => x.Severity).OrderByDescending(SevRank).First();
                return new
                {
                    Id = g.Key,
                    Message = latest.Message,
                    ErrorType = latest.ErrorType,
                    ErrorModule = latest.ErrorModule,
                    App = latest.App,
                    AppDetail = latest.AppDetail,
                    ErrorMethod = latest.ErrorMethod,
                    Caller = latest.Caller,
                    CustomMessage = latest.CustomMessage,
                    IsAsync = latest.IsAsync,
                    Category = latest.Category,
                    Severity = sev,
                    ParseNote = g.Select(x => x.ParseNote).FirstOrDefault(n => !string.IsNullOrEmpty(n)),
                    Count = g.Count(),
                    BackgroundCount = g.Count(IsBackground),
                    First = Ts(g.Min(x => x.Timestamp)),
                    Last = Ts(g.Max(x => x.Timestamp)),
                    SiteIds = g.Select(x => x.SiteID.ToString()).Distinct().ToList(),
                    Servers = g.Select(x => x.ServerName).Where(s => !string.IsNullOrEmpty(s)).Distinct().ToList()
                };
            })
            .OrderByDescending(g => g.Last)
            .ToList();

        return new
        {
            groups = groups,
            facets = facets,
            totalRecords = filtered.Count,
            filesInRange = load.FilesInRange,
            filesExamined = load.FilesExamined,
            truncated = load.Truncated,
            warnings = load.Warnings,
            backgroundTotal = backgroundTotal,
            backgroundHidden = hide ? backgroundTotal : 0,
            hideBackgroundByDefault = _hideBackgroundByDefault
        };
    }

    public object GetIpasDetails(DateTime from, DateTime to, IpasFilter f, string groupId, int page, int pageSize)
    {
        var load = LoadIpasCached(from, to, f.Search);

        bool hide = _hideBackgroundByDefault && !f.ShowBackground;
        var matches = ApplyFilters(load.Records, f)
            .Where(r => !(hide && IsBackground(r)))
            .Where(r => r.GroupId == groupId)
            .OrderByDescending(r => r.Timestamp)
            .ToList();

        // Only the requested page is read from disk (raw text), so opening a group stays fast however many occurrences it has.
        if (pageSize < 1) pageSize = 10;
        if (pageSize > 50) pageSize = 50;
        int pages = Math.Max(1, (int)Math.Ceiling(matches.Count / (double)pageSize));
        if (page < 1) page = 1;
        if (page > pages) page = pages;
        int maxRaw = GetInt("MaxRawChars", 100000);
        var shown = matches.Skip((page - 1) * pageSize).Take(pageSize).ToList();

        var occurrences = shown.Select(r => new
        {
            Timestamp = Ts(r.Timestamp),
            ServerName = r.ServerName,
            Source = r.Source,
            FileName = r.FileName,
            Message = r.Message,
            Caller = r.Caller,
            CustomMessage = r.CustomMessage,
            ContextDetails = r.ContextDetails,
            Category = r.Category,
            Severity = r.Severity,
            IsAsync = r.IsAsync,
            IsBackground = IsBackground(r),
            Module = r.ErrorModule,
            App = r.App,
            AppDetail = r.AppDetail,
            SiteID = r.SiteID,
            ParseNote = r.ParseNote,
            RawText = ReadRaw(r.FilePath, maxRaw)
        }).ToList();

        return new { total = matches.Count, page = page, pageSize = pageSize, shown = occurrences.Count, occurrences = occurrences };
    }

    // The full file text (both blocks). Read on demand so the cache never holds raw text.
    private static string ReadRaw(string path, int maxChars)
    {
        try
        {
            string text = LogParser.ReadText(path);
            if (text == null) return "(file larger than 20 MB, not shown)";
            if (maxChars > 0 && text.Length > maxChars)
                return text.Substring(0, maxChars) + "\n... (truncated, file has " + text.Length + " characters)";
            return text;
        }
        catch (Exception ex)
        {
            return "(file could not be read: " + ex.Message + ")";
        }
    }

    // ---- log4net support ---------------------------------------------------

    private static readonly Regex Log4NetNameRegex =
        new Regex(@"^(?<base>.+?\.log)(\.\d+)?$", RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly Regex IpasNameRegex =
        new Regex(@"^\d{2}-\d{2}-\d{4}-\d{2}_\d{2}_\d{2}_\d+$", RegexOptions.Compiled);
    private static readonly Regex FileTimeRegex =
        new Regex(@"^(\d{2})-(\d{2})-(\d{4})-(\d{2})_(\d{2})_(\d{2})", RegexOptions.Compiled);

    public object GetLog4NetLogs(DateTime from, DateTime to, string search, string levels, string logger, string channel)
    {
        DebugLogger.Info("GetLog4NetLogs START channel=" + (channel ?? "") + " levels=" + (levels ?? ""));

        string dir = UiSettings.Load().Log4NetFolder ?? ConfigurationManager.AppSettings["Log4NetDirectoryPath"];
        if (string.IsNullOrWhiteSpace(dir))
            dir = _logDirectory; // fall back to the shared log directory

        if (string.IsNullOrWhiteSpace(dir))
            throw new Exception("log4net directory path is not configured (Log4NetDirectoryPath).");
        if (!Directory.Exists(dir))
            throw new Exception("log4net directory not found: " + dir);

        // 1) Discover log4net files (cached). The discovery scan is capped so that a
        //    directory also containing hundreds of thousands of error files isn't fully walked per request.
        var index = GetCached("l4n-index|" + dir, () => BuildLog4NetIndex(dir));

        // 2) Parse the selected channel's files (cached per channel).
        string channelKey = string.IsNullOrWhiteSpace(channel) ? "*ALL*" : channel;
        // The entry cap must not be used up by entries older than the range, or an older range would always be empty.
        // A file last written before the chosen day cannot hold anything in range, so it is skipped; entries before
        // that day are dropped as they are read. The day is part of the cache key so each start day keeps its own set.
        DateTime since = from == DateTime.MinValue ? DateTime.MinValue : from.Date;
        var parsed = GetCached("l4n-parsed|" + dir + "|" + channelKey + "|" + since.ToString("yyyyMMdd", CultureInfo.InvariantCulture), () =>
        {
            var files = index.Files;
            if (!string.IsNullOrWhiteSpace(channel))
                files = files.Where(f => string.Equals(f.Channel, channel, StringComparison.OrdinalIgnoreCase)).ToList();

            var parser = new Log4NetParser();
            var acc = new List<LogEntry>();
            // LastWrite is UTC and the entries are server time: a day of margin covers any zone difference
            DateTime sinceUtc = since == DateTime.MinValue ? DateTime.MinValue : since.AddDays(-1);
            foreach (var f in files.Where(f => f.LastWrite >= sinceUtc).OrderByDescending(f => f.LastWrite))
            {
                try { acc.AddRange(parser.ParseLogs(f.Path).Where(e => e.Timestamp >= since)); }
                catch (Exception ex) { DebugLogger.Error("ERROR parsing log4net file: " + f.Path, ex); }

                if (acc.Count >= _maxTotalEntries)
                {
                    DebugLogger.Warn("log4net reached MaxTotalEntries=" + _maxTotalEntries + "; stopping parse early.");
                    break;
                }
            }
            return acc;
        });

        // 3) Filter the cached set (date + free-text search).
        IEnumerable<LogEntry> q = parsed.Where(e => e.Timestamp >= from && e.Timestamp <= to);
        if (!string.IsNullOrWhiteSpace(search))
        {
            q = q.Where(e =>
                (e.Message ?? "").IndexOf(search, StringComparison.OrdinalIgnoreCase) >= 0 ||
                (e.Logger ?? "").IndexOf(search, StringComparison.OrdinalIgnoreCase) >= 0 ||
                (e.Notes ?? "").IndexOf(search, StringComparison.OrdinalIgnoreCase) >= 0);
        }
        var filtered = q.ToList();

        // Logger facet from the date/search-filtered set (before level/logger filters).
        var allLoggers = filtered
            .Select(e => e.Logger ?? "")
            .Where(s => s.Length > 0)
            .Distinct()
            .OrderBy(x => x)
            .ToList();

        // Level filter (skip when nothing or everything is selected)
        var levelSet = (levels ?? "")
            .Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(s => s.Trim().ToUpperInvariant())
            .ToList();
        if (levelSet.Count > 0 && levelSet.Count < 6)
            filtered = filtered.Where(e => levelSet.Contains((e.Level ?? "").ToUpperInvariant())).ToList();

        // Logger filter
        if (!string.IsNullOrWhiteSpace(logger))
            filtered = filtered.Where(e => string.Equals(e.Logger ?? "", logger, StringComparison.OrdinalIgnoreCase)).ToList();

        // Newest first
        filtered = filtered.OrderByDescending(e => e.Timestamp).ToList();

        int maxEntries = GetInt("MaxStreamEntries", 2000);
        bool truncated = false;
        if (maxEntries > 0 && filtered.Count > maxEntries)
        {
            filtered = filtered.Take(maxEntries).ToList();
            truncated = true;
        }

        int maxNotesChars = GetInt("MaxNotesChars", 4000);
        var outEntries = TruncateNotes(filtered, maxNotesChars);

        DebugLogger.Info("GetLog4NetLogs RETURN count=" + outEntries.Count + " truncated=" + truncated);

        return new
        {
            entries = outEntries,
            loggers = allLoggers,
            channels = index.Channels,
            truncated = truncated,
            // lets the page say "the newest entry is from ..." when the chosen range is empty
            newest = parsed.Count == 0 ? null : Ts(parsed.Max(e => e.Timestamp))
        };
    }

    private sealed class Log4NetFile
    {
        public string Path;
        public string Channel;
        public DateTime LastWrite;
    }

    private sealed class Log4NetIndex
    {
        public List<Log4NetFile> Files;
        public List<string> Channels;
    }

    private Log4NetIndex BuildLog4NetIndex(string dir)
    {
        var files = new List<Log4NetFile>();
        int scanned = 0;
        bool capped = false;

        foreach (var path in Directory.EnumerateFiles(dir))
        {
            if (++scanned > _maxScanFiles) { capped = true; break; }

            var nm = System.IO.Path.GetFileName(path);
            if (!IsLog4NetFile(nm)) continue;

            DateTime lw;
            try { lw = File.GetLastWriteTimeUtc(path); }
            catch { lw = DateTime.MinValue; }

            files.Add(new Log4NetFile { Path = path, Channel = GetChannelName(nm), LastWrite = lw });
        }

        if (capped)
            DebugLogger.Warn("log4net discovery capped at MaxScanFiles=" + _maxScanFiles +
                             " - consider date-subfoldering the log directory.");

        var channels = files.Select(f => f.Channel).Distinct().OrderBy(x => x).ToList();
        DebugLogger.Info("log4net index: scanned=" + scanned + " matchedFiles=" + files.Count + " channels=" + channels.Count);
        return new Log4NetIndex { Files = files, Channels = channels };
    }

    private bool IsLog4NetFile(string fileName)
    {
        var m = Log4NetNameRegex.Match(fileName);
        if (!m.Success) return false;
        // Exclude the timestamp-named error files (which also end in .log).
        string bare = Path.GetFileNameWithoutExtension(m.Groups["base"].Value);
        return !IpasNameRegex.IsMatch(bare);
    }

    private string GetChannelName(string fileName)
    {
        var m = Log4NetNameRegex.Match(fileName);
        string baseName = m.Success ? m.Groups["base"].Value : fileName;
        return Path.GetFileNameWithoutExtension(baseName);
    }

    // ---- health check (browser-callable diagnostic, no debug file needed) ----

    public object GetHealth()
    {
        string l4nDir = UiSettings.Load().Log4NetFolder ?? ConfigurationManager.AppSettings["Log4NetDirectoryPath"];
        if (string.IsNullOrWhiteSpace(l4nDir)) l4nDir = _logDirectory;

        string debugPath = ConfigurationManager.AppSettings["DebugLogPath"];
        bool debugWritable = false;
        string debugError = null;
        try
        {
            if (!string.IsNullOrWhiteSpace(debugPath))
            {
                var d = Path.GetDirectoryName(debugPath);
                if (!string.IsNullOrEmpty(d) && !Directory.Exists(d)) Directory.CreateDirectory(d);
                File.AppendAllText(debugPath, "");
                debugWritable = true;
            }
        }
        catch (Exception ex) { debugError = ex.Message; }

        string identity = "";
        try { identity = System.Security.Principal.WindowsIdentity.GetCurrent().Name; }
        catch { }

        return new
        {
            serverTimeLocal = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
            serverTimeUtc = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss"),
            appPoolIdentity = identity,
            ipas = _sources.Select(s => DirStatus(s.Path, true)).ToList(),
            log4net = DirStatus(l4nDir, false),
            debugPath = debugPath,
            debugWritable = debugWritable,
            debugError = debugError
        };
    }

    private static object DirStatus(string dir, bool ipasNaming)
    {
        if (string.IsNullOrWhiteSpace(dir))
            return new { dir = dir, exists = false, error = "not configured" };
        if (!Directory.Exists(dir))
            return new { dir = dir, exists = false, error = "directory not found (path wrong, or app-pool identity can't see it)" };

        try
        {
            int count = 0;
            DateTime newest = DateTime.MinValue;
            string newestName = null;
            foreach (var path in Directory.EnumerateFiles(dir))
            {
                count++;
                if (ipasNaming)
                {
                    var t = ExtractFileTime(Path.GetFileNameWithoutExtension(path));
                    if (t != DateTime.MinValue && t > newest) { newest = t; newestName = Path.GetFileName(path); }
                }
                if (count >= 500000) break;
            }
            return new
            {
                dir = dir,
                exists = true,
                canRead = true,
                fileCount = count,
                newestFile = newestName,
                newestFileTime = newest == DateTime.MinValue ? null : newest.ToString("yyyy-MM-dd HH:mm:ss")
            };
        }
        catch (Exception ex)
        {
            return new { dir = dir, exists = true, canRead = false, error = "cannot read (permission?): " + ex.Message };
        }
    }

    // Expects the file name WITHOUT extension. Uses a single compiled regex
    // (the old version compiled a fresh regex per file — fatal at scale).
    private static DateTime ExtractFileTime(string fileNameNoExt)
    {
        var match = FileTimeRegex.Match(fileNameNoExt);
        if (!match.Success)
            return DateTime.MinValue;

        try
        {
            return new DateTime(
                int.Parse(match.Groups[3].Value),
                int.Parse(match.Groups[1].Value),
                int.Parse(match.Groups[2].Value),
                int.Parse(match.Groups[4].Value),
                int.Parse(match.Groups[5].Value),
                int.Parse(match.Groups[6].Value)
            );
        }
        catch
        {
            // Malformed components (e.g. month 13) must not crash the request.
            return DateTime.MinValue;
        }
    }

    private void ValidateLimits(DateTime from, DateTime to)
    {
        if (_enableTimeLimit && (to - from).TotalHours > _maxHours)
            throw new Exception("Time range cannot exceed " + _maxHours + " hours");

        if (_enableDayLimit && (to - from).TotalDays > _maxDays)
            throw new Exception("Date range cannot exceed " + _maxDays + " days");
    }

    private bool GetBool(string key)
    {
        return (ConfigurationManager.AppSettings[key] ?? "false").ToLower() == "true";
    }

    private int GetInt(string key, int defaultVal)
    {
        int val;
        return int.TryParse(ConfigurationManager.AppSettings[key], out val) ? val : defaultVal;
    }
}
