using System;
using System.Collections.Generic;


    public class LogGroup
    {
        public string GroupKey { get; set; }
        public string Message { get; set; }
        public string ErrorType { get; set; }
        public string ErrorModule { get; set; }
        public string ErrorMethod { get; set; }
        public int Count { get; set; }
        public DateTime FirstOccurrence { get; set; }
        public DateTime LastOccurrence { get; set; }
        public List<string> SiteIds { get; set; }
        public List<LogEntry> Logs { get; set; }
         
        public LogGroup()
        {
            SiteIds = new List<string>();
            Logs = new List<LogEntry>();
        }
    }
