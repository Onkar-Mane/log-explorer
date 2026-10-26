using System;
using System.Configuration;
using System.Globalization;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.Services;

public partial class Default : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
    }

    /// <summary>
    /// Culture-invariant parse of the datetime-local strings ("yyyy-MM-ddTHH:mm") the UI sends.
    /// Fails OPEN (broad range) instead of collapsing to an empty window, and makes the
    /// end ('to') inclusive of the whole selected minute so same-minute files aren't dropped.
    /// </summary>
    private static DateTime ParseBound(string s, bool isTo)
    {
        DateTime d;
        bool ok = DateTime.TryParse(s, CultureInfo.InvariantCulture, DateTimeStyles.None, out d)
                  || DateTime.TryParse(s, out d); // last-resort: server culture

        if (!ok)
            return isTo ? DateTime.MaxValue : DateTime.MinValue;

        // A bound sent without seconds ("16:18") means up to 16:18:59.999. A bound WITH seconds
        // ("11:20:00") is an exact time and is used as is, so exact windows like 11:18-11:20 work.
        if (isTo && !HasSeconds(s))
            d = d.AddSeconds(59).AddMilliseconds(999);
        else if (isTo && d.Millisecond == 0)
            d = d.AddMilliseconds(999);    // "11:20:00" includes 11:20:00.450 (log4net times carry milliseconds)

        return d;
    }

    private static readonly Regex SecondsRegex = new Regex(@"\d{1,2}:\d{2}:\d{2}", RegexOptions.Compiled);
    private static bool HasSeconds(string s) { return s != null && SecondsRegex.IsMatch(s); }

    /// <summary>Server clock offset from UTC in minutes (web.config ServerUtcOffsetMinutes; 0 = servers run on UTC).</summary>
    protected string ServerUtcOffsetMinutes
    {
        get
        {
            int v;
            if (!int.TryParse(ConfigurationManager.AppSettings["ServerUtcOffsetMinutes"], out v))
                v = (int)TimeZoneInfo.Local.GetUtcOffset(DateTime.Now).TotalMinutes; // not configured: this machine's clock
            return v.ToString(CultureInfo.InvariantCulture);
        }
    }

    /// <summary>Changes whenever dist/app.css is rebuilt, so browsers never keep a stale copy.</summary>
    protected string AssetVersion
    {
        get
        {
            try { return System.IO.File.GetLastWriteTimeUtc(Server.MapPath("~/dist/app.css")).Ticks.ToString(CultureInfo.InvariantCulture); }
            catch { return "0"; }
        }
    }

    /// <summary>Initial state of the "Show background/sync errors" toggle.</summary>
    protected string HideBackgroundDefault
    {
        get
        {
            return ((ConfigurationManager.AppSettings["HideBackgroundLogsByDefault"] ?? "false").Trim().ToLower() == "true")
                ? "true" : "false";
        }
    }

    /// <summary>Emitted into the page as window.__DIAG; controls the on-page diagnostic panel.</summary>
    protected string DiagEnabled
    {
        get
        {
            return ((ConfigurationManager.AppSettings["EnableDiagnostics"] ?? "false").ToLower() == "true")
                ? "true" : "false";
        }
    }

    /// <summary>
    /// Browser-callable health check for diagnosing server deployments (no debug file needed).
    /// Gated behind EnableDiagnostics so it's off in normal prod.
    /// Call from the page's console:
    ///   fetch('Default.aspx/GetHealth',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})
    ///     .then(r=>r.json()).then(x=>console.log(JSON.stringify(x.d,null,2)))
    /// </summary>
    [WebMethod(EnableSession = true)]
    public static object GetHealth()
    {
        if (!IsAdmin()) return new { error = "Sign in as admin first." };   // it shows folder paths and the site's account
        if ((ConfigurationManager.AppSettings["EnableDiagnostics"] ?? "false").ToLower() != "true")
            return new { error = "Diagnostics disabled. Set EnableDiagnostics=true in web.config to use GetHealth." };

        try { return new LogService().GetHealth(); }
        catch (Exception ex) { return new { error = ex.Message }; }
    }

    /// <summary>Look-and-feel settings (JSON) written into the page so the right style is applied before first paint.</summary>
    protected string UiSettingsJson
    {
        get
        {
            var s = UiSettings.Load();
            return new JavaScriptSerializer().Serialize(new
            {
                appStyle = s.AppStyle,
                adminStyle = s.AdminStyle,
                superStyle = s.SuperAdminStyle,
                role = Role(),                     // so a signed-in admin gets their style before the first paint
                allowUserStyles = s.AllowUserStyles,
                userStyles = s.UserStyles,
                defaultRange = s.DefaultRange,
                defaultZone = s.DefaultZone,
                defaultMode = s.DefaultMode,
                hideBackground = new LogService().HideBackgroundByDefault,
                adminConfigured = AdminAuth.IsConfigured,
                suggestionsEnabled = SuggestionConfig.Current().Enabled
            });
        }
    }

    // Two roles: "admin" sees the dashboard; "superadmin" also sees and changes the settings.
    private static string Role()
    {
        var session = HttpContext.Current.Session;
        return session == null ? null : session["lv_role"] as string;
    }

    private static bool IsAdmin() { return Role() != null; }
    private static bool IsSuper() { return Role() == AdminAuth.RoleSuper; }
    private static string WhoAmI() { return HttpContext.Current.Session["lv_admin"] as string; }
    private const string NeedSuper = "This needs the super admin sign-in.";

    [WebMethod(EnableSession = true)]
    public static object AdminStatus()
    {
        return new { admin = IsAdmin(), role = Role(), configured = AdminAuth.IsConfigured };
    }

    [WebMethod(EnableSession = true)]
    public static object AdminLogin(string username, string password)
    {
        string error, role;
        string ip = HttpContext.Current.Request.UserHostAddress ?? "";
        if (!AdminAuth.Validate(ip, username, password, out error, out role))
        {
            AdminAudit.Write(username, "sign-in failed", error);
            return new { ok = false, error = error };
        }
        AdminAudit.Write(username, "signed in", "role: " + role);

        HttpContext.Current.Session["lv_admin"] = (username ?? "").Trim();
        HttpContext.Current.Session["lv_role"] = role;
        HttpContext.Current.Session.Timeout = 30;
        return new { ok = true, role = role };
    }

    [WebMethod(EnableSession = true)]
    public static object AdminLogout()
    {
        AdminAudit.Write(WhoAmI(), "signed out", "");
        HttpContext.Current.Session.Remove("lv_admin");
        HttpContext.Current.Session.Remove("lv_role");
        return new { ok = true };
    }

    private static System.Collections.Generic.List<string> ToList(string[] a)
    {
        return a == null ? new System.Collections.Generic.List<string>() : new System.Collections.Generic.List<string>(a);
    }

    private static object SettingsDto(UiSettings s)
    {
        return new
        {
            appStyle = s.AppStyle, adminStyle = s.AdminStyle, superStyle = s.SuperAdminStyle, role = Role(),
            allowUserStyles = s.AllowUserStyles, userStyles = s.UserStyles,
            defaultRange = s.DefaultRange, defaultZone = s.DefaultZone, defaultMode = s.DefaultMode,
            hideBackground = new LogService().HideBackgroundByDefault, adminConfigured = true
        };
    }

    [WebMethod(EnableSession = true)]
    public static object AdminState()
    {
        if (!IsSuper()) return new { ok = false, error = NeedSuper };
        var svc = new LogService();
        return new
        {
            ok = true,
            settings = SettingsDto(UiSettings.Load()),
            rules = svc.GetRules(),
            folders = svc.GetFolderConfig(),
            limits = svc.GetLimits(),
            status = svc.GetAdminStatus(),
            audit = AdminAudit.Tail(15)
        };
    }

    [WebMethod(EnableSession = true)]
    public static object SaveUiSettings(string appStyle, bool allowUserStyles, string[] userStyles, bool useWebConfigRules,
                                        string[] backgroundPages, string[] backgroundModules, string[] alwaysShow,
                                        bool hideBackground, string defaultRange, string defaultZone, string defaultMode,
                                        bool useWebConfigFolders, string[] logFolders, string log4netFolder,
                                        bool useWebConfigLimits, int maxFiles, int maxSearchFiles,
                                        string adminStyle, string superStyle)
    {
        if (!IsSuper()) return new { ok = false, error = NeedSuper };
        try
        {
            var s = UiSettings.Sanitize(new UiSettings
            {
                AppStyle = appStyle,
                AdminStyle = adminStyle,
                SuperAdminStyle = superStyle,
                AllowUserStyles = allowUserStyles,
                UserStyles = ToList(userStyles),
                BackgroundPages = useWebConfigRules ? null : ToList(backgroundPages),
                BackgroundModules = useWebConfigRules ? null : ToList(backgroundModules),
                AlwaysShowMessages = useWebConfigRules ? null : ToList(alwaysShow),
                HideBackgroundByDefault = useWebConfigRules ? (bool?)null : hideBackground,
                DefaultRange = defaultRange,
                DefaultZone = defaultZone,
                DefaultMode = defaultMode,
                LogFolders = useWebConfigFolders ? null : ToList(logFolders),
                Log4NetFolder = useWebConfigFolders ? null : log4netFolder,
                MaxFiles = useWebConfigLimits ? (int?)null : maxFiles,
                MaxSearchFiles = useWebConfigLimits ? (int?)null : maxSearchFiles
            });
            var cur = UiSettings.Load();   // the Suggestions tab saves its own settings; keep them
            s.SuggestionsEnabled = cur.SuggestionsEnabled; s.SuggestionsVisible = cur.SuggestionsVisible;
            s.SuggestionMaxChars = cur.SuggestionMaxChars; s.SuggestionsPerHour = cur.SuggestionsPerHour;
            s.SuggestionsNeedSignIn = cur.SuggestionsNeedSignIn; s.UserSignUpOpen = cur.UserSignUpOpen; s.UserPasswordMinLength = cur.UserPasswordMinLength;
            UiSettings.Save(s);
            LogService.ClearCaches();      // folders may have changed: read the files again
            AdminAudit.Write(WhoAmI(), "saved settings",
                "style=" + s.AppStyle + "; adminStyle=" + (s.AdminStyle.Length > 0 ? s.AdminStyle : "same") + "; superAdminStyle=" + (s.SuperAdminStyle.Length > 0 ? s.SuperAdminStyle : "same") + "; usersMayPick=" + s.AllowUserStyles + " [" + string.Join(",", s.UserStyles.ToArray()) + "]; " +
                (useWebConfigRules ? "background rules=web.config" : "background rules saved (" + (s.BackgroundPages ?? new System.Collections.Generic.List<string>()).Count + " pages, " +
                    (s.BackgroundModules ?? new System.Collections.Generic.List<string>()).Count + " modules, " + (s.AlwaysShowMessages ?? new System.Collections.Generic.List<string>()).Count + " always-show)") +
                "; range=" + s.DefaultRange + "; zone=" + s.DefaultZone + "; mode=" + s.DefaultMode +
                "; folders=" + (s.LogFolders == null ? "web.config" : string.Join(" ; ", s.LogFolders.ToArray())) + "; log4net=" + (s.Log4NetFolder ?? "web.config") +
                "; filesPerView=" + (s.MaxFiles.HasValue ? s.MaxFiles.Value.ToString() : "web.config") + "; filesPerSearch=" + (s.MaxSearchFiles.HasValue ? s.MaxSearchFiles.Value.ToString() : "web.config"));
            // tell the admin straight away if a saved folder cannot be reached
            var test = LogService.TestFolders(s.LogFolders == null ? ConfigList() : s.LogFolders.ToArray(), null);
            return new { ok = true, settings = SettingsDto(s), folderCheck = test };
        }
        catch (Exception ex)
        {
            DebugLogger.Error("SaveUiSettings failed", ex);
            return new { ok = false, error = "Could not save: " + ex.Message + " (the site needs write access to the App_Data folder)." };
        }
    }

    // ===================== Suggestions =====================
    // Anyone may read and send; admins also see who sent each one (address, computer name, Windows user, browser),
    // set a status, reply, and hide; only the super admin deletes and changes the limits.

    // the signed-in user account (Suggestions), if any; an account switched off or deleted meanwhile counts as signed out
    private static UserAccount CurrentUser()
    {
        var session = HttpContext.Current.Session;
        string id = session == null ? null : session["lv_user"] as string;
        var u = UserStore.Find(id);
        if (u == null || u.Disabled) { if (id != null) session.Remove("lv_user"); return null; }
        return u;
    }
    private static string Ip() { return SuggestionStore.ClientIp(HttpContext.Current.Request, SuggestionConfig.Current()); }

    [WebMethod(EnableSession = true)]
    public static object GetSuggestions()
    {
        try
        {
            var cfg = SuggestionConfig.Current();
            if (!cfg.Enabled && !IsAdmin()) return new { ok = false, error = "Suggestions are switched off." };
            return SuggestionStore.List(Ip(), CurrentUser(), IsAdmin());
        }
        catch (Exception ex) { DebugLogger.Error("GetSuggestions failed", ex); return new { ok = false, error = "Could not read the suggestions." }; }
    }

    [WebMethod(EnableSession = true)]
    public static object AddSuggestion(string category, string title, string text, string name, string device)
    {
        try { return SuggestionStore.Add(HttpContext.Current, category, title, text, name, device, CurrentUser(), IsAdmin() ? WhoAmI() : null); }
        catch (Exception ex) { DebugLogger.Error("AddSuggestion failed", ex); return new { ok = false, error = "Could not save the suggestion." }; }
    }

    [WebMethod(EnableSession = true)]
    public static object VoteSuggestion(string id)
    {
        try { return SuggestionStore.Vote(HttpContext.Current, id, CurrentUser()); }
        catch (Exception ex) { DebugLogger.Error("VoteSuggestion failed", ex); return new { ok = false, error = "Could not save the vote." }; }
    }

    [WebMethod(EnableSession = true)]
    public static object AdminUpdateSuggestion(string id, string status, string reply, bool hidden)
    {
        if (!IsAdmin()) return new { ok = false, error = "Sign in as admin first." };
        string change;
        var r = SuggestionStore.Update(id, status, reply, hidden, WhoAmI(), out change);
        if (change.Length > 0) AdminAudit.Write(WhoAmI(), "updated a suggestion", change);
        return r;
    }

    [WebMethod(EnableSession = true)]
    public static object AdminDeleteSuggestion(string id)
    {
        if (!IsSuper()) return new { ok = false, error = NeedSuper };
        string title;
        var r = SuggestionStore.Delete(id, out title);
        if (title.Length > 0) AdminAudit.Write(WhoAmI(), "deleted a suggestion", title);
        return r;
    }

    [WebMethod(EnableSession = true)]
    public static object SaveSuggestionSettings(bool enabled, bool visibleToUsers, int maxChars, int perHour, bool needSignIn, bool signUpOpen, int passwordMin)
    {
        if (!IsSuper()) return new { ok = false, error = NeedSuper };
        try
        {
            var cur = UiSettings.Load();
            var s = UiSettings.Sanitize(cur);      // a copy of the current settings
            s.SuggestionsEnabled = enabled; s.SuggestionsVisible = visibleToUsers;
            s.SuggestionMaxChars = maxChars; s.SuggestionsPerHour = perHour;
            s.SuggestionsNeedSignIn = needSignIn; s.UserSignUpOpen = signUpOpen;
            s.UserPasswordMinLength = Math.Max(2, Math.Min(64, passwordMin));
            UiSettings.Save(s);
            var cfg = SuggestionConfig.Current();
            AdminAudit.Write(WhoAmI(), "saved suggestion settings", "enabled=" + cfg.Enabled + "; everyoneSeesAll=" + cfg.VisibleToUsers + "; maxChars=" + cfg.MaxChars + "; perHour=" + cfg.PerHour
                + "; needSignIn=" + cfg.NeedSignIn + "; signUpOpen=" + UserStore.SignUpOpen + "; passwordMin=" + UserStore.MinPassword);
            return new { ok = true, config = new { enabled = cfg.Enabled, visibleToUsers = cfg.VisibleToUsers, maxChars = cfg.MaxChars, perHour = cfg.PerHour, needSignIn = cfg.NeedSignIn, signUpOpen = UserStore.SignUpOpen, passwordMin = UserStore.MinPassword } };
        }
        catch (Exception ex)
        {
            DebugLogger.Error("SaveSuggestionSettings failed", ex);
            return new { ok = false, error = "Could not save: " + ex.Message + " (the site needs write access to the App_Data folder)." };
        }
    }

    // ===================== User accounts (Suggestions) =====================
    // Open sign-up; passwords are only kept as slow salted hashes, the file is encrypted with the server's DPAPI key.
    // Each sign-up and sign-in also records the address, the computer name from DNS and the browser's device id.

    private static string Host(string ip) { return SuggestionStore.HostName(ip, SuggestionConfig.Current()); }

    [WebMethod(EnableSession = true)]
    public static object UserSignUp(string username, string name, string password, string device)
    {
        try
        {
            string ip = Ip(); UserAccount u;
            var r = UserStore.SignUp(username, name, password, ip, Host(ip), UserStore.CleanDevice(device), out u);
            if (u != null) { HttpContext.Current.Session["lv_user"] = u.Id; AdminAudit.Write(u.Username, "created a user account", "name: " + u.Name); }
            return r;
        }
        catch (Exception ex) { DebugLogger.Error("UserSignUp failed", ex); return new { ok = false, error = "Could not create the account." }; }
    }

    [WebMethod(EnableSession = true)]
    public static object UserSignIn(string username, string password, string device)
    {
        try
        {
            string ip = Ip(); UserAccount u;
            var r = UserStore.SignIn(username, password, ip, Host(ip), UserStore.CleanDevice(device), out u);
            if (u != null) HttpContext.Current.Session["lv_user"] = u.Id;
            return r;
        }
        catch (Exception ex) { DebugLogger.Error("UserSignIn failed", ex); return new { ok = false, error = "Could not sign in." }; }
    }

    [WebMethod(EnableSession = true)]
    public static object UserSignOut()
    {
        HttpContext.Current.Session.Remove("lv_user");
        return new { ok = true };
    }

    [WebMethod(EnableSession = true)]
    public static object UserChangePassword(string oldPassword, string newPassword)
    {
        var u = CurrentUser();
        if (u == null) return new { ok = false, error = "Sign in first." };
        try { return UserStore.ChangePassword(u.Id, oldPassword, newPassword, Ip()); }
        catch (Exception ex) { DebugLogger.Error("UserChangePassword failed", ex); return new { ok = false, error = "Could not change the password." }; }
    }

    [WebMethod(EnableSession = true)]
    public static object UserResetWithCode(string username, string code, string newPassword)
    {
        try { return UserStore.ResetWithCode(username, code, newPassword, Ip()); }
        catch (Exception ex) { DebugLogger.Error("UserResetWithCode failed", ex); return new { ok = false, error = "Could not reset the password." }; }
    }

    [WebMethod(EnableSession = true)]
    public static object UserDeleteSelf(string password)
    {
        var u = CurrentUser();
        if (u == null) return new { ok = false, error = "Sign in first." };
        string who;
        var r = UserStore.DeleteSelf(u.Id, password, Ip(), out who);
        if (who.Length > 0) { HttpContext.Current.Session.Remove("lv_user"); AdminAudit.Write(who, "deleted their own user account", ""); }
        return r;
    }

    [WebMethod(EnableSession = true)]
    public static object AdminListUsers()
    {
        if (!IsSuper()) return new { ok = false, error = NeedSuper };
        return new { ok = true, users = UserStore.AdminList() };
    }

    [WebMethod(EnableSession = true)]
    public static object AdminUserAction(string id, string action)
    {
        if (!IsSuper()) return new { ok = false, error = NeedSuper };
        string change;
        var r = UserStore.AdminAction(id, action, out change);
        if (change.Length > 0) AdminAudit.Write(WhoAmI(), change, "");
        return r;
    }

    [WebMethod(EnableSession = true)]
    public static object GetDashboard(string from, string to, string module)
    {
        if (!IsAdmin()) return new { error = "Sign in as admin first." };
        try
        {
            return new LogService().GetDashboard(ParseBound(from, false), ParseBound(to, true), module);
        }
        catch (Exception ex)
        {
            DebugLogger.Error("GetDashboard failed", ex);
            return new { error = ex.Message };
        }
    }

    private static string[] ConfigList()
    {
        return (System.Configuration.ConfigurationManager.AppSettings["LogDirectoryPath"] ?? "").Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
    }

    [WebMethod(EnableSession = true)]
    public static object AdminTestFolders(string[] folders, string log4netFolder)
    {
        if (!IsSuper()) return new { ok = false, error = NeedSuper };
        try { return new { ok = true, result = LogService.TestFolders(folders, log4netFolder) }; }
        catch (Exception ex) { return new { ok = false, error = ex.Message }; }
    }

    [WebMethod(EnableSession = true)]
    public static object GetServiceHealth(string from, string to)
    {
        if (!IsAdmin()) return new { error = "Sign in as admin first." };
        try { return new LogService().GetServiceHealth(ParseBound(from, false), ParseBound(to, true)); }
        catch (Exception ex)
        {
            DebugLogger.Error("GetServiceHealth failed", ex);
            return new { error = ex.Message };
        }
    }

    [WebMethod(EnableSession = true)]
    public static object AdminClearCache()
    {
        if (!IsSuper()) return new { ok = false, error = NeedSuper };
        LogService.ClearCaches();
        AdminAudit.Write(WhoAmI(), "cleared cache", "logs will be read again");
        return new { ok = true };
    }

    private static IpasFilter BuildFilter(string search, string server, string errorType, string[] modules,
                                          string caller, string customMessage, bool asyncOnly, bool showBackground)
    {
        return new IpasFilter
        {
            Search = search, Server = server, ErrorType = errorType, Modules = modules,
            Caller = caller, CustomMessage = customMessage, AsyncOnly = asyncOnly, ShowBackground = showBackground
        };
    }

    [WebMethod]
    public static object GetLogs(string from, string to, string search, string server, string errorType, string[] modules,
                                 string caller, string customMessage, bool asyncOnly, bool showBackground)
    {
        var requestId = Guid.NewGuid().ToString("N");
        DebugLogger.Info("GetLogs requestId=" + requestId + " from=" + (from ?? "") + " to=" + (to ?? "") + " search=" + (search ?? ""));

        DateTime fromDate = ParseBound(from, false);
        DateTime toDate = ParseBound(to, true);

        try
        {
            return new LogService().GetIpasGroups(fromDate, toDate,
                BuildFilter(search, server, errorType, modules, caller, customMessage, asyncOnly, showBackground));
        }
        catch (Exception ex)
        {
            DebugLogger.Error("GetLogs FAILED requestId=" + requestId, ex);
            return new { error = ex.Message };
        }
    }

    [WebMethod]
    public static object GetLog4NetLogs(string from, string to, string search, string levels, string logger, string channel)
    {
        var requestId = Guid.NewGuid().ToString("N");
        DebugLogger.Info("GetLog4NetLogs requestId=" + requestId);

        DateTime fromDate = ParseBound(from, false);
        DateTime toDate = ParseBound(to, true);

        var service = new LogService();

        try
        {
            return service.GetLog4NetLogs(fromDate, toDate, search, levels, logger, channel);
        }
        catch (Exception ex)
        {
            DebugLogger.Error("GetLog4NetLogs FAILED requestId=" + requestId, ex);
            return new { error = ex.Message };
        }
    }

    [WebMethod]
    public static object GetLogDetails(string from, string to, string search, string groupId, string server, string errorType,
                                       string[] modules, string caller, string customMessage, bool asyncOnly, bool showBackground, int page, int pageSize)
    {
        var requestId = Guid.NewGuid().ToString("N");
        DebugLogger.Info("GetLogDetails requestId=" + requestId);

        DateTime fromDate = ParseBound(from, false);
        DateTime toDate = ParseBound(to, true);

        try
        {
            return new LogService().GetIpasDetails(fromDate, toDate,
                BuildFilter(search, server, errorType, modules, caller, customMessage, asyncOnly, showBackground), groupId, page, pageSize);
        }
        catch (Exception ex)
        {
            DebugLogger.Error("GetLogDetails FAILED requestId=" + requestId, ex);
            return new { error = ex.Message };
        }
    }
}
