#!/usr/bin/env node
/*
 * Writes made-up error files (and a few log4net files) so you can try Log Explorer without real logs.
 *
 *   node tools/make-sample-logs.js [outputFolder] [days]
 *   node tools/make-sample-logs.js D:\Logs\Sample 7
 *
 * Then point web.config at them:
 *   <add key="LogDirectoryPath" value="D:\Logs\Sample\errors" />
 *   <add key="Log4NetDirectoryPath" value="D:\Logs\Sample\log4net" />
 * Error files are written the way many .NET apps write them: one exception per file, UTF-16 without a BOM.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const SampleData = require('./sample-data');

const out = path.resolve(process.argv[2] || 'sample-logs');
const days = Math.max(1, Math.min(60, parseInt(process.argv[3] || '7', 10) || 7));
const errorsDir = path.join(out, 'errors'), l4nDir = path.join(out, 'log4net');
fs.mkdirSync(errorsDir, { recursive: true });
fs.mkdirSync(l4nDir, { recursive: true });

const now = Date.now();
const records = SampleData.generate(now, { days: days });
for (const r of records) {
    fs.writeFileSync(path.join(errorsDir, r.file), Buffer.from(SampleData.fileText(r), 'utf16le'));   // UTF-16 LE, no BOM
}

const byChannel = {};
for (const e of SampleData.log4net(now, { days: Math.min(days, 3) }).reverse()) {
    let text = e.line + ' [' + e.thread + '] ' + e.level + ' ' + e.logger + ' - ' + e.message + '\r\n';
    if (e.notes) text += e.notes.replace(/\n/g, '\r\n') + '\r\n';
    (byChannel[e.channel] = byChannel[e.channel] || []).push(text);
}
for (const ch of Object.keys(byChannel)) fs.writeFileSync(path.join(l4nDir, ch + '.log'), byChannel[ch].join(''), 'utf8');

console.log('Wrote ' + records.length + ' error files to ' + errorsDir);
console.log('Wrote ' + Object.keys(byChannel).length + ' log4net files to ' + l4nDir);
