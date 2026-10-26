#!/usr/bin/env node
/*
 * Builds the GitHub Pages demo into docs/: the real page (Default.aspx) with the server tags filled in and a small
 * in-browser "server" (tools/demo-api.js) answering from made-up data (tools/sample-data.js).
 *
 *   node tools/build-demo.js
 *
 * Run it again whenever Default.aspx changes, then commit docs/.
 */
'use strict';
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const docs = path.join(root, 'docs');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8').replace(/^﻿/, '');

function copyDir(from, to) {
    fs.mkdirSync(to, { recursive: true });
    for (const e of fs.readdirSync(from, { withFileTypes: true })) {
        const a = path.join(from, e.name), b = path.join(to, e.name);
        if (e.isDirectory()) copyDir(a, b); else fs.copyFileSync(a, b);
    }
}

let html = read('Default.aspx');
const ui = { appStyle: 'slate', adminStyle: '', superStyle: '', role: null, allowUserStyles: true, userStyles: ['slate', 'teal', 'web', 'midnight'],
             defaultRange: '24h', defaultZone: 'server', defaultMode: 'dark', hideBackground: true, adminConfigured: true, suggestionsEnabled: true };
const tags = {
    '<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="Default" ResponseEncoding="UTF-8" %>\n': '',
    '<%= AssetVersion %>': 'demo',
    // the demo keeps its own settings for the tab session (see demo-api.js); this is only the first look
    '<%= UiSettingsJson %>': '(function(){try{var s=JSON.parse(sessionStorage.getItem("logExplorerDemo"));if(s&&s.ui){s.ui.role=s.role;s.ui.suggestionsEnabled=true;s.ui.adminConfigured=true;return s.ui;}}catch(e){}return ' + JSON.stringify(ui) + ';})()',
    '<%= DiagEnabled %>': 'false',
    '<%= ServerUtcOffsetMinutes %>': '(-new Date().getTimezoneOffset())',    // the visitor's own clock plays "server time"
    '<%= HideBackgroundDefault %>': 'true'
};
for (const k of Object.keys(tags)) {
    if (html.indexOf(k) < 0) throw new Error('Default.aspx no longer contains ' + k + '; update tools/build-demo.js');
    html = html.split(k).join(tags[k]);
}
if (/<%/.test(html)) throw new Error('An unknown server tag is left in the page: ' + html.match(/<%[^%]*%>/)[0]);

// the demo "server" must be in place before the page's own scripts run
html = html.replace('<head>', '<head>\n    <script src="sample-data.js"></script>\n    <script src="demo-api.js"></script>');
html = html.replace('<title>Log Explorer</title>', '<title>Log Explorer: demo</title>\n    <meta name="description" content="Demo of Log Explorer with made-up data: a viewer for .NET error log files and log4net logs." />');
// a slim note at the top so nobody mistakes the demo for a real system
html = html.replace(/(<body[^>]*>)/, '$1\n    <div class="demo-note" role="note">Demo with made-up data. Admin sign-in: <b>demo</b> / <b>demo</b>. Nothing you do here leaves this browser tab. <a href="https://github.com/Onkar-Mane/log-explorer">Source on GitHub</a></div>');
html = html.replace('</style>', '        .demo-note { padding: .375rem 1rem; font-size: .75rem; text-align: center; color: var(--lv-text); background: color-mix(in srgb, var(--lv-primary) 18%, var(--lv-card)); border-bottom: 1px solid var(--lv-border); }\n        .demo-note a { color: var(--lv-primary); }\n    </style>');

fs.mkdirSync(docs, { recursive: true });
fs.writeFileSync(path.join(docs, 'index.html'), html, 'utf8');
fs.copyFileSync(path.join(root, 'tools', 'sample-data.js'), path.join(docs, 'sample-data.js'));
fs.copyFileSync(path.join(root, 'tools', 'demo-api.js'), path.join(docs, 'demo-api.js'));
copyDir(path.join(root, 'dist'), path.join(docs, 'dist'));
copyDir(path.join(root, 'lib'), path.join(docs, 'lib'));
fs.writeFileSync(path.join(docs, '.nojekyll'), '');            // serve the files as they are
console.log('Demo built in ' + docs);
