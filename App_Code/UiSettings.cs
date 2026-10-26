using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.Script.Serialization;

/// <summary>
/// Settings an admin can change in the browser. Stored in App_Data/ui-settings.json (the web server's account
/// only needs write access to App_Data; web.config is never rewritten, so saving does not restart the site).
/// A null rule list or flag means "use the value from web.config".
/// </summary>
public class UiSettings
{
    // look and feel
    public string AppStyle { get; set; }              // style everyone gets: slate | teal | web | midnight
    public bool AllowUserStyles { get; set; }         // may users pick their own style in their browser?
    public List<string> UserStyles { get; set; }      // styles users may pick when AllowUserStyles is on
    public string AdminStyle { get; set; }            // style an admin sees once signed in ("" = same as everyone)
    public string SuperAdminStyle { get; set; }       // style the super admin sees once signed in ("" = same as everyone)

    // background / sync error rules (null = web.config)
    public List<string> BackgroundPages { get; set; }
    public List<string> BackgroundModules { get; set; }
    public List<string> AlwaysShowMessages { get; set; }
    public bool? HideBackgroundByDefault { get; set; }

    // where the logs are read from (null = web.config)
    public List<string> LogFolders { get; set; }      // error-file folders, one entry each, "Label=Path" or just a path
    public string Log4NetFolder { get; set; }         // log4net folder

    // how much to read (null = web.config)
    public int? MaxFiles { get; set; }                // newest files read per view when nobody is searching
    public int? MaxSearchFiles { get; set; }          // newest files whose raw text is searched per search

    // what the page opens with
    public string DefaultRange { get; set; }          // today | 24h | 7d
    public string DefaultZone { get; set; }           // server | browser | an IANA zone from Zones
    public string DefaultMode { get; set; }           // dark | light | system (a person's own Dark/Light choice always wins)

    // suggestions (null = web.config)
    public bool? SuggestionsEnabled { get; set; }
    public bool? SuggestionsVisible { get; set; }     // false: people only see their own
    public int? SuggestionMaxChars { get; set; }
    public int? SuggestionsPerHour { get; set; }
    public bool? SuggestionsNeedSignIn { get; set; }  // sending and voting need a user account
    public bool? UserSignUpOpen { get; set; }         // people may create accounts themselves
    public int? UserPasswordMinLength { get; set; }   // shortest password for user accounts (2 .. 64)

    public static readonly string[] KnownStyles = { "slate", "teal", "web", "midnight" };
    public static readonly string[] Ranges = { "today", "24h", "7d" };
    public static readonly string[] Modes = { "dark", "light", "system" };
    public static readonly string[] Zones =
    {
        "server", "browser", "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "Europe/London",
        "Europe/Berlin", "Asia/Dubai", "Asia/Kolkata", "Asia/Shanghai", "Asia/Singapore", "Asia/Tokyo", "Australia/Sydney"
    };

    private static readonly object Gate = new object();
    private static UiSettings _cached;
    private static DateTime _cachedStamp = DateTime.MaxValue;

    private static string PathOnDisk
    {
        get { return HttpContext.Current.Server.MapPath("~/App_Data/ui-settings.json"); }
    }

    public static UiSettings Defaults()
    {
        return new UiSettings
        {
            AppStyle = "slate", AllowUserStyles = false, UserStyles = new List<string>(KnownStyles),
            DefaultRange = "today", DefaultZone = "server", DefaultMode = "dark"
        };
    }

    /// <summary>Current settings. The file is only re-read when it changes. Treat the result as read-only.</summary>
    public static UiSettings Load()
    {
        lock (Gate)
        {
            try
            {
                string p = PathOnDisk;
                DateTime stamp = File.Exists(p) ? File.GetLastWriteTimeUtc(p) : DateTime.MinValue;
                if (_cached != null && stamp == _cachedStamp) return _cached;

                _cached = stamp == DateTime.MinValue
                    ? Defaults()
                    : Sanitize(new JavaScriptSerializer().Deserialize<UiSettings>(File.ReadAllText(p)));
                _cachedStamp = stamp;
                return _cached;
            }
            catch (Exception ex)
            {
                DebugLogger.Error("UiSettings.Load failed, using defaults", ex);
                return Defaults();
            }
        }
    }

