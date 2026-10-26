using System;
using System.Collections.Generic;
using System.Configuration;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Script.Serialization;

/// <summary>A user account for the Suggestions tab. The password itself is never stored, only a salted slow hash.</summary>
public class UserAccount
{
    public string Id { get; set; }
    public string Username { get; set; }          // lower case, unique
    public string Name { get; set; }              // full name as typed at sign-up
    public string PasswordHash { get; set; }      // base64 PBKDF2 (HMAC-SHA1, 20 bytes = one SHA-1 block, so no wasted second pass), Iterations rounds
    public string Salt { get; set; }              // base64, 16 random bytes per user
    public int Iterations { get; set; }
    public DateTime CreatedUtc { get; set; }
    public string CreatedIp { get; set; }
    public string CreatedHost { get; set; }
    public string CreatedDevice { get; set; }
    public DateTime? LastSignInUtc { get; set; }
    public string LastIp { get; set; }
    public string LastHost { get; set; }
    public string LastDevice { get; set; }
    public bool Disabled { get; set; }
    public string ResetHash { get; set; }         // one-time reset code from an admin (hashed), valid 24 h
    public DateTime? ResetExpiryUtc { get; set; }
}

/// <summary>
/// Accounts live in App_Data/users.dat. The whole file is encrypted with Windows DPAPI (machine key + a fixed extra
/// secret), so a copy is unreadable on any other computer, and IIS never serves App_Data. Passwords inside are hashed
/// (PBKDF2, 100,000 rounds, random salt), so even the decrypted file does not reveal them. Restrict the folder further
/// with NTFS permissions (Administrators + the site's app pool account only).
/// Note: because the key belongs to this server, moving the site to another server means people sign up again.
/// </summary>
public static class UserStore
{
    public const int MaxPassword = 128, MinName = 2, MaxName = 60;

    /// <summary>Shortest password allowed: Settings, else web.config UserPasswordMinLength, else 6. Always 2 to 64.
    /// There is deliberately no short maximum: a longer password (or a phrase) is only ever safer.</summary>
    public static int MinPassword
    {
        get
        {
            int n;
            var ui = UiSettings.Load();
            if (ui.UserPasswordMinLength.HasValue) n = ui.UserPasswordMinLength.Value;
            else if (!int.TryParse(ConfigurationManager.AppSettings["UserPasswordMinLength"], out n)) n = 6;
            return Math.Max(2, Math.Min(64, n));
        }
    }
    private const int Rounds = 100000;
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("LogExplorer.users.v1");
    private static readonly Regex UserRx = new Regex(@"^[a-z0-9][a-z0-9._-]{2,31}$", RegexOptions.Compiled);
    private static readonly Regex DeviceRx = new Regex(@"^[a-f0-9]{16,32}$", RegexOptions.Compiled);
    private const string CodeChars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";     // no 0/O, 1/I

    private static readonly object Gate = new object();
    private static List<UserAccount> _users;
    private static DateTime _stamp = DateTime.MinValue;

    private sealed class Attempt { public int Fails; public DateTime LockedUntil; }
    private static readonly Dictionary<string, Attempt> Attempts = new Dictionary<string, Attempt>(StringComparer.OrdinalIgnoreCase);

    private static string PathOnDisk { get { return HttpContext.Current.Server.MapPath("~/App_Data/users.dat"); } }
    private static DateTime Stamp(string p) { return File.Exists(p) ? File.GetLastWriteTimeUtc(p) : DateTime.MinValue; }

    public static bool SignUpOpen
    {
        get
        {
            var ui = UiSettings.Load();
            if (ui.UserSignUpOpen.HasValue) return ui.UserSignUpOpen.Value;
            string v = (ConfigurationManager.AppSettings["UserSignUpOpen"] ?? "").Trim().ToLowerInvariant();
            return v.Length == 0 || v == "true" || v == "1";
        }
    }
    public static int SignUpsPerDay
    {
        get { int n; return int.TryParse(ConfigurationManager.AppSettings["UserSignUpsPerDayPerComputer"], out n) ? Math.Max(1, Math.Min(50, n)) : 3; }
    }

    // ---- file -----------------------------------------------------------------------------------

