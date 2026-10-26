using System;

public class LogEntry
{
    public DateTime Timestamp { get; set; }
    public string Message { get; set; }
    public string ServerName { get; set; }
    public string ErrorType { get; set; }
    public string ErrorModule { get; set; }
    public string ErrorMethod { get; set; }
    public string Notes { get; set; }
    public int SiteID { get; set; }

    // log4net-specific fields (left empty for error files)
    public string Level { get; set; }
    public string Thread { get; set; }
    public string Logger { get; set; }
    public string Channel { get; set; }
}
