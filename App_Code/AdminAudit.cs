using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Web;

/// <summary>
/// A plain-text record of admin sign-ins and changes (App_Data/admin-audit.log): who, from where, what.
/// Passwords are never written.
/// </summary>
public static class AdminAudit
{
    private static readonly object Gate = new object();
    private const int MaxBytes = 256 * 1024;

    private static string PathOnDisk
    {
        get { return HttpContext.Current.Server.MapPath("~/App_Data/admin-audit.log"); }
    }

    private static string Clean(string s, int max)
    {
        if (string.IsNullOrEmpty(s)) return "";
        var sb = new StringBuilder();
        foreach (char ch in s) sb.Append(char.IsControl(ch) ? ' ' : ch);
        string t = sb.ToString().Trim();
        return t.Length > max ? t.Substring(0, max) : t;
    }

    public static void Write(string who, string action, string detail)
    {
        try
        {
            string ip = HttpContext.Current != null && HttpContext.Current.Request != null ? HttpContext.Current.Request.UserHostAddress : "";
            string line = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss") + "Z\t" + Clean(ip, 45) + "\t" + Clean(who, 40) + "\t" + Clean(action, 40) + "\t" + Clean(detail, 300);
            lock (Gate)
            {
                string p = PathOnDisk;
                Directory.CreateDirectory(Path.GetDirectoryName(p));
                if (File.Exists(p) && new FileInfo(p).Length > MaxBytes)
                {
                    // keep the newest half so the file never grows without bound
                    var keep = File.ReadAllLines(p).Reverse().Take(500).Reverse().ToArray();
                    File.WriteAllLines(p, keep);
                }
                File.AppendAllText(p, line + "\r\n");
            }
        }
        catch (Exception ex)
        {
            DebugLogger.Error("AdminAudit.Write failed", ex);
        }
    }

    /// <summary>The newest entries, newest first.</summary>
    public static List<string> Tail(int count)
    {
        try
        {
            lock (Gate)
            {
                string p = PathOnDisk;
                if (!File.Exists(p)) return new List<string>();
                return File.ReadAllLines(p).Reverse().Take(count).ToList();
            }
        }
        catch
        {
            return new List<string>();
        }
    }
}