    private static List<UserAccount> Users()
    {
        string p = PathOnDisk;
        if (_users != null && Stamp(p) == _stamp) return _users;
        try
        {
            if (!File.Exists(p)) _users = new List<UserAccount>();
            else
            {
                byte[] plain = ProtectedData.Unprotect(File.ReadAllBytes(p), Entropy, DataProtectionScope.LocalMachine);
                _users = new JavaScriptSerializer { MaxJsonLength = int.MaxValue }.Deserialize<List<UserAccount>>(Encoding.UTF8.GetString(plain)) ?? new List<UserAccount>();
            }
        }
        catch (Exception ex)
        {
            // never overwrite a file we could not read (e.g. copied from another server): keep it aside
            DebugLogger.Error("users.dat could not be read; it is kept as users.dat.unreadable-*", ex);
            try { File.Move(p, p + ".unreadable-" + DateTime.Now.ToString("yyyyMMddHHmmss", CultureInfo.InvariantCulture)); } catch { }
            _users = new List<UserAccount>();
        }
        _stamp = Stamp(p);
        return _users;
    }

    private static void Persist()
    {
        string p = PathOnDisk;
        Directory.CreateDirectory(Path.GetDirectoryName(p));
        byte[] plain = Encoding.UTF8.GetBytes(new JavaScriptSerializer { MaxJsonLength = int.MaxValue }.Serialize(_users));
        byte[] sealedBytes = ProtectedData.Protect(plain, Entropy, DataProtectionScope.LocalMachine);
        string tmp = p + ".tmp";
        File.WriteAllBytes(tmp, sealedBytes);
        if (File.Exists(p)) File.Replace(tmp, p, null); else File.Move(tmp, p);
        _stamp = Stamp(p);
    }

    // ---- hashing ----------------------------------------------------------------------------------

    private static readonly byte[] DummySalt = new byte[16];

    private static byte[] Random(int n) { var b = new byte[n]; using (var rng = new RNGCryptoServiceProvider()) rng.GetBytes(b); return b; }

    private static string Hash(string secret, byte[] salt, int rounds)
    {
        using (var kdf = new Rfc2898DeriveBytes(secret, salt, rounds)) return Convert.ToBase64String(kdf.GetBytes(20));
    }

    private static bool SameBytes(string a, string b)
    {
        byte[] x = Encoding.ASCII.GetBytes(a ?? ""), y = Encoding.ASCII.GetBytes(b ?? "");
        int diff = x.Length ^ y.Length;
        for (int i = 0; i < x.Length && i < y.Length; i++) diff |= x[i] ^ y[i];
        return diff == 0;
    }

    private static bool PasswordOk(UserAccount u, string password)
    {
        return SameBytes(Hash(password ?? "", Convert.FromBase64String(u.Salt), u.Iterations), u.PasswordHash);
    }

    private static void SetPassword(UserAccount u, string password)
    {
        byte[] salt = Random(16);
        u.Salt = Convert.ToBase64String(salt); u.Iterations = Rounds; u.PasswordHash = Hash(password, salt, Rounds);
        u.ResetHash = null; u.ResetExpiryUtc = null;
    }

    // ---- checks -------------------------------------------------------------------------------

    public static string CleanUsername(string s) { return (s ?? "").Trim().ToLowerInvariant(); }
    public static string CleanDevice(string s) { s = (s ?? "").Trim().ToLowerInvariant(); return DeviceRx.IsMatch(s) ? s : ""; }

    private static string PasswordProblem(string pw, string username)
    {
        pw = pw ?? "";
        int min = MinPassword;
        if (pw.Length < min) return "The password needs at least " + min + " characters.";
        if (pw.Length > MaxPassword) return "The password is too long.";
        if (pw.Trim().Length == 0) return "The password cannot be only spaces.";
        if (username.Length > 0 && pw.ToLowerInvariant().Contains(username)) return "The password must not contain your username.";
        if (pw.Distinct().Count() < Math.Min(4, min)) return "Choose a less simple password (not the same character again and again).";
        return null;
    }

    // a slow answer and a 5-minute lock after 5 wrong tries, per address + username
    private static string Locked(string key)
    {
        lock (Attempts)
        {
            Attempt a;
            if (!Attempts.TryGetValue(key, out a)) { a = new Attempt(); Attempts[key] = a; }
            if (a.LockedUntil > DateTime.UtcNow)
                return "Too many wrong attempts. Try again in " + (int)Math.Ceiling((a.LockedUntil - DateTime.UtcNow).TotalMinutes) + " minute(s).";
            a.Fails++;                                       // counted before the check, so parallel guesses cannot slip through
            if (a.Fails >= 5) { a.LockedUntil = DateTime.UtcNow.AddMinutes(5); a.Fails = 0; }
            if (Attempts.Count > 5000) Attempts.Clear();
            return null;
        }
    }
    private static void Passed(string key) { lock (Attempts) { Attempts.Remove(key); } }

