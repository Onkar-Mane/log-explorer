using System.Text.RegularExpressions;

/// <summary>
/// Helpers for pulling structured values out of free-text log content.
/// </summary>
public static class LogFieldHelper
{
    // Matches "SiteID=5", "Site Id : 12", "siteid=  7", etc. Requires a digit value
    // after ':' or '=' so it won't false-positive on stack-trace parameter names.
    private static readonly Regex SiteIdRegex =
        new Regex(@"site\s*id\s*[:=]\s*(\d+)", RegexOptions.IgnoreCase | RegexOptions.Compiled);

    /// <summary>
    /// Extracts a SiteID embedded in free text (e.g. "... | SiteID=5").
    /// Returns 0 when none of the supplied texts contain one.
    /// </summary>
    public static int ExtractSiteId(params string[] texts)
    {
        if (texts == null) return 0;

        foreach (var t in texts)
        {
            if (string.IsNullOrEmpty(t)) continue;

            var m = SiteIdRegex.Match(t);
            if (m.Success)
            {
                int id;
                if (int.TryParse(m.Groups[1].Value, out id))
                    return id;
            }
        }
        return 0;
    }
}
