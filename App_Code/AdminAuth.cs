using System;
using System.Collections.Generic;
using System.Configuration;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

/// <summary>
/// Two sign-ins, both kept in web.config:
///   SuperAdminUsername / SuperAdminPassword : dashboard AND settings
///   AdminUsername      / AdminPassword      : dashboard only (for example a plant admin)
/// A password is plain text, or "sha256:&lt;hex&gt;". An account with an empty name or password is switched off.
/// Usernames ignore capital letters; passwords do not. Five wrong attempts from one address lock it out for five minutes.
/// </summary>
public static class AdminAuth
{
    public const string RoleSuper = "superadmin";
    public const string RoleAdmin = "admin";

    private sealed class Attempt { public int Fails; public DateTime LockedUntil; }

    private static readonly object Gate = new object();
    private static readonly Dictionary<string, Attempt> Attempts = new Dictionary<string, Attempt>();

    private static string Cfg(string key) { return (ConfigurationManager.AppSettings[key] ?? "").Trim(); }

    private static bool SuperConfigured { get { return Cfg("SuperAdminUsername").Length > 0 && Cfg("SuperAdminPassword").Length > 0; } }
    private static bool AdminConfigured { get { return Cfg("AdminUsername").Length > 0 && Cfg("AdminPassword").Length > 0; } }

    public static bool IsConfigured { get { return SuperConfigured || AdminConfigured; } }

    public static bool Validate(string ip, string user, string password, out string error, out string role)
    {
        error = null;
        role = null;
        if (!IsConfigured)
        {
            error = "Admin sign-in is not set up. Add the sign-in details to web.config.";
            return false;
        }

        ip = ip ?? "";
        lock (Gate)
        {
            Attempt a;
            if (!Attempts.TryGetValue(ip, out a)) { a = new Attempt(); Attempts[ip] = a; }
            if (a.LockedUntil > DateTime.UtcNow)
            {
                int mins = (int)Math.Ceiling((a.LockedUntil - DateTime.UtcNow).TotalMinutes);
                error = "Too many wrong attempts. Try again in " + mins + " minute(s).";
                return false;
            }
            // the attempt is counted now, before the check, so many guesses sent at once cannot all get past the lockout
            a.Fails++;
            if (a.Fails >= 5) { a.LockedUntil = DateTime.UtcNow.AddMinutes(5); a.Fails = 0; }
        }

        // every check always runs, so timing does not reveal which account or which part was wrong
        bool superOk = SuperConfigured & NameMatches(user, Cfg("SuperAdminUsername")) & PasswordMatches(password ?? "", Cfg("SuperAdminPassword"));
        bool adminOk = AdminConfigured & NameMatches(user, Cfg("AdminUsername")) & PasswordMatches(password ?? "", Cfg("AdminPassword"));
        if (superOk || adminOk)
        {
            role = superOk ? RoleSuper : RoleAdmin;
            lock (Gate) { Attempts.Remove(ip); }
            return true;
        }

        Thread.Sleep(500);
        error = "Wrong username or password.";
        return false;
    }

    private static bool NameMatches(string typed, string configured)
    {
        return ConstantEquals(Encoding.UTF8.GetBytes((typed ?? "").Trim().ToLowerInvariant()), Encoding.UTF8.GetBytes(configured.ToLowerInvariant()));
    }

    private static bool PasswordMatches(string password, string configured)
    {
        if (configured.StartsWith("sha256:", StringComparison.OrdinalIgnoreCase))
        {
            using (var sha = SHA256.Create())
            {
                byte[] h = sha.ComputeHash(Encoding.UTF8.GetBytes(password));
                var sb = new StringBuilder(h.Length * 2);
                foreach (byte b in h) sb.Append(b.ToString("x2"));
                return ConstantEquals(Encoding.ASCII.GetBytes(sb.ToString()),
                                      Encoding.ASCII.GetBytes(configured.Substring(7).Trim().ToLowerInvariant()));
            }
        }
        return ConstantEquals(Encoding.UTF8.GetBytes(password), Encoding.UTF8.GetBytes(configured));
    }

    private static bool ConstantEquals(byte[] a, byte[] b)
    {
        int diff = a.Length ^ b.Length;
        for (int i = 0; i < a.Length && i < b.Length; i++) diff |= a[i] ^ b[i];
        return diff == 0;
    }
}