    // ---- what the page sees -------------------------------------------------------------------

    public static object Public(UserAccount u)
    {
        return u == null ? null : new { id = u.Id, username = u.Username, name = u.Name };
    }

    public static UserAccount Find(string id)
    {
        if (string.IsNullOrEmpty(id)) return null;
        lock (Gate) { return Users().FirstOrDefault(x => x.Id == id); }
    }

    // ---- actions -----------------------------------------------------------------------------------

    public static object SignUp(string username, string name, string password, string ip, string host, string device, out UserAccount created)
    {
        created = null;
        if (!SignUpOpen) return new { ok = false, error = "New accounts are switched off. Ask an admin." };
        username = CleanUsername(username);
        name = SuggestionStore.Clean(name, false);
        if (!UserRx.IsMatch(username)) return new { ok = false, error = "The username needs 3 to 32 letters or digits (dots, dashes and underscores are fine, no spaces)." };
        if (name.Length < MinName || name.Length > MaxName) return new { ok = false, error = "Please give your name (" + MinName + " to " + MaxName + " characters)." };
        string bad = PasswordProblem(password, username);
        if (bad != null) return new { ok = false, error = bad };

        lock (Gate)
        {
            var all = Users();
            if (all.Any(x => x.Username == username)) return new { ok = false, error = "That username is taken. Choose another." };
            int today = all.Count(x => x.CreatedIp == ip && x.CreatedUtc > DateTime.UtcNow.AddDays(-1));
            if (today >= SignUpsPerDay) return new { ok = false, error = "This computer has created " + today + " accounts today. Try again tomorrow or ask an admin." };
            var u = new UserAccount
            {
                Id = Guid.NewGuid().ToString("N").Substring(0, 12), Username = username, Name = name, CreatedUtc = DateTime.UtcNow,
                CreatedIp = ip, CreatedHost = host, CreatedDevice = device, LastSignInUtc = DateTime.UtcNow, LastIp = ip, LastHost = host, LastDevice = device
            };
            SetPassword(u, password);
            all.Add(u);
            try { Persist(); }
            catch (Exception ex) { all.Remove(u); DebugLogger.Error("Saving a new account failed", ex); return new { ok = false, error = "Could not save the account (the site needs write access to App_Data)." }; }
            created = u;
            return new { ok = true, user = Public(u) };
        }
    }

    public static object SignIn(string username, string password, string ip, string host, string device, out UserAccount signedIn)
    {
        signedIn = null;
        username = CleanUsername(username);
        string key = ip + "|" + username;
        string locked = Locked(key);
        if (locked != null) return new { ok = false, error = locked };

        UserAccount u;
        lock (Gate) { u = Users().FirstOrDefault(x => x.Username == username); }
        // the hash is slow on purpose and runs for unknown names too, so the answer time does not reveal which names exist
        bool ok = u != null ? PasswordOk(u, password) : (Hash(password ?? "", DummySalt, Rounds).Length < 0);
        if (!ok) { System.Threading.Thread.Sleep(300); return new { ok = false, error = "Wrong username or password." }; }
        if (u.Disabled) return new { ok = false, error = "This account is switched off. Ask an admin." };
        Passed(key);
        lock (Gate)
        {
            u.LastSignInUtc = DateTime.UtcNow; u.LastIp = ip; u.LastHost = host; if (device.Length > 0) u.LastDevice = device;
            try { Persist(); } catch (Exception ex) { DebugLogger.Error("Saving sign-in time failed", ex); }
        }
        signedIn = u;
        return new { ok = true, user = Public(u) };
    }

    public static object ChangePassword(string id, string oldPassword, string newPassword, string ip)
    {
        var u = Find(id);
        if (u == null) return new { ok = false, error = "Sign in first." };
        string locked = Locked(ip + "|" + u.Username);
        if (locked != null) return new { ok = false, error = locked };
        if (!PasswordOk(u, oldPassword)) return new { ok = false, error = "The current password is not right." };
        string bad = PasswordProblem(newPassword, u.Username);
        if (bad != null) return new { ok = false, error = bad };
        Passed(ip + "|" + u.Username);
        lock (Gate)
        {
            SetPassword(u, newPassword);
            try { Persist(); } catch (Exception ex) { DebugLogger.Error("Saving a password change failed", ex); return new { ok = false, error = "Could not save the new password." }; }
        }
        return new { ok = true };
    }

