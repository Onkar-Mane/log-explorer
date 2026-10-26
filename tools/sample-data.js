/*
 * Made-up error data for a fictional web shop. Used by:
 *   - tools/make-sample-logs.js  (writes real error files you can point the site at)
 *   - docs/demo-api.js           (the GitHub Pages demo, which has no server)
 * Nothing here comes from a real system. Works in Node and in the browser.
 */
(function (root, factory) {
    if (typeof module === 'object' && module.exports) module.exports = factory();
    else root.SampleData = factory();
}(typeof self !== 'undefined' ? self : this, function () {
    'use strict';

    // One template = one kind of error. w = how common it is. bg = a background / sync job.
    const TEMPLATES = [
        { id: 'credit', w: 30, type: 'System.InvalidOperationException', msg: 'Order {n} could not be saved: customer credit limit exceeded',
          module: 'Shop_Orders', method: 'SaveOrder', caller: 'OrderService', custom: 'Error while saving the order', cat: 'Error', sev: 'error',
          app: 'Order processing', detail: 'OrderService · SaveOrder', burstNow: 26,
          stack: 'at Shop_Orders.OrderBAL.SaveOrder(Order order)\n   at Shop_Orders.OrderService.Save(OrderDto dto)' },
        { id: 'ora942', w: 14, type: 'System.Data.OracleClient.OracleException', msg: 'ORA-00942: table or view does not exist',
          module: 'Shop_Reports', srcModule: 'System.Data.OracleClient', method: 'GetDailyReport', caller: 'ReportService', custom: 'Error while loading the daily report',
          cat: 'Database', sev: 'error', app: 'Reports', detail: 'ReportService · GetDailyReport',
          stack: 'at System.Data.OracleClient.OracleConnection.CheckError(OciErrorHandle errorHandle, Int32 rc)\n   at Shop_Reports.ReportDAL.GetDailyReport(DateTime day)' },
        { id: 'timeout', w: 12, type: 'System.Net.WebException', msg: 'The operation has timed out',
          module: 'Shop_Integration', method: 'CallCarrierApi', caller: 'ShippingService', custom: 'Carrier API call failed', cat: 'Timeout', sev: 'warning',
          app: 'Integrations', detail: 'ShippingService · CallCarrierApi', burstAgo: 3, burstSize: 18,
          stack: 'at System.Net.HttpWebRequest.GetResponse()\n   at Shop_Integration.CarrierClient.CallCarrierApi(String shipmentId)' },
        { id: 'abort', w: 8, type: 'System.Threading.ThreadAbortException', msg: 'Thread was being aborted.',
          module: '/shop/Services/orders_Service.asmx/GetOpenOrders', caller: '/shop/Services/orders_Service.asmx', cat: 'Web request', sev: 'warning',
          app: 'Orders web service', detail: 'Shop web · orders_Service.asmx · GetOpenOrders',
          stack: 'at System.Threading.Thread.AbortInternal()\n   at System.Web.HttpResponse.End()' },
        { id: 'nullref', w: 10, type: 'System.NullReferenceException', msg: 'Object reference not set to an instance of an object.',
          module: 'Shop_Inventory', method: 'UpdateStock', caller: 'InventoryService', custom: 'Error while updating stock', cat: 'Code defect', sev: 'error',
          app: 'Inventory', detail: 'InventoryService · UpdateStock',
          stack: 'at Shop_Inventory.StockBAL.UpdateStock(Int32 itemId, Decimal qty)\n   at Shop_Inventory.InventoryService.Adjust(AdjustDto dto)' },
        { id: 'format', w: 9, bg: true, type: 'System.FormatException', msg: 'Input string was not in a correct format.',
          module: 'Shop_SyncService', method: 'ImportPrices', caller: 'SyncService', custom: 'Price import failed for one row', cat: 'Code defect', sev: 'error',
          app: 'Nightly sync', detail: 'SyncService · ImportPrices', servers: ['SHOP-APP01'],
          stack: 'at System.Number.StringToNumber(String str, NumberStyles options)\n   at Shop_SyncService.PriceImport.ImportPrices(String file)' },
        { id: 'io', w: 4, type: 'System.UnauthorizedAccessException', msg: "Access to the path 'D:\\Exports\\daily-{d}.csv' is denied.",
          module: 'Shop_Exports', method: 'WriteDailyFile', caller: 'ExportJob', cat: 'File / IO', sev: 'error',
          app: 'Exports', detail: 'ExportJob · WriteDailyFile', hours: [2], servers: ['SHOP-APP01'],
          stack: 'at System.IO.FileStream.Init(String path, FileMode mode)\n   at Shop_Exports.ExportJob.WriteDailyFile(DateTime day)' },
        { id: 'async', w: 5, bg: true, async: true, type: 'System.Reflection.TargetInvocationException',
          msg: 'Exception has been thrown by the target of an invocation. Connection refused (catalog.example.internal:443)',
          module: 'Shop_SyncService', method: 'Send', caller: 'Shop_SyncService.SyncService+RefreshCatalogDelegate', custom: 'Error occurred in async call',
          cat: 'Service call', sev: 'error', app: 'Nightly sync', detail: 'SyncService › RefreshCatalog', servers: ['SHOP-APP01'],
          stack: 'at System.RuntimeMethodHandle.InvokeMethod(Object target, Object[] arguments)\n   at Shop_SyncService.SyncService.Send(IAsyncResult ar)' },
        { id: 'pk', w: 6, type: 'System.Data.SqlClient.SqlException', msg: "Violation of PRIMARY KEY constraint 'PK_Invoice'. Cannot insert duplicate key in object 'dbo.Invoice'.",
          module: 'Shop_Billing', srcModule: 'System.Data.SqlClient', method: 'CreateInvoice', caller: 'BillingService', cat: 'Database', sev: 'error',
          app: 'Billing', detail: 'BillingService · CreateInvoice',
          stack: 'at System.Data.SqlClient.SqlCommand.ExecuteNonQuery()\n   at Shop_Billing.InvoiceDAL.CreateInvoice(Invoice inv)' },
        { id: 'validation', w: 3, type: 'System.Web.HttpRequestValidationException',
          msg: 'A potentially dangerous Request.Form value was detected from the client (comment="<b>Hi</b>").',
          module: '/shop/Login.aspx', caller: '/shop/Login.aspx', cat: 'Web request', sev: 'warning', app: 'Shop web', detail: 'Login.aspx',
          stack: 'at System.Web.HttpRequest.ValidateString(String value, String collectionKey)' },
        { id: 'payment', w: 2, type: 'System.Net.Http.HttpRequestException', msg: 'Payment gateway returned 502 Bad Gateway',
          module: 'Shop_Payments', method: 'Capture', caller: 'PaymentService', custom: 'Card capture failed', cat: 'Service call', sev: 'error',
          app: 'Payments', detail: 'PaymentService · Capture', burstNow: 6,
          stack: 'at Shop_Payments.GatewayClient.Capture(PaymentDto p)' },
        { id: 'argnull', w: 4, type: 'System.ArgumentNullException', msg: 'Value cannot be null.\nParameter name: sku',
          module: 'Shop_Catalog', method: 'GetProduct', caller: 'CatalogService', cat: 'Code defect', sev: 'error',
          app: 'Catalog', detail: 'CatalogService · GetProduct',
          stack: 'at Shop_Catalog.CatalogBAL.GetProduct(String sku)' }
    ];
    const SERVERS = ['SHOP-WEB01', 'SHOP-WEB02', 'SHOP-APP01'];

    function rng(seed) {                                   // small seeded random, so the same seed gives the same data
        let a = seed >>> 0;
        return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
    }
    const pad = (n, w) => String(n).padStart(w || 2, '0');
    // local wall-clock text; the demo treats the visitor's own clock as "server time"
    function localIso(ms) { const d = new Date(ms); return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + 'T' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds()); }

    /** Records over the last `days` days up to `nowMs`. About `perDay` errors a day, busier in working hours. */
    function generate(nowMs, opts) {
        opts = opts || {};
        const days = opts.days || 7, perDay = opts.perDay || 380, rand = rng(opts.seed || 20261026);
        const totalW = TEMPLATES.reduce((s, t) => s + t.w, 0);
        const out = [];
        const span = days * 86400000;
        const add = (t, ms) => {
            const d = new Date(ms);
            const n = 40000 + Math.floor(rand() * 60000);
            const servers = t.servers || SERVERS;
            out.push({
                t: t, ms: ms, server: servers[Math.floor(rand() * servers.length)],
                message: t.msg.replace('{n}', n).replace('{d}', d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate())),
                site: 1 + Math.floor(rand() * 4)
            });
        };
        for (const t of TEMPLATES) {
            const count = Math.round(perDay * days * t.w / totalW);
            for (let i = 0; i < count; i++) {
                let ms, tries = 0;
                do {
                    ms = nowMs - (rand() < 0.12 ? rand() * 86400000 : rand() * span);
                    const h = new Date(ms).getHours();
                    if (t.hours) { if (t.hours.indexOf(h) >= 0) break; }
                    else if ((h >= 7 && h <= 20) || rand() < 0.25) break;            // quieter at night
                } while (++tries < 40);
                if (t.hours && t.hours.indexOf(new Date(ms).getHours()) < 0) continue;
                add(t, ms);
            }
            if (t.burstNow) {                                                    // failing right now: all inside the current hour
                const sinceHour = Math.max(60000, nowMs - new Date(nowMs).setMinutes(0, 0, 0));
                for (let i = 0; i < t.burstNow; i++) add(t, nowMs - rand() * Math.min(50 * 60000, sinceHour));
            }
            if (t.burstAgo) for (let i = 0; i < t.burstSize; i++) add(t, nowMs - (t.burstAgo * 3600000) - rand() * 3600000);
        }
        out.sort((a, b) => b.ms - a.ms);
        out.forEach((r, i) => { r.file = fileName(r.ms, i); });
        return out;
    }

    function fileName(ms, i) {
        const d = new Date(ms);
        return pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + '-' + d.getFullYear() + '-' + pad(d.getHours()) + '_' + pad(d.getMinutes()) + '_' + pad(d.getSeconds()) + '_' + pad((d.getMilliseconds() * 10 + i) % 10000, 4) + '.log';
    }

    /** The text of one error file: block 1 (the exception) and block 2 (what the application passed to its logger). */
    function fileText(r) {
        const t = r.t, ts = localIso(r.ms);
        let s = 'TimeStamp: ' + ts + '\r\n'
              + 'Message: ' + r.message + '\r\n'
              + 'Server Name: ' + r.server + '\r\n'
              + 'Error Type: ' + t.type + '\r\n'
              + 'Error Module: ' + (t.srcModule || (t.module.charAt(0) === '/' ? 'System.Web' : t.module)) + '\r\n'
              + 'Error Method: ' + (t.method || 'ProcessRequest') + '\r\n'
              + 'Notes: ' + t.stack.replace(/\n/g, '') + '\r\n';
        s += 'TimeStamp: ' + ts + '\r\n'
           + 'Message: ' + t.caller + ' Browser Settings values for id: SiteID: ' + r.site + '\r\n'
           + 'Server Name: ' + r.server + '\r\n'
           + (t.custom ? 'Custom Message: ' + t.custom + '\r\n' : '')
           + 'Error Module: ' + t.module + '\r\n'
           + 'Error Method: ' + (t.method || '') + '\r\n'
           + 'Line Number: 0\r\n';
        return s;
    }

    /** A few log4net lines per hour for three channels. */
    function log4net(nowMs, opts) {
        opts = opts || {};
        const rand = rng((opts.seed || 7) + 1), days = opts.days || 2, out = [];
        const channels = [
            { ch: 'Orders', loggers: ['OrderService', 'OrderQueue'], msgs: ['Order {n} received', 'Order {n} queued for picking', 'Order {n} shipped'] },
            { ch: 'Sync', loggers: ['PriceImport', 'CatalogRefresh'], msgs: ['Imported {n} prices', 'Catalog refresh started', 'Catalog refresh finished in {s} s'] },
            { ch: 'SignalR', loggers: ['HubConnection'], msgs: ['Client connected', 'Client disconnected', 'Reconnecting after {s} s'] }
        ];
        const levels = ['INFO', 'INFO', 'INFO', 'INFO', 'DEBUG', 'WARN', 'ERROR'];
        for (let ms = nowMs - days * 86400000; ms < nowMs; ms += 60000 * (4 + Math.floor(rand() * 9))) {
            const c = channels[Math.floor(rand() * channels.length)];
            const lvl = levels[Math.floor(rand() * levels.length)];
            let msg = c.msgs[Math.floor(rand() * c.msgs.length)].replace('{n}', 40000 + Math.floor(rand() * 60000)).replace('{s}', 1 + Math.floor(rand() * 30));
            let notes = '';
            if (lvl === 'ERROR') { msg = 'Unhandled error in ' + c.loggers[0]; notes = 'System.TimeoutException: The operation has timed out.\n   at ' + c.ch + '.Worker.Run()'; }
            const d = new Date(ms);
            out.push({ ms: ms, channel: c.ch, logger: c.loggers[Math.floor(rand() * c.loggers.length)], level: lvl, thread: String(1 + Math.floor(rand() * 12)), message: msg, notes: notes,
                       line: d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds()) + ',' + pad(d.getMilliseconds(), 3) });
        }
        return out.sort((a, b) => b.ms - a.ms);
    }

    return { TEMPLATES: TEMPLATES, SERVERS: SERVERS, generate: generate, fileText: fileText, fileName: fileName, log4net: log4net, localIso: localIso };
}));
