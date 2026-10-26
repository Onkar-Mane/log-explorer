using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

/// <summary>
/// Parses ONE error file (one exception per file, see README) into ONE IpasRecord.
/// Files are UTF-16 LE without BOM. Each file holds an exception block and usually a context block
/// ("&lt;caller&gt; Browser Settings values for id: ..."). Blocks can be glued together without a
/// newline ("Line Number: 0TimeStamp: 2026-..."), so blocks are split on the TimeStamp token itself.
/// </summary>
public class LogParser
{
    private const long MaxFileBytes = 20L * 1024 * 1024;

    // A new block starts at "TimeStamp: <ISO date>" even when glued to the previous line.
    private static readonly Regex BlockStart = new Regex(
        @"TimeStamp\s*:\s*(?=\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    // Field headers at line start. A field value runs until the next header, so a message that
    // wraps over several lines (or starts on the line after "Message:") is kept whole.
    private static readonly Regex FieldStart = new Regex(
        @"^[ \t]*(Time ?Stamp|Message|Server ?Name|Error ?Type|Error ?Module|Error ?Method|Notes|Custom ?Message|Line ?Number|Site ?ID)[ \t]*:",
        RegexOptions.Multiline | RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex ContextMessage = new Regex(
        @"^(?<caller>.*?)\s*Browser Settings values for id\s*:?\s*(?<details>.*)$",
        RegexOptions.Singleline | RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex WrapperPrefix = new Regex(
        @"^\s*Exception has been thrown by the target of an invocation\.?\s*",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    private static readonly Regex StackFrame = new Regex(
        @"\bat\s+(?<ns>[A-Za-z_][\w.`+<>]*)\.(?<m>[A-Za-z_<>][\w<>]*)\s*\(",
        RegexOptions.Compiled);

    private sealed class Block
    {
        public readonly Dictionary<string, string> F = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        public string Get(string key) { string v; return F.TryGetValue(key, out v) ? v : ""; }
    }

    // ---- public API ----------------------------------------------------------

    public IpasRecord ParseFile(string path, string source, DateTime fileTime)
    {
        string text = ReadText(path);
        if (text == null)
        {
            return new IpasRecord
            {
                Timestamp = fileTime, FilePath = path, FileName = Path.GetFileName(path), Source = source ?? "",
                ServerName = source ?? "", Message = "(file larger than 20 MB, not parsed)", ErrorType = "", ErrorModule = "", ErrorMethod = "",
                Caller = "", CustomMessage = "", ContextDetails = "", Category = "Unparsed", Severity = "warning",
                ParseNote = "File is larger than 20 MB and was skipped.", NormKey = "unparsed|toolarge", GroupId = Hash("unparsed|toolarge")
            };
        }
        return ParseText(text, path, source, fileTime);
    }

    /// <summary>Reads a file as text (UTF-16 LE no BOM, BOM variants, or UTF-8). Null when over the size cap.</summary>
    public static string ReadText(string path)
    {
        var fi = new FileInfo(path);
        if (fi.Length > MaxFileBytes) return null;
        // FileShare.ReadWrite: a file the app is still appending to can be read instead of failing
        using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
        {
            var b = new byte[fs.Length];
            int read = 0, n;
            while (read < b.Length && (n = fs.Read(b, read, b.Length - read)) > 0) read += n;
            if (read < b.Length) Array.Resize(ref b, read);
            return DecodeBytes(b);
        }
    }

    public static string DecodeBytes(byte[] b)
    {
        string s;
        if (b.Length >= 2 && b[0] == 0xFF && b[1] == 0xFE) s = Encoding.Unicode.GetString(b, 2, b.Length - 2);
        else if (b.Length >= 2 && b[0] == 0xFE && b[1] == 0xFF) s = Encoding.BigEndianUnicode.GetString(b, 2, b.Length - 2);
        else if (b.Length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) s = Encoding.UTF8.GetString(b, 3, b.Length - 3);
        else s = (GuessUtf16(b) ?? Encoding.UTF8).GetString(b);

        return s.IndexOf('\0') >= 0 ? s.Replace("\0", "") : s;
    }

    public IpasRecord ParseText(string text, string path, string source, DateTime fileTime)
    {
        source = source ?? "";
        var rec = new IpasRecord
        {
            FilePath = path,
            FileName = Path.GetFileName(path),
            Source = source,
            Caller = "", CustomMessage = "", ContextDetails = "", ErrorType = "", ErrorModule = "", ErrorMethod = "", Message = ""
        };

        // 1) split into blocks
        var starts = BlockStart.Matches(text);
        var blocks = new List<Block>();
        for (int i = 0; i < starts.Count; i++)
        {
            int s = starts[i].Index;
            int e = (i + 1 < starts.Count) ? starts[i + 1].Index : text.Length;
            blocks.Add(ParseBlock(text.Substring(s, e - s)));
        }

        if (blocks.Count == 0)
        {
            rec.Timestamp = fileTime;
            rec.ServerName = source;
            rec.Message = FirstLine(text, 300);
            rec.Category = "Unparsed";
            rec.Severity = "warning";
            rec.ParseNote = "No TimeStamp field found, so the file layout is not recognised. Open the occurrence to read the raw file.";
            Finish(rec);
            return rec;
        }

        // 2) the exception block is the first block that is not a pure context block
        Block primary = null;
        foreach (var b in blocks) { if (!IsContext(b)) { primary = b; break; } }
        bool contextOnly = primary == null;
        if (contextOnly) primary = blocks[0];

        var callers = new List<string>();
        var customs = new List<string>();
        var details = new List<string>();
        string ctxModule = "", ctxMethod = "";
        int extraExceptions = 0;
        foreach (var b in blocks)
        {
            if (!contextOnly && object.ReferenceEquals(b, primary)) continue;
            if (IsContext(b))
            {
                var m = ContextMessage.Match(b.Get("Message"));
                if (m.Success)
                {
                    AddDistinct(callers, m.Groups["caller"].Value.Trim());
                    AddDistinct(details, m.Groups["details"].Value.Trim());
                }
                AddDistinct(customs, b.Get("CustomMessage"));
                if (ctxModule.Length == 0) ctxModule = b.Get("ErrorModule");
                if (ctxMethod.Length == 0) ctxMethod = b.Get("ErrorMethod");
            }
            else
            {
                extraExceptions++;
            }
        }

        rec.HasContext = contextOnly || blocks.Exists(IsContext);
        rec.Caller = callers.Count > 0 ? callers[0] : "";
        rec.CustomMessage = string.Join(" | ", customs.ToArray());
        rec.ContextDetails = string.Join(" | ", details.ToArray());

        // 3) fields from the exception block
        string type = primary.Get("ErrorType");
        string message = primary.Get("Message");
        string notes = primary.Get("Notes");
        rec.ErrorType = type;
        // Block 1 "Error Module" is only ex.Source (often mscorlib / System.Web). The module the developer passed to
        // Common.LogException is in block 2, so that one wins whenever block 2 exists.
        rec.ContextModule = StripQuery(ctxModule);
        rec.ErrorModule = StripQuery(ctxModule.Length > 0 ? ctxModule : primary.Get("ErrorModule"));
        rec.ErrorMethod = primary.Get("ErrorMethod").Length > 0 ? primary.Get("ErrorMethod") : ctxMethod;
        rec.ServerName = FirstNonEmpty(primary.Get("ServerName"), FirstContextField(blocks, "ServerName"), source);

        if (contextOnly)
        {
            message = rec.CustomMessage.Length > 0 ? rec.CustomMessage
                : ((rec.Caller.Length > 0 ? rec.Caller : "Unknown caller") + " (context only, no exception recorded)");
        }

        // 4) wrapped async errors: show the real inner message and the real caller
        rec.IsAsync = type.IndexOf("TargetInvocationException", StringComparison.OrdinalIgnoreCase) >= 0
                      || WrapperPrefix.IsMatch(message)
                      || rec.CustomMessage.IndexOf("async call", StringComparison.OrdinalIgnoreCase) >= 0;

        if (rec.IsAsync)
        {
            string inner = WrapperPrefix.Replace(message, "").Trim();
            if (inner.Length > 0) message = inner;

            string module, method;
            if (rec.Caller.Length > 0)
            {
                // The wrapper's own method (InvokeMethod / Send) says nothing: use the caller's method.
                SplitCaller(rec.Caller, out module, out method);
                if (method.Length > 0) rec.ErrorMethod = method;
                if (rec.ErrorModule.Length == 0) rec.ErrorModule = module;
            }
            else if (StackCaller(notes, out module, out method))
            {
                rec.ErrorModule = module;
                rec.ErrorMethod = method;
            }
        }

        // readable name: main project + file/method, from the module, the caller and (for .NET-only modules) the stack
        string appName, appDetail;
        ModuleNames.Describe(rec.ErrorModule, rec.Caller, rec.ErrorMethod, notes, out appName, out appDetail);
        rec.App = appName; rec.AppDetail = appDetail;

        // 5) message fallbacks so a group is never "No Message"
        if (message.Length == 0) message = rec.CustomMessage;
        if (message.Length == 0 && type.Length > 0)
        {
            message = ShortType(type) + " (no message recorded)";
            rec.ParseNote = "The exception was logged with an empty Message. Open the occurrence to read the stack trace.";
        }
        if (message.Length == 0) message = FirstLine(notes, 300);
        if (message.Length == 0)
        {
            message = "(no message in file)";
            rec.ParseNote = "The file has no Message field. Open the occurrence to read the raw file.";
        }
        rec.Message = message;

        if (extraExceptions > 0)
        {
            string more = "File contains " + extraExceptions + " additional exception block(s); the raw text shows all of them.";
            rec.ParseNote = rec.ParseNote == null ? more : rec.ParseNote + " " + more;
        }

        // 6) timestamp is SERVER time; never fall back to the machine clock
        DateTime ts;
        if (!TryParseStamp(primary.Get("TimeStamp"), out ts)) ts = fileTime;
        rec.Timestamp = ts;

        int site;
        if (!int.TryParse(primary.Get("SiteID"), out site))
            site = LogFieldHelper.ExtractSiteId(message, rec.ContextDetails, notes);
        rec.SiteID = site;

        // 7) severity from the real error text. For wrapped errors the wrapper type says nothing.
        string cat = Classify(rec.IsAsync ? "" : type, message + " " + rec.CustomMessage, !contextOnly);
        rec.Category = cat;
        rec.Severity = SeverityOf(cat);

        Finish(rec);
        return rec;
    }

    // ---- grouping + severity helpers (public for tests) ------------------------------

    // The same server, module, caller, message and key repeat thousands of times. One shared copy of each keeps a
    // remembered file small. The pool is emptied when it grows large or when the cache is cleared.
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, string> Pooled =
        new System.Collections.Concurrent.ConcurrentDictionary<string, string>(StringComparer.Ordinal);

    public static string Pool(string s)
    {
        if (string.IsNullOrEmpty(s)) return s ?? "";
        if (s.Length > 600) return s;
        string v;
        if (Pooled.TryGetValue(s, out v)) return v;
        if (Pooled.Count > 200000) Pooled.Clear();
        Pooled[s] = s;
        return s;
    }

    public static void ClearPool() { Pooled.Clear(); }

    private static void Finish(IpasRecord rec)
    {
        string key = (rec.ErrorType ?? "").ToLowerInvariant() + "|"
                   + (rec.Caller ?? "").ToLowerInvariant() + "|"
                   + (rec.ErrorModule ?? "").ToLowerInvariant() + "/" + (rec.ErrorMethod ?? "").ToLowerInvariant() + "|"
                   + NormalizeMessage(rec.Message);
        rec.NormKey = Pool(key);
        rec.GroupId = Pool(Hash(key));
        if (string.IsNullOrEmpty(rec.Category)) rec.Category = "Error";
        if (string.IsNullOrEmpty(rec.Severity)) rec.Severity = "error";

        rec.ServerName = Pool(rec.ServerName); rec.Source = Pool(rec.Source); rec.Message = Pool(rec.Message);
        rec.ErrorType = Pool(rec.ErrorType); rec.ErrorModule = Pool(rec.ErrorModule); rec.ErrorMethod = Pool(rec.ErrorMethod);
        rec.Caller = Pool(rec.Caller); rec.CustomMessage = Pool(rec.CustomMessage); rec.ContextDetails = Pool(rec.ContextDetails);
        rec.ContextModule = Pool(rec.ContextModule); rec.Category = Pool(rec.Category); rec.Severity = Pool(rec.Severity);
        rec.App = Pool(rec.App); rec.AppDetail = Pool(rec.AppDetail);
        rec.ParseNote = rec.ParseNote == null ? null : Pool(rec.ParseNote);
    }

    private static readonly Regex RxGuid = new Regex(@"\b[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\b", RegexOptions.Compiled);
    private static readonly Regex RxIsoDate = new Regex(@"\b\d{4}-\d{2}-\d{2}(?:[T ]\d{1,2}:\d{2}(?::\d{2}(?:\.\d+)?)?)?\b", RegexOptions.Compiled);
    private static readonly Regex RxSlashDate = new Regex(@"\b\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}\b", RegexOptions.Compiled);
    private static readonly Regex RxTime = new Regex(@"\b\d{1,2}:\d{2}(?::\d{2})?(?:\s?[AaPp][Mm])?\b", RegexOptions.Compiled);
    private static readonly Regex RxHex = new Regex(@"\b0x[0-9a-fA-F]+\b", RegexOptions.Compiled);
    private static readonly Regex RxDigitToken = new Regex(@"\b[\w.\-]*\d[\w.\-]*\b", RegexOptions.Compiled);
    private static readonly Regex RxSpace = new Regex(@"\s+", RegexOptions.Compiled);

    /// <summary>
    /// Removes the variable parts of a message (GUIDs, dates, times, numbers, ids and material numbers)
    /// so the same error with different values falls into one group. ORA-nnnnn codes are kept.
    /// </summary>
    public static string NormalizeMessage(string message)
    {
        if (string.IsNullOrEmpty(message)) return "";
        string s = RxGuid.Replace(message, "<guid>");
        s = RxIsoDate.Replace(s, "<date>");
        s = RxSlashDate.Replace(s, "<date>");
        s = RxTime.Replace(s, "<time>");
        s = RxHex.Replace(s, "<hex>");
        s = RxDigitToken.Replace(s, delegate(Match m)
        {
            return m.Value.StartsWith("ORA-", StringComparison.OrdinalIgnoreCase) ? m.Value : "<n>";
        });
        s = RxSpace.Replace(s, " ").Trim().ToLowerInvariant();
        return s.Length > 300 ? s.Substring(0, 300) : s;
    }

    /// <summary>Category from Error Type + message text. Order matters: most specific first.</summary>
    public static string Classify(string errorType, string message, bool hasException)
    {
        string t = (errorType ?? "").ToLowerInvariant();
        string hay = t + " " + (message ?? "").ToLowerInvariant();

        if (Has(hay, "ora-", "oracleexception", "oracleclient", "sqlexception", "dbexception", "sql server", "deadlock", "unique constraint", "odbcexception"))
            return "Database";
        if (Has(hay, "faultexception", "communicationexception", "endpointnotfound", "channelterminated", "no endpoint listening", "wcf"))
            return "Service call";
        if (Has(hay, "timeoutexception", "timed out", "timeout"))
            return "Timeout";
        if (Has(hay, "socketexception", "webexception", "httprequestexception", "forcibly closed", "unable to connect", "remote name could not be resolved", "network"))
            return "Network";
        if (Has(hay, "sapnco", "rfc", "sap "))
            return "SAP";
        if (Has(hay, "maxjsonlength", "jsonexception", "jsonreaderexception", "serializ"))
            return "Serialization";
        if (Has(hay, "ioexception", "filenotfound", "directorynotfound", "unauthorizedaccess", "could not find a part of the path",
                     "being used by another process", "access to the path", "not enough space"))
            return "File / IO";
        if (Has(hay, "nullreferenceexception", "argumentnullexception", "argumentoutofrange", "argumentexception", "invalidcastexception",
                     "formatexception", "input string was not in a correct format", "indexoutofrange", "keynotfound", "invalidoperationexception",
                     "notimplemented", "dividebyzero", "overflowexception", "object reference not set", "nullable object must have a value"))
            return "Code defect";
        if (Has(hay, "httpexception", "httpunhandledexception", "viewstate", "httprequestvalidation"))
            return "Web request";
        if (t.Length > 0) return "Error";
        return hasException ? "Error" : "Info";
    }

    public static string SeverityOf(string category)
    {
        switch (category)
        {
            case "Timeout":
            case "Network":
            case "Unparsed":
                return "warning";
            case "Info":
                return "info";
            default:
                return "error";
        }
    }

    // ---- small helpers -------------------------------------------------------

    private static bool Has(string hay, params string[] needles)
    {
        foreach (var n in needles) if (hay.IndexOf(n, StringComparison.Ordinal) >= 0) return true;
        return false;
    }

    private static Block ParseBlock(string text)
    {
        var b = new Block();
        var ms = FieldStart.Matches(text);
        for (int i = 0; i < ms.Count; i++)
        {
            string key = Regex.Replace(ms[i].Groups[1].Value, @"\s+", "");
            int start = ms[i].Index + ms[i].Length;
            int end = (i + 1 < ms.Count) ? ms[i + 1].Index : text.Length;
            if (!b.F.ContainsKey(key))
                b.F[key] = text.Substring(start, end - start).Trim();
        }
        return b;
    }

    private static bool IsContext(Block b)
    {
        if (b.Get("ErrorType").Length > 0 || b.Get("Notes").Length > 0) return false;
        return b.Get("Message").IndexOf("Browser Settings values for id", StringComparison.OrdinalIgnoreCase) >= 0
            || b.Get("CustomMessage").Length > 0
            || b.Get("LineNumber").Length > 0;
    }

    private static string StripQuery(string s)
    {
        if (string.IsNullOrEmpty(s)) return "";
        int q = s.IndexOf('?');
        return (q >= 0 ? s.Substring(0, q) : s).Trim();
    }

    private static string ShortType(string type)
    {
        int i = type.LastIndexOf('.');
        return i >= 0 && i < type.Length - 1 ? type.Substring(i + 1) : type;
    }

    private static void AddDistinct(List<string> list, string value)
    {
        if (string.IsNullOrEmpty(value)) return;
        foreach (var x in list) if (string.Equals(x, value, StringComparison.OrdinalIgnoreCase)) return;
        list.Add(value);
    }

    private static string FirstContextField(List<Block> blocks, string key)
    {
        foreach (var b in blocks) { var v = b.Get(key); if (v.Length > 0) return v; }
        return "";
    }

    private static string FirstNonEmpty(params string[] values)
    {
        foreach (var v in values) if (!string.IsNullOrEmpty(v)) return v;
        return "";
    }

    private static string FirstLine(string text, int max)
    {
        if (string.IsNullOrEmpty(text)) return "";
        foreach (var raw in text.Split('\n'))
        {
            var line = raw.Trim();
            if (line.Length == 0) continue;
            return line.Length > max ? line.Substring(0, max) : line;
        }
        return "";
    }

    // "Shop_Orders.OrderBAL+PrintLabelDelegate" -> module "Shop_Orders.OrderBAL", method "PrintLabelDelegate"
    public static void SplitCaller(string caller, out string module, out string method)
    {
        int idx = caller.LastIndexOf('+');
        if (idx < 0) idx = caller.LastIndexOf('.');
        if (idx > 0 && idx < caller.Length - 1)
        {
            module = caller.Substring(0, idx);
            method = caller.Substring(idx + 1);
        }
        else
        {
            module = caller;
            method = "";
        }
    }

    // First stack frame outside System.* / Microsoft.* (used when there is no context block).
    private static bool StackCaller(string notes, out string module, out string method)
    {
        module = null; method = null;
        if (string.IsNullOrEmpty(notes)) return false;
        foreach (Match m in StackFrame.Matches(notes))
        {
            string ns = m.Groups["ns"].Value;
            if (ns.StartsWith("System.", StringComparison.Ordinal) || ns.StartsWith("Microsoft.", StringComparison.Ordinal) || ns.StartsWith("mscorlib", StringComparison.Ordinal))
                continue;
            module = ns;
            method = m.Groups["m"].Value;
            return true;
        }
        return false;
    }

    private static readonly string[] StampFormats =
        { "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.FFFFFFF", "yyyy-MM-dd HH:mm:ss.FFFFFFF" };

    private static bool TryParseStamp(string value, out DateTime ts)
    {
        if (!string.IsNullOrEmpty(value) &&
            DateTime.TryParseExact(value.Trim(), StampFormats, CultureInfo.InvariantCulture, DateTimeStyles.None, out ts))
            return true;
        ts = DateTime.MinValue;
        return false;
    }

    private static string Hash(string key)
    {
        // 64-bit FNV-1a: stable, fast, and allowed on servers with the Windows FIPS policy on (MD5 throws there)
        ulong h = 14695981039346656037UL;
        foreach (char c in key) { h ^= c; h *= 1099511628211UL; }
        return h.ToString("x16");
    }

    private static Encoding GuessUtf16(byte[] b)
    {
        int n = Math.Min(b.Length, 512);
        if (n < 4) return null;

        int oddZero = 0, evenZero = 0, odd = 0, even = 0;
        for (int i = 0; i < n; i++)
        {
            if ((i & 1) == 0) { even++; if (b[i] == 0) evenZero++; }
            else { odd++; if (b[i] == 0) oddZero++; }
        }
        double oddRatio = odd == 0 ? 0 : (double)oddZero / odd;
        double evenRatio = even == 0 ? 0 : (double)evenZero / even;

        if (oddRatio > 0.30 && evenRatio < 0.05) return Encoding.Unicode;
        if (evenRatio > 0.30 && oddRatio < 0.05) return Encoding.BigEndianUnicode;
        return null;
    }
}