    /// <summary>With the one-time code an admin gave out: choose a new password.</summary>
    public static object ResetWithCode(string username, string code, string newPassword, string ip)
    {
        username = CleanUsername(username);
        string locked = Locked(ip + "|" + username);
        if (locked != null) return new { ok = false, error = locked };
        UserAccount u;
        lock (Gate) { u = Users().FirstOrDefault(x => x.Username == username); }
        string c = (code ?? "").Trim().ToUpperInvariant().Replace("-", "").Replace(" ", "");
        bool ok = u != null && !string.IsNullOrEmpty(u.ResetHash) && u.ResetExpiryUtc.HasValue && u.ResetExpiryUtc.Value > DateTime.UtcNow
                  && SameBytes(Hash(c, Convert.FromBase64String(u.Salt), 1000), u.ResetHash);
        if (!ok) { System.Threading.Thread.Sleep(300); return new { ok = false, error = "The username or the reset code is not right, or the code has expired." }; }
        string bad = PasswordProblem(newPassword, username);
        if (bad != null) return new { ok = false, error = bad };
        Passed(ip + "|" + username);
        lock (Gate)
        {
            SetPassword(u, newPassword);
            u.Disabled = false;
            try { Persist(); } catch (Exception ex) { DebugLogger.Error("Saving a reset password failed", ex); return new { ok = false, error = "Could not save the new password." }; }
        }
        return new { ok = true };
    }

    public static object DeleteSelf(string id, string password, string ip, out string who)
    {
        who = "";
        var u = Find(id);
        if (u == null) return new { ok = false, error = "Sign in first." };
        string locked = Locked(ip + "|" + u.Username);
        if (locked != null) return new { ok = false, error = locked };
        if (!PasswordOk(u, password)) return new { ok = false, error = "The password is not right." };
        Passed(ip + "|" + u.Username);
        lock (Gate)
        {
            Users().Remove(u);
            try { Persist(); } catch (Exception ex) { Users().Add(u); DebugLogger.Error("Deleting an account failed", ex); return new { ok = false, error = "Could not delete the account." }; }
        }
        who = u.Username + " (" + u.Name + ")";
        return new { ok = true };
    }

    // ---- admin ---------------------------------------------------------------------------------------

    private static string Local(DateTime? utc) { return utc.HasValue ? utc.Value.ToLocalTime().ToString("yyyy-MM-dd'T'HH:mm:ss", CultureInfo.InvariantCulture) : ""; }

    public static object AdminList()
    {
        lock (Gate)
        {
            return Users().OrderByDescending(u => u.CreatedUtc).Select(u => new
            {
                id = u.Id, username = u.Username, name = u.Name, disabled = u.Disabled,
                created = Local(u.CreatedUtc), createdIp = u.CreatedIp, createdHost = u.CreatedHost, createdDevice = u.CreatedDevice,
                lastSignIn = Local(u.LastSignInUtc), lastIp = u.LastIp, lastHost = u.LastHost, lastDevice = u.LastDevice,
                resetPending = u.ResetExpiryUtc.HasValue && u.ResetExpiryUtc.Value > DateTime.UtcNow
            }).ToList();
        }
    }

    /// <summary>disable | enable | reset (returns a one-time code, shown once) | delete</summary>
    public static object AdminAction(string id, string action, out string change)
    {
        change = "";
        lock (Gate)
        {
            var all = Users();
            var u = all.FirstOrDefault(x => x.Id == id);
            if (u == null) return new { ok = false, error = "That account is no longer there." };
            string code = null;
            switch ((action ?? "").ToLowerInvariant())
            {
                case "disable": u.Disabled = true; change = "switched off account " + u.Username; break;
                case "enable": u.Disabled = false; change = "switched on account " + u.Username; break;
                case "reset":
                    var b = Random(10); var sb = new StringBuilder();
                    for (int i = 0; i < 10; i++) sb.Append(CodeChars[b[i] % CodeChars.Length]);
                    code = sb.ToString();
                    u.ResetHash = Hash(code, Convert.FromBase64String(u.Salt), 1000);
                    u.ResetExpiryUtc = DateTime.UtcNow.AddHours(24);
                    change = "made a reset code for " + u.Username;
                    break;
                case "delete": all.Remove(u); change = "deleted account " + u.Username + " (" + u.Name + ")"; break;
                default: return new { ok = false, error = "Unknown action." };
            }
            try { Persist(); }
            catch (Exception ex) { DebugLogger.Error("Saving an account change failed", ex); change = ""; return new { ok = false, error = "Could not save the change." }; }
            return new { ok = true, code = code == null ? null : code.Substring(0, 5) + "-" + code.Substring(5) };
        }
    }

    public static void Reset() { lock (Gate) { _users = null; } }
}
