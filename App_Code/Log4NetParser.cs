using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

/// <summary>
/// Parses log4net text output produced by a PatternLayout of the form:
///     %date [%thread] %level %logger - %message%newline
/// e.g.  2025-04-14 16:11:24,954 [7] INFO SignalRLogger - Creating internal connection
///
/// Lines that do not match the header pattern are treated as continuation lines
/// (multi-line messages / exception stack traces) and appended to the current entry.
/// </summary>
public class Log4NetParser : ILogParser
{
    private static readonly Regex LineRegex = new Regex(
        @"^(?<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2},\d{3}) \[(?<thread>[^\]]*)\] (?<level>[A-Za-z]+) (?<logger>\S+) - (?<msg>.*)$",
        RegexOptions.Compiled);

    private static readonly Regex RollingSuffixRegex = new Regex(
        @"^(?<base>.+?\.log)(\.\d+)?$", RegexOptions.IgnoreCase | RegexOptions.Compiled);

    public List<LogEntry> ParseLogs(string filePath)
    {
        var logs = new List<LogEntry>();

        try
        {
            var fi = new FileInfo(filePath);
            if (fi.Length > 20 * 1024 * 1024)
            {
                DebugLogger.Warn("Skipping large log4net file: " + filePath + " (" + (fi.Length / 1024 / 1024) + " MB)");
                return logs;
            }

            string channel = GetChannelName(filePath);
            LogEntry current = null;
            var notes = new StringBuilder();

            // FileShare.ReadWrite: log4net keeps the file it is writing open, and a plain read would be refused
            using (var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (var reader = new StreamReader(fs, true))
            {
            string rawLine;
            while ((rawLine = reader.ReadLine()) != null)
            {

                // Strip NUL / BOM artifacts only — never touch real whitespace.
                var line = (rawLine ?? string.Empty).Replace(((char)0).ToString(), "").Replace(((char)0xFEFF).ToString(), "");
                var m = LineRegex.Match(line);

                if (m.Success)
                {
                    if (current != null)
                    {
                        current.Notes = notes.ToString().Trim();
                        logs.Add(current);
                    }
                    notes.Clear();

                    DateTime ts;
                    if (!DateTime.TryParseExact(m.Groups["ts"].Value, "yyyy-MM-dd HH:mm:ss,fff",
                            CultureInfo.InvariantCulture, DateTimeStyles.None, out ts))
                    {
                        ts = DateTime.Now;
                    }

                    string level = m.Groups["level"].Value.ToUpperInvariant();
                    string logger = m.Groups["logger"].Value;

                    current = new LogEntry
                    {
                        Timestamp = ts,
                        Thread = m.Groups["thread"].Value,
                        Level = level,
                        Logger = logger,
                        Message = m.Groups["msg"].Value,
                        Channel = channel,
                        ServerName = "",
                        // log4net has no SiteID field; your code embeds it in the
                        // message text (e.g. "... | SiteID=5"), so pull it from there.
                        SiteID = LogFieldHelper.ExtractSiteId(m.Groups["msg"].Value),
                        // Mirror into legacy fields so shared formatting code keeps working.
                        ErrorType = level,
                        ErrorModule = logger,
                        ErrorMethod = ""
                    };
                }
                else
                {
                    if (string.IsNullOrWhiteSpace(line))
                        continue;

                    // Continuation of the previous entry (exception / multi-line message).
                    if (current != null)
                        notes.AppendLine(rawLine);
                }
            }

            }

            if (current != null)
            {
                current.Notes = notes.ToString().Trim();
                logs.Add(current);
            }

            // Production safety: at most 20,000 entries per file, and they are the NEWEST ones (the end of the file)
            if (logs.Count > 20000)
            {
                DebugLogger.Warn("log4net file has " + logs.Count + " entries; keeping the newest 20000: " + filePath);
                logs.RemoveRange(0, logs.Count - 20000);
            }

            DebugLogger.Info("log4net parsed entries: " + logs.Count + " from " + filePath);
        }
        catch (Exception ex)
        {
            DebugLogger.Error("Log4NetParser error file=" + filePath, ex);
        }

        return logs;
    }

    /// <summary>"SignalR.log" / "SignalR.log.3" -> "SignalR" (logical channel name).</summary>
    private string GetChannelName(string filePath)
    {
        string name = Path.GetFileName(filePath);
        var m = RollingSuffixRegex.Match(name);
        string baseName = m.Success ? m.Groups["base"].Value : name;
        return Path.GetFileNameWithoutExtension(baseName);
    }
}
