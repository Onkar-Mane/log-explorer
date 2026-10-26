using System.Collections.Generic;

/// <summary>
/// A log-format provider. Each supported log type (error files, log4net, future formats)
/// implements this so LogService can stay format-agnostic.
/// </summary>
public interface ILogParser
{
    List<LogEntry> ParseLogs(string filePath);
}