    public static void Save(UiSettings s)
    {
        s = Sanitize(s);
        lock (Gate)
        {
            string p = PathOnDisk;
            Directory.CreateDirectory(Path.GetDirectoryName(p));
            string tmp = p + ".tmp";
            File.WriteAllText(tmp, new JavaScriptSerializer().Serialize(s));
            if (File.Exists(p)) File.Replace(tmp, p, null);   // one step: there is never a moment without a settings file
            else File.Move(tmp, p);
            _cached = null;                     // re-read on next Load
            _cachedStamp = DateTime.MaxValue;
        }
    }

    private static int? Clamp(int? v, int lo, int hi)
    {
        return v.HasValue ? (int?)Math.Max(lo, Math.Min(hi, v.Value)) : null;
    }

    private static bool PathOk(string p)
    {
        if (string.IsNullOrWhiteSpace(p) || p.Length > 400) return false;
        foreach (char ch in p) if (char.IsControl(ch) || "<>\"|?*".IndexOf(ch) >= 0) return false;
        return true;
    }

    private static List<string> CleanFolders(List<string> list)
    {
        if (list == null) return null;
        var clean = list.Select(x => (x ?? "").Trim()).Where(PathOk).Distinct(StringComparer.OrdinalIgnoreCase).Take(10).ToList();
        return clean.Count == 0 ? null : clean;      // an empty list would leave the viewer with nothing to read
    }

    private static List<string> CleanList(List<string> list)
    {
        if (list == null) return null;
        return list.Select(x => (x ?? "").Trim())
                   .Where(x => x.Length > 0 && x.Length <= 200)
                   .Distinct(StringComparer.OrdinalIgnoreCase)
                   .Take(200).ToList();
    }

    public static UiSettings Sanitize(UiSettings s)
    {
        if (s == null) return Defaults();
        string app = (s.AppStyle ?? "").Trim().ToLowerInvariant();
        var styles = (s.UserStyles ?? new List<string>())
            .Select(x => (x ?? "").Trim().ToLowerInvariant())
            .Where(x => KnownStyles.Contains(x))
            .Distinct().ToList();
        string range = (s.DefaultRange ?? "").Trim().ToLowerInvariant();
        string zone = (s.DefaultZone ?? "").Trim();
        string mode = (s.DefaultMode ?? "").Trim().ToLowerInvariant();
        string adminStyle = (s.AdminStyle ?? "").Trim().ToLowerInvariant();
        string superStyle = (s.SuperAdminStyle ?? "").Trim().ToLowerInvariant();
        return new UiSettings
        {
            AdminStyle = KnownStyles.Contains(adminStyle) ? adminStyle : "",
            SuperAdminStyle = KnownStyles.Contains(superStyle) ? superStyle : "",
            AppStyle = KnownStyles.Contains(app) ? app : "slate",
            AllowUserStyles = s.AllowUserStyles && styles.Count > 0,
            UserStyles = styles,
            BackgroundPages = CleanList(s.BackgroundPages),
            BackgroundModules = CleanList(s.BackgroundModules),
            AlwaysShowMessages = CleanList(s.AlwaysShowMessages),
            HideBackgroundByDefault = s.HideBackgroundByDefault,
            LogFolders = CleanFolders(s.LogFolders),
            Log4NetFolder = PathOk(s.Log4NetFolder) ? s.Log4NetFolder.Trim() : null,
            MaxFiles = Clamp(s.MaxFiles, 100, 100000),
            MaxSearchFiles = Clamp(s.MaxSearchFiles, 100, 200000),
            DefaultRange = Ranges.Contains(range) ? range : "today",
            DefaultZone = Zones.Contains(zone) ? zone : "server",
            DefaultMode = Modes.Contains(mode) ? mode : "dark",
            SuggestionsEnabled = s.SuggestionsEnabled,
            SuggestionsVisible = s.SuggestionsVisible,
            SuggestionMaxChars = Clamp(s.SuggestionMaxChars, 100, 5000),
            SuggestionsPerHour = Clamp(s.SuggestionsPerHour, 1, 50),
            SuggestionsNeedSignIn = s.SuggestionsNeedSignIn,
            UserSignUpOpen = s.UserSignUpOpen,
            UserPasswordMinLength = Clamp(s.UserPasswordMinLength, 2, 64)
        };
    }
}
