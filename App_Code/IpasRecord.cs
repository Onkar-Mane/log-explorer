using System;

/// <summary>
/// One error FILE = one record ("Ipas" is the historical name of this file format in the code). A file usually holds two blocks (the exception, and a
/// "Browser Settings values for id" context block); both are merged into this record.
/// Timestamp is SERVER time (no time zone attached).
/// </summary>
public class IpasRecord
{
    public DateTime Timestamp { get; set; }
    public string FilePath { get; set; }
    public string FileName { get; set; }
    public string Source { get; set; }          // folder label from web.config ("label=path"), else ""
    public string ServerName { get; set; }

    // What the UI shows. For wrapped async errors these are the REAL inner message / caller.
    public string Message { get; set; }
    public string ErrorType { get; set; }
    public string ErrorModule { get; set; }      // block-2 module when present (block 1 is only ex.Source); query string removed
    public string ErrorMethod { get; set; }

    // Readable names (ModuleNames.Describe). Display only: grouping and filters keep the raw ErrorModule.
    public string App { get; set; }              // "Plant web service", "Goods receipt (GR)"
    public string AppDetail { get; set; }        // "Shop web · orders_Service.asmx · GetOpenOrders"

    // Context (block 2)
    public bool HasContext { get; set; }         // false when the file has no block 2 (loggingLevel Normal)
    public string ContextModule { get; set; }    // Error Module from block 2 (what was passed to Common.LogException)
    public string Caller { get; set; }          // page id / caller taken from "<caller> Browser Settings values for id:"
    public string CustomMessage { get; set; }
    public string ContextDetails { get; set; }  // text after "Browser Settings values for id:"
    public bool IsAsync { get; set; }
    public int SiteID { get; set; }

    public string Category { get; set; }        // Database, Timeout, Code defect, ...
    public string Severity { get; set; }        // error | warning | info

    public string NormKey { get; set; }         // normalised grouping key
    public string GroupId { get; set; }         // short stable hash of NormKey
    public string ParseNote { get; set; }       // set when the file layout was unexpected
    public long LastUsed { get; set; }          // ticks of the last request that used this record (cache trimming)
}
