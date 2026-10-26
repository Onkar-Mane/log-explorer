using System;
using System.Configuration;
using System.IO;

public static class DebugLogger
{
    private static readonly bool _enabled =
        (ConfigurationManager.AppSettings["EnableDebugLog"] ?? "false").ToLower() == "true";

    private static readonly string _path =
        ConfigurationManager.AppSettings["DebugLogPath"];

    public static void Info(string message)
    {
        Write("INFO", message, null);
    }

    public static void Warn(string message)
    {
        Write("WARN", message, null);
    }

    public static void Error(string message, Exception ex)
    {
        Write("ERROR", message, ex);
    }

    // Backward compatible
    public static void Log(string message)
    {
        Info(message);
    }

    private static void Write(string level, string message, Exception ex)
    {
        if (!_enabled) return;
        if (string.IsNullOrWhiteSpace(_path)) return;

        try
        {
            var resolvedPath = Path.IsPathRooted(_path)
                ? _path
                : Path.Combine(AppDomain.CurrentDomain.BaseDirectory, _path);

            var dir = Path.GetDirectoryName(resolvedPath);
            if (!Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            var line = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") +
                       " | " + level +
                       " | " + message;

            if (ex != null)
                line += Environment.NewLine + ex;

            File.AppendAllText(resolvedPath, line + Environment.NewLine);
        }
        catch { }
    }
}
