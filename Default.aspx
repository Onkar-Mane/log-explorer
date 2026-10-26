<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Default.aspx.cs" Inherits="Default" ResponseEncoding="UTF-8" %>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Log Explorer</title>

    <!-- Compiled, purged Tailwind (built locally via `npm run build:css`) -->
    <link rel="stylesheet" href="dist/app.css?v=<%= AssetVersion %>" />

    <!-- Font Awesome (self-hosted) -->
    <link rel="stylesheet" href="lib/fontawesome/css/all.min.css" />

    <!-- Flatpickr (self-hosted, calendar / datetime picker) -->
    <link rel="stylesheet" href="lib/flatpickr/flatpickr.min.css" />
    <script src="lib/flatpickr/flatpickr.min.js"></script>

    <!-- Apply theme before first paint to avoid flash-of-wrong-theme (FOUC) -->
    <script>
        window.__UI = <%= UiSettingsJson %>;
        (function () {
            try {
                var t = localStorage.getItem('lv_theme');
                if (t !== 'light' && t !== 'dark') {
                    var mode = (window.__UI && window.__UI.defaultMode) || 'dark';
                    t = mode === 'system' ? ((window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) ? 'light' : 'dark') : (mode === 'light' ? 'light' : 'dark');
                }
                document.documentElement.setAttribute('data-theme', t);
                var ui = window.__UI || {}, pref = localStorage.getItem('lv_palette');
                // a signed-in admin / super admin first gets the style chosen for that role, if one is set
                var style = (ui.role === 'superadmin' && ui.superStyle) || (ui.role === 'admin' && ui.adminStyle) || ui.appStyle || 'slate';
                if (ui.allowUserStyles && pref && (ui.userStyles || []).indexOf(pref) >= 0) style = pref;
                if (style === 'web' || style === 'midnight' || style === 'slate') document.documentElement.setAttribute('data-palette', style);
            } catch (e) {
                document.documentElement.setAttribute('data-theme', 'dark');
            }
        })();
        window.__DIAG = <%= DiagEnabled %>;
        window.__SERVER_OFFSET = <%= ServerUtcOffsetMinutes %>;
        window.__HIDE_BG = <%= HideBackgroundDefault %>;
    </script>

    <style>
        /* ------------------------------------------------------------------
           Design tokens. Neutrals lean blue-green graphite; one accent (teal)
           is reserved for interactive state, so severity colours stay unique.
           Legacy --lv-* names are kept because the render templates use them.
           ------------------------------------------------------------------ */
        :root {
            --lv-bg: #0f1417;
            --lv-card: #151b1f;
            --lv-surface: #1a2125;
            --lv-surface-2: #212a30;
            --lv-border: #28333a;
            --lv-border-strong: #384650;
            --lv-input: #101619;

            --lv-text: #e6ecef;
            --lv-muted: #97a5ae;
            --lv-muted-2: #7f8d96;

            --lv-primary: #3cc9b8;
            --lv-primary-hover: #66d9cb;
            --lv-primary-ink: #06211e;
            --lv-primary-glow: rgba(60, 201, 184, 0.16);

            --lv-success: #34c58a;
            --lv-error: #f0605d;
            --lv-warning: #e8a23a;
            --lv-info: #5aa9e6;
            --lv-debug: #8795a1;

            --lv-picker-bg: #151b1f;
            --lv-picker-border: #384650;
            --lv-picker-text: #e6ecef;

            --st-kw: #66d9cb;
            --st-fn: #d3dce1;
            --st-line: #7f8d96;
            --st-ns: #97a5ae;

            --page-max: 2400px;   /* header and content share this, so their edges always line up */
            color-scheme: dark;
            --series-1: #3987e5;
            --series-2: #d95926;
            --series-3: #199e70;
            --series-4: #c98500;
            --series-5: #d55181;
            --series-6: #008300;
            --series-7: #9085e9;
            --series-8: #e66767;
            --radius: 6px;
            --mono: "Cascadia Mono", "Cascadia Code", "JetBrains Mono", Consolas, "SFMono-Regular", Menlo, monospace;
            --sans: "Segoe UI Variable Text", "Segoe UI", system-ui, -apple-system, "Helvetica Neue", Arial, sans-serif;
        }

        :root[data-theme="light"] {
            color-scheme: light;
            --series-1: #2a78d6;
            --series-2: #eb6834;
            --series-3: #1baf7a;
            --series-4: #eda100;
            --series-5: #e87ba4;
            --series-6: #008300;
            --series-7: #6250d6;
            --series-8: #e34948;
            --lv-bg: #f2f5f6;
            --lv-card: #ffffff;
            --lv-surface: #f7f9fa;
            --lv-surface-2: #edf1f3;
            --lv-border: #dde4e8;
            --lv-border-strong: #c4cfd5;
            --lv-input: #ffffff;

            --lv-text: #151c20;
            --lv-muted: #526169;
            --lv-muted-2: #64737c;

            --lv-primary: #0b7f75;
            --lv-primary-hover: #086a62;
            --lv-primary-ink: #ffffff;
            --lv-primary-glow: rgba(11, 127, 117, 0.14);

            --lv-error: #c8322f;
            --lv-warning: #a8620a;
            --lv-info: #1d6fb5;
            --lv-debug: #5f6e78;

            --lv-picker-bg: #ffffff;
            --lv-picker-border: #c4cfd5;
            --lv-picker-text: #151c20;

            --st-kw: #0b7f75;
            --st-fn: #26333a;
            --st-line: #8796a0;
            --st-ns: #5d6c75;
        }

        /* Style "teal" (the default look when no other style is chosen): jet black #0A0A0A, cerulean #007BA7 for everything
           you can click, neon rose #FF2D95 only for the header line and the selected tab, so it never reads as an error colour.
           On black, cerulean text is lifted to #2AA8DB so links stay readable (4.5:1 or more); buttons keep the cerulean family. */
        :root:not([data-palette]) {
            --lv-bg: #0a0a0a;
            --lv-card: #121212;
            --lv-surface: #171717;
            --lv-surface-2: #1f1f1f;
            --lv-border: #262626;
            --lv-border-strong: #393939;
            --lv-input: #0e0e0e;
            --lv-text: #ededed;
            --lv-muted: #a6a6a6;
            --lv-muted-2: #8c8c8c;
            --lv-primary: #2aa8db;
            --lv-primary-hover: #5cc0e8;
            --lv-primary-ink: #04121a;
            --lv-primary-glow: rgba(0, 123, 167, 0.28);
            --lv-picker-bg: #121212;
            --lv-picker-border: #393939;
            --lv-picker-text: #ededed;
            --st-kw: #5cc0e8;
            --st-fn: #e0e0e0;
            --st-line: #8c8c8c;
            --st-ns: #a6a6a6;
            --tab-accent: #ff2d95;
            --topbar-bg: #0a0a0a;
            --topbar-line: linear-gradient(90deg, #007ba7, #ff2d95);
            --freq-fill: linear-gradient(90deg, #007ba7, #ff2d95);
            --page-glow: radial-gradient(900px 320px at 100% -80px, rgba(255, 45, 149, .10), transparent 70%), radial-gradient(900px 380px at 0% -120px, rgba(0, 123, 167, .16), transparent 70%);
        }
        :root:not([data-palette])[data-theme="light"] {
            --lv-bg: #f4f6f8;
            --lv-card: #ffffff;
            --lv-surface: #f8f9fb;
            --lv-surface-2: #eef1f4;
            --lv-border: #e0e4e9;
            --lv-border-strong: #c7ced6;
            --lv-input: #ffffff;
            --lv-text: #0a0a0a;
            --lv-muted: #4f5761;
            --lv-muted-2: #646c76;
            --lv-primary: #007ba7;
            --lv-primary-hover: #00668b;
            --lv-primary-ink: #ffffff;
            --lv-primary-glow: rgba(0, 123, 167, 0.14);
            --lv-picker-bg: #ffffff;
            --lv-picker-border: #c7ced6;
            --lv-picker-text: #0a0a0a;
            --st-kw: #007ba7;
            --st-fn: #1a1a1a;
            --st-line: #7a828c;
            --st-ns: #4f5761;
            --tab-accent: #e8137f;
            --topbar-bg: #ffffff;
            --page-glow: radial-gradient(900px 300px at 100% -80px, rgba(255, 45, 149, .07), transparent 70%), radial-gradient(900px 340px at 0% -120px, rgba(0, 123, 167, .09), transparent 70%);
        }

        /* Style: "Web". Blue is the interactive colour; the red stays on the logo, header and tab
           underline only, so it is never confused with the red used for errors. */
        :root[data-palette="web"] {
            --lv-bg: #070b1a;
            --lv-card: #0d1330;
            --lv-surface: #121a40;
            --lv-surface-2: #1a2455;
            --lv-border: #26306b;
            --lv-border-strong: #36428f;
            --lv-input: #0a1028;
            --lv-text: #eaf0ff;
            --lv-muted: #9aa8d8;
            --lv-muted-2: #8392c4;
            --lv-primary: #4c8dff;
            --lv-primary-hover: #7aaaff;
            --lv-primary-ink: #04122e;
            --lv-primary-glow: rgba(76, 141, 255, 0.2);
            --lv-picker-bg: #0d1330;
            --lv-picker-border: #36428f;
            --lv-picker-text: #eaf0ff;
            --st-kw: #7aaaff;
            --st-fn: #dbe4ff;
            --st-line: #8392c4;
            --st-ns: #9aa8d8;
            --brand-bg: #e62429;
            --brand-ink: #ffffff;
            --tab-accent: #e62429;
            --freq-fill: linear-gradient(90deg, #e62429, #4c8dff);
            --topbar-bg: linear-gradient(100deg, #0b1445 0%, #14236b 45%, #5a1230 80%, #8c1423 100%);
            --web-stroke: #b9ccff;
            --web-opacity: .55;
            --page-glow: radial-gradient(1100px 420px at 100% -60px, rgba(230, 36, 41, .20), transparent 70%), radial-gradient(1000px 520px at 0% -120px, rgba(76, 141, 255, .20), transparent 70%);
            --logo-glow: drop-shadow(0 0 7px rgba(230, 36, 41, .6));
            --web-fixed-opacity: .30;
            --dot-color: rgba(255, 255, 255, .20);
            --thread-color: rgba(255, 255, 255, .7);
            --btn-glow: 0 0 0 1px rgba(76, 141, 255, .5), 0 8px 22px -8px rgba(76, 141, 255, .9);
            --topbar-web: none;
            --topbar-line: linear-gradient(90deg, #e62429, #4c8dff);
        }
        :root[data-palette="web"][data-theme="light"] {
            --lv-bg: #eef1fb;
            --lv-card: #ffffff;
            --lv-surface: #f5f7fd;
            --lv-surface-2: #e8ecf8;
            --lv-border: #d6dcf0;
            --lv-border-strong: #bcc6e6;
            --lv-input: #ffffff;
            --lv-text: #12183a;
            --lv-muted: #4a5686;
            --lv-muted-2: #5c6896;
            --lv-primary: #1f55d6;
            --lv-primary-hover: #1743ad;
            --lv-primary-ink: #ffffff;
            --lv-primary-glow: rgba(31, 85, 214, 0.15);
            --lv-picker-bg: #ffffff;
            --lv-picker-border: #bcc6e6;
            --lv-picker-text: #12183a;
            --st-kw: #1f55d6;
            --st-fn: #1d2550;
            --st-line: #8a95bf;
            --st-ns: #566190;
            --brand-bg: #d71920;
            --tab-accent: #d71920;
            --topbar-bg: linear-gradient(100deg, #ffffff 0%, #e3eafc 50%, #fbd5da 100%);
            --web-stroke: #2c4aa8;
            --web-opacity: .42;
            --page-glow: radial-gradient(1100px 380px at 100% -60px, rgba(215, 25, 32, .10), transparent 70%), radial-gradient(1000px 460px at 0% -120px, rgba(31, 85, 214, .12), transparent 70%);
            --logo-glow: none;
            --web-fixed-opacity: .24;
            --dot-color: rgba(31, 85, 214, .22);
            --thread-color: rgba(18, 24, 58, .55);
            --btn-glow: 0 8px 20px -10px rgba(31, 85, 214, .8);
            --topbar-web: none;
        }

        /* Style: "Slate". A calm factory-floor look: slate #3a4d5d for actions, a deep red #e1000f
           for the selected tab and the header line, quiet greys. Red never marks an action, so it is not confused with errors. */
        :root[data-palette="slate"] {
            --lv-bg: #10151a;
            --lv-card: #171e25;
            --lv-surface: #1c252d;
            --lv-surface-2: #232e38;
            --lv-border: #2a3540;
            --lv-border-strong: #3a4754;
            --lv-input: #121920;
            --lv-text: #e8edf1;
            --lv-muted: #a0acb7;
            --lv-muted-2: #8995a1;
            --lv-primary: #8fb0cc;
            --lv-primary-hover: #aac5dc;
            --lv-primary-ink: #0d1822;
            --lv-primary-glow: rgba(143, 176, 204, 0.18);
            --lv-picker-bg: #171e25;
            --lv-picker-border: #3a4754;
            --lv-picker-text: #e8edf1;
            --st-kw: #aac5dc;
            --st-fn: #dfe6ec;
            --st-line: #8995a1;
            --st-ns: #a0acb7;
            --tab-accent: #ff3b45;
            --topbar-bg: #19222b;
            --topbar-line: linear-gradient(90deg, #e1000f, #e1000f 30%, #3a4d5d 30%);
            --freq-fill: linear-gradient(90deg, #4e677c, #8fb0cc);
        }
        :root[data-palette="slate"][data-theme="light"] {
            --lv-bg: #f2f3f5;
            --lv-card: #ffffff;
            --lv-surface: #f7f8f9;
            --lv-surface-2: #ededed;
            --lv-border: #e1e4e8;
            --lv-border-strong: #c9ced4;
            --lv-input: #ffffff;
            --lv-text: #222c35;
            --lv-muted: #5f6973;
            --lv-muted-2: #6c7680;
            --lv-primary: #3a4d5d;
            --lv-primary-hover: #2c3b48;
            --lv-primary-ink: #ffffff;
            --lv-primary-glow: rgba(58, 77, 93, 0.14);
            --lv-picker-bg: #ffffff;
            --lv-picker-border: #c9ced4;
            --lv-picker-text: #222c35;
            --st-kw: #3a4d5d;
            --st-fn: #222c35;
            --st-line: #828c96;
            --st-ns: #5f6973;
            --tab-accent: #e1000f;
            --topbar-bg: #ffffff;
            --freq-fill: linear-gradient(90deg, #4e677c, #3a4d5d);
        }

        /* Style: "Midnight". Charcoal with searchlight yellow. A skyline strip and a searchlight. */
        :root[data-palette="midnight"] {
            --lv-bg: #0a0a0c;
            --lv-card: #121316;
            --lv-surface: #191b1f;
            --lv-surface-2: #22252a;
            --lv-border: #2b2e34;
            --lv-border-strong: #3c4047;
            --lv-input: #0e0f12;
            --lv-text: #ececec;
            --lv-muted: #a3a7ae;
            --lv-muted-2: #8d9199;
            --lv-primary: #f5c518;
            --lv-primary-hover: #ffd84d;
            --lv-primary-ink: #141100;
            --lv-primary-glow: rgba(245, 197, 24, 0.2);
            --lv-picker-bg: #121316;
            --lv-picker-border: #3c4047;
            --lv-picker-text: #ececec;
            --st-kw: #f5c518;
            --st-fn: #e8e8e8;
            --st-line: #8d9199;
            --st-ns: #a3a7ae;
            --brand-bg: #f5c518;
            --brand-ink: #141100;
            --tab-accent: #f5c518;
            --freq-fill: linear-gradient(90deg, #f5c518, #ff9f1a);
            --topbar-bg: linear-gradient(100deg, #1c1e24 0%, #17181d 50%, #2a2410 100%);
            --skyline-fill: #000000;
            --skyline-opacity: .92;
            --signal-glow: rgba(245, 197, 24, .30);
            --signal-sweep: rgba(245, 197, 24, .12);
            --page-glow: radial-gradient(900px 300px at 70% -80px, rgba(245, 197, 24, .10), transparent 70%);
            --btn-glow: 0 0 0 1px rgba(245, 197, 24, .45), 0 8px 22px -8px rgba(245, 197, 24, .75);
        }
        :root[data-palette="midnight"][data-theme="light"] {
            --lv-bg: #eeeeef;
            --lv-card: #ffffff;
            --lv-surface: #f6f6f7;
            --lv-surface-2: #ebebed;
            --lv-border: #dcdce0;
            --lv-border-strong: #c4c4ca;
            --lv-input: #ffffff;
            --lv-text: #17181a;
            --lv-muted: #55575d;
            --lv-muted-2: #666870;
            --lv-primary: #946c00;
            --lv-primary-hover: #7a5a00;
            --lv-primary-ink: #ffffff;
            --tab-accent: #946c00;   /* bright yellow vanishes on the light header; a deep gold reads as selected */
            --lv-primary-glow: rgba(148, 108, 0, 0.16);
            --lv-picker-bg: #ffffff;
            --lv-picker-border: #c4c4ca;
            --lv-picker-text: #17181a;
            --st-kw: #946c00;
            --st-fn: #26272a;
            --st-line: #8c8e95;
            --st-ns: #5a5c62;
            --topbar-bg: linear-gradient(100deg, #ffffff 0%, #f2f2f3 60%, #fdf1bd 100%);
            --skyline-fill: #1a1a1a;
            --skyline-opacity: .16;
            --signal-glow: rgba(245, 197, 24, .45);
            --signal-sweep: rgba(245, 197, 24, .22);
            --page-glow: radial-gradient(900px 300px at 70% -80px, rgba(245, 197, 24, .16), transparent 70%);
            --btn-glow: 0 8px 20px -10px rgba(148, 108, 0, .8);
        }

        body {
            font-family: var(--sans);
            font-size: 14px;
            -webkit-font-smoothing: antialiased;
            text-rendering: optimizeLegibility;
        }

        .tabular { font-variant-numeric: tabular-nums; }
        .mono    { font-family: var(--mono); }
        .transition-standard { transition: background .15s ease, color .15s ease, border-color .15s ease; }

        .pretty-scroll::-webkit-scrollbar { width: 8px; height: 8px; }
        .pretty-scroll::-webkit-scrollbar-track { background: transparent; }
        .pretty-scroll::-webkit-scrollbar-thumb { background: var(--lv-border-strong); border-radius: 8px; }
        .pretty-scroll::-webkit-scrollbar-thumb:hover { background: var(--lv-muted-2); }

        .lv-text    { color: var(--lv-text); }
        .lv-muted   { color: var(--lv-muted); }
        .lv-muted-2 { color: var(--lv-muted-2); }

        :focus-visible { outline: 2px solid var(--lv-primary); outline-offset: 2px; }

        /* ---------- Top bar ---------- */
        .topbar {
            position: sticky;
            top: 0;
            z-index: 40;
            background: var(--topbar-web, none) right top / auto 100% no-repeat, var(--topbar-bg, var(--lv-card));
            border-bottom: 1px solid var(--lv-border);
        }
        .topbar::after { content: ""; position: absolute; left: 0; right: 0; bottom: -1px; height: 2px; background: var(--topbar-line, transparent); pointer-events: none; }
        .topbar-inner {
            display: flex;
            align-items: stretch;
            gap: 2rem;
            max-width: var(--page-max);
            margin: 0 auto;
            padding: 0 1rem;
            min-height: 3.25rem;
        }
        .brand { display: flex; align-items: center; gap: .625rem; }
        .brand-mark {
            display: grid;
            place-items: center;
            width: 1.75rem;
            height: 1.75rem;
            border-radius: var(--radius);
            background: var(--brand-bg, var(--lv-primary));
            color: var(--brand-ink, var(--lv-primary-ink));
            font-size: .75rem;
        }
        body { background-image: var(--page-glow, none); background-repeat: no-repeat; }
        .topbar-inner { position: relative; z-index: 1; }
        .web-art { display: none; position: absolute; right: 0; top: 0; height: 100%; width: auto; pointer-events: none; z-index: 0; }
        .web-art path { stroke: var(--web-stroke, currentColor); stroke-opacity: var(--web-opacity, .4); stroke-width: 1; stroke-dasharray: 1; stroke-dashoffset: 0; }
        :root[data-palette="web"] .web-art { display: block; }
        /* the web draws itself once when the page opens, then breathes slowly */
        :root[data-palette="web"] .web-ray { animation: web-draw .9s ease-out both; animation-delay: calc(var(--i) * 70ms); }
        :root[data-palette="web"] .web-ring { animation: web-draw 1.1s ease-out both; animation-delay: calc(450ms + var(--i) * 90ms); }
        :root[data-palette="web"] .web-art { animation: web-breathe 7s ease-in-out 2.5s infinite; }
        @keyframes web-draw { from { stroke-dashoffset: 1; } to { stroke-dashoffset: 0; } }
        @keyframes web-breathe { 0%, 100% { opacity: 1; } 50% { opacity: .55; } }

        /* a thread of colour that slowly runs along the bottom of the header */
        :root[data-palette="web"] .topbar::after {
            height: 3px;
            background: repeating-linear-gradient(90deg, #e62429, #4c8dff 25%, #e62429 50%);
            background-size: 200% 100%;
            animation: thread-run 9s linear infinite;
        }
        @keyframes thread-run { from { background-position-x: 0; } to { background-position-x: 200%; } }

        /* "spider-sense": the logo gives a soft red tingle now and then */
        :root[data-palette="web"] .brand-logo { filter: var(--logo-glow, none); animation: spider-sense 6s ease-in-out infinite; }
        @keyframes spider-sense {
            0%, 80%, 100% { filter: var(--logo-glow, none); }
            88% { filter: drop-shadow(0 0 14px rgba(230, 36, 41, .95)) drop-shadow(0 0 3px rgba(230, 36, 41, .9)); }
        }
        :root[data-palette="web"] .lv-btn-primary { box-shadow: var(--btn-glow); }
        :root[data-palette="web"] .lv-btn-primary:hover { box-shadow: var(--btn-glow), 0 0 22px rgba(76, 141, 255, .55); }
        :root[data-palette="web"] .lv-row:hover { box-shadow: inset 3px 0 0 0 var(--lv-primary), 0 0 0 1px color-mix(in srgb, var(--lv-primary) 35%, transparent); }
        :root[data-palette="web"] .lv-row[data-sev="error"]:hover { box-shadow: inset 3px 0 0 0 var(--lv-error), 0 0 0 1px color-mix(in srgb, var(--lv-primary) 35%, transparent); }
        :root[data-palette="web"] .lv-table-container { box-shadow: 0 0 0 1px color-mix(in srgb, var(--lv-primary) 25%, transparent), 0 18px 40px -24px rgba(76, 141, 255, .45); }
        :root[data-palette="web"] .freq-bar > i { animation: bar-grow .32s var(--ease-out-strong) both; transform-origin: left; }
        @keyframes bar-grow { from { transform: scaleX(.04); } to { transform: scaleX(1); } }
        :root[data-palette="web"] thead th { border-bottom-color: color-mix(in srgb, var(--lv-primary) 45%, var(--lv-border)); }

        /* Spider-Verse print look: halftone dots fading across the header, and a slight colour misregistration on the title */
        :root[data-palette="web"] .topbar { overflow: visible; }
        :root[data-palette="web"] .topbar-inner::before {
            content: ""; position: absolute; left: 0; top: 0; right: 0; bottom: 0; z-index: -1; pointer-events: none;
            background: radial-gradient(circle, var(--dot-color) 1.1px, transparent 1.7px) 0 0 / 9px 9px;
            -webkit-mask-image: linear-gradient(90deg, #000 0%, rgba(0, 0, 0, .0) 60%);
            mask-image: linear-gradient(90deg, #000 0%, rgba(0, 0, 0, 0) 60%);
        }
        :root[data-palette="web"] .brand-name { text-shadow: 1.2px 0 rgba(230, 36, 41, .75), -1.2px 0 rgba(76, 141, 255, .75); }
        :root[data-palette="web"][data-theme="light"] .brand-name { text-shadow: 1px 0 rgba(215, 25, 32, .45), -1px 0 rgba(31, 85, 214, .45); }

        /* a small spider that keeps lowering itself on a thread and swinging, inside the header */
        .spidey { display: none; position: absolute; left: 64%; top: 0; width: 38px; margin-left: -19px; z-index: 2; transform-origin: 50% 0; pointer-events: none; }
        :root[data-palette="web"] .spidey { display: block; animation: spidey-swing 4.6s ease-in-out infinite; }
        .spidey-thread { display: block; width: 1px; margin: 0 auto; height: 10px; background: var(--thread-color, #fff); animation: spidey-drop 11s ease-in-out infinite; }
        .spidey-body { display: block; width: 36px; height: 39px; margin: -1px auto 0; overflow: visible; }
        .spidey-body .eye { transform-box: fill-box; transform-origin: 50% 50%; animation: spidey-blink 5.5s infinite; }
        @keyframes spidey-swing { 0%, 100% { transform: rotate(-9deg); } 50% { transform: rotate(9deg); } }
        @keyframes spidey-drop { 0%, 12% { height: 6px; } 45%, 62% { height: 24px; } 100% { height: 6px; } }
        @keyframes leg-left { from { transform: rotate(-9deg); } to { transform: rotate(9deg); } }
        @keyframes leg-right { from { transform: rotate(9deg); } to { transform: rotate(-9deg); } }
        @keyframes spidey-blink { 0%, 92%, 100% { transform: scaleY(1); } 95% { transform: scaleY(.1); } }
        /* while something loads he works harder: lowers himself further and bobs on the thread */
        body.is-busy .spidey-thread { animation: spidey-work 1.5s ease-in-out infinite; }
        body.is-busy .spidey { animation-duration: 1.8s; }
        @keyframes spidey-work { 0%, 100% { height: 14px; } 50% { height: 34px; } }
        @media (max-width: 900px) { .spidey { left: 47%; } }

        /* comic "glitch" when you hover the main button */
        @keyframes spider-glitch {
            0% { transform: translate(0); text-shadow: none; }
            20% { transform: translate(-1.5px, .5px); text-shadow: 2px 0 #e62429, -2px 0 #00e5ff; }
            40% { transform: translate(1.5px, -.5px); text-shadow: -2px 0 #e62429, 2px 0 #00e5ff; }
            60% { transform: translate(-1px, 0); text-shadow: 1px 0 #e62429, -1px 0 #00e5ff; }
            100% { transform: translate(0); text-shadow: none; }
        }
        @media (hover: hover) and (pointer: fine) { :root[data-palette="web"] .lv-btn-primary:hover { animation: spider-glitch .3s steps(2, end) 1; } }

        /* Midnight: skyline along the bottom of the header, a searchlight that sweeps across it, a scanning yellow line */
        .skyline { display: none; position: absolute; left: 0; right: 0; bottom: 0; width: 100%; height: 100%; pointer-events: none; z-index: 0; fill: var(--skyline-fill, #000); opacity: var(--skyline-opacity, .5); }
        .signal { display: none; position: absolute; inset: 0; pointer-events: none; z-index: 0; }
        :root[data-palette="midnight"] .skyline { display: block; }
        :root[data-palette="midnight"] .signal {
            display: block;
            background:
                linear-gradient(100deg, transparent 42%, var(--signal-sweep) 50%, transparent 58%) 0 0 / 260% 100% no-repeat,
                radial-gradient(150px 70px at 74% 0%, var(--signal-glow), transparent 72%);
            animation: searchlight 10s ease-in-out infinite;
        }
        @keyframes searchlight { 0% { background-position: 120% 0, 0 0; } 55%, 100% { background-position: -30% 0, 0 0; } }
        :root[data-palette="midnight"] .topbar::after {
            height: 2px;
            background: linear-gradient(90deg, transparent, #f5c518, transparent) -40% 0 / 35% 100% no-repeat, rgba(245, 197, 24, .35);
            animation: scan-run 5.5s linear infinite;
        }
        @keyframes scan-run { from { background-position: -40% 0, 0 0; } to { background-position: 140% 0, 0 0; } }
        :root[data-palette="midnight"] .lv-btn-primary { box-shadow: var(--btn-glow); }
        :root[data-palette="midnight"] .lv-btn-primary:hover { box-shadow: var(--btn-glow), 0 0 20px rgba(245, 197, 24, .5); }
        :root[data-palette="midnight"] .lv-table-container { box-shadow: 0 0 0 1px color-mix(in srgb, var(--lv-primary) 22%, transparent), 0 18px 40px -26px rgba(245, 197, 24, .4); }
        :root[data-palette="midnight"] thead th { border-bottom-color: color-mix(in srgb, var(--lv-primary) 45%, var(--lv-border)); }
        :root[data-palette="midnight"] .freq-bar > i { animation: bar-grow .32s var(--ease-out-strong) both; transform-origin: left; }

        /* pinned group bar inside an open group: stays just under the table header while its occurrences scroll */
        .detail-sticky {
            position: sticky;
            top: var(--thead-h, 2.1rem);
            z-index: 15;
            display: flex;
            align-items: center;
            gap: .75rem;
            margin: -1rem -1rem .75rem;
            padding: .5rem 1rem;
            background: var(--lv-surface-2);
            border-bottom: 1px solid var(--lv-border-strong);
            box-shadow: inset 3px 0 0 0 var(--lv-error), 0 6px 12px -8px rgba(0, 0, 0, .5);
        }
        .detail-sticky[data-sev="warning"] { box-shadow: inset 3px 0 0 0 var(--lv-warning), 0 6px 12px -8px rgba(0, 0, 0, .5); }
        .detail-sticky[data-sev="info"] { box-shadow: inset 3px 0 0 0 var(--lv-info), 0 6px 12px -8px rgba(0, 0, 0, .5); }
        .detail-sticky-msg { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: .875rem; font-weight: 600; color: var(--lv-text); }
        .detail-sticky-meta { font-size: .8125rem; color: var(--lv-muted); white-space: nowrap; }
        .detail-collapse { height: 1.75rem; }

        /* admin entry: far right of the header, apart from the everyday controls so it is never clicked by accident */
        .admin-sep { align-self: center; width: 1px; height: 1.25rem; margin: 0 .75rem 0 1.25rem; background: var(--lv-border-strong); }
        .admin-btn {
            position: relative;
            display: inline-grid;
            place-items: center;
            width: 2rem;
            height: 2rem;
            padding: 0;
            font-size: .8125rem;
            color: var(--lv-muted-2);
            background: transparent;
            border: 1px solid transparent;
            border-radius: 50%;
            opacity: .65;
            cursor: pointer;
            transition: opacity .15s ease, color .15s ease, border-color .15s ease, background .15s ease;
        }
        .admin-btn:hover, .admin-btn:focus-visible { opacity: 1; color: var(--lv-text); border-color: var(--lv-border-strong); background: var(--lv-surface); }
        .admin-btn.signed-in { opacity: 1; color: var(--lv-text); }
        .admin-icon .icon-tick { display: none; }
        .admin-btn.signed-in .icon-tick { display: block; stroke: var(--lv-success); }
        .admin-btn.signed-in .icon-lock { display: none; }
        .admin-btn:hover .admin-icon { transform: scale(1.08); }
        .admin-icon { transition: transform .15s ease; }
        .admin-btn.signed-in::after { content: ""; position: absolute; right: 1px; top: 1px; width: .5rem; height: .5rem; border-radius: 50%; background: var(--lv-success); box-shadow: 0 0 0 2px var(--lv-card); }

        /* paging */
        .lv-row { scroll-margin-top: var(--thead-h, 2.1rem); }
        .pager { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: .5rem 1rem; padding: .5rem 1rem; border-top: 1px solid var(--lv-border); background: var(--lv-surface); }
        .pager.hidden { display: none; }
        .pg-nav, .det-pager { display: inline-flex; align-items: center; gap: .375rem; }
        .pg-info { font-size: .8125rem; color: var(--lv-muted); }
        .pg-gap { padding: 0 .25rem; color: var(--lv-muted-2); }
        .pg-btn { min-width: 2rem; height: 2rem; padding: 0 .5rem; font: inherit; font-size: .8125rem; font-weight: 600; color: var(--lv-muted); background: var(--lv-card); border: 1px solid var(--lv-border); border-radius: var(--radius); cursor: pointer; transition: color .12s ease, border-color .12s ease, background .12s ease; }
        .pg-btn:hover:not([disabled]) { color: var(--lv-text); border-color: var(--lv-border-strong); }
        .pg-btn[disabled] { opacity: .4; cursor: default; }
        .pg-btn.current { color: var(--lv-primary-ink); background: var(--lv-primary); border-color: transparent; }
        .pg-rows { display: inline-flex; align-items: center; gap: .5rem; font-size: .8125rem; color: var(--lv-muted); }
        .pg-rows select { width: auto; height: 2rem; padding: 0 .5rem; }
        .det-pager-bot { justify-content: flex-end; margin-top: .75rem; }
        .detail-sticky .det-pager .pg-btn { height: 1.75rem; min-width: 1.75rem; }

        /* ---------- less clutter on the error list ---------- */
        .collapsed { display: none; }
        .more-btn { display: inline-flex; align-items: center; gap: .5rem; height: 2rem; padding: 0 .75rem; font: inherit; font-size: .8125rem; font-weight: 600; color: var(--lv-muted); background: transparent; border: 1px solid var(--lv-border); border-radius: var(--radius); cursor: pointer; transition: color .12s ease, background .12s ease, border-color .12s ease; }
        .more-btn:hover { color: var(--lv-text); border-color: var(--lv-border-strong); }
        .more-btn[aria-expanded="true"] { color: var(--lv-text); background: var(--lv-surface); }
        .more-btn.hidden { display: none; }
        .more-count { min-width: 1.25rem; padding: 0 .375rem; text-align: center; font-size: .6875rem; font-weight: 700; line-height: 1.25rem; color: var(--lv-primary-ink); background: var(--lv-primary); border-radius: 999px; }
        .more-count.hidden { display: none; }
        table.hide-caller .col-caller, table.hide-sites .col-sites, table.hide-server .col-server { display: none; }
        .seg button.active { color: var(--lv-primary-ink); background: var(--lv-primary); }
        .src-tab.hidden { display: none; }

        /* ---------- dashboard ---------- */
        .view-title { margin: 0 0 1rem; font-size: 1.125rem; font-weight: 650; color: var(--lv-text); }
        .settings-page { padding: 1.25rem 1.5rem; background: var(--lv-card); border: 1px solid var(--lv-border); border-radius: 8px; }
        .settings-page .tab-panel { max-height: none; overflow: visible; display: grid; grid-template-columns: repeat(auto-fit, minmax(min(24rem, 100%), 1fr)); gap: 1.75rem 3rem; align-items: start; }
        .settings-page .tab-panel.hidden { display: none; }
        .settings-page .tabs { flex-wrap: wrap; }   /* five settings tabs wrap on a phone */
        .sg { min-width: 0; }
        .modal-note .mono { overflow-wrap: anywhere; word-break: break-all; }
        .sg-title { margin: 0 0 .5rem; padding-bottom: .5rem; font-size: .9375rem; font-weight: 650; color: var(--lv-text); border-bottom: 1px solid var(--lv-border); }
        .sg .modal-label:first-of-type { margin-top: .5rem; }
        .settings-page .modal-actions { margin-top: 1.25rem; padding-top: 1rem; border-top: 1px solid var(--lv-border); }
        .settings-page .audit-box { max-height: 22rem; }
        .dash-bar { display: flex; flex-wrap: wrap; align-items: center; gap: .75rem 1rem; margin-bottom: 1rem; }
        .dash-body { transition: opacity .15s ease; }
        .dash-body.is-loading { opacity: .92; }   /* colours must stay readable while refreshing */
        .dash-kpis { display: grid; grid-template-columns: minmax(15rem, 1.5fr) repeat(4, minmax(9rem, 1fr)); margin-bottom: 1rem; background: var(--lv-card); border: 1px solid var(--lv-border); border-radius: 8px; }
        .kpi { padding: 1rem 1.25rem; border-left: 1px solid var(--lv-border); min-width: 0; }
        .kpi:first-child { border-left: 0; }
        .kpi-label { font-size: .8125rem; color: var(--lv-muted); }
        .kpi-value { margin-top: .25rem; font-size: 1.75rem; font-weight: 650; line-height: 1.2; color: var(--lv-text); }
        .kpi-hero { display: flex; align-items: center; }
        .kpi-hero .kpi-value { margin-top: 0; font-size: 3rem; line-height: 1.1; }
        .kpi-small { font-size: 1.125rem; line-height: 2.1rem; }
        .panel { margin-bottom: 1rem; padding: 1rem 1.25rem; background: var(--lv-card); border: 1px solid var(--lv-border); border-radius: 8px; min-width: 0; }
        .panel-title { margin: 0 0 .5rem; font-size: .9375rem; font-weight: 650; color: var(--lv-text); }
        .panel-note { margin: 0 0 .75rem; font-size: .8125rem; color: var(--lv-muted); line-height: 1.45; }
        .dash-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(24rem, 100%), 1fr)); gap: 1rem; }
        @media (max-width: 900px) {
            .dash-kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); }
            .kpi-hero { grid-column: 1 / -1; border-bottom: 1px solid var(--lv-border); }
            .kpi { border-left: 0; }
            .kpi:nth-child(odd):not(.kpi-hero) { border-right: 1px solid var(--lv-border); }
            .kpi:nth-child(n+4) { border-top: 1px solid var(--lv-border); }
            .kpi-hero .kpi-value { font-size: 2.5rem; }
            .panel { padding: .75rem 1rem; }
            .dash-bar .dash-signout { margin-left: 0 !important; }
        }
        .dash-grid .panel { margin-bottom: 0; }
        .legend { display: flex; flex-wrap: wrap; gap: .25rem 1.25rem; margin-bottom: .5rem; font-size: .8125rem; color: var(--lv-muted); }
        .legend .sw { display: inline-block; width: .75rem; height: .75rem; margin-right: .375rem; border-radius: 2px; vertical-align: -1px; }
        .chart { position: relative; }
        .chart svg { display: block; max-width: 100%; }
        .chart .g { stroke: var(--lv-border); stroke-width: 1; }
        .chart .ax { fill: var(--lv-muted-2); font-size: 11px; font-family: var(--sans); }
        .s1 { fill: var(--series-1); background: var(--series-1); }
        .s2 { fill: var(--series-2); background: var(--series-2); }
        .legend .sw.s1, .legend .sw.s2, .tip-row .key.s1, .tip-row .key.s2 { fill: none; }
        .chart .hit { fill: transparent; }
        .chart .hit:hover { fill: color-mix(in srgb, var(--lv-text) 7%, transparent); }
        .chart-tip { position: absolute; z-index: 5; min-width: 13rem; padding: .5rem .75rem; pointer-events: none; font-size: .8125rem; color: var(--lv-muted); background: var(--lv-card); border: 1px solid var(--lv-border-strong); border-radius: 6px; box-shadow: 0 10px 24px -10px rgba(0, 0, 0, .5); }
        .chart-tip.hidden { display: none; }
        .tip-head { margin-bottom: .25rem; font-weight: 600; color: var(--lv-text); }
        .tip-row { display: flex; align-items: center; gap: .5rem; }
        .tip-row .key { display: inline-block; width: .875rem; height: 3px; border-radius: 2px; }
        .tip-row b { min-width: 1.5rem; color: var(--lv-text); }
        .chart-table summary { margin-top: .5rem; font-size: .8125rem; color: var(--lv-muted); cursor: pointer; }
        .chart-table > div { max-height: 14rem; overflow: auto; margin-top: .5rem; }
        .mini-table { width: 100%; border-collapse: collapse; font-size: .8125rem; }
        .mini-table th, .mini-table td { padding: .25rem .5rem; text-align: left; border-bottom: 1px solid var(--lv-border); }
        .mini-table .r, .jobs-table .r { text-align: right; }
        .matrix { position: relative; display: grid; gap: .25rem; }
        .mx-row { display: grid; grid-template-columns: minmax(8rem, 15rem) minmax(0, 1fr) 3.5rem; align-items: center; gap: .75rem; padding: .3rem .5rem; margin: 0 -.5rem; font: inherit; font-size: .8125rem; text-align: left; color: var(--lv-text); background: none; border: 0; border-radius: 6px; cursor: pointer; }
        .mx-row:hover { background: var(--lv-surface); }
        .mx-row.sel { background: color-mix(in srgb, var(--lv-primary) 12%, transparent); box-shadow: inset 3px 0 0 0 var(--lv-primary); }
        .mx-name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .mx-wrap { display: block; }
        .mx-track { display: flex; gap: 2px; height: 14px; }
        .mx-seg { display: block; flex-basis: 0; min-width: 3px; border-radius: 0; }
        .mx-seg:last-child { border-radius: 0 4px 4px 0; }
        .mx-total { text-align: right; font-weight: 600; }
        .tip-row.on b, .tip-row.on span { color: var(--lv-text); }
        .dash-bar .lv-input.msel-btn { height: 2rem; }
        .barlist { display: grid; gap: .125rem; }
        .bl-row { display: grid; grid-template-columns: minmax(0, 1fr) 7rem 3rem; align-items: center; gap: .125rem .75rem; padding: .375rem .5rem; margin: 0 -.5rem; font: inherit; font-size: .8125rem; text-align: left; color: var(--lv-text); background: none; border: 0; border-radius: 6px; }
        .bl-row.pick { cursor: pointer; }
        .bl-row.pick:hover { background: var(--lv-surface); }
        .bl-name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .bl-track { display: block; height: 10px; background: color-mix(in srgb, var(--series-1) 14%, transparent); border-radius: 0 5px 5px 0; }
        .bl-track i { display: block; height: 100%; background: var(--series-1); border-radius: 0 4px 4px 0; }
        .bl-val { text-align: right; font-weight: 600; color: var(--lv-text); }
        .bl-sub { grid-column: 1 / -1; font-size: .75rem; color: var(--lv-muted-2); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        #jobsBody { overflow-x: auto; }
        .jobs-table { width: 100%; min-width: 46rem; border-collapse: collapse; font-size: .8125rem; }
        .jobs-table th { padding: .5rem .75rem; text-align: left; font-weight: 600; color: var(--lv-muted); border-bottom: 1px solid var(--lv-border-strong); white-space: nowrap; }
        .jobs-table td { padding: .5rem .75rem; vertical-align: middle; border-bottom: 1px solid var(--lv-border); color: var(--lv-text); }
        .jobs-table .job-name { font-size: .8125rem; word-break: break-word; text-align: left; }
        .jobs-table .job-msg { max-width: 26rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: var(--lv-muted); }
        .spark { display: block; }
        .status { display: inline-flex; align-items: center; gap: .375rem; font-weight: 600; white-space: nowrap; }
        .st-crit { color: #d03b3b; }
        .st-warn { color: #fab219; }
        .st-ok { color: #0ca30c; }
        :root[data-theme="light"] .st-warn { color: #a86c00; }
        :root[data-theme="light"] .st-ok { color: #0a7a0a; }

        /* admin dialog: tabs, text areas, status */
        .tabs { display: flex; gap: .25rem; margin: 0 0 .75rem; border-bottom: 1px solid var(--lv-border); }
        .tab { padding: .5rem .75rem; font: inherit; font-size: .8125rem; font-weight: 600; color: var(--lv-muted); background: none; border: 0; border-bottom: 2px solid transparent; margin-bottom: -1px; cursor: pointer; }
        .tab:hover { color: var(--lv-text); }
        .tab.active { color: var(--lv-text); border-bottom-color: var(--tab-accent, var(--lv-primary)); }
        .tab-panel { max-height: 55vh; overflow-y: auto; padding-right: .25rem; }
        .tab-panel.hidden { display: none; }
        .modal-text { height: auto; padding: .5rem .75rem; font-family: var(--mono); font-size: .75rem; line-height: 1.5; resize: vertical; }
        .stat-row { padding: .5rem 0; border-bottom: 1px solid var(--lv-border); font-size: .8125rem; color: var(--lv-muted); overflow-wrap: anywhere; }
        .stat-row b { color: var(--lv-text); }
        .stat-ok { color: var(--lv-success); font-weight: 600; }
        .stat-bad { color: var(--lv-error); font-weight: 600; }
        .audit-box { margin: .25rem 0 0; padding: .625rem; max-height: 9rem; overflow: auto; font-family: var(--mono); font-size: .6875rem; line-height: 1.5; color: var(--lv-muted); background: var(--lv-surface); border: 1px solid var(--lv-border); border-radius: var(--radius); white-space: pre-wrap; overflow-wrap: anywhere; }

        /* Midnight: the searchlight, a few bats on the wing, and lit windows in the skyline */
        .batsignal, .win { display: none; }
        .signal { overflow: hidden; }   /* the bats start just outside the header; never let them widen the page */
        :root[data-palette="midnight"] .batsignal { display: block; position: absolute; left: 58%; top: 0; width: 240px; height: 52px; animation: signal-pulse 4.5s ease-in-out infinite; }
        .batsignal .sigbat { fill: #0b0b0d; }
        .batsignal .beam { animation: beam-flicker 6s linear infinite; }
        :root[data-palette="midnight"] .win { display: block; position: absolute; width: 2px; height: 3px; background: #ffd84d; opacity: .15; animation: win-twinkle 4s ease-in-out infinite; }
        :root[data-palette="midnight"][data-theme="light"] .win { background: #b88a00; }
        .sigfly { opacity: 0; animation: sig-cross 9s linear infinite; }
        .sigfly path { transform-box: fill-box; transform-origin: 50% 40%; animation: bat-flap .3s ease-in-out infinite alternate; }
        @keyframes sig-cross { 0%, 52% { opacity: 0; transform: translate(0, 8px); } 56% { opacity: .95; } 94% { opacity: .95; } 100% { opacity: 0; transform: translate(118px, -9px); } }
        :root[data-palette="midnight"] body.is-busy .batsignal { animation-duration: 1.4s; }
        body.is-busy .sigfly { animation-duration: 3.2s; }
        body.is-busy .batsignal .beam { animation-duration: 1.2s; }
        @keyframes signal-pulse { 0%, 100% { opacity: .85; transform: scale(1); } 50% { opacity: 1; transform: scale(1.04); } }
        @keyframes beam-flicker { 0%, 100% { opacity: .85; } 40% { opacity: .55; } 44% { opacity: .95; } 70% { opacity: .7; } }
        @keyframes bat-flap { from { transform: scaleY(1); } to { transform: scaleY(.5); } }
        @keyframes win-twinkle { 0%, 100% { opacity: .12; } 50% { opacity: .95; } }
        @media (max-width: 900px) { :root[data-palette="midnight"] .batsignal { left: 40%; } }

        /* ambient motion and the loader: one small creature at a time, never a glow or an outline */
        .fx { position: absolute; inset: 0; overflow: hidden; pointer-events: none; z-index: 0; }
        .fx-bat { position: absolute; left: 0; top: 0; fill: #000; opacity: .82; overflow: visible; }
        .fx-bat .flap { transform-origin: 50% 40%; transform-box: fill-box; animation: bat-flap .32s ease-in-out infinite alternate; }
        :root[data-theme="light"] .fx-bat { fill: #1a1a1a; opacity: .7; }
        .fx-swing { position: absolute; top: 0; width: 20px; margin-left: -10px; transform-origin: 50% 0; opacity: 0; }
        .fx-swing .th { display: block; width: 1px; height: calc(100% - 20px); margin: 0 auto; background: var(--thread-color, rgba(255, 255, 255, .7)); }
        .fx-swing svg { display: block; }
        .fx-packet { position: absolute; left: 0; bottom: 0; height: 2px; border-radius: 2px; background: linear-gradient(90deg, transparent, var(--lv-primary), transparent); opacity: .85; }
        .busy-line { position: absolute; left: 0; right: 0; bottom: -1px; height: 2px; overflow: hidden; pointer-events: none; opacity: 0; transition: opacity .15s ease; z-index: 3; }
        body.is-busy .busy-line { opacity: 1; }
        .busy-line i { display: block; width: 28%; height: 100%; background: linear-gradient(90deg, transparent, var(--lv-primary), transparent); animation: busy-run 1.1s linear infinite; }
        @keyframes busy-run { from { transform: translateX(-100%); } to { transform: translateX(360%); } }
        @keyframes spider-bob { from { transform: translateY(-3px); } to { transform: translateY(3px); } }
        /* the "Reading log files" spinner follows the style too */
        :root[data-palette="midnight"] .spinner { width: 1.75rem; height: .9rem; border: 0; border-radius: 0; background: url("data:image/svg+xml,%3Csvg%20xmlns%3D'http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg'%20viewBox%3D'0%200%2060%2030'%3E%3Cpath%20fill%3D'%23f5c518'%20d%3D'M30%206L27%202L26%208C20%207%2012%208%202%204C5%2010%206%2016%209%2021C12%2017%2015%2017%2018%2021C21%2016%2025%2017%2027%2022L30%2018L33%2022C35%2017%2039%2016%2042%2021C45%2017%2048%2017%2051%2021C54%2016%2055%2010%2058%204C48%208%2040%207%2034%208L33%202Z'%2F%3E%3C%2Fsvg%3E") center / contain no-repeat; animation: bat-flap .35s ease-in-out infinite alternate; }
        :root[data-palette="web"] .spinner { width: 1.15rem; height: 1.25rem; border: 0; border-radius: 0; background: url("data:image/svg+xml,%3Csvg%20xmlns%3D'http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg'%20viewBox%3D'0%200%2024%2026'%3E%3Cg%20stroke%3D'%23e62429'%20stroke-width%3D'1.6'%20stroke-linecap%3D'round'%20fill%3D'none'%3E%3Cpath%20d%3D'M9.5%2011L4.5%207L2%209M9%2013L3.5%2012L1.5%2015M9%2015L4%2018L2.5%2022M10%2017L7.5%2021.5L7%2024M14.5%2011L19.5%207L22%209M15%2013L20.5%2012L22.5%2015M15%2015L20%2018L21.5%2022M14%2017L16.5%2021.5L17%2024'%2F%3E%3C%2Fg%3E%3Cellipse%20cx%3D'12'%20cy%3D'15'%20rx%3D'4.4'%20ry%3D'5.6'%20fill%3D'%23e62429'%2F%3E%3Ccircle%20cx%3D'12'%20cy%3D'8.4'%20r%3D'3'%20fill%3D'%23e62429'%2F%3E%3C%2Fsvg%3E") center / contain no-repeat; animation: spider-bob .9s ease-in-out infinite alternate; }

        /* The loader. The page blurs, a card sits in the middle of the screen, and the style's creatures move around it.
           It fades in only after a short wait, so quick answers never flash it, and it leaves faster than it came. */
        :root { --ease-out-strong: cubic-bezier(.23, 1, .32, 1); --ease-in-out-strong: cubic-bezier(.77, 0, .175, 1); }
        .load-overlay { position: fixed; inset: 0; z-index: 35; display: grid; place-items: center; padding: 1rem; overflow: hidden; background: color-mix(in srgb, var(--lv-bg) 45%, transparent); -webkit-backdrop-filter: blur(6px); backdrop-filter: blur(6px); cursor: progress; opacity: 0; visibility: hidden; pointer-events: none; transition: opacity 160ms ease-out, visibility 0s linear 160ms; }
        .load-overlay.on { opacity: 1; visibility: visible; pointer-events: auto; transition: opacity 240ms var(--ease-out-strong) 250ms, visibility 0s linear 250ms; }
        .ov-fx { position: absolute; inset: 0; pointer-events: none; }
        .dl-card { position: relative; z-index: 1; display: flex; flex-direction: column; align-items: center; gap: 1rem; width: min(22rem, 100%); text-align: center; color: var(--lv-text); transform: scale(.96) translateY(6px); transition: transform 160ms ease-out; }
        /* a soft pool of the page colour behind the text: readable, with no edges */
        .dl-card::before { content: ""; position: absolute; z-index: -1; inset: -4.5rem -6rem; background: radial-gradient(closest-side, color-mix(in srgb, var(--lv-bg) 88%, transparent), color-mix(in srgb, var(--lv-bg) 55%, transparent) 55%, transparent); pointer-events: none; }
        .load-overlay.on .dl-card { transform: none; transition: transform 320ms var(--ease-out-strong) 250ms; }
        .dl-text { display: grid; gap: .25rem; min-width: 0; font-size: .875rem; line-height: 1.4; color: var(--lv-muted); }
        .dl-text b { font-size: 1.125rem; font-weight: 650; letter-spacing: -.01em; color: var(--lv-text); }
        .dl-sub { font-variant-numeric: tabular-nums; }
        .dl-art { position: relative; flex: none; width: 9rem; height: 7rem; display: grid; place-items: center; }
        .dl-art > * { display: none; }

        /* Teal: a log file with a line of light reading down through it; thin lights stream across the screen */
        .dl-doc { width: 4.25rem; height: auto; color: var(--lv-primary); overflow: visible; }
        :root:not([data-palette="midnight"]):not([data-palette="web"]) .dl-art > .dl-doc { display: block; }
        .dl-doc .ln { opacity: .35; animation: ln-lit 1.6s linear infinite; }
        .dl-doc .ln:nth-of-type(1) { animation-delay: .32s; } .dl-doc .ln:nth-of-type(2) { animation-delay: .64s; } .dl-doc .ln:nth-of-type(3) { animation-delay: .96s; } .dl-doc .ln:nth-of-type(4) { animation-delay: 1.28s; } .dl-doc .ln:nth-of-type(5) { animation-delay: 1.6s; }
        .dl-doc .scan { animation: doc-scan 1.6s linear infinite; }
        @keyframes ln-lit { 0% { opacity: 1; } 30%, 100% { opacity: .35; } }
        @keyframes doc-scan { from { transform: translateY(0); } to { transform: translateY(40px); } }
        .ov-stream { position: absolute; left: 0; height: 2px; border-radius: 2px; background: linear-gradient(90deg, transparent, var(--lv-primary), transparent); }

        /* Midnight: the searchlight in the card, a searchlight sweeping behind it, bats crossing the screen */
        .dl-signal { width: 8.5rem; height: auto; overflow: visible; filter: drop-shadow(0 0 18px rgba(245, 197, 24, .35)); }
        :root[data-palette="midnight"] .dl-art > .dl-signal { display: block; }
        .dl-signal .disc { animation: disc-pulse 2.4s ease-in-out infinite alternate; }
        .dl-signal .cross { opacity: 0; animation: dl-cross 2.6s linear infinite; }
        .dl-signal .cross path { transform-box: fill-box; transform-origin: 50% 40%; animation: bat-flap .22s ease-in-out infinite alternate; }
        @keyframes disc-pulse { from { opacity: .82; } to { opacity: 1; } }
        @keyframes dl-cross { 0%, 30% { opacity: 0; transform: translate(0, 6px); } 40%, 88% { opacity: 1; } 100% { opacity: 0; transform: translate(84px, -6px); } }
        /* the wedge is cut on the inner layer and blurred on the outer one, so the light has soft edges (a clip on the same layer would cut the blur off) */
        .ov-beam { display: none; position: absolute; left: 50%; bottom: -8vh; width: 60vmax; height: 130vh; margin-left: -30vmax; transform-origin: 50% 100%; filter: blur(26px); opacity: .9; animation: beam-sweep 7s ease-in-out infinite alternate; }
        .ov-beam::before { content: ""; position: absolute; inset: 0; background: linear-gradient(to top, rgba(245, 197, 24, .24), rgba(245, 197, 24, .06) 60%, transparent 85%); clip-path: polygon(47% 100%, 53% 100%, 100% 0, 0 0); }
        :root[data-palette="midnight"] .ov-beam { display: block; }
        @keyframes beam-sweep { from { transform: rotate(-26deg); } to { transform: rotate(26deg); } }
        .ov-bat { position: absolute; left: 0; top: 0; fill: #4c4f5b; overflow: visible; }
        .ov-bat g { transform-box: fill-box; transform-origin: 50% 40%; animation: bat-flap .26s ease-in-out infinite alternate; }
        :root[data-theme="light"] .ov-bat { fill: #1a1a1a; }

        /* Web: webs in the top corners, spiders dropping on threads, one crawling round the card */
        .dl-spider-wrap { width: 3.25rem; position: relative; animation: dl-drop 1.3s ease-in-out infinite alternate; }
        .dl-spider-wrap::before { content: ""; position: absolute; left: 50%; bottom: 100%; width: 1px; height: 5rem; background: linear-gradient(to top, var(--thread-color, #fff), transparent); }
        .dl-spider { display: block; width: 3.25rem; height: auto; overflow: visible; }
        .dl-orbit { display: none; position: absolute; left: 50%; top: 50%; width: 0; height: 0; }
        .dl-orbit svg { position: absolute; left: -9px; top: -10px; width: 18px; height: 20px; overflow: visible; animation: dl-orbit 5.5s linear infinite; }
        .dl-orbit .legs path { animation-duration: .16s; }
        :root[data-palette="web"] .dl-art > .dl-orbit { display: block; }
        @keyframes dl-orbit { from { transform: rotate(0deg) translateX(4.6rem) rotate(180deg); } to { transform: rotate(360deg) translateX(4.6rem) rotate(180deg); } }
        :root[data-palette="web"] .dl-art > .dl-spider-wrap { display: block; }
        @keyframes dl-drop { from { transform: translateY(-14px); } to { transform: translateY(8px); } }
        .ov-web { display: none; position: absolute; top: 0; width: min(38vmin, 320px); height: auto; overflow: visible; }
        .ov-web.r { right: 0; transform: scaleX(-1); }
        .ov-web.l { left: 0; }
        :root[data-palette="web"] .ov-web { display: block; }
        .ov-web path { fill: none; stroke: var(--thread-color, #fff); stroke-opacity: .45; stroke-width: 1; stroke-dasharray: 1; stroke-dashoffset: 1; }
        .load-overlay.on .ov-web path { animation: web-draw .8s var(--ease-out-strong) both; animation-delay: calc(250ms + var(--i) * 45ms); }
        .ov-drop { position: absolute; top: 0; display: flex; flex-direction: column; align-items: center; }
        .ov-drop .th { flex: 1; width: 1px; background: var(--thread-color, #fff); }
        .ov-drop svg { display: block; flex: none; overflow: visible; }
        .legs path { transform-box: fill-box; animation: leg-left .55s ease-in-out infinite alternate; }
        .legs path:nth-child(n+5) { animation-name: leg-right; }
        .legs path:nth-child(-n+4) { transform-origin: 100% 50%; }
        .legs path:nth-child(n+5) { transform-origin: 0 50%; }
        .legs path:nth-child(2n) { animation-delay: -.28s; }
        .legs path:nth-child(3n) { animation-duration: .4s; }
        .ov-drop.moving .legs path { animation-duration: .16s; }

        /* a keyboard-focused tab gets a soft inner outline, so it never doubles up with the underline and the header line */
        .src-tab:focus-visible { outline: 2px solid var(--lv-primary); outline-offset: -7px; border-radius: 6px; }
        .src-tab:focus:not(:focus-visible) { outline: none; }

        /* ---------- Suggestions ---------- */
        .sg-layout { display: grid; grid-template-columns: minmax(18rem, 26rem) minmax(0, 1fr); gap: 1.25rem; align-items: start; }
        @media (max-width: 900px) { .sg-layout { grid-template-columns: minmax(0, 1fr); } }
        @media (min-width: 901px) { .sg-side { position: sticky; top: 4.5rem; } }
        .sg-side { display: grid; gap: 1rem; min-width: 0; }
        /* signed out: one centred card to sign in or create an account; the form and the list come after */
        .sg-gate-art { display: none; }
        #viewSuggest.sg-gated .sg-layout { grid-template-columns: minmax(0, 27rem); justify-content: center; padding-top: 1.5rem; }
        #viewSuggest.sg-gated .sg-listwrap, #viewSuggest.sg-gated #sgForm { display: none; }
        #viewSuggest.sg-gated .sg-side { position: static; }
        #viewSuggest.sg-gated .sg-accbox { padding: 1.5rem 1.5rem 1.25rem; }
        #viewSuggest.sg-gated .sg-gate-art { display: grid; place-items: center; width: 2.75rem; height: 2.75rem; margin-bottom: .75rem; font-size: 1.25rem; color: var(--lv-primary); background: color-mix(in srgb, var(--lv-primary) 14%, transparent); border-radius: 12px; }
        #viewSuggest.sg-gated .panel-title { font-size: 1.0625rem; }
        /* a small dot on the tab until this browser has opened it once, so people find out they can suggest things */
        .tab-dot { display: inline-block; width: 7px; height: 7px; margin-left: .375rem; border-radius: 50%; background: var(--tab-accent, var(--lv-primary)); vertical-align: middle; }
        .tab-dot.hidden { display: none; }
        .sg-side > .panel { margin-bottom: 0; }
        .sg-accbox .lv-input { width: 100%; }
        .sg-accbox .tabs { margin-bottom: .25rem; }
        .sg-accbtn { width: 100%; margin-top: .875rem; }
        .sg-me { display: flex; align-items: center; gap: .625rem; }
        .sg-me > i { font-size: 1.5rem; color: var(--lv-primary); }
        .sg-me-text { flex: 1; min-width: 0; overflow-wrap: anywhere; }
        .sg-acc-more { margin-top: .75rem; font-size: .8125rem; }
        .sg-acc-more summary { cursor: pointer; color: var(--lv-muted); font-weight: 600; }
        .sg-acc-more form { padding-top: .25rem; }
        .sg-acc-more form + form { margin-top: .75rem; padding-top: .75rem; border-top: 1px solid var(--lv-border); }
        .sg-warn { margin-top: .25rem; font-size: .6875rem; color: var(--lv-warning); }
        .settings-page .tab-panel[data-panel="users"]:not(.hidden) { display: block; }
        .users-wrap { overflow-x: auto; }
        .users-table { min-width: 48rem; }
        .users-acts { white-space: nowrap; }
        .users-acts .lv-copy-btn + .lv-copy-btn { margin-left: .375rem; }
        .sg-form .lv-input { width: 100%; }
        .sg-form textarea.lv-input, .sg-admin textarea.lv-input { height: auto; padding: .5rem .75rem; line-height: 1.5; resize: vertical; }
        .sg-form textarea.lv-input { min-height: 9rem; }
        .sg-field-foot { display: flex; justify-content: space-between; gap: .75rem; margin-top: .25rem; font-size: .75rem; color: var(--lv-muted-2); }
        .sg-count.warn { color: var(--lv-warning); }
        .sg-count.over { color: var(--lv-error); font-weight: 650; }
        .sg-opt { font-weight: 400; color: var(--lv-muted-2); }
        .sg-privacy { display: flex; gap: .5rem; margin: .875rem 0; padding: .625rem .75rem; font-size: .75rem; line-height: 1.45; color: var(--lv-muted); background: var(--lv-surface); border: 1px solid var(--lv-border); border-radius: 6px; }
        .sg-privacy i { margin-top: .125rem; color: var(--lv-primary); }
        .sg-form .lv-btn-primary { width: 100%; }
        .sg-msg { min-height: 1.25rem; margin-top: .5rem; font-size: .8125rem; color: var(--lv-muted); }
        .sg-msg.ok { color: var(--lv-success); }
        .sg-msg.err { color: var(--lv-error); }
        .sg-listwrap { min-width: 0; }
        .sg-listwrap .seg { flex-wrap: wrap; max-width: 100%; }   /* seven filters wrap on a phone instead of widening the page */
        .sg-cards { display: grid; gap: .75rem; }
        .sg-card { min-width: 0; padding: 1rem 1.125rem; background: var(--lv-card); border: 1px solid var(--lv-border); border-radius: 8px; }
        .sg-card.is-hidden { border-style: dashed; opacity: .75; }
        .sg-head { display: flex; flex-wrap: wrap; gap: .375rem; margin-bottom: .5rem; }
        .sg-chip { display: inline-flex; align-items: center; height: 1.375rem; padding: 0 .5rem; font-size: .6875rem; font-weight: 650; border-radius: 999px; color: var(--lv-muted); border: 1px solid var(--lv-border-strong); }
        .sg-cat-idea { color: var(--series-1); border-color: color-mix(in srgb, var(--series-1) 45%, transparent); }
        .sg-cat-problem { color: var(--series-2); border-color: color-mix(in srgb, var(--series-2) 45%, transparent); }
        .sg-st-new { color: var(--lv-primary); background: color-mix(in srgb, var(--lv-primary) 12%, transparent); border-color: transparent; }
        .sg-st-planned { color: var(--series-7); background: color-mix(in srgb, var(--series-7) 14%, transparent); border-color: transparent; }
        .sg-st-done { color: var(--lv-success); background: color-mix(in srgb, var(--lv-success) 14%, transparent); border-color: transparent; }
        .sg-st-declined, .sg-st-hidden { border-style: dashed; }
        .sg-mine { color: var(--lv-text); }
        .sg-ttl { margin: 0 0 .375rem; font-size: .9375rem; font-weight: 650; line-height: 1.35; color: var(--lv-text); overflow-wrap: anywhere; }
        .sg-text { margin: 0; font-size: .8125rem; line-height: 1.55; color: var(--lv-text); white-space: pre-wrap; overflow-wrap: anywhere; }
        .sg-meta { display: flex; flex-wrap: wrap; align-items: center; gap: .375rem 1rem; margin-top: .75rem; font-size: .75rem; color: var(--lv-muted-2); }
        .sg-vote { margin-left: auto; display: inline-flex; align-items: center; gap: .375rem; height: 1.75rem; padding: 0 .625rem; font: inherit; font-size: .75rem; color: var(--lv-muted); background: var(--lv-surface); border: 1px solid var(--lv-border); border-radius: 999px; cursor: pointer; transition: transform 120ms ease-out, color .15s ease, border-color .15s ease; }
        .sg-vote:active { transform: scale(.96); }
        .sg-vote[aria-pressed="true"] { color: var(--lv-primary); border-color: color-mix(in srgb, var(--lv-primary) 60%, transparent); }
        .sg-vote:disabled { cursor: default; opacity: .6; }
        .sg-reply { margin-top: .75rem; padding: .625rem .75rem; font-size: .8125rem; background: var(--lv-surface); border-left: 3px solid var(--lv-primary); border-radius: 0 6px 6px 0; }
        .sg-reply-h { margin-bottom: .25rem; font-size: .6875rem; font-weight: 650; color: var(--lv-muted); }
        .sg-reply p { margin: 0; color: var(--lv-text); white-space: pre-wrap; overflow-wrap: anywhere; }
        .sg-admin { display: grid; gap: .5rem; margin-top: .875rem; padding-top: .75rem; border-top: 1px dashed var(--lv-border-strong); }
        .sg-who { font-size: .75rem; color: var(--lv-muted); overflow-wrap: anywhere; }
        .sg-who b { color: var(--lv-text); font-weight: 600; }
        .sg-agent { margin-top: .125rem; font-size: .6875rem; color: var(--lv-muted-2); }
        .sg-admin-row { display: grid; grid-template-columns: 10rem minmax(0, 1fr); gap: .5rem; }
        @media (max-width: 560px) { .sg-admin-row { grid-template-columns: minmax(0, 1fr); } }
        .sg-admin textarea.lv-input { min-height: 2.25rem; }
        .sg-admin-actions { display: flex; flex-wrap: wrap; align-items: center; gap: .5rem; }
        .sg-del.confirm { color: #fff; background: var(--lv-error); border-color: var(--lv-error); }
        .sg-admin-msg { font-size: .75rem; color: var(--lv-muted); }
        .sg-empty { padding: 2rem 0; text-align: center; }
        .tab-badge { display: inline-grid; place-items: center; min-width: 1.125rem; height: 1.125rem; margin-left: .375rem; padding: 0 .3rem; font-size: .625rem; font-weight: 700; color: #fff; background: var(--tab-accent, var(--lv-primary)); border-radius: 999px; }
        .tab-badge.hidden { display: none; }

        /* floating tip for small bars */
        .float-tip { position: fixed; z-index: 300; pointer-events: none; padding: .375rem .625rem; font-size: .8125rem; color: var(--lv-muted); background: var(--lv-card); border: 1px solid var(--lv-border-strong); border-radius: 6px; box-shadow: 0 10px 24px -10px rgba(0, 0, 0, .55); }
        .float-tip.hidden { display: none; }
        .float-tip .tip-head { font-weight: 600; color: var(--lv-text); }
        .sp-hit { fill: transparent; }
        .sp-hit:hover { fill: color-mix(in srgb, var(--lv-text) 10%, transparent); }

        /* health: a status page for modules, jobs and servers */
        .health-banner { display: flex; align-items: center; gap: .75rem; padding: .875rem 1.25rem; margin-bottom: 1rem; font-size: 1rem; font-weight: 650; background: var(--lv-card); border: 1px solid var(--lv-border); border-left: 4px solid currentColor; border-radius: 8px; }
        .hrows { display: grid; }
        .hrow { display: grid; grid-template-columns: minmax(9rem, 16rem) 13rem minmax(8rem, 1fr) minmax(12rem, 17rem) 3.5rem; align-items: center; gap: .5rem 1rem; padding: .625rem 0; border-bottom: 1px solid var(--lv-border); font-size: .8125rem; }
        .hrow:last-child { border-bottom: 0; }
        .hname { text-align: left; font-size: .8125rem; font-weight: 600; color: var(--lv-text); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        button.hname { color: var(--lv-primary); }
        .hname-cell { display: grid; min-width: 0; }
        .hraw { font-size: .6875rem; color: var(--lv-muted-2); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .mx-name small { margin-left: .375rem; font-size: .6875rem; color: var(--lv-muted-2); font-family: var(--mono); }
        .hstrip { display: flex; gap: 2px; align-items: stretch; height: 26px; min-width: 0; }
        .hb { display: block; flex: 1 1 0; min-width: 2px; max-width: 14px; border-radius: 2px; }
        .hb.good { background: #0ca30c; opacity: .75; }
        .hb.warn { background: #fab219; }
        .hb.crit { background: #d03b3b; }
        .hb:hover { outline: 2px solid var(--lv-text); outline-offset: 1px; }
        .hstats { color: var(--lv-muted); }
        .hb.go { cursor: pointer; }
        .health-filters { display: flex; flex-wrap: wrap; align-items: center; gap: .75rem 1rem; margin: 0 0 1rem; }
        .health-filters .seg button { display: inline-flex; align-items: center; gap: .375rem; }
        .hf-n { font-weight: 650; font-variant-numeric: tabular-nums; opacity: .8; }
        .seg button.active .st-crit, .seg button.active .st-warn, .seg button.active .st-ok { color: inherit; }
        .health-banner { flex-wrap: wrap; }
        .banner-act { margin-left: auto; font-size: .8125rem; font-weight: 600; }
        .htotal { text-align: right; font-weight: 650; color: var(--lv-text); }
        .health-banner.st-ok i, .health-banner.st-ok { color: #0ca30c; }
        .health-banner span { color: var(--lv-text); }
        :root[data-theme="light"] .health-banner.st-ok { color: #0a7a0a; }
        :root[data-theme="light"] .health-banner.st-warn { color: #a86c00; }
        @media (max-width: 900px) {
            .hrow { grid-template-columns: minmax(0, 1fr) auto; }
            .hstrip, .hstats { grid-column: 1 / -1; }
            .htotal { grid-row: 1; grid-column: 2; }
            .hrow .status { grid-column: 1 / -1; grid-row: 2; }
        }

        /* admin dialog */
        .modal { position: fixed; inset: 0; z-index: 100; display: grid; place-items: center; padding: 1rem; }
        .modal.hidden { display: none; }
        .modal-backdrop { position: absolute; inset: 0; background: rgba(0, 0, 0, .55); }
        .modal-panel { position: relative; width: min(26rem, 100%); padding: 1.25rem; background: var(--lv-card); color: var(--lv-text); border: 1px solid var(--lv-border-strong); border-radius: 10px; box-shadow: 0 24px 60px -12px rgba(0, 0, 0, .6); }
        .modal-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: .75rem; }
        .modal-title { margin: 0; font-size: 1rem; font-weight: 650; }
        .modal-label { display: block; margin: .75rem 0 .25rem; font-size: .8125rem; font-weight: 600; color: var(--lv-muted); }
        .modal-note { font-size: .8125rem; color: var(--lv-muted); line-height: 1.45; }
        .modal-error { min-height: 1.25rem; margin-top: .5rem; font-size: .8125rem; color: var(--lv-error); }
        .modal-sub { margin: .5rem 0 0 1.5rem; display: grid; gap: .125rem; }
        .modal-sub.disabled { opacity: .45; pointer-events: none; }
        .modal-actions { display: flex; align-items: center; gap: .5rem; margin-top: 1rem; }
        .style-select[hidden] { display: none; }

        .brand-logo { display: block; height: 1.625rem; width: auto; }
        .brand-logo + .brand-name { padding-left: .75rem; border-left: 1px solid var(--lv-border-strong); line-height: 1.625rem; }
        .brand-name { font-size: 1rem; font-weight: 650; letter-spacing: -.01em; color: var(--lv-text); }

        .src-tabs { display: flex; align-items: stretch; gap: 1.25rem; }
        .src-tab {
            position: relative;
            display: inline-flex;
            align-items: center;
            padding: 0 .125rem;
            font-size: .875rem;
            font-weight: 550;
            color: var(--lv-muted);
            background: none;
            border: 0;
            cursor: pointer;
            transition: color .15s ease;
        }
        .src-tab:hover { color: var(--lv-text); }
        .src-tab.active { color: var(--lv-text); }
        .src-tab.active::after {
            content: "";
            position: absolute;
            left: 0; right: 0; bottom: -1px;
            height: 3px;
            border-radius: 3px 3px 0 0;
            background: var(--tab-accent, var(--lv-primary));
        }
        /* the selected tab also sits on a soft tinted pill, so it reads as selected in every style, light or dark */
        .src-tab.active::before {
            content: "";
            position: absolute;
            inset: .625rem -.5rem;
            border-radius: 6px;
            background: color-mix(in srgb, var(--tab-accent, var(--lv-primary)) 18%, transparent);
            z-index: -1;
        }

        .icon-btn {
            display: inline-flex;
            align-items: center;
            gap: .5rem;
            align-self: center;
            height: 2rem;
            padding: 0 .625rem;
            font-size: .8125rem;
            color: var(--lv-muted);
            background: transparent;
            border: 1px solid var(--lv-border);
            border-radius: var(--radius);
            cursor: pointer;
            transition: color .15s ease, border-color .15s ease, background .15s ease;
        }
        .icon-btn:hover { color: var(--lv-text); border-color: var(--lv-border-strong); background: var(--lv-surface); }

        /* ---------- Filter toolbar ---------- */
        .toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: .75rem; }

        .field { position: relative; flex: 0 1 15.5rem; min-width: 13rem; }
        .field-search { flex: 1 1 18rem; }
        .field-label {
            position: absolute;
            left: .75rem;
            top: 50%;
            transform: translateY(-50%);
            font-size: .75rem;
            font-weight: 600;
            color: var(--lv-muted-2);
            pointer-events: none;
            z-index: 1;
        }
        .field .lv-input.has-label { padding-left: 3.25rem; }
        .field-btn {
            position: absolute;
            right: .25rem;
            top: 50%;
            transform: translateY(-50%);
            display: grid;
            place-items: center;
            width: 1.75rem;
            height: 1.75rem;
            color: var(--lv-muted);
            background: none;
            border: 0;
            border-radius: 4px;
            cursor: pointer;
        }
        .field-btn:hover { color: var(--lv-primary); background: var(--lv-primary-glow); }
        .field-icon {
            position: absolute;
            left: .75rem;
            top: 50%;
            transform: translateY(-50%);
            color: var(--lv-muted-2);
            font-size: .8125rem;
            pointer-events: none;
            z-index: 1;
        }

        .lv-input {
            width: 100%;
            height: 2.25rem;
            padding: 0 .75rem;
            font: inherit;
            font-size: .875rem;
            color: var(--lv-text);
            background: var(--lv-input);
            border: 1px solid var(--lv-border);
            border-radius: var(--radius);
            outline: none;
            transition: border-color .15s ease, box-shadow .15s ease;
        }
        select.lv-input {
            -webkit-appearance: none; appearance: none;
            padding-right: 2.25rem;
            cursor: pointer;
            background-image: linear-gradient(45deg, transparent 50%, var(--lv-muted) 50%), linear-gradient(135deg, var(--lv-muted) 50%, transparent 50%);
            background-position: calc(100% - 1.15rem) 50%, calc(100% - .8rem) 50%;
            background-size: .35rem .35rem, .35rem .35rem;
            background-repeat: no-repeat;
        }
        select.lv-input:hover, select.lv-input:focus-visible { background-image: linear-gradient(45deg, transparent 50%, var(--lv-text) 50%), linear-gradient(135deg, var(--lv-text) 50%, transparent 50%); }
        select.lv-input option { color: var(--lv-text); background: var(--lv-card); }
        .lv-input::placeholder { color: var(--lv-muted-2); }
        .lv-input:hover { border-color: var(--lv-border-strong); }
        .lv-input:focus-visible {
            border-color: var(--lv-primary);
            box-shadow: 0 0 0 3px var(--lv-primary-glow);
            outline: none;
        }

        .lv-btn-primary {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: .5rem;
            height: 2.25rem;
            padding: 0 1.125rem;
            font: inherit;
            font-size: .875rem;
            font-weight: 600;
            color: var(--lv-primary-ink);
            background: var(--lv-primary);
            border: 0;
            border-radius: var(--radius);
            cursor: pointer;
            transition: background .15s ease, transform .1s ease;
        }
        .lv-btn-primary:hover { background: var(--lv-primary-hover); }
        .lv-btn-primary:active { transform: scale(.98); }
        .lv-btn-primary:disabled { opacity: .5; pointer-events: none; }

        .toolbar-row2 { margin-top: .75rem; display: flex; flex-wrap: wrap; align-items: center; gap: .75rem 1.25rem; }
        /* these must come after the rule above or the row would never hide */
        .toolbar-row2.collapsed, .toolbar-row2.hidden { display: none; }
        .reset-btn { margin-left: auto; }

        .seg {
            display: inline-flex;
            padding: 2px;
            gap: 2px;
            background: var(--lv-surface);
            border: 1px solid var(--lv-border);
            border-radius: var(--radius);
        }
        .seg button {
            height: 1.75rem;
            padding: 0 .75rem;
            font: inherit;
            font-size: .8125rem;
            font-weight: 550;
            color: var(--lv-muted);
            background: none;
            border: 0;
            border-radius: 4px;
            cursor: pointer;
            transition: background .12s ease, color .12s ease;
        }
        .seg button:hover { color: var(--lv-text); background: var(--lv-surface-2); }
        .seg-caption { font-size: .8125rem; color: var(--lv-muted); }

        .lvl-chip {
            display: inline-flex;
            align-items: center;
            gap: .4rem;
            height: 1.75rem;
            padding: 0 .625rem;
            font: inherit;
            font-size: .8125rem;
            font-weight: 550;
            color: var(--lv-muted-2);
            background: transparent;
            border: 1px dashed var(--lv-border-strong);
            border-radius: var(--radius);
            cursor: pointer;
            transition: color .12s ease, border-color .12s ease, background .12s ease;
        }
        .lvl-chip::before { content: ""; width: .5rem; height: .5rem; border-radius: 50%; background: currentColor; opacity: .35; }
        .lvl-chip:hover { color: var(--lv-text); }
        .lvl-chip.active { color: var(--lv-text); border-style: solid; border-color: var(--lv-border-strong); background: var(--lv-surface); }
        .lvl-chip.active::before { opacity: 1; }
        .lvl-chip[data-level="FATAL"].active::before, .lvl-chip[data-level="ERROR"].active::before { color: var(--lv-error); }
        .lvl-chip[data-level="WARN"].active::before  { color: var(--lv-warning); }
        .lvl-chip[data-level="INFO"].active::before  { color: var(--lv-info); }
        .lvl-chip[data-level="DEBUG"].active::before, .lvl-chip[data-level="TRACE"].active::before { color: var(--lv-debug); }

        /* ---------- Results ---------- */
        .lv-table-container {
            background: var(--lv-card);
            border: 1px solid var(--lv-border);
            border-radius: 8px;
            overflow: hidden;
        }
        .results-bar {
            display: flex;
            align-items: baseline;
            justify-content: space-between;
            gap: 1rem;
            padding: .75rem 1rem;
            border-bottom: 1px solid var(--lv-border);
        }
        .results-count { font-size: .9375rem; font-weight: 650; color: var(--lv-text); }
        .results-hint  { font-size: .8125rem; color: var(--lv-muted); }

        thead th {
            position: sticky;
            top: 0;
            z-index: 20;
            padding: .5rem 1rem;
            text-align: left;
            font-size: .75rem;
            font-weight: 600;
            color: var(--lv-muted);
            background: var(--lv-surface);
            border-bottom: 1px solid var(--lv-border);
            white-space: nowrap;
        }

        .lv-row {
            background: var(--lv-card);
            border-bottom: 1px solid var(--lv-border);
            cursor: pointer;
            transition: background .12s ease;
        }
        .lv-row:hover { background: var(--lv-surface); }
        .lv-row.active { background: var(--lv-surface-2); }
        .lv-row[data-sev="error"]   { box-shadow: inset 3px 0 0 0 var(--lv-error); }
        .lv-row[data-sev="warning"] { box-shadow: inset 3px 0 0 0 var(--lv-warning); }
        .lv-row[data-sev="info"]    { box-shadow: inset 3px 0 0 0 var(--lv-info); }
        .lv-row[data-sev="debug"]   { box-shadow: inset 3px 0 0 0 var(--lv-debug); }
        .lv-row:focus-visible, .lv-row[data-sev]:focus-visible { outline: none; box-shadow: inset 0 0 0 2px var(--lv-primary); }   /* after the severity rules, so it wins */
        .lv-row.active:focus-visible { box-shadow: inset 0 0 0 2px var(--lv-primary); }

        .cell-title { font-size: .875rem; font-weight: 600; color: var(--lv-text); line-height: 1.35; }
        .cell-sub   { margin-top: .25rem; font-family: var(--mono); font-size: .75rem; color: var(--lv-muted-2); }
        .t-rel { font-size: .8125rem; font-weight: 550; color: var(--lv-text); }
        .t-abs { margin-top: .125rem; font-family: var(--mono); font-size: .6875rem; color: var(--lv-muted-2); }

        /* Frequency bar: the one distinctive element. Bar length = share of the busiest group. */
        .freq { display: flex; flex-direction: column; align-items: flex-end; gap: .3rem; min-width: 4.5rem; }
        .freq-n { font-family: var(--mono); font-size: .875rem; font-weight: 650; color: var(--lv-text); }
        .freq-bar { display: block; width: 100%; height: 4px; border-radius: 2px; background: var(--lv-surface-2); overflow: hidden; }
        .freq-bar > i { display: block; height: 100%; border-radius: 2px; background: var(--freq-fill, var(--lv-primary)); }

        .sites { display: flex; flex-wrap: wrap; gap: .25rem; }
        .site-tag {
            padding: .0625rem .375rem;
            font-family: var(--mono);
            font-size: .6875rem;
            color: var(--lv-muted);
            background: var(--lv-surface-2);
            border-radius: 4px;
        }

        .expand-btn {
            display: inline-grid;
            place-items: center;
            width: 1.75rem;
            height: 1.75rem;
            color: var(--lv-muted);
            background: none;
            border: 0;
            border-radius: 4px;
            transition: background .12s ease, color .12s ease;
        }
        .expand-btn:hover { background: var(--lv-surface-2); color: var(--lv-text); }
        .expand-btn i { transition: transform .2s var(--ease-out-strong); }
        .lv-row.active .expand-btn i { color: var(--lv-primary); }

        /* ---------- Detail panel ---------- */
        .lv-detail-panel {
            background: var(--lv-bg);
            border-bottom: 1px solid var(--lv-border);
            padding: 1rem;
        }
        .trace-card {
            background: var(--lv-card);
            border: 1px solid var(--lv-border);
            border-radius: var(--radius);
            overflow: hidden;
        }
        .trace-card + .trace-card { margin-top: .75rem; }
        .trace-head {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            justify-content: space-between;
            gap: .5rem 1rem;
            padding: .5rem .75rem;
            background: var(--lv-surface);
            border-bottom: 1px solid var(--lv-border);
        }
        .trace-meta { display: flex; flex-wrap: wrap; align-items: center; gap: .25rem 1.25rem; font-size: .8125rem; color: var(--lv-muted); }
        .trace-meta b { font-weight: 600; color: var(--lv-text); }
        .trace-meta i { margin-right: .375rem; font-size: .6875rem; color: var(--lv-muted-2); }

        .lv-trace-container {
            position: relative;
            margin-top: .5rem;
            background: var(--lv-card);
            border: 1px solid var(--lv-border);
            border-radius: var(--radius);
            overflow: hidden;
        }
        .lv-pre {
            margin: 0;
            padding: .875rem 1rem;
            font-family: var(--mono);
            font-size: .75rem;
            line-height: 1.65;
            color: var(--lv-text);
            background: transparent;
            overflow: auto;
            white-space: pre-wrap;
            overflow-wrap: anywhere;
        }

        .lv-copy-btn {
            display: inline-flex;
            align-items: center;
            gap: .375rem;
            height: 1.625rem;
            padding: 0 .5rem;
            font: inherit;
            font-size: .75rem;
            font-weight: 600;
            color: var(--lv-muted);
            background: var(--lv-card);
            border: 1px solid var(--lv-border);
            border-radius: 4px;
            cursor: pointer;
            transition: color .15s ease, border-color .15s ease, background .15s ease;
        }
        .lv-copy-btn:hover { color: var(--lv-text); border-color: var(--lv-border-strong); }
        .lv-copy-btn.copied { background: var(--lv-success); color: #04150e; border-color: transparent; }

        /* ---------- Flatpickr ---------- */
        .flatpickr-calendar {
            background: var(--lv-picker-bg) !important;
            border: 1px solid var(--lv-picker-border) !important;
            border-radius: 8px !important;
            box-shadow: 0 12px 32px -8px rgba(0, 0, 0, .45) !important;
            color: var(--lv-picker-text) !important;
        }
        .flatpickr-day { color: var(--lv-picker-text) !important; }
        .flatpickr-day.selected { background: var(--lv-primary) !important; border-color: var(--lv-primary) !important; color: var(--lv-primary-ink) !important; }
        .flatpickr-day:hover { background: var(--lv-surface-2) !important; }
        .flatpickr-time { border-top: 1px solid var(--lv-border) !important; }
        .flatpickr-time input { color: var(--lv-picker-text) !important; }

        /* ---------- Severity tags ---------- */
        .badge {
            display: inline-flex;
            align-items: center;
            gap: .4rem;
            padding: .125rem .5rem;
            font-size: .75rem;
            font-weight: 600;
            color: var(--badge-c, var(--lv-muted));
            background: color-mix(in srgb, var(--badge-c, var(--lv-muted)) 12%, transparent);
            border-radius: 4px;
            white-space: nowrap;
        }
        .badge::before { content: ""; width: .375rem; height: .375rem; border-radius: 50%; background: currentColor; }
        .badge-error   { --badge-c: var(--lv-error); }
        .badge-warning { --badge-c: var(--lv-warning); }
        .badge-info    { --badge-c: var(--lv-info); }
        .badge-debug   { --badge-c: var(--lv-debug); }
        .badge-trace   { --badge-c: var(--lv-debug); opacity: .75; }
        .badge-fatal   { --badge-c: var(--lv-error); background: var(--lv-error); color: #fff; }
        .badge-fatal::before { background: #fff; }

        /* ---------- Messages / empty / loading ---------- */
        .notice {
            display: flex;
            align-items: flex-start;
            gap: .75rem;
            padding: .625rem .875rem;
            font-size: .875rem;
            color: var(--lv-text);
            background: var(--lv-surface);
            border: 1px solid var(--lv-border);
            border-left: 3px solid var(--notice-c, var(--lv-info));
            border-radius: var(--radius);
        }
        .notice i.lead { margin-top: .2rem; color: var(--notice-c, var(--lv-info)); }
        .notice-error   { --notice-c: var(--lv-error); }
        .notice-info    { --notice-c: var(--lv-info); }
        .notice-success { --notice-c: var(--lv-success); }
        .notice button { margin-left: auto; color: var(--lv-muted); background: none; border: 0; cursor: pointer; }
        .notice button:hover { color: var(--lv-text); }

        .empty { max-width: 32rem; margin: 0 auto; padding: 3rem 1rem; text-align: center; }
        .empty-actions { display: flex; flex-wrap: wrap; justify-content: center; gap: .5rem; margin-top: 1rem; }
        .empty-hint { margin-top: .75rem; font-size: .8125rem; color: var(--lv-muted-2); }
        .lv-copy-btn.hidden { display: none; }
        .lv-copy-btn[disabled] { opacity: .45; cursor: default; }
        .empty-title { font-size: 1rem; font-weight: 650; color: var(--lv-text); }
        .empty-body  { margin-top: .375rem; font-size: .875rem; line-height: 1.5; color: var(--lv-muted); }

        .sk-rows { display: grid; gap: .25rem; padding: .5rem 0; }
        .sk { display: flex; align-items: center; gap: 1.25rem; padding: .75rem .25rem; border-bottom: 1px solid var(--lv-border); }
        .sk:last-child { border-bottom: 0; }
        .sk i { display: block; height: .7rem; border-radius: 4px; background: linear-gradient(90deg, var(--lv-surface-2) 30%, color-mix(in srgb, var(--lv-surface-2) 40%, var(--lv-card)) 50%, var(--lv-surface-2) 70%); background-size: 300% 100%; animation: sk-shine 1.3s linear infinite; }
        @keyframes sk-shine { from { background-position: 100% 0; } to { background-position: 0 0; } }
        .loading { display: flex; align-items: center; justify-content: center; gap: .75rem; padding: 4rem 1rem; font-size: .875rem; color: var(--lv-muted); }
        .spinner { width: 1.125rem; height: 1.125rem; border: 2px solid var(--lv-border-strong); border-top-color: var(--lv-primary); border-radius: 50%; animation: lv-spin .7s linear infinite; }
        @keyframes lv-spin { to { transform: rotate(360deg); } }

        /* One orchestrated moment: rows settle in once per load. */
        @keyframes lv-rise { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
        .lv-row { animation: lv-fade 120ms ease-out both; }
        @keyframes lv-fade { from { opacity: 0; } to { opacity: 1; } }


        /* ---------- error-file view additions ---------- */
        .topbar-actions { display: flex; align-items: center; gap: .5rem; margin-left: auto; }
        .style-select { width: auto; height: 2rem; padding: 0 .5rem; font-size: .8125rem; }
        .page-wrap { width: 100%; max-width: var(--page-max); margin: 0 auto; padding: 1.25rem 1rem; }
        .th-sort {
            display: inline-flex;
            align-items: center;
            padding: 0;
            font: inherit;
            font-weight: 600;
            color: inherit;
            background: none;
            border: 0;
            cursor: pointer;
            white-space: nowrap;
        }
        .th-sort:hover { color: var(--lv-text); }
        th.th-active, th.th-active .th-sort { color: var(--lv-text); }
        .th-arrow { font-size: .625rem; color: var(--lv-primary); white-space: pre; }

        .results-left { display: flex; flex-wrap: wrap; align-items: baseline; gap: .25rem 1rem; }
        .bg-note { font-size: .8125rem; color: var(--lv-muted); }
        .linkbtn { padding: 0; font: inherit; font-size: .8125rem; font-weight: 600; color: var(--lv-primary); background: none; border: 0; cursor: pointer; text-decoration: underline; text-underline-offset: 2px; }
        .linkbtn:hover { color: var(--lv-primary-hover); }

        .check { display: inline-flex; align-items: center; gap: .5rem; height: 2.25rem; font-size: .8125rem; color: var(--lv-text); cursor: pointer; }
        .check input { width: 1rem; height: 1rem; accent-color: var(--lv-primary); }

        .tags { display: flex; flex-wrap: wrap; gap: .25rem; margin-top: .375rem; }
        .tag {
            padding: .0625rem .375rem;
            font-size: .6875rem;
            font-weight: 600;
            color: var(--lv-muted);
            background: var(--lv-surface-2);
            border-radius: 4px;
        }
        .tag-bg { color: var(--lv-muted); background: transparent; box-shadow: inset 0 0 0 1px var(--lv-border-strong); }
        .cell-note { margin-top: .25rem; font-size: .75rem; color: var(--lv-muted); line-height: 1.35; }

        mark { padding: 0 .125rem; color: inherit; background: color-mix(in srgb, var(--lv-warning) 38%, transparent); border-radius: 2px; }

        .msel { position: relative; }
        .msel-btn { display: inline-flex; align-items: center; justify-content: space-between; gap: .5rem; width: 14rem; text-align: left; cursor: pointer; }
        .msel-btn span { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .msel-btn i { font-size: .625rem; color: var(--lv-muted); }
        .msel-pop {
            position: absolute;
            z-index: 50;
            top: calc(100% + 4px);
            left: 0;
            width: 26rem;
            max-width: calc(100vw - 2rem);
            background: var(--lv-card);
            border: 1px solid var(--lv-border-strong);
            border-radius: 8px;
            box-shadow: 0 12px 32px -8px rgba(0, 0, 0, .45);
        }
        .msel-top { display: flex; align-items: center; justify-content: space-between; padding: .5rem .75rem; border-bottom: 1px solid var(--lv-border); }
        #moduleList { max-height: 16rem; overflow-y: auto; overflow-x: hidden; padding: .25rem; }
        .msel-item span { min-width: 0; overflow-wrap: anywhere; }
        .msel-item .msel-text { display: grid; gap: .0625rem; }
        .msel-raw { font-size: .6875rem; color: var(--lv-muted-2); }
        /* module column: the readable name large, the file and method small; the raw value is on hover */
        .mod-app { font-size: .8125rem; font-weight: 600; line-height: 1.3; color: var(--lv-text); }
        .mod-detail { margin-top: .125rem; font-size: .6875rem; line-height: 1.35; color: var(--lv-muted-2); word-break: break-word; }
        .msel-item { display: flex; align-items: center; gap: .625rem; padding: .375rem .5rem; font-size: .8125rem; border-radius: 4px; cursor: pointer; }
        .msel-item:hover { background: var(--lv-surface); }
        .msel-item input { accent-color: var(--lv-primary); }
        .msel-search { height: 2rem; flex: 1; margin-right: .5rem; }
        .msel-btn.has-value { border-color: var(--lv-primary); }
        .msel-list { max-height: 16rem; overflow-y: auto; overflow-x: hidden; padding: .25rem; }
        .msel-opt { padding: .375rem .625rem; font-size: .8125rem; border-radius: 4px; cursor: pointer; overflow-wrap: anywhere; }
        .msel-opt:hover, .msel-opt.active { background: var(--lv-surface-2); }
        .msel-opt.sel { color: var(--lv-primary); font-weight: 600; }
        .msel-empty { padding: .75rem; font-size: .8125rem; color: var(--lv-muted); }

        .trace-ctx { display: flex; flex-wrap: wrap; gap: .25rem 1.25rem; padding: .5rem .75rem; font-size: .8125rem; color: var(--lv-muted); border-bottom: 1px solid var(--lv-border); }
        .trace-ctx b { font-weight: 600; color: var(--lv-text); margin-right: .25rem; }
        .detail-note { margin-bottom: .75rem; font-size: .8125rem; color: var(--lv-muted); }
        .trace-meta .tag { margin-left: .25rem; }

        .sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }

        @media (max-width: 720px) {
            .topbar-inner { gap: 1rem; flex-wrap: wrap; padding-top: .5rem; }
            .src-tabs { order: 3; width: 100%; min-height: 2.5rem; overflow-x: auto; scrollbar-width: none; }
            .src-tab { white-space: nowrap; flex: none; }   /* six tabs scroll sideways on a phone */
            .field, .field-search { flex: 1 1 100%; }
            .lv-btn-primary { width: 100%; }
        }

        @media (prefers-reduced-motion: reduce) {
            *, *::before, *::after {
                animation-duration: .001ms !important;
                animation-iteration-count: 1 !important;
                transition-duration: .001ms !important;
                scroll-behavior: auto !important;
            }
        }
    </style>
</head>
<body class="min-h-screen bg-[var(--lv-bg)] text-[var(--lv-text)]">
    <header class="topbar">
        <svg class="web-art" aria-hidden="true" viewBox="0 0 460 64" preserveAspectRatio="xMaxYMin slice" fill="none"><path class="web-ray" style="--i:0" pathLength="1" d="M460 0L423.7 518.7"/><path class="web-ray" style="--i:1" pathLength="1" d="M460 0L316.7 499.9"/><path class="web-ray" style="--i:2" pathLength="1" d="M460 0L215.9 459.1"/><path class="web-ray" style="--i:3" pathLength="1" d="M460 0L125.8 398.3"/><path class="web-ray" style="--i:4" pathLength="1" d="M460 0L50.2 320.1"/><path class="web-ray" style="--i:5" pathLength="1" d="M460 0L-7.4 228.0"/><path class="web-ray" style="--i:6" pathLength="1" d="M460 0L-44.6 125.8"/><path class="web-ray" style="--i:7" pathLength="1" d="M460 0L-59.7 18.1"/><path class="web-ring" style="--i:0" pathLength="1" d="M458.2 25.9Q456.0 22.5 452.8 25.0Q451.4 21.2 447.8 23.0Q447.2 19.0 443.3 19.9Q443.5 15.9 439.5 16.0Q440.6 12.1 436.6 11.4Q438.5 7.8 434.8 6.3Q437.3 3.2 434.0 0.9"/><path class="web-ring" style="--i:1" pathLength="1" d="M456.4 51.9Q452.1 45.1 445.7 50.0Q442.9 42.4 435.6 45.9Q434.4 37.9 426.6 39.8Q427.1 31.8 419.0 32.0Q421.2 24.2 413.3 22.8Q417.0 15.7 409.5 12.6Q414.7 6.4 408.0 1.8"/><path class="web-ring" style="--i:2" pathLength="1" d="M454.1 83.8Q447.2 72.8 436.8 80.7Q432.3 68.5 420.6 74.2Q418.7 61.3 406.0 64.3Q406.8 51.3 393.8 51.7Q397.3 39.2 384.5 36.8Q390.5 25.3 378.5 20.3Q386.8 10.3 376.1 2.9"/><path class="web-ring" style="--i:3" pathLength="1" d="M451.5 121.7Q441.4 105.7 426.4 117.3Q419.8 99.5 402.7 107.7Q400.0 89.0 381.6 93.5Q382.8 74.6 363.9 75.1Q369.0 56.9 350.3 53.5Q359.1 36.7 341.6 29.5Q353.7 14.9 338.1 4.3"/><path class="web-ring" style="--i:4" pathLength="1" d="M448.3 167.6Q434.3 145.6 413.7 161.5Q404.6 137.1 381.1 148.3Q377.3 122.6 352.0 128.7Q353.7 102.7 327.6 103.4Q334.6 78.3 309.0 73.6Q321.1 50.6 297.0 40.6Q313.6 20.6 292.1 5.9"/><path class="web-ring" style="--i:5" pathLength="1" d="M444.5 221.5Q426.1 192.4 398.8 213.4Q386.8 181.1 355.8 196.0Q350.8 162.0 317.3 170.1Q319.5 135.7 285.1 136.7Q294.3 103.5 260.5 97.3Q276.4 66.8 244.6 53.7Q266.5 27.2 238.1 7.7"/><path class="web-ring" style="--i:6" pathLength="1" d="M440.2 283.3Q416.6 246.1 381.7 273.0Q366.4 231.7 326.7 250.8Q320.2 207.2 277.4 217.6Q280.2 173.6 236.2 174.8Q248.1 132.4 204.7 124.5Q225.2 85.5 184.4 68.7Q212.5 34.8 176.2 9.9"/><path class="web-ring" style="--i:7" pathLength="1" d="M435.3 353.1Q405.9 306.8 362.4 340.3Q343.3 288.8 293.8 312.6Q285.8 258.3 232.5 271.2Q235.9 216.4 181.0 217.9Q195.8 165.1 141.8 155.2Q167.3 106.5 116.5 85.6Q151.5 43.4 106.2 12.4"/></svg>
        <div class="spidey" aria-hidden="true"><i class="spidey-thread"></i><svg class="spidey-body" viewBox="0 0 24 26" width="36" height="39"><g class="legs" stroke="#e62429" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" fill="none"><path d="M9.5 11L4.5 7L2 9"/><path d="M9 13L3.5 12L1.5 15"/><path d="M9 15L4 18L2.5 22"/><path d="M10 17L7.5 21.5L7 24"/><path d="M14.5 11L19.5 7L22 9"/><path d="M15 13L20.5 12L22.5 15"/><path d="M15 15L20 18L21.5 22"/><path d="M14 17L16.5 21.5L17 24"/></g><ellipse cx="12" cy="15" rx="4.4" ry="5.6" fill="#e62429"/><circle cx="12" cy="8.4" r="3" fill="#e62429"/><circle class="eye" cx="10.8" cy="7.8" r="1.05" fill="#fff"/><circle class="eye" cx="13.2" cy="7.8" r="1.05" fill="#fff"/></svg></div>
        <svg class="skyline" aria-hidden="true" viewBox="0 0 1200 40" preserveAspectRatio="none"><path d="M0 40L0 19L26 19L26 22L46 22L46 11L62 11L62 26L86 26L86 31L117 31L117 16L137 16L137 21L165 21L165 10L172.5 2L180 10L180 22L188.5 14L197 22L197 22L215 22L215 26L246 26L246 22L285 22L285 25L313 25L313 24L347 24L347 10L363 10L363 21L399 21L399 23L428 23L428 29L458 29L458 30L483 30L483 16L507 16L507 25L545 25L545 22L558 14L571 22L571 22L596 22L596 15L616 15L616 14L626.5 6L637 14L637 10L656.5 2L676 10L676 17L709 17L709 25L723 25L723 23L742 23L742 26L758.5 18L775 26L775 24L789 24L789 30L801.5 22L814 30L814 12L839 12L839 29L865 29L865 26L902 26L902 16L920 16L920 12L951 12L951 28L986 28L986 32L1002 32L1002 12L1037 12L1037 31L1063 31L1063 31L1089 31L1089 25L1108 25L1108 29L1125 29L1125 30L1155 30L1155 21L1171 21L1171 14L1185 14L1185 24L1201.5 16L1218 24L1200 40Z"/></svg>
        <div class="signal" aria-hidden="true"><svg class="batsignal" viewBox="0 0 240 52"><defs><radialGradient id="sigGlow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#fff6b8"/><stop offset=".6" stop-color="#f5c518"/><stop offset="1" stop-color="#f5c518" stop-opacity="0"/></radialGradient><linearGradient id="beamGrad" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f5c518" stop-opacity=".5"/><stop offset="1" stop-color="#f5c518" stop-opacity="0"/></linearGradient></defs><polygon class="beam" points="180,24 54,52 176,52" fill="url(#beamGrad)"/><ellipse class="sigdisc" cx="176" cy="21" rx="52" ry="19" fill="url(#sigGlow)"/><g transform="translate(92 22)"><g class="sigfly"><path class="sigbat" d="M30 6L27 2L26 8C20 7 12 8 2 4C5 10 6 16 9 21C12 17 15 17 18 21C21 16 25 17 27 22L30 18L33 22C35 17 39 16 42 21C45 17 48 17 51 21C54 16 55 10 58 4C48 8 40 7 34 8L33 2Z" transform="scale(.42)"/></g></g></svg><i class="win" style="left:64.7%;bottom:18px;animation-delay:1.8s;animation-duration:3.4s"></i><i class="win" style="left:23.4%;bottom:15px;animation-delay:1.2s;animation-duration:4.3s"></i><i class="win" style="left:79.6%;bottom:8px;animation-delay:3.7s;animation-duration:6.4s"></i><i class="win" style="left:94.4%;bottom:11px;animation-delay:1.8s;animation-duration:4.8s"></i><i class="win" style="left:44.6%;bottom:12px;animation-delay:1.5s;animation-duration:6.2s"></i><i class="win" style="left:12.5%;bottom:16px;animation-delay:0.2s;animation-duration:4.3s"></i><i class="win" style="left:44.2%;bottom:11px;animation-delay:3.6s;animation-duration:5.6s"></i><i class="win" style="left:73.0%;bottom:8px;animation-delay:5.0s;animation-duration:3.2s"></i><i class="win" style="left:7.1%;bottom:9px;animation-delay:5.2s;animation-duration:3.3s"></i><i class="win" style="left:77.5%;bottom:13px;animation-delay:5.1s;animation-duration:4.5s"></i><i class="win" style="left:76.1%;bottom:16px;animation-delay:3.6s;animation-duration:5.7s"></i><i class="win" style="left:30.7%;bottom:17px;animation-delay:4.6s;animation-duration:6.3s"></i><i class="win" style="left:63.6%;bottom:10px;animation-delay:4.5s;animation-duration:4.1s"></i><i class="win" style="left:21.1%;bottom:11px;animation-delay:1.3s;animation-duration:4.5s"></i><i class="win" style="left:50.7%;bottom:17px;animation-delay:2.5s;animation-duration:3.7s"></i><i class="win" style="left:67.9%;bottom:14px;animation-delay:5.6s;animation-duration:3.1s"></i><i class="win" style="left:71.3%;bottom:5px;animation-delay:2.1s;animation-duration:6.3s"></i><i class="win" style="left:34.4%;bottom:3px;animation-delay:2.8s;animation-duration:6.3s"></i><i class="win" style="left:57.6%;bottom:2px;animation-delay:0.5s;animation-duration:4.2s"></i><i class="win" style="left:96.2%;bottom:10px;animation-delay:4.1s;animation-duration:5.7s"></i><i class="win" style="left:47.2%;bottom:3px;animation-delay:3.5s;animation-duration:4.8s"></i><i class="win" style="left:98.2%;bottom:3px;animation-delay:5.1s;animation-duration:6.1s"></i><i class="win" style="left:62.9%;bottom:3px;animation-delay:5.1s;animation-duration:5.4s"></i><i class="win" style="left:56.3%;bottom:13px;animation-delay:2.7s;animation-duration:5.8s"></i><i class="win" style="left:58.9%;bottom:12px;animation-delay:5.6s;animation-duration:3.3s"></i><i class="win" style="left:37.0%;bottom:13px;animation-delay:3.3s;animation-duration:4.1s"></i><i class="win" style="left:29.1%;bottom:9px;animation-delay:4.3s;animation-duration:4.0s"></i><i class="win" style="left:5.1%;bottom:3px;animation-delay:5.8s;animation-duration:6.7s"></i><i class="win" style="left:83.6%;bottom:17px;animation-delay:2.5s;animation-duration:4.4s"></i><i class="win" style="left:31.0%;bottom:19px;animation-delay:0.4s;animation-duration:6.1s"></i><i class="win" style="left:2.1%;bottom:8px;animation-delay:3.8s;animation-duration:6.7s"></i><i class="win" style="left:72.1%;bottom:8px;animation-delay:0.9s;animation-duration:5.0s"></i><i class="win" style="left:29.2%;bottom:3px;animation-delay:0.9s;animation-duration:6.6s"></i><i class="win" style="left:17.3%;bottom:3px;animation-delay:3.6s;animation-duration:6.2s"></i><i class="win" style="left:67.9%;bottom:16px;animation-delay:2.4s;animation-duration:4.6s"></i><i class="win" style="left:89.1%;bottom:8px;animation-delay:3.9s;animation-duration:4.4s"></i><i class="win" style="left:17.9%;bottom:17px;animation-delay:3.1s;animation-duration:3.7s"></i><i class="win" style="left:38.3%;bottom:17px;animation-delay:5.0s;animation-duration:5.8s"></i><i class="win" style="left:80.1%;bottom:11px;animation-delay:1.3s;animation-duration:5.9s"></i><i class="win" style="left:69.4%;bottom:8px;animation-delay:0.5s;animation-duration:6.0s"></i><i class="win" style="left:48.6%;bottom:6px;animation-delay:0.7s;animation-duration:3.3s"></i><i class="win" style="left:67.4%;bottom:5px;animation-delay:3.1s;animation-duration:6.1s"></i><i class="win" style="left:41.0%;bottom:6px;animation-delay:5.6s;animation-duration:3.7s"></i><i class="win" style="left:66.2%;bottom:12px;animation-delay:5.5s;animation-duration:3.8s"></i><i class="win" style="left:18.4%;bottom:2px;animation-delay:1.4s;animation-duration:3.4s"></i><i class="win" style="left:96.1%;bottom:6px;animation-delay:4.5s;animation-duration:3.5s"></i></div>
        <div id="fx" class="fx" aria-hidden="true"></div>
        <div id="busyLine" class="busy-line" aria-hidden="true"><i></i></div>
        <div class="topbar-inner">
            <div class="brand">
                <svg class="brand-logo" viewBox="0 0 28 28" width="26" height="26" role="img" aria-label="Log Explorer"><rect x="1" y="1" width="26" height="26" rx="7" fill="var(--lv-primary)"/><path d="M8 9.5h12M8 14h8M8 18.5h10" stroke="var(--lv-primary-ink)" stroke-width="2.2" stroke-linecap="round"/></svg>
                <h1 class="brand-name">Log Explorer</h1>
            </div>
            <div class="src-tabs" role="tablist" aria-label="Log source">
                <button type="button" data-source="ipas" class="src-tab active" role="tab">Error files</button>
                <button type="button" data-source="log4net" class="src-tab" role="tab">log4net</button>
                <button type="button" data-view="suggest" class="src-tab hidden" role="tab">Suggestions<span id="sgDot" class="tab-dot hidden" title="New: send your ideas"></span><span id="sgNew" class="tab-badge hidden"></span></button>
                <button type="button" data-view="dashboard" class="src-tab admin-only hidden" role="tab">Dashboard</button>
                <button type="button" data-view="health" class="src-tab admin-only hidden" role="tab">Health</button>
                <button type="button" data-view="settings" class="src-tab admin-only super-only hidden" role="tab">Settings</button>
            </div>
            <div class="topbar-actions">
                <select id="paletteSelect" class="lv-input style-select" aria-label="Colour style" title="Colour style" hidden></select>
                <button id="themeToggleBtn" type="button" class="icon-btn" title="Switch between light and dark theme">
                    <i id="themeIcon" class="fa-solid fa-moon"></i>
                    <span id="themeLabel">Dark</span>
                </button>
                <span class="admin-sep" aria-hidden="true"></span>
                <button id="adminBtn" type="button" class="admin-btn" title="Admin sign-in" aria-label="Admin sign-in"><svg id="adminIcon" class="admin-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 2.8 4.6 5.6v5.7c0 4.6 3.1 8.3 7.4 9.9 4.3-1.6 7.4-5.3 7.4-9.9V5.6L12 2.8Z"/><g class="icon-lock"><circle cx="12" cy="10.2" r="1.7"/><path d="M12 11.9v3.3"/></g><path class="icon-tick" d="m8.6 11.9 2.4 2.5 4.5-4.9"/></svg></button>
            </div>
        </div>
    </header>

    <div class="page-wrap">
        <!-- Filters -->
        <section id="viewFilters" class="mb-5" aria-label="Filters">
            <div class="toolbar">
                <div class="field">
                    <span class="field-label" aria-hidden="true">From</span>
                    <div id="fromPicker" class="flatpickr relative">
                        <input id="fromDate" data-input type="text" inputmode="numeric"
                            class="lv-input has-label pr-10 mono" style="font-size:.8125rem"
                            placeholder="YYYY-MM-DD HH:mm:ss" aria-label="From date and time" />
                        <button type="button" data-toggle class="field-btn" aria-label="Open calendar" title="Open calendar">
                            <i class="fa-solid fa-calendar-days text-sm"></i>
                        </button>
                    </div>
                </div>
                <div class="field">
                    <span class="field-label" aria-hidden="true">To</span>
                    <div id="toPicker" class="flatpickr relative">
                        <input id="toDate" data-input type="text" inputmode="numeric"
                            class="lv-input has-label pr-10 mono" style="font-size:.8125rem"
                            placeholder="YYYY-MM-DD HH:mm:ss" aria-label="To date and time" />
                        <button type="button" data-toggle class="field-btn" aria-label="Open calendar" title="Open calendar">
                            <i class="fa-solid fa-calendar-days text-sm"></i>
                        </button>
                    </div>
                </div>
                <div class="field field-search">
                    <i class="fa-solid fa-magnifying-glass field-icon"></i>
                    <input id="searchInput" type="text" placeholder="Search the full text of both blocks, stack trace, caller, server"
                        class="lv-input" style="padding-left:2.25rem" aria-label="Search logs" />
                </div>
                <button id="applyFiltersBtn" class="lv-btn-primary">Apply filters</button>
            </div>

            <div class="toolbar-row2">
                <div class="flex items-center gap-2">
                    <span class="seg-caption">Range</span>
                    <div class="seg" role="group" aria-label="Quick time range">
                        <button type="button" onclick="setToday()">Today</button>
                        <button type="button" onclick="setRange(1)">Last hour</button>
                        <button type="button" onclick="setRange(6)">Last 6 hours</button>
                        <button type="button" onclick="setRange(24)">Last 24 hours</button>
                        <button type="button" onclick="setRange(168)">Last 7 days</button>
                    </div>
                </div>
                <div class="flex items-center gap-2">
                    <label for="tzSelect" class="seg-caption">Show times in</label>
                    <select id="tzSelect" class="lv-input" style="width:15.5rem" title="The From and To fields and every time on this page use this time zone. Files are stored in server time."></select>
                </div>
                <button type="button" id="moreFiltersBtn" class="more-btn" aria-expanded="false" aria-controls="ipasFilters"><i class="fa-solid fa-sliders"></i> More filters <span id="moreCount" class="more-count hidden"></span></button>

                <!-- log4net-only filters (levels / channel / logger) -->
                <div id="log4netFilters" class="hidden flex flex-wrap items-center gap-x-5 gap-y-3">
                    <div class="flex flex-wrap items-center gap-2" role="group" aria-label="Levels">
                        <button type="button" class="lvl-chip active" data-level="TRACE">Trace</button>
                        <button type="button" class="lvl-chip active" data-level="DEBUG">Debug</button>
                        <button type="button" class="lvl-chip active" data-level="INFO">Info</button>
                        <button type="button" class="lvl-chip active" data-level="WARN">Warn</button>
                        <button type="button" class="lvl-chip active" data-level="ERROR">Error</button>
                        <button type="button" class="lvl-chip active" data-level="FATAL">Fatal</button>
                    </div>
                    <select id="channelFilter" class="lv-input" style="width:13.5rem" aria-label="Log file"><option value="">All log files</option></select>
                    <select id="loggerFilter" class="lv-input" style="width:12.5rem" aria-label="Logger"><option value="">All loggers</option></select>
                    <label class="check" title="Refresh every 10 seconds and show new entries at the top. It pauses while a row is open."><input id="l4nFollow" type="checkbox" /> Follow new entries</label>
                </div>
            </div>

            <!-- Filters for error files, built from what the loaded logs contain -->
            <div id="ipasFilters" class="toolbar-row2 collapsed">
                <select id="serverFilter" class="lv-input" style="width:11.5rem" aria-label="Server"><option value="">All servers</option></select>
                <select id="typeFilter" class="lv-input" style="width:14rem" aria-label="Error type"><option value="">All error types</option></select>
                <div class="msel" id="moduleSel">
                    <button type="button" id="moduleBtn" class="lv-input msel-btn" aria-haspopup="listbox" aria-expanded="false" aria-label="Modules">
                        <span id="moduleLabel">All modules</span><i class="fa-solid fa-chevron-down"></i>
                    </button>
                    <div id="modulePop" class="msel-pop hidden" role="group" aria-label="Choose modules">
                        <div class="msel-top"><input id="moduleSearch" type="search" class="lv-input msel-search" placeholder="Search modules" aria-label="Search modules" autocomplete="off" /><button type="button" id="moduleClear" class="linkbtn">Clear</button></div>
                        <div id="moduleList" class="pretty-scroll"></div>
                    </div>
                </div>
                <select id="callerFilter" class="lv-input" style="width:15rem" aria-label="Source or caller"><option value="">All sources / callers</option></select>
                <input id="customFilter" type="text" class="lv-input" style="width:13rem" placeholder="Custom message contains" aria-label="Custom message contains" />
                <label class="check" title="Show only errors thrown inside background (async) calls. The app wraps these as &quot;Exception has been thrown by the target of an invocation&quot;; this viewer shows the real inner error instead."><input id="asyncOnly" type="checkbox" /> Async calls only</label>
                <label class="check" title="Sync services and other background jobs listed in web.config (BackgroundLogPageNames / BackgroundLogModules). They are hidden by default so user-facing errors stand out; nothing is deleted."><input id="showBackground" type="checkbox" /> Show background/sync errors</label>
                <button type="button" id="resetFiltersBtn" class="more-btn reset-btn" title="Back to the default time range with no search and no extra filters"><i class="fa-solid fa-rotate-left"></i> Reset filters</button>
            </div>

            <div id="messageArea" class="mt-3"></div>

            <!-- Diagnostics Area (gated by EnableDiagnostics) -->
            <div id="diagArea" class="mt-3 rounded-md border border-[var(--lv-border)] bg-[var(--lv-surface)] p-3 hidden">
                <div class="mb-2 text-xs font-semibold lv-muted"><i class="fa-solid fa-bug mr-1.5"></i>Diagnostic trace</div>
                <div id="diagContent" class="grid grid-cols-1 md:grid-cols-3 gap-3 text-[11px] mono lv-muted"></div>
            </div>
        </section>

        <!-- Results -->
        <div id="viewResults" class="lv-table-container">
            <div class="results-bar">
                <div class="results-left">
                    <span id="resultsCount" class="results-count tabular" aria-live="polite"></span>
                    <span id="bgNote"></span>
                    <button type="button" id="l4nCsv" class="lv-copy-btn hidden" title="Download every entry that matches the filters as a spreadsheet file"><i class="fa-solid fa-download"></i> Download CSV</button>
                </div>
                <div id="groupsMeta" class="results-hint"></div>
            </div>

            <div class="pretty-scroll w-full overflow-auto" style="max-height: calc(100vh - 21rem)">
                <table id="logsTable" class="w-full min-w-[1500px] text-left text-sm border-separate border-spacing-0">
                    <thead id="tableHead"></thead>
                    <tbody id="logsTableBody"></tbody>
                </table>
            </div>
            <div id="pager" class="pager hidden"></div>
        </div>

        <!-- Dashboard (admin only) -->
        <section id="viewDashboard" class="hidden" aria-label="Dashboard">
            <div class="dash-bar">
                <div class="seg" role="group" aria-label="Dashboard time range">
                    <button type="button" data-drange="today" class="active">Today</button>
                    <button type="button" data-drange="24h">Last 24 hours</button>
                    <button type="button" data-drange="7d">Last 7 days</button>
                    <button type="button" data-drange="30d">Last 30 days</button>
                </div>
                <select id="dashModule" class="lv-input" style="width:15rem" aria-label="Module"><option value="">All modules</option></select>
                <label class="check"><input id="dashAuto" type="checkbox" /> Refresh every minute</label>
                <button type="button" id="dashRefresh" class="lv-copy-btn" style="height:2rem">Refresh now</button>
                <span id="dashUpdated" class="seg-caption" aria-live="polite"></span>
                <button type="button" class="linkbtn dash-signout" data-signout="1" style="margin-left:auto">Sign out</button>
            </div>
            <div id="dashNotice"></div>

            <div id="dashBody" class="dash-body">
                <div class="dash-kpis">
                    <div class="kpi kpi-hero" title="Errors people can run into"><div class="kpi-label sr-only">Errors people can run into</div><div id="kpiUser" class="kpi-value">0</div></div>
                    <div class="kpi"><div class="kpi-label">Different errors</div><div id="kpiGroups" class="kpi-value">0</div></div>
                    <div class="kpi"><div class="kpi-label">Servers affected</div><div id="kpiServers" class="kpi-value">0</div></div>
                    <div class="kpi"><div class="kpi-label">Busiest period</div><div id="kpiBusy" class="kpi-value kpi-small">none</div></div>
                    <div class="kpi"><div class="kpi-label">Background and sync errors</div><div id="kpiBg" class="kpi-value">0</div></div>
                </div>

                <div class="panel">
                    <h3 class="panel-title">Errors over time</h3>
                    <div class="legend" aria-hidden="false">
                        <span><i class="sw s1"></i>Errors people can run into</span>
                        <span><i class="sw s2"></i>Background and sync errors</span>
                    </div>
                    <div id="chartTime" class="chart"><div id="chartTip" class="chart-tip hidden" role="tooltip"></div></div>
                    <details class="chart-table">
                        <summary>Show as a table</summary>
                        <div id="chartTable" class="pretty-scroll"></div>
                    </details>
                </div>

                <div class="panel">
                    <h3 class="panel-title">Kinds of error in each module</h3>
                    <p class="panel-note">Each bar is one module, split by the kind of error. Select a module to see only that module in everything on this page; select it again to go back.</p>
                    <div id="matrixLegend" class="legend"></div>
                    <div id="matrix" class="matrix"><div id="matrixTip" class="chart-tip hidden" role="tooltip"></div></div>
                    <details class="chart-table">
                        <summary>Show as a table</summary>
                        <div id="matrixTable" class="pretty-scroll"></div>
                    </details>
                </div>

                <div class="dash-grid">
                    <div class="panel"><h3 class="panel-title">Most frequent errors</h3><p class="panel-note">Select one to open it in the error list.</p><div id="listGroups" class="barlist"></div></div>
                    <div class="panel"><h3 class="panel-title">By module</h3><div id="listModule" class="barlist"></div></div>
                    <div class="panel"><h3 class="panel-title">By kind of error</h3><div id="listCategory" class="barlist"></div></div>
                    <div class="panel"><h3 class="panel-title">By page or caller</h3><div id="listCaller" class="barlist"></div></div>
                    <div class="panel"><h3 class="panel-title">By server</h3><div id="listServer" class="barlist"></div></div>
                </div>

                <div class="panel">
                    <h3 class="panel-title">Background and sync jobs</h3>
                    <p class="panel-note">These run all the time, so they are kept apart from the errors above. The status comes from how recently a job logged an error, not from whether the job is running.</p>
                    <div id="jobsBody" class="pretty-scroll"></div>
                </div>
            </div>
        </section>

        <!-- Health (admin) -->
        <section id="viewHealth" class="hidden" aria-label="Health">
            <div class="dash-bar">
                <div class="seg" role="group" aria-label="Health range">
                    <button type="button" data-hrange="24h" class="active">Last 24 hours</button>
                    <button type="button" data-hrange="7d">Last 7 days</button>
                </div>
                <label class="check"><input id="healthAuto" type="checkbox" /> Refresh every minute</label>
                <button type="button" id="healthRefresh" class="lv-copy-btn" style="height:2rem">Refresh now</button>
                <span id="healthUpdated" class="seg-caption" aria-live="polite"></span>
                <button type="button" class="linkbtn dash-signout" data-signout="1" style="margin-left:auto">Sign out</button>
            </div>
            <div id="healthNotice"></div>
            <div id="healthBody" class="dash-body">
                <div id="healthBanner" class="health-banner"><i class="fa-solid fa-circle-notch fa-spin"></i> <span>Reading the logs…</span></div>
                <div class="health-filters">
                    <div class="seg" role="group" aria-label="Show by status">
                        <button type="button" data-hstatus="all" class="active">All <b id="hfAll" class="hf-n"></b></button>
                        <button type="button" data-hstatus="crit"><i class="fa-solid fa-circle-xmark st-crit"></i> Failing now <b id="hfCrit" class="hf-n"></b></button>
                        <button type="button" data-hstatus="warn"><i class="fa-solid fa-triangle-exclamation st-warn"></i> Errors in the last hour <b id="hfWarn" class="hf-n"></b></button>
                        <button type="button" data-hstatus="ok"><i class="fa-solid fa-circle-check st-ok"></i> Quiet <b id="hfOk" class="hf-n"></b></button>
                    </div>
                    <select id="healthModule" class="lv-input" style="width:15rem" aria-label="Module"><option value="">All modules</option></select>
                    <button type="button" id="healthClear" class="linkbtn hidden">Clear filters</button>
                </div>
                <div class="panel">
                    <h3 class="panel-title">Modules</h3>
                    <p class="panel-note">One bar per hour (or day). Green means the module logged no errors in that hour, amber some, red many. Only modules that logged at least one error in this range are listed, and "quiet" means nothing was logged, not proof that it is running. Select a name to open its errors.</p>
                    <div id="healthModules" class="hrows"></div>
                </div>
                <div class="panel">
                    <h3 class="panel-title">Background and sync jobs</h3>
                    <div id="healthJobs" class="hrows"></div>
                </div>
                <div class="panel">
                    <h3 class="panel-title">Servers</h3>
                    <div id="healthServers" class="hrows"></div>
                </div>
            </div>
        </section>

        <!-- Suggestions (everyone; admins also see who sent each one) -->
        <section id="viewSuggest" class="hidden" aria-label="Suggestions">
            <div class="sg-layout">
                <div class="sg-side">
                <div id="sgAccount" class="panel sg-accbox hidden">
                    <div id="sgSignedOut">
                        <div class="sg-gate-art" aria-hidden="true"><i class="fa-regular fa-lightbulb"></i></div>
                        <h2 class="panel-title" id="sgGateTitle">Your account</h2>
                        <p class="panel-note" id="sgSignedOutNote"></p>
                        <div class="tabs" role="tablist" aria-label="Account">
                            <button type="button" class="tab active" data-acc="in" role="tab" aria-selected="true">Sign in</button>
                            <button type="button" class="tab" data-acc="up" role="tab" id="accUpTab">Create account</button>
                            <button type="button" class="tab" data-acc="reset" role="tab">Forgot password</button>
                        </div>
                        <form id="accInForm" data-accp="in">
                            <label class="modal-label" for="accInUser">Username</label>
                            <input id="accInUser" class="lv-input" type="text" autocomplete="username" maxlength="32" required />
                            <label class="modal-label" for="accInPass">Password</label>
                            <input id="accInPass" class="lv-input" type="password" autocomplete="current-password" maxlength="128" required />
                            <button type="submit" class="lv-btn-primary sg-accbtn">Sign in</button>
                        </form>
                        <form id="accUpForm" data-accp="up" class="hidden">
                            <label class="modal-label" for="accUpUser">Username</label>
                            <input id="accUpUser" class="lv-input" type="text" autocomplete="username" maxlength="32" required />
                            <div class="sg-field-foot"><span>3 to 32 letters or digits; dots, dashes and underscores are fine</span></div>
                            <label class="modal-label" for="accUpName">Full name</label>
                            <input id="accUpName" class="lv-input" type="text" autocomplete="name" maxlength="60" required />
                            <label class="modal-label" for="accUpPass">Password</label>
                            <input id="accUpPass" class="lv-input" type="password" autocomplete="new-password" maxlength="128" required />
                            <div class="sg-field-foot"><span id="accPwHint">At least 6 characters, not your username</span></div>
                            <label class="modal-label" for="accUpPass2">Password again</label>
                            <input id="accUpPass2" class="lv-input" type="password" autocomplete="new-password" maxlength="128" required />
                            <p class="sg-privacy"><i class="fa-solid fa-circle-info" aria-hidden="true"></i><span>Your password is never stored, only a code made from it. Your name, this computer's network address and name, and a random id kept by this browser are saved with the account. Only the super admin can see them.</span></p>
                            <button type="submit" class="lv-btn-primary sg-accbtn">Create account</button>
                        </form>
                        <form id="accResetForm" data-accp="reset" class="hidden">
                            <p class="panel-note">Ask an admin for a reset code. They see it once and give it to you in person or by phone; it works for 24 hours.</p>
                            <label class="modal-label" for="accResetUser">Username</label>
                            <input id="accResetUser" class="lv-input" type="text" autocomplete="username" maxlength="32" required />
                            <label class="modal-label" for="accResetCode">Reset code</label>
                            <input id="accResetCode" class="lv-input mono" type="text" autocomplete="one-time-code" maxlength="20" placeholder="ABCDE-FGHJK" required />
                            <label class="modal-label" for="accResetPass">New password</label>
                            <input id="accResetPass" class="lv-input" type="password" autocomplete="new-password" maxlength="128" required />
                            <button type="submit" class="lv-btn-primary sg-accbtn">Set new password</button>
                        </form>
                        <div id="accMsg" class="sg-msg" role="status" aria-live="polite"></div>
                    </div>
                    <div id="sgSignedIn" class="hidden">
                        <div class="sg-me"><i class="fa-solid fa-circle-user" aria-hidden="true"></i><div class="sg-me-text"><b id="sgMeName"></b><div class="sg-agent mono" id="sgMeUser"></div></div><button type="button" class="linkbtn" id="accOut">Sign out</button></div>
                        <details class="sg-acc-more">
                            <summary>My account</summary>
                            <form id="myPassForm">
                                <label class="modal-label" for="myOldPass">Current password</label>
                                <input id="myOldPass" class="lv-input" type="password" autocomplete="current-password" maxlength="128" required />
                                <label class="modal-label" for="myNewPass">New password</label>
                                <input id="myNewPass" class="lv-input" type="password" autocomplete="new-password" maxlength="128" required />
                                <button type="submit" class="lv-copy-btn sg-accbtn">Change password</button>
                            </form>
                            <form id="myDelForm">
                                <label class="modal-label" for="myDelPass">Delete my account: type your password</label>
                                <input id="myDelPass" class="lv-input" type="password" autocomplete="current-password" maxlength="128" required />
                                <button type="submit" id="myDelBtn" class="lv-copy-btn sg-del sg-accbtn">Delete my account</button>
                                <p class="modal-note">Your suggestions stay, with your name on them.</p>
                            </form>
                            <div id="myAccMsg" class="sg-msg" role="status" aria-live="polite"></div>
                        </details>
                    </div>
                </div>
                <form id="sgForm" class="panel sg-form" novalidate>
                    <h2 class="panel-title">Suggest an improvement</h2>
                    <p class="panel-note">An idea, a problem you ran into, or something you miss in the Log Explorer. <span id="sgWho"></span></p>
                    <div id="sgOff" class="hidden"><div class="notice notice-info">Suggestions are switched off for users. Admins still see the list.</div></div>
                    <label class="modal-label" for="sgCat">Type</label>
                    <select id="sgCat" class="lv-input">
                        <option value="idea">Idea</option>
                        <option value="problem">Problem</option>
                        <option value="other">Other</option>
                    </select>
                    <label class="modal-label" for="sgTitle">Title</label>
                    <input id="sgTitle" class="lv-input" type="text" maxlength="120" autocomplete="off" aria-describedby="sgTitleCount" />
                    <div class="sg-field-foot"><span>A few words, at least 3 characters</span><span id="sgTitleCount" class="sg-count tabular">0 / 120</span></div>
                    <label class="modal-label" for="sgText">Details</label>
                    <textarea id="sgText" class="lv-input" rows="6" maxlength="1000" aria-describedby="sgTextCount"></textarea>
                    <div class="sg-field-foot"><span>What should change, and why</span><span id="sgTextCount" class="sg-count tabular">0 / 1000</span></div>
                    <div id="sgNameRow">
                        <label class="modal-label" for="sgName">Your name <span class="sg-opt">(optional)</span></label>
                        <input id="sgName" class="lv-input" type="text" maxlength="60" autocomplete="name" />
                    </div>
                    <p class="sg-privacy"><i class="fa-solid fa-circle-info" aria-hidden="true"></i><span>Saved with your suggestion: your computer's network address and name, your browser and the time. Only admins can see them. Please don't write passwords or personal data.</span></p>
                    <button id="sgSend" type="submit" class="lv-btn-primary">Send suggestion</button>
                    <div id="sgMsg" class="sg-msg" role="status" aria-live="polite"></div>
                </form>
                </div>
                <div class="sg-listwrap">
                    <div class="dash-bar">
                        <div class="seg" role="group" aria-label="Show suggestions">
                            <button type="button" data-sgf="all" class="active">All</button>
                            <button type="button" data-sgf="new">New</button>
                            <button type="button" data-sgf="planned">Planned</button>
                            <button type="button" data-sgf="done">Done</button>
                            <button type="button" data-sgf="declined">Not planned</button>
                            <button type="button" data-sgf="mine">Mine</button>
                            <button type="button" data-sgf="hidden" id="sgHiddenBtn" class="hidden">Hidden</button>
                        </div>
                        <select id="sgSort" class="lv-input" style="width:11rem" aria-label="Sort suggestions">
                            <option value="new">Newest first</option>
                            <option value="votes">Most votes first</option>
                        </select>
                        <span id="sgCountText" class="seg-caption" aria-live="polite"></span>
                    </div>
                    <div id="sgList"></div>
                </div>
            </div>
        </section>

        <!-- Settings (admin only) -->
        <section id="viewSettings" class="hidden" aria-label="Settings">
            <div class="settings-page">
                <h2 class="view-title">Settings</h2>
                <div id="adminSettingsView">
                    <div class="tabs" role="tablist">
                        <button type="button" class="tab active" data-tab="look" role="tab">Appearance</button>
                        <button type="button" class="tab" data-tab="rules" role="tab">Rules and defaults</button>
                        <button type="button" class="tab" data-tab="folders" role="tab">Log folders and limits</button>
                        <button type="button" class="tab" data-tab="suggest" role="tab">Suggestions</button>
                        <button type="button" class="tab" data-tab="users" role="tab">Users</button>
                        <button type="button" class="tab" data-tab="status" role="tab">Status</button>
                    </div>

                    <div class="tab-panel" data-panel="look">
                        <div class="sg">
                            <h3 class="sg-title">Look for everyone</h3>
                            <label class="modal-label" for="appStyle">Style</label>
                            <select id="appStyle" class="lv-input">
                                <option value="slate">Slate (default)</option>
                                <option value="teal">Cerulean &amp; rose</option>
                                <option value="web">Web</option>
                                <option value="midnight">Midnight</option>
                            </select>
                            <label class="modal-label" for="defMode">Colour mode when the page opens</label>
                            <select id="defMode" class="lv-input">
                                <option value="dark">Dark</option>
                                <option value="light">Light</option>
                                <option value="system">Follow each person's computer setting</option>
                            </select>
                            <p class="modal-note">People who switch between Dark and Light themselves keep their own choice.</p>
                        </div>
                        <div class="sg">
                            <h3 class="sg-title">Look after signing in</h3>
                            <label class="modal-label" for="adminStyle">Style for admins</label>
                            <select id="adminStyle" class="lv-input">
                                <option value="">Same as everyone</option>
                                <option value="slate">Slate</option>
                                <option value="teal">Cerulean &amp; rose</option>
                                <option value="web">Web</option>
                                <option value="midnight">Midnight</option>
                            </select>
                            <label class="modal-label" for="superStyle">Style for the super admin</label>
                            <select id="superStyle" class="lv-input">
                                <option value="">Same as everyone</option>
                                <option value="slate">Slate</option>
                                <option value="teal">Cerulean &amp; rose</option>
                                <option value="web">Web</option>
                                <option value="midnight">Midnight</option>
                            </select>
                            <p class="modal-note">Applies as soon as that person signs in, and goes back to the style for everyone when they sign out. If users may pick their own style, their own pick still wins.</p>
                        </div>
                        <div class="sg">
                            <h3 class="sg-title">Choices for users</h3>
                            <label class="check"><input id="allowUserStyles" type="checkbox" /> Let users choose a style for themselves</label>
                            <div id="userStylesBox" class="modal-sub">
                                <div class="modal-note">Users can only choose from the styles ticked here. Their choice is saved in their own browser and never changes what other people see.</div>
                                <label class="check"><input type="checkbox" class="userStyle" value="slate" /> Slate</label>
                                <label class="check"><input type="checkbox" class="userStyle" value="teal" /> Cerulean &amp; rose</label>
                                <label class="check"><input type="checkbox" class="userStyle" value="web" /> Web</label>
                                <label class="check"><input type="checkbox" class="userStyle" value="midnight" /> Midnight</label>
                            </div>
                        </div>
                    </div>

                    <div class="tab-panel hidden" data-panel="rules">
                        <div class="sg">
                            <h3 class="sg-title">Background and sync errors</h3>
                            <p class="modal-note" id="rulesSource"></p>
                            <label class="modal-label" for="rulePages">Page names, one per line</label>
                            <textarea id="rulePages" class="lv-input modal-text" rows="5" spellcheck="false"></textarea>
                            <label class="modal-label" for="ruleModules">Modules, one per line</label>
                            <textarea id="ruleModules" class="lv-input modal-text" rows="5" spellcheck="false"></textarea>
                        </div>
                        <div class="sg">
                            <h3 class="sg-title">What stays visible</h3>
                            <label class="modal-label" for="ruleAlways">Always show these custom messages, one per line</label>
                            <textarea id="ruleAlways" class="lv-input modal-text" rows="3" spellcheck="false"></textarea>
                            <label class="check" style="margin-top:.75rem"><input id="ruleHide" type="checkbox" /> Hide background errors until someone ticks "Show background/sync errors"</label>
                            <button type="button" id="rulesReset" class="linkbtn" style="margin-top:.5rem">Use the values from web.config again</button>
                        </div>
                        <div class="sg">
                            <h3 class="sg-title">When the page opens</h3>
                            <label class="modal-label" for="defRange">Time range</label>
                            <select id="defRange" class="lv-input">
                                <option value="today">Today (midnight to now)</option>
                                <option value="24h">Last 24 hours</option>
                                <option value="7d">Last 7 days</option>
                            </select>
                            <label class="modal-label" for="defZone">Time zone</label>
                            <select id="defZone" class="lv-input"></select>
                            <p class="modal-note">People who pick their own time zone keep their choice.</p>
                        </div>
                    </div>

                    <div class="tab-panel hidden" data-panel="folders">
                        <div class="sg">
                            <h3 class="sg-title">Where the logs are read from</h3>
                            <p class="modal-note" id="foldersSource"></p>
                            <label class="modal-label" for="folderLines">Error log folders, one per line</label>
                            <textarea id="folderLines" class="lv-input modal-text" rows="4" spellcheck="false" placeholder="D:\Logs\Errors"></textarea>
                            <p class="modal-note">To read several servers, start each line with a name and an equals sign, for example <span class="mono">SERVER1=\\SERVER1\D$\Logs\Errors</span>. The account the site runs under must be allowed to read each folder.</p>
                            <label class="modal-label" for="log4netFolder">log4net folder</label>
                            <input id="log4netFolder" class="lv-input mono" type="text" spellcheck="false" style="font-size:.8125rem" />
                            <div class="modal-actions" style="margin-top:.75rem">
                                <button type="button" id="testFolders" class="lv-copy-btn" title="Check the folders without saving anything">Test these folders</button>
                                <button type="button" id="foldersReset" class="linkbtn">Use the values from web.config again</button>
                            </div>
                            <div id="folderResult" class="modal-note" role="status"></div>
                        </div>
                        <div class="sg">
                            <h3 class="sg-title">How many files to read</h3>
                            <label class="modal-label" for="limFiles">Most files to read when nobody is searching</label>
                            <input id="limFiles" class="lv-input mono" type="number" min="100" max="100000" step="100" style="width:10rem" />
                            <label class="modal-label" for="limSearch">Most files to search through in one search</label>
                            <input id="limSearch" class="lv-input mono" type="number" min="100" max="200000" step="100" style="width:10rem" />
                            <p class="modal-note">The newest files are read first, and the page tells people when a limit cut a range short. A remembered file costs about 0.6 KB of memory (20,000 files is roughly 12 MB), and the first read after a restart takes about 30 to 60 seconds for 20,000 files. Searching reads the whole text of every file, so keep that number lower. The dashboard has its own, much higher limit (DashboardMaxFiles in web.config). Your server writes roughly 550 error files an hour, so 20,000 covers about a day and a half.</p>
                        </div>
                    </div>

                    <div class="tab-panel hidden" data-panel="suggest">
                        <div class="sg">
                            <h3 class="sg-title">Suggestions tab</h3>
                            <label class="check"><input id="sgEnabled" type="checkbox" /> Let people send suggestions</label>
                            <label class="check"><input id="sgVisible" type="checkbox" /> Everyone can read all suggestions and replies</label>
                            <label class="check"><input id="sgNeedSignIn" type="checkbox" /> Sending and voting need a user account</label>
                            <label class="check"><input id="sgSignUpOpen" type="checkbox" /> People may create their own account</label>
                            <p class="modal-note">When this is off, people only see the suggestions sent from their own computer.</p>
                            <label class="modal-label" for="sgMax">Most characters in the details (100 to 5000)</label>
                            <input id="sgMax" class="lv-input" type="number" min="100" max="5000" step="50" />
                            <label class="modal-label" for="sgPerHour">Most suggestions per computer per hour (1 to 50)</label>
                            <input id="sgPerHour" class="lv-input" type="number" min="1" max="50" />
                            <label class="modal-label" for="sgPwMin">Shortest password for user accounts (2 to 64)</label>
                            <input id="sgPwMin" class="lv-input" type="number" min="2" max="64" />
                            <p class="modal-note">6 or more is recommended. Five wrong tries lock a name for 5 minutes, but a very short password can still be guessed by a colleague who wants to post in someone else's name.</p>
                        </div>
                        <div class="sg">
                            <h3 class="sg-title">What is saved about the sender</h3>
                            <p class="modal-note">The computer's network address, its name from the office DNS (when DNS knows the address), the browser and the time. The Windows user name is saved too once Windows Authentication is turned on for this site in IIS. People are told this next to the form. Only admins see these details, and every admin change (status, reply, hide, delete) is written to the activity log.</p>
                            <p class="modal-note">A shared computer or a remote desktop server gives one address to many people, so treat the address as a strong hint, not proof.</p>
                        </div>
                    </div>

                    <div class="tab-panel hidden" data-panel="users">
                        <div class="dash-bar"><h3 class="sg-title" style="border:0;margin:0;padding:0">User accounts</h3><span id="usersCount" class="seg-caption"></span>
                            <button type="button" class="lv-copy-btn" style="margin-left:auto" onclick="loadUsersAdmin()">Refresh</button></div>
                        <p class="modal-note">Accounts for the Suggestions tab. Passwords are never stored, and the file is encrypted with this server's key. "Same browser as" means one browser was used for several accounts, worth a look if posts look odd. A reset code is shown once: give it to the person directly.</p>
                        <div id="usersMsg" class="sg-msg ok" role="status" aria-live="polite"></div>
                        <div id="usersBody" class="users-wrap"></div>
                    </div>

                    <div class="tab-panel hidden" data-panel="status">
                        <div class="sg">
                            <h3 class="sg-title">Log folders and memory</h3>
                            <div id="statusBody" class="modal-note">Loading…</div>
                            <button type="button" id="clearCacheBtn" class="lv-copy-btn" style="margin-top:.75rem" title="Forget everything read so far. The next search reads the log files again.">Re-read logs now</button>
                        </div>
                        <div class="sg">
                            <h3 class="sg-title">Recent admin activity</h3>
                            <pre id="auditBox" class="audit-box"></pre>
                        </div>
                    </div>

                    <div id="adminSaved" class="modal-note" role="status"></div>
                    <div class="modal-actions">
                        <button id="adminSave" type="button" class="lv-btn-primary">Save</button>
                        <button id="adminSignOut" type="button" class="icon-btn" style="margin-left:auto" data-signout="1">Sign out</button>
                    </div>
                </div>
            </div>
        </section>
    </div>

    <div id="adminModal" class="modal hidden" role="dialog" aria-modal="true" aria-labelledby="adminTitle">
        <div class="modal-backdrop" data-close="1"></div>
        <div class="modal-panel">
            <div class="modal-head">
                <h2 id="adminTitle" class="modal-title">Admin sign-in</h2>
                <button type="button" class="expand-btn" data-close="1" aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
            </div>

            <form id="adminLoginView" autocomplete="off">
                <p class="modal-note" id="adminLoginNote">Sign in to change how the Log Explorer looks for everyone.</p>
                <label class="modal-label" for="adminUser">Username</label>
                <input id="adminUser" class="lv-input" type="text" autocomplete="username" />
                <label class="modal-label" for="adminPass">Password</label>
                <input id="adminPass" class="lv-input" type="password" autocomplete="current-password" />
                <div id="adminError" class="modal-error" role="alert"></div>
                <button id="adminSignIn" type="submit" class="lv-btn-primary" style="width:100%;margin-top:.75rem">Sign in</button>
            </form>

        </div>
    </div>

    <script>
        // ===================== Time zones =====================
        // Log files (name and TimeStamp) are SERVER time. The From/To fields and every time shown use the zone
        // picked in "Show times in"; requests always go to the server converted back to SERVER time.
        const SERVER_OFFSET_MIN = Number(window.__SERVER_OFFSET) || 0;
        const HIDE_BG_DEFAULT = (window.__UI && typeof window.__UI.hideBackground === 'boolean') ? window.__UI.hideBackground : !!window.__HIDE_BG;
        const TZ_KEY = 'lv_tz';
        let __tz = 'server';

        const ZONE_LIST = [
            ['America/New_York', 'US Eastern'], ['America/Chicago', 'US Central'], ['America/Denver', 'US Mountain'],
            ['America/Los_Angeles', 'US Pacific'], ['Europe/London', 'UK'], ['Europe/Berlin', 'Central Europe'],
            ['Asia/Dubai', 'Gulf'], ['Asia/Kolkata', 'India'], ['Asia/Shanghai', 'China'], ['Asia/Singapore', 'Singapore'],
            ['Asia/Tokyo', 'Japan'], ['Australia/Sydney', 'Sydney']
        ];

        const __dtfCache = {};
        function dtf(zone) {
            if (!__dtfCache[zone]) {
                __dtfCache[zone] = new Intl.DateTimeFormat('en-US', {
                    timeZone: zone, hourCycle: 'h23', year: 'numeric', month: '2-digit', day: '2-digit',
                    hour: '2-digit', minute: '2-digit', second: '2-digit'
                });
            }
            return __dtfCache[zone];
        }

        // Offset (minutes east of UTC) of a zone at a given instant.
        function tzOffsetMin(zone, epochMs) {
            if (zone === 'server') return SERVER_OFFSET_MIN;
            if (zone === 'browser') return -new Date(epochMs).getTimezoneOffset();
            const p = {};
            dtf(zone).formatToParts(new Date(epochMs)).forEach(x => { p[x.type] = x.value; });
            const asUtc = Date.UTC(+p.year, +p.month - 1, +p.day, (+p.hour) % 24, +p.minute, +p.second);
            return Math.round((asUtc - Math.floor(epochMs / 1000) * 1000) / 60000);
        }

        const pad2 = (n) => String(n).padStart(2, '0');
        function fmtOffset(min) {
            const sign = min < 0 ? '-' : '+';
            const a = Math.abs(min);
            return 'UTC' + sign + pad2(Math.floor(a / 60)) + ':' + pad2(a % 60);
        }
        // Wall-clock text of an instant in a zone: "YYYY-MM-DD HH:mm:ss"
        function epochToWallStr(zone, epochMs) {
            const d = new Date(epochMs + tzOffsetMin(zone, epochMs) * 60000);
            return d.getUTCFullYear() + '-' + pad2(d.getUTCMonth() + 1) + '-' + pad2(d.getUTCDate()) + ' ' +
                   pad2(d.getUTCHours()) + ':' + pad2(d.getUTCMinutes()) + ':' + pad2(d.getUTCSeconds());
        }
        function wallToEpoch(zone, y, mo, d, h, mi, s) {
            const guess = Date.UTC(y, mo - 1, d, h, mi, s);
            const first = guess - tzOffsetMin(zone, guess) * 60000;
            return guess - tzOffsetMin(zone, first) * 60000;
        }
        const FIELD_RE = /^\s*(\d{4})-(\d{2})-(\d{2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?\s*$/;
        // Reads a From/To field in the given zone. A value typed without seconds means the whole minute for To.
        function fieldToEpoch(id, isTo, zone) {
            const m = FIELD_RE.exec(document.getElementById(id).value);
            if (!m) return null;
            const hasSec = m[6] !== undefined;
            const sec = hasSec ? +m[6] : (isTo ? 59 : 0);
            return wallToEpoch(zone || __tz, +m[1], +m[2], +m[3], +m[4], +m[5], sec);
        }
        function epochToServerStr(epochMs) {
            const d = new Date(epochMs + SERVER_OFFSET_MIN * 60000);
            return d.getUTCFullYear() + '-' + pad2(d.getUTCMonth() + 1) + '-' + pad2(d.getUTCDate()) + 'T' +
                   pad2(d.getUTCHours()) + ':' + pad2(d.getUTCMinutes()) + ':' + pad2(d.getUTCSeconds());
        }
        const SERVER_STR_RE = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/;
        function serverStrToEpoch(s) {
            const m = SERVER_STR_RE.exec(s || '');
            if (!m) return null;
            return Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]) - SERVER_OFFSET_MIN * 60000;
        }
        // A server-time string from the API, shown in the selected zone.
        function fmtServerStr(s) {
            const e = serverStrToEpoch(s);
            return e === null ? '—' : epochToWallStr(__tz, e);
        }
        function zoneLabel(zone) {
            const now = Date.now();
            if (zone === 'server') return 'Server time (' + fmtOffset(SERVER_OFFSET_MIN) + ')';
            if (zone === 'browser') return 'My browser time (' + fmtOffset(tzOffsetMin('browser', now)) + ')';
            const name = (ZONE_LIST.find(z => z[0] === zone) || [zone, zone])[1];
            return name + ' (' + fmtOffset(tzOffsetMin(zone, now)) + ')';
        }

        // Returns {from, to} as SERVER-time strings, or null (with a message) when a field is invalid.
        function serverBounds() {
            const f = fieldToEpoch('fromDate', false);
            const t = fieldToEpoch('toDate', true);
            if (f === null || t === null) {
                showMessage('Enter From and To as YYYY-MM-DD HH:mm:ss, or pick them from the calendar.', 'error');
                return null;
            }
            if (f > t) {
                showMessage('From is after To. Swap the two dates.', 'error');
                return null;
            }
            return { from: epochToServerStr(f), to: epochToServerStr(t) };
        }

        let __fpFrom = null, __fpTo = null;
        function setField(id, text) {
            const fp = id === 'fromDate' ? __fpFrom : __fpTo;
            if (fp) fp.setDate(text, false); else document.getElementById(id).value = text;
        }
        function setFieldsFromEpoch(fromMs, toMs) {
            setField('fromDate', epochToWallStr(__tz, fromMs));
            setField('toDate', epochToWallStr(__tz, toMs));
        }
        // Midnight at the start of today in the selected zone.
        function startOfTodayEpoch() {
            const t = epochToWallStr(__tz, Date.now()).split(/[- :]/).map(Number);
            return wallToEpoch(__tz, t[0], t[1], t[2], 0, 0, 0);
        }
        function applyDefaultRange() {
            const r = (window.__UI && window.__UI.defaultRange) || 'today';
            const now = Date.now();
            const from = r === '24h' ? now - 24 * 3600 * 1000 : (r === '7d' ? now - 7 * 24 * 3600 * 1000 : startOfTodayEpoch());
            setFieldsFromEpoch(from, now);
        }
        function setToday() {
            setFieldsFromEpoch(startOfTodayEpoch(), Date.now());
            loadLogs();
        }
        function setRange(hours) {
            const to = Date.now();
            setFieldsFromEpoch(to - hours * 3600 * 1000, to);
            loadLogs();
        }

        function buildZoneSelect() {
            const sel = document.getElementById('tzSelect');
            const opts = [['server', zoneLabel('server')], ['browser', zoneLabel('browser')]]
                .concat(ZONE_LIST.map(z => [z[0], zoneLabel(z[0])]));
            sel.innerHTML = opts.map(o => `<option value="${escapeHtml(o[0])}">${escapeHtml(o[1])}</option>`).join('');
            sel.value = __tz;
        }

        function changeZone(next) {
            // Keep the same instants in the From/To fields, written in the new zone.
            const f = fieldToEpoch('fromDate', false), t = fieldToEpoch('toDate', true);
            __tz = next;
            try { localStorage.setItem(TZ_KEY, next); } catch (e) { }
            if (f !== null && t !== null) setFieldsFromEpoch(f, t);
            if (__source === 'log4net') renderStream(window.__streamEntries || []);
            else renderLogs(__lastGroupsRaw || []);
        }

        // ===================== Helpers =====================
        function parseDotNetDate(value) {
            if (!value) return null;
            if (typeof value === 'string') {
                const m = /\/Date\((-?\d+)\)\//.exec(value);
                if (m) return new Date(parseInt(m[1], 10));
                const d = new Date(value);
                return isNaN(d.getTime()) ? null : d;
            }
            if (typeof value === 'number') {
                const d = new Date(value);
                return isNaN(d.getTime()) ? null : d;
            }
            return null;
        }

        // log4net timestamps arrive as /Date(ms)/ instants; shown in the selected zone.
        function formatTimestamp(value) {
            const d = parseDotNetDate(value);
            return d ? epochToWallStr(__tz, d.getTime()) : '—';
        }

        function timeAgo(dateVal) {
            const d = (dateVal instanceof Date) ? dateVal : parseDotNetDate(dateVal);
            if (!d) return '—';

            const diffMs = Date.now() - d.getTime();
            if (diffMs < 0) return 'just now';

            const sec = Math.floor(diffMs / 1000);
            if (sec < 60) return 'just now';
            const min = Math.floor(sec / 60);
            if (min < 60) return `${min} min ago`;
            const hr = Math.floor(min / 60);
            if (hr < 24) return `${hr} hr ago`;
            const days = Math.floor(hr / 24);
            if (days < 7) return `${days} days ago`;
            return epochToWallStr(__tz, d.getTime()).slice(0, 16);
        }

        const __escapeMap = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
        function escapeHtml(text) {
            if (text == null) return '';
            return String(text).replace(/[&<>"']/g, (c) => __escapeMap[c]);
        }

        // Escapes text and wraps every case-insensitive match of the search term in <mark>.
        function highlight(text, term) {
            const raw = text == null ? '' : String(text);
            if (!term) return escapeHtml(raw);
            const t = String(term).replace(/[.*+?^$()|[\]\\{}]/g, '\\$&');
            try { return raw.split(new RegExp('(' + t + ')', 'gi')).map((p, i) => i % 2 ? '<mark>' + escapeHtml(p) + '</mark>' : escapeHtml(p)).join(''); }
            catch (e) { return escapeHtml(raw); }
        }

        function formatStackTrace(notes) {
            if (!notes) return '';
            const trimmed = String(notes).trim();
            if (!trimmed) return '';
            const parts = trimmed.split(' at ');
            if (parts.length === 1) return trimmed;
            return parts[0] + '\n  at ' + parts.slice(1).join('\n  at ');
        }

        function formatStackTraceHtml(notes) {
            const text = formatStackTrace(notes);
            if (!text) return '';
            const lines = text.split('\n');
            return lines.map(line => {
                const idx = line.indexOf('at ');
                if (idx >= 0) {
                    const before = escapeHtml(line.slice(0, idx));
                    const kw = `<span style="color:var(--st-kw)">at </span>`;

                    let rest = line.slice(idx + 3);
                    const lastDot = rest.lastIndexOf('.');
                    if (lastDot > 0) {
                        const ns = `<span style="color:var(--st-ns)">${escapeHtml(rest.slice(0, lastDot + 1))}</span>`;
                        const fn = `<span style="color:var(--st-fn)">${escapeHtml(rest.slice(lastDot + 1))}</span>`;
                        rest = ns + fn;
                    } else {
                        rest = `<span style="color:var(--st-fn)">${escapeHtml(rest)}</span>`;
                    }

                    return `${before}${kw}${rest}`;
                }
                return `<span style="color:var(--st-line)">${escapeHtml(line)}</span>`;
            }).join('\n');
        }

        async function handleCopy(btn, text) {
            if (!btn.dataset.orig) btn.dataset.orig = btn.innerHTML;
            const originalContent = btn.dataset.orig;
            try {
                if (navigator.clipboard && navigator.clipboard.writeText) {
                    await navigator.clipboard.writeText(text);
                } else {
                    const textarea = document.createElement('textarea');
                    textarea.value = text;
                    textarea.style.position = 'fixed';
                    textarea.style.left = '-9999px';
                    document.body.appendChild(textarea);
                    textarea.select();
                    document.execCommand('copy');
                    document.body.removeChild(textarea);
                }
                btn.innerHTML = '<i class="fa-solid fa-check"></i> Copied';
                btn.classList.add('copied');
                setTimeout(() => {
                    btn.innerHTML = originalContent;
                    btn.classList.remove('copied');
                }, 2000);
            } catch (err) {
                console.error('Copy failed', err);
            }
        }

        // append=true adds another notice under the existing ones.
        function showMessage(message, type, append) {
            const messageArea = document.getElementById('messageArea');
            const glyphs = { error: 'fa-triangle-exclamation', info: 'fa-circle-info', success: 'fa-circle-check' };
            const kind = glyphs[type] ? type : 'success';
            const html = `
                <div class="notice notice-${kind}" role="alert">
                    <i class="fa-solid ${glyphs[kind]} lead"></i>
                    <div>${escapeHtml(message)}</div>
                    <button type="button" aria-label="Dismiss message" onclick="this.parentNode.remove()">
                        <i class="fa-solid fa-xmark"></i>
                    </button>
                </div>`;
            if (append) messageArea.insertAdjacentHTML('beforeend', html); else messageArea.innerHTML = html;
        }

        function updateDiag(info) {
            if (!window.__DIAG) return; // disabled in prod via EnableDiagnostics
            const diagArea = document.getElementById('diagArea');
            const diagContent = document.getElementById('diagContent');
            if (!diagArea || !diagContent) return;
            diagArea.classList.remove('hidden');
            let html = '';
            for (const [k, v] of Object.entries(info)) {
                html += `<div><span class="font-semibold">${escapeHtml(k)}:</span> ${escapeHtml(v)}</div>`;
            }
            diagContent.innerHTML = html;
        }

        function showLoading(show) {
            if (!show) return;
            document.getElementById('logsTableBody').innerHTML = `
                <tr>
                    <td colspan="${currentColspan()}">
                        <span class="sr-only">Reading log files…</span>
                        <div class="sk-rows" aria-hidden="true">${[62, 48, 70, 55, 66, 44].map(w => '<div class="sk"><i style="width:4%"></i><i style="width:9%"></i><i style="width:' + w + '%"></i><i style="width:12%"></i><i style="width:8%"></i></div>').join('')}</div>
                    </td>
                </tr>`;
        }

        // ===================== State =====================
        let __lastGroupsRaw = [];
        let __listSeq = 0, __listInFlight = 0;   // which list request is the newest, and how many are still running
        let __lastQuery = null;                  // what the shown list was asked with (occurrences use the same)
        let __lastResult = null;

        // ---- paging (groups table and log4net list are paged in the browser; occurrences are paged by the server) ----
        function lsGet(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
        function lsSet(k, v) { try { localStorage.setItem(k, v); } catch (e) { } }
        const PAGE_SIZES = { ipas: [10, 25, 50, 100], log4net: [10, 25, 50, 100, 250] };
        const __pageSize = { ipas: Number(lsGet('lv_gsize')) || 10, log4net: Number(lsGet('lv_lsize')) || 50 };
        let __page = 1;

        function pageNumbers(cur, pages) {
            if (pages <= 7) return Array.from({ length: pages }, (_, i) => i + 1);
            const set = new Set([1, 2, pages - 1, pages, cur - 1, cur, cur + 1]);
            const list = Array.from(set).filter(n => n >= 1 && n <= pages).sort((a, b) => a - b);
            const out = [];
            list.forEach((n, i) => { if (i > 0 && n - list[i - 1] > 1) out.push('…'); out.push(n); });
            return out;
        }
        function rerenderCurrent() {
            if (__source === 'log4net') renderStream(window.__streamEntries || []); else renderLogs(__lastGroupsRaw || []);
            const sc = document.querySelector('.lv-table-container .overflow-auto'); if (sc) sc.scrollTop = 0;
        }
        function renderPager(total) {
            const el = document.getElementById('pager');
            const key = __source, size = __pageSize[key], sizes = PAGE_SIZES[key];
            if (total <= sizes[0]) { el.classList.add('hidden'); el.innerHTML = ''; return; }
            const pages = Math.max(1, Math.ceil(total / size));
            const a = (__page - 1) * size + 1, b = Math.min(total, __page * size);
            const noun = key === 'log4net' ? 'entries' : 'groups';
            el.innerHTML =
                '<span class="pg-info tabular">Showing ' + a + '–' + b + ' of ' + total + ' ' + noun + '</span>' +
                '<span class="pg-nav">' +
                '<button type="button" class="pg-btn" data-page="' + (__page - 1) + '"' + (__page <= 1 ? ' disabled' : '') + ' aria-label="Previous page"><i class="fa-solid fa-chevron-left"></i></button>' +
                pageNumbers(__page, pages).map(n => n === '…' ? '<span class="pg-gap">…</span>'
                    : '<button type="button" class="pg-btn' + (n === __page ? ' current' : '') + '" data-page="' + n + '"' + (n === __page ? ' aria-current="page"' : '') + '>' + n + '</button>').join('') +
                '<button type="button" class="pg-btn" data-page="' + (__page + 1) + '"' + (__page >= pages ? ' disabled' : '') + ' aria-label="Next page"><i class="fa-solid fa-chevron-right"></i></button>' +
                '</span>' +
                '<label class="pg-rows">Rows per page <select class="lv-input pg-size">' + sizes.map(n => '<option value="' + n + '"' + (n === size ? ' selected' : '') + '>' + n + '</option>').join('') + '</select></label>';
            el.classList.remove('hidden');
            el.querySelectorAll('[data-page]').forEach(btn => btn.addEventListener('click', () => {
                if (btn.disabled) return;
                __page = Number(btn.dataset.page); rerenderCurrent();
            }));
            el.querySelector('.pg-size').addEventListener('change', (e) => {
                __pageSize[key] = Number(e.target.value); lsSet(key === 'log4net' ? 'lv_lsize' : 'lv_gsize', e.target.value);
                __page = 1; rerenderCurrent();
            });
        }

        // Active log source: 'ipas' (grouped errors) or 'log4net' (chronological stream)
        let __source = 'ipas';
        let __activeLevels = new Set(['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL']);
        const __selModules = new Set();

        function currentColspan() { return __source === 'log4net' ? 7 : 11; }

        // ===================== Page wiring =====================
        document.addEventListener('DOMContentLoaded', function () {
            // Theme toggle (persisted)
            const themeKey = 'lv_theme';
            const applyTheme = (theme) => {
                const next = theme === 'light' ? 'light' : 'dark';
                document.documentElement.setAttribute('data-theme', next);

                const icon = document.getElementById('themeIcon');
                const label = document.getElementById('themeLabel');
                if (icon) icon.className = next === 'light' ? 'fa-solid fa-sun' : 'fa-solid fa-moon';
                if (label) label.textContent = next === 'light' ? 'Light' : 'Dark';
            };

            let savedTheme = null;
            try { savedTheme = localStorage.getItem(themeKey); } catch (e) { }
            // the head script already chose: the person's saved choice, else the admin's default (Dark unless changed)
            applyTheme(savedTheme === 'light' || savedTheme === 'dark' ? savedTheme : document.documentElement.getAttribute('data-theme'));

            document.getElementById('themeToggleBtn')?.addEventListener('click', () => {
                const cur = document.documentElement.getAttribute('data-theme') || 'dark';
                const next = cur === 'light' ? 'dark' : 'light';
                try { localStorage.setItem(themeKey, next); } catch (e) { }
                applyTheme(next);
            });

            // Colour style: the admin decides what is on offer (see Admin dialog)
            buildStylePicker();
            wireSuggestions(); wireAccounts(); wireUsersAdmin(); applySuggestTab();
            document.querySelector('.tab[data-tab="users"]').addEventListener('click', () => loadUsersAdmin());
            wireAdmin();

            // Time zone: the admin's default, unless this person picked their own
            __tz = (window.__UI && window.__UI.defaultZone) || 'server';
            try { const z = localStorage.getItem(TZ_KEY); if (z) __tz = z; } catch (e) { }
            buildZoneSelect();
            if (document.getElementById('tzSelect').value !== __tz) { __tz = 'server'; document.getElementById('tzSelect').value = 'server'; }
            document.getElementById('tzSelect').addEventListener('change', (e) => changeZone(e.target.value));

            // Calendar pickers (24 h, with seconds, so exact windows like 11:18:00-11:20:00 are possible)
            if (typeof flatpickr === 'function') {
                const pickerOptions = {
                    enableTime: true,
                    enableSeconds: true,
                    time_24hr: true,
                    allowInput: true,
                    dateFormat: 'Y-m-d H:i:S',
                    minuteIncrement: 1,
                    wrap: true,
                    disableMobile: 'true',
                    onClose: function (selectedDates, dateStr, instance) {
                        if (instance.input) instance.input.value = dateStr;
                    }
                };
                __fpFrom = flatpickr('#fromPicker', pickerOptions);
                __fpTo = flatpickr('#toPicker', pickerOptions);
            }

            // Default range chosen by the admin (today so far, last 24 hours or last 7 days), written in the selected zone.
            applyDefaultRange();
            byId('resetFiltersBtn').addEventListener('click', () => { resetIpasFilters(); loadLogs(); });

            // Source tabs (grouped error-file view <-> log4net stream view)
            document.querySelectorAll('.src-tab').forEach(btn => {
                btn.addEventListener('click', () => {
                    const to = btn.dataset.source || btn.dataset.view;
                    if (to === 'ipas' && __view !== 'ipas' && __drilled) resetIpasFilters();
                    showView(to);
                });
            });

            // log4net level chips
            document.querySelectorAll('.lvl-chip').forEach(chip => {
                chip.addEventListener('click', () => {
                    const lvl = chip.dataset.level;
                    if (__activeLevels.has(lvl)) { __activeLevels.delete(lvl); chip.classList.remove('active'); }
                    else { __activeLevels.add(lvl); chip.classList.add('active'); }
                    loadLogs();
                });
            });

            // log4net channel / logger dropdowns
            document.getElementById('channelFilter').addEventListener('change', loadLogs);
            document.getElementById('loggerFilter').addEventListener('change', loadLogs);

            // error-file filters
            ['serverFilter', 'typeFilter', 'callerFilter'].forEach(id => document.getElementById(id).addEventListener('change', loadLogs));
            document.getElementById('asyncOnly').addEventListener('change', loadLogs);
            document.getElementById('showBackground').checked = !HIDE_BG_DEFAULT;
            document.getElementById('showBackground').addEventListener('change', loadLogs);
            document.getElementById('customFilter').addEventListener('keypress', (e) => { if (e.key === 'Enter') loadLogs(); });
            wireModulePicker();
            byId('moreFiltersBtn').addEventListener('click', () => setMoreOpen(byId('ipasFilters').classList.contains('collapsed')));
            setMoreOpen(lsGet('lv_more') === '1');
            byId('l4nFollow').addEventListener('change', updateFollow);
            byId('l4nCsv').addEventListener('click', downloadCsv);
            ['serverFilter', 'typeFilter', 'callerFilter', 'channelFilter', 'loggerFilter', 'dashModule', 'healthModule'].forEach(makeSearchable);

            document.getElementById('applyFiltersBtn').addEventListener('click', loadLogs);
            document.getElementById('searchInput').addEventListener('keypress', function (e) {
                if (e.key === 'Enter') loadLogs();
            });

            // Initialise the default source (sets header, then loads)
            switchSource('ipas');
        });

        // ===================== Colour style + admin =====================
        const STYLE_NAMES = { slate: 'Slate', teal: 'Cerulean & rose', web: 'Web', midnight: 'Midnight' };

        function effectiveStyle() {
            const ui = window.__UI || {};
            const role = (typeof __role !== 'undefined' && __role) || null;
            let style = (role === 'superadmin' && ui.superStyle) || (role === 'admin' && ui.adminStyle) || ui.appStyle || 'slate', pref = null;
            try { pref = localStorage.getItem('lv_palette'); } catch (e) { }
            if (ui.allowUserStyles && pref && (ui.userStyles || []).indexOf(pref) >= 0) style = pref;
            else if (pref) { try { localStorage.removeItem('lv_palette'); } catch (e) { } }
            return style;
        }
        function applyStyle() {
            const style = effectiveStyle();
            if (style === 'web' || style === 'midnight' || style === 'slate') document.documentElement.setAttribute('data-palette', style);
            else document.documentElement.removeAttribute('data-palette');
            restartAmbient();
            return style;
        }
        function buildStylePicker() {
            const ui = window.__UI || {};
            const sel = document.getElementById('paletteSelect');
            const style = applyStyle();
            const list = ui.allowUserStyles ? (ui.userStyles || []) : [];
            sel.innerHTML = list.map(v => '<option value="' + v + '">' + STYLE_NAMES[v] + '</option>').join('');
            sel.hidden = list.length === 0;
            sel.value = style;
            sel.onchange = () => {
                try { localStorage.setItem('lv_palette', sel.value); } catch (e) { }
                applyStyle();
            };
        }

        async function pageMethod(name, body) {
            const r = await fetch('Default.aspx/' + name, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) });
            const j = await r.json();
            return j.d;
        }

        // ===================== Views: logs, dashboard, settings =====================
        const byId = (id) => document.getElementById(id);
        let __view = 'ipas';
        let __isAdmin = false;

        function showView(name) {
            if (name === 'settings' && __role !== 'superadmin') name = 'dashboard';   // settings are for the super admin only
            if (name === 'suggest' && !suggestOn()) name = 'ipas';
            __view = name;
            const logs = (name === 'ipas' || name === 'log4net');
            byId('viewFilters').classList.toggle('hidden', !logs);
            byId('viewResults').classList.toggle('hidden', !logs);
            byId('viewDashboard').classList.toggle('hidden', name !== 'dashboard');
            byId('viewHealth').classList.toggle('hidden', name !== 'health');
            byId('viewSettings').classList.toggle('hidden', name !== 'settings');
            byId('viewSuggest').classList.toggle('hidden', name !== 'suggest');
            document.querySelectorAll('.src-tab').forEach(b => {
                const on = (b.dataset.source || b.dataset.view) === name;
                b.classList.toggle('active', on); b.setAttribute('aria-selected', on ? 'true' : 'false');
            });
            stopDashTimer();
            if (logs) switchSource(name);
            else if (name === 'dashboard') { loadDashboard(); startDashTimer(); }
            else if (name === 'health') { loadHealth(); startDashTimer(); }
            else if (name === 'settings' && window.__adminOpenSettings) window.__adminOpenSettings();
            else if (name === 'suggest') { loadSuggestions(); try { localStorage.setItem('lv_sg_seen', '1'); } catch (e) { } byId('sgDot').classList.add('hidden'); }
            updateFollow();
        }

        // admin tabs only exist while an admin is signed in
        // "admin" sees the dashboard; "superadmin" also sees the Settings page
        let __role = null;
        function setAdminUI(admin, role) {
            __isAdmin = !!admin;
            __role = admin ? (role || 'admin') : null;
            document.querySelectorAll('.admin-only').forEach(el => el.classList.toggle('hidden', !admin));
            document.querySelectorAll('.super-only').forEach(el => { if (__role !== 'superadmin') el.classList.add('hidden'); });
            const b = byId('adminBtn');
            b.classList.toggle('signed-in', !!admin);
            b.title = admin ? 'Signed in as ' + (__role === 'superadmin' ? 'super admin' : 'admin') + '. Open the dashboard' : 'Admin sign-in';
            buildStylePicker();          // the style chosen for this role (if any) applies straight away
            applySuggestTab(); refreshSgBadge();
            if (!admin && (__view === 'dashboard' || __view === 'health' || __view === 'settings')) showView('ipas');
            else if (__role !== 'superadmin' && __view === 'settings') showView('dashboard');
        }

        // ===================== Ambient motion, and the loader that goes with each style =====================
        // Idle: now and then one small creature crosses the header, from a random side at a random height.
        // Loading: a thin progress line under the header, and a few more of them, quicker, until the page is ready.
        //   Midnight: bats.  Web: spiders swinging on threads.  Teal: small lights running along the header's edge.
        // Nothing runs for people who ask their computer to reduce motion.
        const MOTION_OK = !(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
        const FX_BAT = 'M30 6L27 2L26 8C20 7 12 8 2 4C5 10 6 16 9 21C12 17 15 17 18 21C21 16 25 17 27 22L30 18L33 22C35 17 39 16 42 21C45 17 48 17 51 21C54 16 55 10 58 4C48 8 40 7 34 8L33 2Z';
        const FX_SPIDER = '<svg viewBox="0 0 24 26" width="20" height="22"><g class="legs" stroke="#e62429" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" fill="none"><path d="M9.5 11L4.5 7L2 9"/><path d="M9 13L3.5 12L1.5 15"/><path d="M9 15L4 18L2.5 22"/><path d="M10 17L7.5 21.5L7 24"/><path d="M14.5 11L19.5 7L22 9"/><path d="M15 13L20.5 12L22.5 15"/><path d="M15 15L20 18L21.5 22"/><path d="M14 17L16.5 21.5L17 24"/></g><ellipse cx="12" cy="15" rx="4.4" ry="5.6" fill="#e62429"/><circle cx="12" cy="8.4" r="3" fill="#e62429"/></svg>';
        let __busy = 0, __busyTimer = null, __ambientTimer = null, __fxCount = 0;
        const fxRand = (a, b) => a + Math.random() * (b - a);
        const fxStyle = () => document.documentElement.getAttribute('data-palette') || 'teal';   // slate and teal share the calm "light packets"

        function fxRun(el, frames, duration, easing, max) {
            const box = byId('fx');
            if (!box || !MOTION_OK || document.hidden || __fxCount >= (max || 5)) return;
            __fxCount++;
            box.appendChild(el);
            const anim = el.animate(frames, { duration: duration, easing: easing || 'linear', fill: 'forwards' });
            const done = () => { if (el.parentNode) { el.remove(); __fxCount--; } };
            anim.onfinish = done; anim.oncancel = done;
        }

        function fxBat(fast) {
            const box = byId('fx'); if (!box) return;
            const W = box.clientWidth || 1200, H = box.clientHeight || 52;
            const size = fxRand(14, 26), kind = Math.floor(fxRand(0, 3));
            const el = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            el.setAttribute('viewBox', '0 0 60 30'); el.setAttribute('class', 'fx-bat'); el.style.width = size + 'px';
            el.innerHTML = '<g class="flap"><path d="' + FX_BAT + '"/></g>';
            const dur = fast ? fxRand(4500, 8000) : fxRand(9000, 18000);
            const t = (x, y) => ({ transform: 'translate(' + Math.round(x) + 'px,' + Math.round(y) + 'px)' });
            let frames;
            if (kind === 0 || kind === 1) {                          // across, left to right or right to left, at its own height
                const y = fxRand(2, Math.max(4, H - size)), ltr = kind === 0;
                const a = ltr ? -size - 10 : W + 10, b = ltr ? W + 10 : -size - 10;
                frames = [t(a, y), t((a + b) / 2, y + fxRand(-9, 9)), t(b, y + fxRand(-7, 7))];
            } else {                                                  // swoops in from the top somewhere, dips, leaves by a side
                const x0 = fxRand(W * 0.08, W * 0.92), right = Math.random() < 0.5;
                frames = [t(x0, -size - 12), t(x0 + (right ? 70 : -70), H - size - 2), t(right ? W + 20 : -size - 20, fxRand(0, 14))];
            }
            fxRun(el, frames, dur, 'ease-in-out');
        }

        function fxSwinger(fast) {
            const box = byId('fx'); if (!box) return;
            const W = box.clientWidth || 1200, len = fxRand(26, 46);
            const el = document.createElement('div');
            el.className = 'fx-swing'; el.style.left = Math.round(fxRand(W * 0.04, W * 0.96)) + 'px'; el.style.height = Math.round(len) + 'px';
            el.innerHTML = '<i class="th"></i>' + FX_SPIDER;
            const dur = fast ? fxRand(2600, 4200) : fxRand(3600, 5600);
            const r = (deg, op, off) => ({ transform: 'rotate(' + deg + 'deg)', opacity: op, offset: off });
            fxRun(el, [r(-40, 0, 0), r(32, 1, 0.22), r(-26, 1, 0.5), r(16, 1, 0.75), r(0, 0, 1)], dur, 'ease-in-out');
        }

        function fxPacket(fast) {
            const box = byId('fx'); if (!box) return;
            const W = box.clientWidth || 1200, w = fxRand(30, 70), ltr = Math.random() < 0.72;
            const el = document.createElement('i');
            el.className = 'fx-packet'; el.style.width = Math.round(w) + 'px';
            const a = ltr ? -w - 10 : W + 10, b = ltr ? W + 10 : -w - 10;
            fxRun(el, [{ transform: 'translateX(' + Math.round(a) + 'px)' }, { transform: 'translateX(' + Math.round(b) + 'px)' }], fast ? fxRand(1600, 3000) : fxRand(3500, 6500), 'ease-in-out');
        }

        function fxSpawn(fast) {
            const s = fxStyle();
            if (s === 'midnight') fxBat(fast); else if (s === 'web') fxSwinger(fast); else fxPacket(fast);
        }

        function scheduleAmbient() {
            clearTimeout(__ambientTimer);
            if (!MOTION_OK) return;
            const calm = fxStyle() === 'teal' || fxStyle() === 'slate';
            __ambientTimer = setTimeout(() => {
                if (!document.hidden && __fxCount < 2 && __busy === 0) fxSpawn(false);
                scheduleAmbient();
            }, calm ? fxRand(5000, 11000) : fxRand(8000, 20000));
        }

        function restartAmbient() {
            const box = byId('fx'); if (box) box.textContent = '';
            __fxCount = 0;
            scheduleAmbient();
        }

        // Call with true when something starts loading and false when it ends (calls can overlap).
        function setBusy(on) {
            __busy = Math.max(0, __busy + (on ? 1 : -1));
            document.body.classList.toggle('is-busy', __busy > 0);
            if (__busy > 0 && !__busyTimer && MOTION_OK) {
                fxSpawn(true); setTimeout(() => { if (__busy > 0) fxSpawn(true); }, 250);
                __busyTimer = setInterval(() => { if (__busy > 0) fxSpawn(true); }, 800);
            } else if (__busy === 0 && __busyTimer) {
                clearInterval(__busyTimer); __busyTimer = null;
            }
        }

        // ===================== The loader =====================
        // A card in the middle of the screen with the page blurred behind it. It fades in only if the answer takes longer than
        // a quarter of a second and counts the seconds. Around it the style's creatures move: spiders drop on threads and one
        // crawls round the card (Web), bats cross the screen under a sweeping searchlight (Midnight), lights stream across (Teal).
        // Nothing moves for people who ask their computer to reduce motion; they get the card alone.
        function webSvg(cls) {
            const R = 300, rays = 7, rings = [40, 85, 135, 190, 250];
            const pt = (r, a) => [r * Math.cos(a), r * Math.sin(a)];
            const ang = []; for (let i = 0; i < rays; i++) ang.push((i / (rays - 1)) * Math.PI / 2);
            let p = '', k = 0;
            ang.forEach(a => { const e = pt(R, a); p += '<path pathLength="1" style="--i:' + (k++) + '" d="M0 0L' + e[0].toFixed(1) + ' ' + e[1].toFixed(1) + '"/>'; });
            rings.forEach(r => {
                let d = '';
                for (let i = 0; i < rays; i++) {
                    const q = pt(r, ang[i]);
                    if (i === 0) { d = 'M' + q[0].toFixed(1) + ' ' + q[1].toFixed(1); continue; }
                    const m = pt(r * 0.86, (ang[i] + ang[i - 1]) / 2);
                    d += 'Q' + m[0].toFixed(1) + ' ' + m[1].toFixed(1) + ' ' + q[0].toFixed(1) + ' ' + q[1].toFixed(1);
                }
                p += '<path pathLength="1" style="--i:' + (k++) + '" d="' + d + '"/>';
            });
            return '<svg class="ov-web ' + cls + '" viewBox="0 0 ' + R + ' ' + R + '">' + p + '</svg>';
        }
        const spiderSvg = (w) => FX_SPIDER.replace('width="20" height="22"', 'width="' + Math.round(w) + '" height="' + Math.round(w * 26 / 24) + '"');
        const DL_HTML = '<div class="ov-fx"><div class="ov-beam"></div>' + webSvg('l') + webSvg('r') + '</div>'
            + '<div class="dl-card" role="status" aria-live="polite"><span class="dl-art" aria-hidden="true">'
            + '<svg class="dl-doc" viewBox="0 0 48 56"><rect x="1.5" y="1.5" width="45" height="53" rx="6" fill="none" stroke="currentColor" stroke-opacity=".4" stroke-width="2"/>'
            +   '<rect class="ln" x="9" y="12" width="30" height="3" rx="1.5" fill="currentColor"/><rect class="ln" x="9" y="20" width="22" height="3" rx="1.5" fill="currentColor"/>'
            +   '<rect class="ln" x="9" y="28" width="27" height="3" rx="1.5" fill="currentColor"/><rect class="ln" x="9" y="36" width="18" height="3" rx="1.5" fill="currentColor"/>'
            +   '<rect class="ln" x="9" y="44" width="25" height="3" rx="1.5" fill="currentColor"/><rect class="scan" x="5" y="5" width="38" height="9" rx="3" fill="currentColor" opacity=".22"/></svg>'
            + '<svg class="dl-signal" viewBox="0 0 96 60"><defs><radialGradient id="dlSigGlow" cx="50%" cy="50%" r="50%"><stop offset="0" stop-color="#fff6b8"/><stop offset=".62" stop-color="#f5c518"/><stop offset="1" stop-color="#f5c518" stop-opacity="0"/></radialGradient></defs>'
            +   '<ellipse class="disc" cx="48" cy="30" rx="46" ry="28" fill="url(#dlSigGlow)"/>'
            +   '<g transform="translate(4 34)"><g class="cross"><path fill="#0b0b0d" d="' + FX_BAT + '" transform="scale(.28)"/></g></g></svg>'
            + '<span class="dl-spider-wrap">' + FX_SPIDER.replace('width="20" height="22"', 'class="dl-spider"') + '</span>'
            + '<span class="dl-orbit">' + FX_SPIDER + '</span>'
            + '</span><span class="dl-text"><b>Reading log files</b><span class="dl-sub">Just a moment</span></span></div>';

        let __ovCount = 0, __ovSpawn = null, __ovStart = null, __ovClear = null, __ovVisibleAt = 0, __ovHide = null;
        function ovLayer() { const o = byId('loadOverlay'); return o && o.querySelector('.ov-fx'); }
        function ovRun(el, frames, opts) {
            const box = ovLayer(); if (!box) return;
            box.appendChild(el);
            const a = el.animate(frames, opts);
            a.onfinish = a.oncancel = () => el.remove();
        }
        const ovCount = (cls) => { const box = ovLayer(); return box ? box.getElementsByClassName(cls).length : 0; };

        function ovSpiderDrop() {
            if (ovCount('ov-drop') >= 6) return;
            const W = innerWidth, H = innerHeight, size = fxRand(22, 40), len = fxRand(H * 0.12, H * 0.48);
            const el = document.createElement('div');
            el.className = 'ov-drop moving';
            el.style.left = Math.round(fxRand(W * 0.04, W * 0.96) - size / 2) + 'px';
            el.style.width = Math.round(size) + 'px'; el.style.height = Math.round(len + size) + 'px';
            el.innerHTML = '<i class="th"></i>' + spiderSvg(size);
            const y = (v) => ({ transform: 'translateY(' + v + ')' });
            const dur = fxRand(4200, 6800);
            ovRun(el, [
                Object.assign(y('-100%'), { offset: 0, easing: 'cubic-bezier(.23, 1, .32, 1)' }),
                Object.assign(y('8px'), { offset: 0.16, easing: 'ease-in-out' }),
                Object.assign(y('-5px'), { offset: 0.23, easing: 'ease-in-out' }),
                Object.assign(y('2px'), { offset: 0.3, easing: 'ease-in-out' }),
                Object.assign(y('0px'), { offset: 0.36, easing: 'linear' }),
                Object.assign(y('0px'), { offset: 0.72, easing: 'cubic-bezier(.77, 0, .175, 1)' }),
                Object.assign(y('-100%'), { offset: 1 })
            ], { duration: dur, fill: 'both' });
            setTimeout(() => el.classList.remove('moving'), dur * 0.36);       // legs calm down while it hangs
            setTimeout(() => el.classList.add('moving'), dur * 0.72);
        }

        function ovBat() {
            if (ovCount('ov-bat') >= 8) return;
            const W = innerWidth, H = innerHeight, size = fxRand(26, 68), ltr = Math.random() < 0.5;
            const el = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            el.setAttribute('viewBox', '0 0 60 30'); el.setAttribute('class', 'ov-bat'); el.style.width = Math.round(size) + 'px';
            el.innerHTML = '<g><path d="' + FX_BAT + '"/></g>';
            const t = (x, y, s) => ({ transform: 'translate(' + Math.round(x) + 'px,' + Math.round(y) + 'px) scale(' + s + ')' });
            const a = ltr ? -size - 20 : W + 20, b = ltr ? W + 20 : -size - 20;
            let frames;
            if (Math.random() < 0.7) {                                     // across the screen, rising and dipping as it goes
                const y0 = fxRand(H * 0.06, H * 0.85);
                frames = [t(a, y0, 1), t(a + (b - a) * 0.3, y0 + fxRand(-60, 60), 1.05), t(a + (b - a) * 0.65, y0 + fxRand(-60, 60), 0.95), t(b, y0 + fxRand(-80, 80), 1)];
            } else {                                                       // grows as it comes toward you, then peels off
                const x0 = fxRand(W * 0.2, W * 0.8), y0 = fxRand(H * 0.3, H * 0.7);
                frames = [t(x0, y0, 0.3), t(x0 + (ltr ? 80 : -80), y0 - 40, 1.2), t(ltr ? W + 40 : -size * 1.6 - 40, y0 - fxRand(60, 200), 1.6)];
            }
            ovRun(el, frames, { duration: fxRand(2600, 4800), easing: 'ease-in-out', fill: 'both' });
        }

        function ovStream() {
            if (ovCount('ov-stream') >= 16) return;
            const W = innerWidth, H = innerHeight, w = fxRand(60, 180), ltr = Math.random() < 0.75;
            const el = document.createElement('i');
            el.className = 'ov-stream'; el.style.width = Math.round(w) + 'px'; el.style.top = Math.round(fxRand(H * 0.04, H * 0.96)) + 'px';
            el.style.opacity = fxRand(0.35, 0.9).toFixed(2);
            const a = ltr ? -w - 10 : W + 10, b = ltr ? W + 10 : -w - 10;
            ovRun(el, [{ transform: 'translateX(' + Math.round(a) + 'px)' }, { transform: 'translateX(' + Math.round(b) + 'px)' }], { duration: fxRand(900, 1900), easing: 'linear' });
        }

        function ovTick() {
            if (document.hidden) return;
            const s = fxStyle();
            if (s === 'web') ovSpiderDrop(); else if (s === 'midnight') ovBat(); else { ovStream(); ovStream(); }
        }

        function ovMotionStart() {
            if (!MOTION_OK) return;
            const s = fxStyle();
            if (s === 'web') { ovSpiderDrop(); setTimeout(ovSpiderDrop, 300); }
            else if (s === 'midnight') { ovBat(); setTimeout(ovBat, 250); setTimeout(ovBat, 600); }
            else { for (let i = 0; i < 5; i++) setTimeout(ovStream, i * 90); }
            __ovSpawn = setInterval(ovTick, s === 'web' ? 850 : s === 'midnight' ? 520 : 170);
        }
        function ovMotionStop() {
            clearTimeout(__ovStart); clearInterval(__ovSpawn); __ovSpawn = null;
            clearTimeout(__ovClear);
            __ovClear = setTimeout(() => {                                 // after the fade-out, clear the stage
                const o = byId('loadOverlay'); if (!o || o.classList.contains('on')) return;
                o.querySelectorAll('.ov-drop, .ov-bat, .ov-stream').forEach(e => e.remove());
            }, 200);
        }

        function loadOverlay(on) {
            let o = byId('loadOverlay');
            if (!o) { o = document.createElement('div'); o.id = 'loadOverlay'; o.className = 'load-overlay'; o.setAttribute('aria-hidden', 'true'); o.innerHTML = DL_HTML; document.body.appendChild(o); }
            __ovCount = Math.max(0, __ovCount + (on ? 1 : -1));
            if (__ovCount > 0) {
                clearTimeout(__ovHide);
                if (o.classList.contains('on')) return;
                const sub = o.querySelector('.dl-sub'), t0 = Date.now();
                __ovVisibleAt = t0 + 250;
                const tick = () => { const n = Math.floor((Date.now() - t0) / 1000); sub.textContent = n < 3 ? 'Just a moment' : 'Still reading, ' + n + ' s'; };
                tick(); clearInterval(o._t); o._t = setInterval(tick, 1000);
                clearTimeout(__ovClear);
                void o.offsetWidth;                                         // so the fade-in always plays from the start
                o.classList.add('on'); o.setAttribute('aria-hidden', 'false');
                clearTimeout(__ovStart); __ovStart = setTimeout(ovMotionStart, 250);   // creatures start with the fade-in, not before
            } else {
                const now = Date.now(), wait = now < __ovVisibleAt ? 0 : Math.max(0, __ovVisibleAt + 400 - now);
                const hide = () => { if (__ovCount > 0) return; clearInterval(o._t); o.classList.remove('on'); o.setAttribute('aria-hidden', 'true'); ovMotionStop(); };
                clearTimeout(__ovHide);
                if (wait) __ovHide = setTimeout(hide, wait); else hide();
            }
        }

        // ===================== Suggestions =====================
        // Everyone can send one and (unless the super admin turned it off) read them and vote once per computer.
        // Admins also see who sent each one (address, computer name, Windows user, browser), set a status, reply and hide;
        // the super admin can delete. Limits are checked here for the counters and again on the server.
        const SG_CAT = { idea: 'Idea', problem: 'Problem', other: 'Other' };
        const SG_STATUS = { new: 'New', planned: 'Planned', done: 'Done', declined: 'Not planned' };
        let __sg = { items: [], config: null, filter: 'all', sort: 'new', seq: 0 };

        function suggestOn() { return !!(window.__UI && window.__UI.suggestionsEnabled) || __isAdmin; }
        function applySuggestTab() {
            const tab = document.querySelector('.src-tab[data-view="suggest"]');
            if (tab) tab.classList.toggle('hidden', !suggestOn());
            let seen = true; try { seen = localStorage.getItem('lv_sg_seen') === '1'; } catch (e) { }
            byId('sgDot').classList.toggle('hidden', seen || !suggestOn() || __isAdmin);
            if (!suggestOn() && __view === 'suggest') showView('ipas');
        }
        function setSgBadge(n) {
            const b = byId('sgNew'); if (!b) return;
            b.textContent = n > 99 ? '99+' : String(n || 0);
            b.classList.toggle('hidden', !__isAdmin || !n);
            b.title = n ? n + ' new suggestion' + (n === 1 ? '' : 's') : '';
        }

        function shortAgent(ua) {
            if (!ua) return '';
            const b = /Edg\/(\d+)/.exec(ua) ? 'Edge ' + /Edg\/(\d+)/.exec(ua)[1] : /OPR\/(\d+)/.exec(ua) ? 'Opera' : /Firefox\/(\d+)/.exec(ua) ? 'Firefox ' + /Firefox\/(\d+)/.exec(ua)[1]
                : /Chrome\/(\d+)/.exec(ua) ? 'Chrome ' + /Chrome\/(\d+)/.exec(ua)[1] : /Safari\//.test(ua) ? 'Safari' : 'Browser';
            const os = /Windows NT/.test(ua) ? 'Windows' : /Android/.test(ua) ? 'Android' : /iPhone|iPad/.test(ua) ? 'iOS' : /Mac OS X/.test(ua) ? 'macOS' : /Linux/.test(ua) ? 'Linux' : '';
            return b + (os ? ' on ' + os : '');
        }

        function sgCounter(inputId, countId, max) {
            const n = byId(inputId).value.length, el = byId(countId);
            el.textContent = n + ' / ' + max;
            el.classList.toggle('warn', n > max * 0.9 && n <= max);
            el.classList.toggle('over', n > max);
        }
        function applySgConfig(c) {
            if (!c) return;
            byId('sgTitle').maxLength = c.titleMax; byId('sgText').maxLength = c.maxChars; byId('sgName').maxLength = c.nameMax;
            sgCounter('sgTitle', 'sgTitleCount', c.titleMax); sgCounter('sgText', 'sgTextCount', c.maxChars);
            if (c.passwordMin) byId('accPwHint').textContent = 'At least ' + c.passwordMin + ' characters, not your username';
            byId('sgWho').textContent = c.visibleToUsers ? 'Everyone can read suggestions and replies.' : 'Only you and the admins can read your suggestions.';
            byId('sgOff').classList.toggle('hidden', c.enabled);
            byId('sgSend').disabled = !c.enabled;
        }

        async function loadSuggestions() {
            const my = ++__sg.seq, list = byId('sgList');
            if (!__sg.items.length) list.innerHTML = '<div class="empty-body">Loading suggestions…</div>';
            try {
                const d = await pageMethod('GetSuggestions');
                if (my !== __sg.seq) return;
                if (!d || !d.ok) { list.innerHTML = '<div class="notice notice-error"></div>'; list.firstChild.textContent = (d && d.error) || 'Could not load the suggestions.'; return; }
                __sg.items = d.items || []; __sg.config = d.config; __me = d.user || null;
                applySgConfig(d.config); renderAccount();
                setSgBadge(d.newCount);
                renderSuggestions();
            } catch (e) {
                if (my === __sg.seq) list.innerHTML = '<div class="notice notice-error">Could not reach the server.</div>';
            }
        }
        async function refreshSgBadge() {
            if (!__isAdmin) { setSgBadge(0); return; }
            try { const d = await pageMethod('GetSuggestions'); if (d && d.ok) setSgBadge(d.newCount); } catch (e) { }
        }

        function sgCard(s) {
            const admin = __isAdmin, esc = escapeHtml;
            const head = '<div class="sg-head"><span class="sg-chip sg-cat-' + esc(s.category) + '">' + esc(SG_CAT[s.category] || 'Other') + '</span>'
                + '<span class="sg-chip sg-st-' + esc(s.status) + '">' + esc(SG_STATUS[s.status] || s.status) + '</span>'
                + (s.hidden ? '<span class="sg-chip sg-st-hidden">Hidden</span>' : '') + (s.mine ? '<span class="sg-chip sg-mine">Yours</span>' : '') + '</div>';
            const meta = '<div class="sg-meta"><span>' + esc(fmtServerStr(s.created)) + '</span>' + (s.name ? '<span>from ' + esc(s.name) + '</span>' : '')
                + '<button type="button" class="sg-vote" data-act="vote" aria-pressed="' + (s.voted ? 'true' : 'false') + '" title="' + (s.voted ? 'You want this too. Click to take your vote back' : 'I want this too') + '"' + (s.hidden ? ' disabled' : '') + '>'
                + '<i class="fa-solid fa-thumbs-up" aria-hidden="true"></i><b class="tabular">' + s.votes + '</b><span class="sr-only"> votes</span></button></div>';
            const reply = s.reply ? '<div class="sg-reply"><div class="sg-reply-h">Reply' + (s.replyBy ? ' from ' + esc(s.replyBy) : '') + (s.replyAt ? ', ' + esc(fmtServerStr(s.replyAt)) : '') + '</div><p>' + esc(s.reply) + '</p></div>' : '';
            let adminBlock = '';
            if (admin) {
                const who = '<div class="sg-who"><i class="fa-solid fa-user-shield" aria-hidden="true"></i> Sent from <b class="mono">' + esc(s.ip || 'unknown address') + '</b>'
                    + (s.host ? ', computer <b class="mono">' + esc(s.host) + '</b>' : ', computer name not found in DNS')
                    + (s.winUser ? ', Windows user <b class="mono">' + esc(s.winUser) + '</b>' : '')
                    + (s.agent ? '<div class="sg-agent" title="' + esc(s.agent) + '">' + esc(shortAgent(s.agent)) + '</div>' : '') + '</div>';
                const opts = Object.keys(SG_STATUS).map(k => '<option value="' + k + '"' + (k === s.status ? ' selected' : '') + '>' + SG_STATUS[k] + '</option>').join('');
                adminBlock = '<div class="sg-admin">' + who
                    + '<div class="sg-admin-row"><select class="lv-input sg-st-sel" aria-label="Status">' + opts + '</select>'
                    + '<textarea class="lv-input sg-reply-in" rows="2" maxlength="' + ((__sg.config && __sg.config.replyMax) || 1000) + '" aria-label="Reply" placeholder="Reply (shown under the suggestion)">' + esc(s.reply) + '</textarea></div>'
                    + '<div class="sg-admin-actions"><button type="button" class="lv-copy-btn" data-act="save">Save</button>'
                    + '<button type="button" class="lv-copy-btn" data-act="hide">' + (s.hidden ? 'Show again' : 'Hide from users') + '</button>'
                    + (__role === 'superadmin' ? '<button type="button" class="lv-copy-btn sg-del" data-act="del">Delete</button>' : '')
                    + '<span class="sg-admin-msg" role="status"></span></div></div>';
            }
            return '<article class="sg-card' + (s.hidden ? ' is-hidden' : '') + '" data-id="' + esc(s.id) + '">' + head
                + '<h3 class="sg-ttl">' + esc(s.title) + '</h3><p class="sg-text">' + esc(s.text) + '</p>' + meta + reply + adminBlock + '</article>';
        }

        function renderSuggestions() {
            const f = __sg.filter;
            let list = __sg.items.filter(s => f === 'all' ? !s.hidden || __isAdmin
                : f === 'mine' ? s.mine : f === 'hidden' ? s.hidden : (s.status === f && !s.hidden));
            list = list.slice().sort((a, b) => __sg.sort === 'votes' ? (b.votes - a.votes) || (a.created < b.created ? 1 : -1) : (a.created < b.created ? 1 : -1));
            document.querySelectorAll('[data-sgf]').forEach(b => {
                const on = b.dataset.sgf === f; b.classList.toggle('active', on); b.setAttribute('aria-pressed', on ? 'true' : 'false');
            });
            byId('sgHiddenBtn').classList.toggle('hidden', !__isAdmin);
            byId('sgCountText').textContent = list.length + (list.length === 1 ? ' suggestion' : ' suggestions');
            byId('sgList').innerHTML = list.length ? '<div class="sg-cards">' + list.map(sgCard).join('') + '</div>'
                : '<div class="empty-body sg-empty">' + (__sg.items.length ? 'Nothing matches this filter.' : 'No suggestions yet. Be the first to send one.') + '</div>';
        }

        function wireSuggestions() {
            const form = byId('sgForm'); if (!form) return;
            try { const n = localStorage.getItem('lv_sgname'); if (n) byId('sgName').value = n; } catch (e) { }
            byId('sgTitle').addEventListener('input', () => sgCounter('sgTitle', 'sgTitleCount', byId('sgTitle').maxLength > 0 ? byId('sgTitle').maxLength : 120));
            byId('sgText').addEventListener('input', () => sgCounter('sgText', 'sgTextCount', byId('sgText').maxLength > 0 ? byId('sgText').maxLength : 1000));
            form.addEventListener('submit', async (e) => {
                e.preventDefault();
                const msg = byId('sgMsg'), btn = byId('sgSend');
                const title = byId('sgTitle').value.trim(), text = byId('sgText').value.trim(), name = byId('sgName').value.trim();
                msg.className = 'sg-msg err';
                if (title.length < 3) { msg.textContent = 'Give the suggestion a short title.'; byId('sgTitle').focus(); return; }
                if (text.length < 10) { msg.textContent = 'Please describe it in a few more words.'; byId('sgText').focus(); return; }
                btn.disabled = true; msg.className = 'sg-msg'; msg.textContent = 'Sending…';
                try {
                    const r = await pageMethod('AddSuggestion', { category: byId('sgCat').value, title: title, text: text, name: __me ? '' : name, device: deviceId() });
                    if (r && r.ok) {
                        try { if (name) localStorage.setItem('lv_sgname', name); else localStorage.removeItem('lv_sgname'); } catch (e2) { }
                        byId('sgTitle').value = ''; byId('sgText').value = '';
                        msg.className = 'sg-msg ok'; msg.textContent = 'Thank you. Your suggestion was sent.';
                        __sg.filter = 'all';
                        await loadSuggestions();
                    } else { msg.className = 'sg-msg err'; msg.textContent = (r && r.error) || 'Could not send it.'; }
                } catch (ex) { msg.className = 'sg-msg err'; msg.textContent = 'Could not reach the server.'; }
                finally { btn.disabled = !(__sg.config ? __sg.config.enabled : true); sgCounter('sgTitle', 'sgTitleCount', byId('sgTitle').maxLength); sgCounter('sgText', 'sgTextCount', byId('sgText').maxLength); }
            });
            document.querySelectorAll('[data-sgf]').forEach(b => b.addEventListener('click', () => { __sg.filter = b.dataset.sgf; renderSuggestions(); }));
            byId('sgSort').addEventListener('change', () => { __sg.sort = byId('sgSort').value; renderSuggestions(); });

            // one listener for every card: vote, and for admins save / hide / delete
            byId('sgList').addEventListener('click', async (e) => {
                const b = e.target.closest('[data-act]'); if (!b || b.disabled) return;
                const card = b.closest('.sg-card'), id = card && card.dataset.id;
                const s = __sg.items.find(x => x.id === id); if (!s) return;
                const say = (t) => { const m = card.querySelector('.sg-admin-msg'); if (m) m.textContent = t; };
                const act = b.dataset.act;
                try {
                    if (act === 'vote') {
                        b.disabled = true;
                        const r = await pageMethod('VoteSuggestion', { id: id });
                        if (r && r.ok) { s.voted = r.voted; s.votes = r.votes; renderSuggestions(); }
                        else { b.disabled = false; if (r && r.needSignIn) { accSay('Sign in to vote.', false); byId('sgAccount').scrollIntoView({ block: 'nearest' }); } }
                    } else if (act === 'save' || act === 'hide') {
                        const hidden = act === 'hide' ? !s.hidden : s.hidden;
                        say('Saving…');
                        const r = await pageMethod('AdminUpdateSuggestion', { id: id, status: card.querySelector('.sg-st-sel').value, reply: card.querySelector('.sg-reply-in').value, hidden: hidden });
                        if (r && r.ok) await loadSuggestions(); else say((r && r.error) || 'Could not save.');
                    } else if (act === 'del') {
                        if (!b.classList.contains('confirm')) {          // a second click within 4 s deletes: no browser dialogs here
                            b.classList.add('confirm'); b.textContent = 'Click again to delete';
                            setTimeout(() => { if (b.isConnected) { b.classList.remove('confirm'); b.textContent = 'Delete'; } }, 4000);
                            return;
                        }
                        say('Deleting…');
                        const r = await pageMethod('AdminDeleteSuggestion', { id: id });
                        if (r && r.ok) await loadSuggestions(); else say((r && r.error) || 'Could not delete.');
                    }
                } catch (ex) { say('Could not reach the server.'); }
            });
        }

        async function loadSgSettings() {
            try {
                const d = await pageMethod('GetSuggestions');
                if (!d || !d.ok) return;
                byId('sgEnabled').checked = d.config.enabled; byId('sgVisible').checked = d.config.visibleToUsers;
                byId('sgMax').value = d.config.maxChars; byId('sgPerHour').value = d.config.perHour; byId('sgPwMin').value = d.config.passwordMin;
                byId('sgNeedSignIn').checked = d.config.needSignIn; byId('sgSignUpOpen').checked = d.config.signUpOpen;
            } catch (e) { }
        }

        // ===================== User accounts (Suggestions) =====================
        // Sending and voting need an account when the super admin says so (the default). Anyone can create one.
        // The browser keeps a random device id; it goes with sign-up, sign-in and every suggestion, so admins can
        // see when one browser is behind several accounts. It holds nothing about the person.
        let __me = null;
        function deviceId() {
            try {
                let d = localStorage.getItem('lv_dev');
                if (!d || !/^[a-f0-9]{32}$/.test(d)) {
                    const b = new Uint8Array(16); (window.crypto || window.msCrypto).getRandomValues(b);
                    d = Array.from(b, x => x.toString(16).padStart(2, '0')).join('');
                    localStorage.setItem('lv_dev', d);
                }
                return d;
            } catch (e) { return ''; }
        }

        function accSay(text, ok) { const m = byId('accMsg'); m.className = 'sg-msg ' + (ok ? 'ok' : 'err'); m.textContent = text || ''; }
        function myAccSay(text, ok) { const m = byId('myAccMsg'); m.className = 'sg-msg ' + (ok ? 'ok' : 'err'); m.textContent = text || ''; }
        function showAccPane(name) {
            document.querySelectorAll('[data-acc]').forEach(b => { const on = b.dataset.acc === name; b.classList.toggle('active', on); b.setAttribute('aria-selected', on ? 'true' : 'false'); });
            document.querySelectorAll('[data-accp]').forEach(p => p.classList.toggle('hidden', p.dataset.accp !== name));
            accSay('');
        }

        // what the left column shows: the account box, and the form only when this person may send
        function renderAccount() {
            const c = __sg.config || {}, need = !!c.needSignIn, canSend = !need || !!__me || __isAdmin;
            const gated = need && !__me && !__isAdmin;          // first sign in or create an account; then the form and the list
            byId('viewSuggest').classList.toggle('sg-gated', gated);
            byId('sgAccount').classList.toggle('hidden', !need && !__me);
            byId('sgSignedOut').classList.toggle('hidden', !!__me);
            byId('sgSignedIn').classList.toggle('hidden', !__me);
            byId('accUpTab').classList.toggle('hidden', c.signUpOpen === false);
            if (__me) { byId('sgMeName').textContent = __me.name; byId('sgMeUser').textContent = __me.username; }
            byId('sgForm').classList.toggle('hidden', !canSend);
            byId('sgNameRow').classList.toggle('hidden', !!__me);       // the account name is used instead
            byId('sgSignedOutNote').textContent = __isAdmin && !__me
                ? 'You are signed in as admin, so you can send without a user account.'
                : 'Sign in to send ideas, vote, and read what others suggested. New here? Create an account, it takes a minute.';
            byId('sgGateTitle').textContent = gated ? 'Help us improve the Log Explorer' : 'Your account';
        }

        function wireAccounts() {
            if (!byId('sgAccount')) return;
            document.querySelectorAll('[data-acc]').forEach(b => b.addEventListener('click', () => showAccPane(b.dataset.acc)));
            const v = (id) => byId(id).value;
            const after = async (r, okText) => {
                if (r && r.ok) {
                    if (r.user) __me = r.user;
                    ['accInPass', 'accUpPass', 'accUpPass2', 'accResetCode', 'accResetPass'].forEach(id => { byId(id).value = ''; });
                    accSay(okText, true);
                    await loadSuggestions();
                } else accSay((r && r.error) || 'Something went wrong.', false);
            };
            byId('accInForm').addEventListener('submit', async (e) => {
                e.preventDefault();
                accSay('Signing in…', true);
                try { await after(await pageMethod('UserSignIn', { username: v('accInUser'), password: v('accInPass'), device: deviceId() }), ''); }
                catch (ex) { accSay('Could not reach the server.', false); }
            });
            byId('accUpForm').addEventListener('submit', async (e) => {
                e.preventDefault();
                if (v('accUpPass') !== v('accUpPass2')) { accSay('The two passwords are not the same.', false); return; }
                accSay('Creating your account…', true);
                try { await after(await pageMethod('UserSignUp', { username: v('accUpUser'), name: v('accUpName'), password: v('accUpPass'), device: deviceId() }), 'Welcome. Your account is ready.'); }
                catch (ex) { accSay('Could not reach the server.', false); }
            });
            byId('accResetForm').addEventListener('submit', async (e) => {
                e.preventDefault();
                accSay('Checking the code…', true);
                try {
                    const r = await pageMethod('UserResetWithCode', { username: v('accResetUser'), code: v('accResetCode'), newPassword: v('accResetPass') });
                    if (r && r.ok) { byId('accInUser').value = v('accResetUser'); showAccPane('in'); accSay('Your new password is set. Sign in with it now.', true); }
                    else accSay((r && r.error) || 'Could not reset the password.', false);
                } catch (ex) { accSay('Could not reach the server.', false); }
            });
            byId('accOut').addEventListener('click', async () => {
                try { await pageMethod('UserSignOut'); } catch (ex) { }
                __me = null; await loadSuggestions();
            });
            byId('myPassForm').addEventListener('submit', async (e) => {
                e.preventDefault();
                try {
                    const r = await pageMethod('UserChangePassword', { oldPassword: v('myOldPass'), newPassword: v('myNewPass') });
                    if (r && r.ok) { byId('myOldPass').value = ''; byId('myNewPass').value = ''; myAccSay('Your password is changed.', true); }
                    else myAccSay((r && r.error) || 'Could not change the password.', false);
                } catch (ex) { myAccSay('Could not reach the server.', false); }
            });
            byId('myDelForm').addEventListener('submit', async (e) => {
                e.preventDefault();
                const b = byId('myDelBtn');
                if (!b.classList.contains('confirm')) {          // a second click within 5 s deletes
                    b.classList.add('confirm'); b.textContent = 'Click again to delete for good';
                    setTimeout(() => { b.classList.remove('confirm'); b.textContent = 'Delete my account'; }, 5000);
                    return;
                }
                try {
                    const r = await pageMethod('UserDeleteSelf', { password: v('myDelPass') });
                    if (r && r.ok) { __me = null; byId('myDelPass').value = ''; await loadSuggestions(); accSay('Your account is deleted. Your suggestions stay, with your name on them.', true); }
                    else myAccSay((r && r.error) || 'Could not delete the account.', false);
                } catch (ex) { myAccSay('Could not reach the server.', false); }
            });
        }

        // ---- Settings > Users (super admin) ----
        async function loadUsersAdmin(note) {
            const host = byId('usersBody'); if (!host) return;
            try {
                const d = await pageMethod('AdminListUsers');
                if (!d || !d.ok) { host.textContent = (d && d.error) || 'Could not load the accounts.'; return; }
                const users = d.users || [];
                // the same browser (device id) behind more than one account is worth a look
                const byDev = {};
                users.forEach(u => [u.createdDevice, u.lastDevice].filter(Boolean).forEach(dv => { (byDev[dv] = byDev[dv] || new Set()).add(u.username); }));
                const esc = escapeHtml;
                const place = (t, ip, h) => t ? esc(fmtServerStr(t)) + '<div class="sg-agent">' + esc(ip || '') + (h ? ' · ' + esc(h) : '') + '</div>' : '—';
                byId('usersCount').textContent = users.length + (users.length === 1 ? ' account' : ' accounts');
                host.innerHTML = !users.length ? '<div class="empty-body">No accounts yet.</div>'
                    : '<table class="jobs-table users-table"><thead><tr><th>Account</th><th>Created</th><th>Last sign-in</th><th>Browser id</th><th>State</th><th></th></tr></thead><tbody>'
                    + users.map(u => {
                        const others = new Set();
                        [u.createdDevice, u.lastDevice].filter(Boolean).forEach(dv => byDev[dv].forEach(n => { if (n !== u.username) others.add(n); }));
                        return '<tr data-uid="' + esc(u.id) + '"><td><b>' + esc(u.username) + '</b><div class="sg-agent">' + esc(u.name) + '</div></td>'
                            + '<td>' + place(u.created, u.createdIp, u.createdHost) + '</td><td>' + place(u.lastSignIn, u.lastIp, u.lastHost) + '</td>'
                            + '<td><span class="mono">' + esc((u.lastDevice || u.createdDevice || '').slice(0, 8)) + '</span>'
                            + (others.size ? '<div class="sg-warn"><i class="fa-solid fa-triangle-exclamation" aria-hidden="true"></i> same browser as ' + esc(Array.from(others).join(', ')) + '</div>' : '') + '</td>'
                            + '<td>' + (u.disabled ? '<span class="status st-warn">Switched off</span>' : '<span class="status st-ok">Active</span>') + (u.resetPending ? '<div class="sg-agent">reset code waiting</div>' : '') + '</td>'
                            + '<td class="users-acts"><button type="button" class="lv-copy-btn" data-uact="' + (u.disabled ? 'enable' : 'disable') + '">' + (u.disabled ? 'Switch on' : 'Switch off') + '</button>'
                            + '<button type="button" class="lv-copy-btn" data-uact="reset">Reset code</button>'
                            + '<button type="button" class="lv-copy-btn sg-del" data-uact="delete">Delete</button></td></tr>';
                    }).join('') + '</tbody></table>';
                byId('usersMsg').textContent = note || '';
            } catch (e) { host.textContent = 'Could not reach the server.'; }
        }
        function wireUsersAdmin() {
            const host = byId('usersBody'); if (!host) return;
            host.addEventListener('click', async (e) => {
                const b = e.target.closest('[data-uact]'); if (!b) return;
                const row = b.closest('tr'), id = row.dataset.uid, act = b.dataset.uact, name = row.querySelector('b').textContent;
                if (act === 'delete' && !b.classList.contains('confirm')) {
                    b.classList.add('confirm'); b.textContent = 'Click again';
                    setTimeout(() => { if (b.isConnected) { b.classList.remove('confirm'); b.textContent = 'Delete'; } }, 4000);
                    return;
                }
                try {
                    const r = await pageMethod('AdminUserAction', { id: id, action: act });
                    if (!r || !r.ok) { byId('usersMsg').textContent = (r && r.error) || 'Could not do that.'; return; }
                    await loadUsersAdmin(act === 'reset' ? 'Reset code for ' + name + ': ' + r.code + '. Give it to them in person or by phone. It works once, for 24 hours, and is not shown again.'
                        : act === 'delete' ? 'Deleted ' + name + '. Their suggestions stay.' : (act === 'disable' ? 'Switched off ' + name + '.' : 'Switched on ' + name + '.'));
                } catch (ex) { byId('usersMsg').textContent = 'Could not reach the server.'; }
            });
        }

        // ===================== Hover times on small bars (jobs table, Health view) =====================
        // A bar carries data-tip="headline|detail". One floating tip follows the pointer; text is set with textContent.
        let __floatTip = null;
        function floatTip() {
            if (!__floatTip) {
                __floatTip = document.createElement('div');
                __floatTip.className = 'float-tip hidden';
                __floatTip.setAttribute('role', 'tooltip');
                document.body.appendChild(__floatTip);
            }
            return __floatTip;
        }
        function bindFloatTip(container) {
            if (!container || container.dataset.tipBound) return;
            container.dataset.tipBound = '1';
            const hide = () => floatTip().classList.add('hidden');
            container.addEventListener('pointermove', (e) => {
                const t = e.target.closest ? e.target.closest('[data-tip]') : null;
                if (!t) { hide(); return; }
                const tip = floatTip(), parts = String(t.dataset.tip).split('|');
                tip.textContent = '';
                const head = document.createElement('div'); head.className = 'tip-head'; head.textContent = parts[0]; tip.appendChild(head);
                if (parts[1]) { const d = document.createElement('div'); d.className = 'tip-detail'; d.textContent = parts[1]; tip.appendChild(d); }
                tip.classList.remove('hidden');
                let x = e.clientX + 14, y = e.clientY + 16;
                if (x + tip.offsetWidth > window.innerWidth - 8) x = e.clientX - tip.offsetWidth - 14;
                if (y + tip.offsetHeight > window.innerHeight - 8) y = e.clientY - tip.offsetHeight - 12;
                tip.style.left = Math.max(4, x) + 'px'; tip.style.top = Math.max(4, y) + 'px';
            });
            container.addEventListener('pointerleave', hide);
        }

        // ===================== Health (admin) =====================
        // Like a status page: every module, background job and server, one bar per hour (or day), green when it logged
        // no errors, amber for some, red for many. "Quiet" means nothing was logged; it does not prove something is running.
        let __healthRange = '24h', __healthData = null, __healthBounds = null, __healthSeq = 0;

        function healthBounds() {
            const now = Date.now(), DAY = 86400000;
            return { from: __healthRange === '7d' ? startOfTodayEpoch() - 6 * DAY : now - DAY, to: now };
        }

        async function loadHealth(quiet) {
            const body = byId('healthBody');
            body.classList.add('is-loading'); setBusy(true); if (!quiet) loadOverlay(true);
            const b = healthBounds(), my = ++__healthSeq;
            try {
                const d = await pageMethod('GetServiceHealth', { from: epochToServerStr(b.from), to: epochToServerStr(b.to) });
                if (my !== __healthSeq) return;           // a newer request has started; this answer is out of date
                if (!d || d.error) {
                    if (d && /sign in/i.test(d.error || '')) { setAdminUI(false); showMessage('Your admin session ended. Sign in again.', 'info'); return; }
                    byId('healthNotice').innerHTML = '';
                    const n = document.createElement('div'); n.className = 'notice notice-error'; n.textContent = (d && d.error) || 'The health view could not be loaded.';
                    byId('healthNotice').appendChild(n);
                    return;
                }
                __healthData = d; __healthBounds = b;     // its own range: the dashboard keeps __dashBounds
                renderHealth(d);
                byId('healthUpdated').textContent = 'Updated ' + epochToWallStr(__tz, Date.now()).slice(11) + ', times in ' + zoneLabel(__tz);
            } catch (e) {
                byId('healthNotice').innerHTML = '';
                const n = document.createElement('div'); n.className = 'notice notice-error'; n.textContent = 'The health view could not be loaded: ' + e.message;
                byId('healthNotice').appendChild(n);
            } finally {
                body.classList.remove('is-loading'); setBusy(false); if (!quiet) loadOverlay(false);
            }
        }

        function healthStatus(c, d) {
            const crit = d.thresholds.critical * (d.hourly ? 1 : 12);
            const lastEp = serverStrToEpoch(c.last), mins = lastEp === null ? 99999 : (Date.now() - lastEp) / 60000;
            const recent = c.per[c.per.length - 1] || 0;
            if (mins < 60 && recent >= crit) return { rank: 0, cls: 'st-crit', icon: 'fa-circle-xmark', label: 'Failing now', mins: mins };
            if (mins < 60) return { rank: 1, cls: 'st-warn', icon: 'fa-triangle-exclamation', label: 'Errors in the last hour', mins: mins };
            return { rank: 2, cls: 'st-ok', icon: 'fa-circle-check', label: 'Quiet', mins: mins };
        }

        // Filters on the Health page: by status (all / failing now / errors in the last hour / quiet) and by module.
        // They only change what is shown; the counts in the banner and on the buttons always cover everything.
        let __healthStatus = 'all', __healthModule = '';
        function setHealthStatus(s) {
            __healthStatus = s;
            document.querySelectorAll('[data-hstatus]').forEach(x => x.classList.toggle('active', x.dataset.hstatus === s));
            if (__healthData) renderHealth(__healthData);
        }

        function healthRow(c, d, pick) {
            const crit = d.thresholds.critical * (d.hourly ? 1 : 12);
            const st = healthStatus(c, d);
            const row = document.createElement('div'); row.className = 'hrow';

            const name = document.createElement('button');
            name.className = 'hname linkbtn'; name.type = 'button';
            const shown = c.label || c.name;
            name.textContent = shown; name.title = (shown !== c.name ? shown + ' (' + c.name + ')' : c.name) + '. Open its errors in this range';
            name.addEventListener('click', () => drillDown(pick(c)));

            const status = document.createElement('span'); status.className = 'status ' + st.cls;
            status.innerHTML = '<i class="fa-solid ' + st.icon + '"></i> ' + st.label;

            // one bar per hour (or day); a bar with errors opens exactly those errors
            const strip = document.createElement('div'); strip.className = 'hstrip'; strip.setAttribute('role', 'img');
            strip.setAttribute('aria-label', 'Errors per ' + (d.hourly ? 'hour' : 'day') + ' for ' + c.name + ', ' + c.count + ' in total');
            let quiet = 0;
            c.per.forEach((n, i) => {
                const bar = document.createElement('i');
                bar.className = 'hb ' + (n === 0 ? 'good' : (n >= crit ? 'crit go' : 'warn go'));
                bar.dataset.i = i;
                if (n === 0) quiet++;
                const label = bucketLabel(d.buckets[i], d.hourly, true) + (d.hourly ? ' hour' : '') + (i === c.per.length - 1 ? ' (so far)' : '');
                bar.dataset.tip = label + '|' + (n === 0 ? 'No errors' : n + (n === 1 ? ' error. Click to open it' : ' errors. Click to open them'));
                strip.appendChild(bar);
            });
            strip.addEventListener('click', (e) => {
                const b = e.target.closest('.hb.go'); if (!b) return;
                const i = +b.dataset.i, from = serverStrToEpoch(d.buckets[i]);
                const next = i + 1 < d.buckets.length ? serverStrToEpoch(d.buckets[i + 1]) : null;
                if (from === null) return;
                floatTip().classList.add('hidden');
                // the first bar starts at the range start (not the full hour) and the last ends when the page was read
                const hb = __healthBounds || { from: from, to: Date.now() };
                drillDown(Object.assign(pick(c), { from: Math.max(from, hb.from), to: next === null ? hb.to : Math.min(next - 1000, hb.to) }));
            });

            const stats = document.createElement('span'); stats.className = 'hstats tabular';
            const lastEp = serverStrToEpoch(c.last);
            stats.textContent = Math.round(quiet / c.per.length * 100) + '% quiet ' + (d.hourly ? 'hours' : 'days') + ', last error ' + timeAgo(lastEp === null ? null : new Date(lastEp));
            const total = document.createElement('span'); total.className = 'htotal tabular'; total.textContent = fmtNum(c.count);
            total.title = c.count + ' errors in this range';

            const cell = document.createElement('div'); cell.className = 'hname-cell'; cell.appendChild(name);
            if (shown !== c.name) { const raw = document.createElement('span'); raw.className = 'hraw mono'; raw.textContent = c.name; raw.title = c.name; cell.appendChild(raw); }   // the actual value, small, so two parts with one name stay apart
            row.appendChild(cell); row.appendChild(status); row.appendChild(strip); row.appendChild(stats); row.appendChild(total);
            row._rank = st.rank; row._name = c.name;
            return row;
        }

        function fillHealthList(id, list, d, kind, emptyText) {
            const host = byId(id);
            host.textContent = '';
            const n = { crit: 0, warn: 0, ok: 0, shown: 0 };
            if (!list || !list.length) { host.innerHTML = '<div class="empty-body">' + escapeHtml(emptyText) + '</div>'; return n; }
            const pick = (c) => { const p = __healthBounds ? { from: __healthBounds.from, to: __healthBounds.to } : {}; p[kind] = c.name; return p; };
            const labels = kind === 'module' ? (d.moduleLabels || {}) : kind === 'job' ? (d.jobLabels || {}) : {};
            list = list.map(c => Object.assign({}, c, { label: labels[c.name] || c.name }));
            const rows = list.map(c => healthRow(c, d, pick));
            rows.forEach(r => { if (r._rank === 0) n.crit++; else if (r._rank === 1) n.warn++; else n.ok++; });
            const want = { crit: 0, warn: 1, ok: 2 }[__healthStatus];
            const order = rows.map((r, i) => i).sort((a, b) => rows[a]._rank - rows[b]._rank || a - b);   // failing first, then by newest error
            order.forEach(i => {
                const r = rows[i];
                if (want !== undefined && r._rank !== want) return;
                if (kind === 'module' && __healthModule && r._name !== __healthModule) return;
                host.appendChild(r); n.shown++;
            });
            if (!n.shown) host.innerHTML = '<div class="empty-body">Nothing in this list matches the filter.</div>';
            return n;
        }

        function renderHealth(d) {
            byId('healthNotice').innerHTML = '';
            const note = (text) => { const n = document.createElement('div'); n.className = 'notice notice-info'; n.textContent = text; byId('healthNotice').appendChild(n); };
            if (d.partial) note('Still reading the older files (' + d.filesExamined + ' of ' + d.filesInRange + ' so far). The bars cover the files already read; press Refresh now in a minute to include more.');
            else if (d.truncated) note('This range holds ' + d.filesInRange + ' files and the newest ' + d.filesExamined + ' were read (limit ' + d.maxFiles + '). Choose a shorter range for the complete picture.');
            (d.warnings || []).forEach(note);

            // module choices: every module in this range, the current choice kept
            learnLabels(d.moduleLabels);
            const names = (d.modules || []).map(c => c.name).sort((a, b) => modLabel(a).localeCompare(modLabel(b)) || a.localeCompare(b));
            if (__healthModule && names.indexOf(__healthModule) < 0) __healthModule = '';
            fillFacet('healthModule', names, 'All modules', modOption);
            byId('healthModule').value = __healthModule; refreshSearchable('healthModule');

            const m = fillHealthList('healthModules', d.modules, d, 'module', 'No module logged an error in this range.');
            const j = fillHealthList('healthJobs', d.jobs, d, 'job', 'No background or sync job logged an error in this range.');
            const s = fillHealthList('healthServers', d.servers, d, 'server', 'No server logged an error in this range.');

            const crit = m.crit + j.crit + s.crit, warn = m.warn + j.warn + s.warn, ok = m.ok + j.ok + s.ok;
            byId('hfAll').textContent = crit + warn + ok; byId('hfCrit').textContent = crit; byId('hfWarn').textContent = warn; byId('hfOk').textContent = ok;
            byId('healthClear').classList.toggle('hidden', __healthStatus === 'all' && !__healthModule);

            // the banner says where the failing parts are, so the count always matches the lists below
            const plural = (n, one, many) => n + ' ' + (n === 1 ? one : many);
            const parts = (a, b, c) => {
                const p = [];
                if (a) p.push(plural(a, 'module', 'modules'));
                if (b) p.push(plural(b, 'background job', 'background jobs'));
                if (c) p.push(plural(c, 'server', 'servers'));
                return p.length > 1 ? p.slice(0, -1).join(', ') + ' and ' + p[p.length - 1] : p[0];
            };
            const banner = byId('healthBanner');
            const cls = crit > 0 ? 'st-crit' : (warn > 0 ? 'st-warn' : 'st-ok');
            const icon = crit > 0 ? 'fa-circle-xmark' : (warn > 0 ? 'fa-triangle-exclamation' : 'fa-circle-check');
            const text = crit > 0 ? 'Failing now: ' + parts(m.crit, j.crit, s.crit) + (warn > 0 ? '. Errors in the last hour: ' + parts(m.warn, j.warn, s.warn) : '')
                : warn > 0 ? 'Errors in the last hour: ' + parts(m.warn, j.warn, s.warn)
                : 'Quiet. Nothing logged an error in the last hour';
            banner.className = 'health-banner ' + cls;
            banner.innerHTML = '<i class="fa-solid ' + icon + '"></i> <span></span>';
            banner.querySelector('span').textContent = text;
            const target = crit > 0 ? 'crit' : (warn > 0 ? 'warn' : '');
            if (target) {
                const b = document.createElement('button'); b.type = 'button'; b.className = 'linkbtn banner-act';
                const showing = __healthStatus === target;
                b.textContent = showing ? 'Show everything' : (target === 'crit' ? 'Show only the failing ones' : 'Show only these');
                b.addEventListener('click', () => setHealthStatus(showing ? 'all' : target));
                banner.appendChild(b);
            }
            bindFloatTip(byId('viewHealth'));
        }

        // ===================== Dashboard =====================
        let __dashRange = 'today', __dashTimer = null, __dashData = null, __dashBounds = null, __dashModule = '', __dashSeq = 0;

        function dashBounds() {
            const now = Date.now(), DAY = 86400000;
            const from = __dashRange === '24h' ? now - DAY : (__dashRange === '7d' ? now - 7 * DAY : (__dashRange === '30d' ? now - 30 * DAY : startOfTodayEpoch()));
            return { from: from, to: now };
        }
        function startDashTimer() {
            stopDashTimer();
            const on = (__view === 'health' ? byId('healthAuto') : byId('dashAuto')).checked;
            if (on) __dashTimer = setInterval(() => { if (__view === 'health') loadHealth(true); else if (__view === 'dashboard') loadDashboard(true); }, 60000);
        }
        function stopDashTimer() { if (__dashTimer) { clearInterval(__dashTimer); __dashTimer = null; } }

        async function loadDashboard(quiet) {
            const body = byId('dashBody');
            body.classList.add('is-loading'); setBusy(true); if (!quiet) loadOverlay(true);   // keep the frame while refreshing; the loader card blurs the page unless it is the timed refresh
            const b = dashBounds(), my = ++__dashSeq;
            try {
                const d = await pageMethod('GetDashboard', { from: epochToServerStr(b.from), to: epochToServerStr(b.to), module: __dashModule });
                if (my !== __dashSeq) return;             // a newer request has started; this answer is out of date
                if (!d || d.error) {
                    if (d && /sign in/i.test(d.error || '')) { setAdminUI(false); showMessage('Your admin session ended. Sign in again.', 'info'); return; }
                    byId('dashNotice').innerHTML = '';
                    showDashNotice((d && d.error) || 'The dashboard could not be loaded.', 'error');
                    return;
                }
                __dashData = d; __dashBounds = b;
                renderDashboard(d);
                byId('dashUpdated').textContent = 'Updated ' + epochToWallStr(__tz, Date.now()).slice(11) + ', times in ' + zoneLabel(__tz);
            } catch (e) {
                showDashNotice('The dashboard could not be loaded: ' + e.message, 'error');
            } finally {
                body.classList.remove('is-loading'); setBusy(false); if (!quiet) loadOverlay(false);
            }
        }
        function showDashNotice(text, kind) {
            const el = byId('dashNotice');
            const div = document.createElement('div');
            div.className = 'notice notice-' + kind;
            div.textContent = text;
            el.appendChild(div);
        }

        const fmtNum = (n) => (n >= 10000 ? (Math.round(n / 100) / 10) + 'K' : Number(n).toLocaleString('en-US'));
        function bucketLabel(s, hourly, full) {
            if (!hourly && s) return full ? s.slice(0, 10) : s.slice(5, 10);   // a day is a server day; moving it to another zone would shift the date
            const w = fmtServerStr(s);   // "YYYY-MM-DD HH:mm:ss" in the selected zone
            if (w === '—') return '';
            return full ? (hourly ? w.slice(0, 16) : w.slice(0, 10)) : (hourly ? w.slice(11, 16) : w.slice(5, 10));
        }

        function renderDashboard(d) {
            byId('dashNotice').innerHTML = '';
            if (d.partial) showDashNotice('Still reading the older files (' + d.filesExamined + ' of ' + d.filesInRange + ' so far). The first read after the site restarts takes a while. The numbers cover the newest files already read; press Refresh now in a minute to include more.', 'info');
            else if (d.truncated) showDashNotice('This range holds ' + d.filesInRange + ' files and the dashboard read the newest ' + d.filesExamined + ' (its limit, DashboardMaxFiles in web.config, is ' + d.maxFiles + '). Choose a shorter range for the complete picture.', 'info');
            (d.warnings || []).forEach(w => showDashNotice(w, 'info'));

            byId('kpiUser').textContent = fmtNum(d.kpi.userTotal);
            byId('kpiGroups').textContent = fmtNum(d.kpi.groups);
            byId('kpiServers').textContent = fmtNum(d.kpi.servers);
            byId('kpiBg').textContent = fmtNum(d.kpi.backgroundTotal);
            byId('kpiBusy').textContent = d.kpi.busiestCount > 0
                ? d.kpi.busiestCount + ' errors at ' + bucketLabel(d.kpi.busiestBucket, d.hourly, false) : 'none';

            learnLabels(d.moduleLabels);
            fillFacet('dashModule', d.modules || [], 'All modules', modOption);
            renderTimeChart(d);
            renderChartTable(d);
            renderMatrix(d);

            barList('listGroups', (d.topGroups || []).map(g => ({ name: g.message, sub: [g.category, g.app || g.module].filter(Boolean).join(' in '), count: g.count, pick: { search: (g.message || '').slice(0, 60) } })));
            barList('listModule', (d.byModule || []).map(x => ({ name: modLabel(x.name), count: x.count, pick: x.name === '(none)' ? null : { module: x.name } })));
            barList('listCategory', (d.byCategory || []).map(x => ({ name: x.name, count: x.count, pick: null })));
            barList('listCaller', (d.byCaller || []).map(x => ({ name: x.name, count: x.count, pick: { caller: x.name } })));
            barList('listServer', (d.byServer || []).map(x => ({ name: x.name, count: x.count, pick: x.name === '(none)' ? null : { server: x.name } })));
            renderJobs(d);
        }

        // ---- which kinds of error each module has -------------------------------------------------------------
        // A kind of error keeps the same colour everywhere (slots 1,3,4,5,6,7,8 of the chart palette: orange is kept for
        // "background" in the time chart). Anything beyond the seven common kinds is shown as "Other".
        const CAT_SLOT = { 'Error': 1, 'Database': 3, 'Service call': 4, 'Web request': 5, 'File / IO': 6, 'Code defect': 7, 'Timeout': 8 };
        const catColor = (name) => CAT_SLOT[name] ? 'var(--series-' + CAT_SLOT[name] + ')' : 'color-mix(in srgb, var(--lv-muted-2) 70%, transparent)';
        const catKey = (name) => CAT_SLOT[name] ? name : 'Other';

        function renderMatrix(d) {
            const host = byId('matrix'), tip = byId('matrixTip');
            const rows = d.moduleMatrix || [];
            host.textContent = '';
            if (!rows.length) { host.innerHTML = '<div class="empty-body">No errors in this range.</div>'; if (tip) host.appendChild(tip); byId('matrixLegend').innerHTML = ''; byId('matrixTable').innerHTML = ''; return; }

            // fold the rarer kinds into "Other" per row
            const folded = rows.map(r => {
                const m = {};
                r.cats.forEach(c => { m[catKey(c.name)] = (m[catKey(c.name)] || 0) + c.count; });
                return { module: r.module, total: r.total, cats: m };
            });
            const order = Object.keys(CAT_SLOT).concat(['Other']).filter(k => folded.some(r => r.cats[k]));
            const max = Math.max.apply(null, folded.map(r => r.total).concat([1]));

            byId('matrixLegend').innerHTML = order.map(k => '<span><i class="sw" style="background:' + catColor(k) + '"></i>' + escapeHtml(k) + '</span>').join('');

            folded.forEach(r => {
                const row = document.createElement('button');
                row.type = 'button';
                row.className = 'mx-row' + (r.module.toLowerCase() === (__dashModule || '').toLowerCase() ? ' sel' : '');
                row.title = 'Show only this module';
                const name = document.createElement('span'); name.className = 'mx-name'; name.textContent = modLabel(r.module); name.title = modOption(r.module);
                if (modLabel(r.module) !== r.module) { const raw = document.createElement('small'); raw.textContent = r.module; name.appendChild(raw); }
                const track = document.createElement('span'); track.className = 'mx-track'; track.style.width = Math.max(4, Math.round(r.total / max * 100)) + '%';
                order.forEach(k => {
                    if (!r.cats[k]) return;
                    const seg = document.createElement('i'); seg.className = 'mx-seg'; seg.style.flexGrow = r.cats[k]; seg.style.background = catColor(k);
                    seg.dataset.cat = k; seg.dataset.n = r.cats[k];
                    track.appendChild(seg);
                });
                const total = document.createElement('span'); total.className = 'mx-total tabular'; total.textContent = fmtNum(r.total);
                const wrap = document.createElement('span'); wrap.className = 'mx-wrap'; wrap.appendChild(track);
                row.appendChild(name); row.appendChild(wrap); row.appendChild(total);
                row.addEventListener('click', () => {
                    __dashModule = (r.module.toLowerCase() === (__dashModule || '').toLowerCase()) ? '' : r.module;   // select again to clear
                    const sel = byId('dashModule'); sel.value = __dashModule; refreshSearchable('dashModule');
                    loadDashboard();
                });
                row.addEventListener('pointermove', (e) => {
                    const seg = e.target.closest ? e.target.closest('.mx-seg') : null;
                    tip.textContent = '';
                    const head = document.createElement('div'); head.className = 'tip-head'; head.textContent = modOption(r.module); tip.appendChild(head);
                    order.filter(k => r.cats[k]).forEach(k => {
                        const line = document.createElement('div'); line.className = 'tip-row' + (seg && seg.dataset.cat === k ? ' on' : '');
                        const key = document.createElement('i'); key.className = 'key'; key.style.background = catColor(k);
                        const val = document.createElement('b'); val.textContent = String(r.cats[k]);
                        const nm = document.createElement('span'); nm.textContent = k;
                        line.appendChild(key); line.appendChild(val); line.appendChild(nm); tip.appendChild(line);
                    });
                    tip.classList.remove('hidden');
                    const box = host.getBoundingClientRect();
                    let x = e.clientX - box.left + 14; if (x + tip.offsetWidth > box.width) x = e.clientX - box.left - tip.offsetWidth - 14;
                    tip.style.left = Math.max(0, x) + 'px'; tip.style.top = Math.max(0, e.clientY - box.top - 10) + 'px';
                });
                row.addEventListener('pointerleave', () => tip.classList.add('hidden'));
                host.appendChild(row);
            });
            host.appendChild(tip);

            // the same numbers as a table (the light-mode colours rely on this and on the tooltip for exact values)
            byId('matrixTable').innerHTML = '<table class="mini-table"><thead><tr><th>Module</th>' + order.map(k => '<th class="r">' + escapeHtml(k) + '</th>').join('') + '<th class="r">Total</th></tr></thead><tbody>' +
                folded.map(r => '<tr><td>' + escapeHtml(modOption(r.module)) + '</td>' + order.map(k => '<td class="r tabular">' + (r.cats[k] || 0) + '</td>').join('') + '<td class="r tabular">' + r.total + '</td></tr>').join('') + '</tbody></table>';
        }

        function niceMax(v) {
            const p = Math.pow(10, Math.floor(Math.log10(Math.max(1, v))));
            for (const m of [1, 2, 2.5, 5, 10]) if (v <= m * p) return m * p;
            return 10 * p;
        }
        function topRoundedRect(x, y, w, h, r) {
            r = Math.max(0, Math.min(r, h, w / 2));
            return 'M' + x + ' ' + (y + h) + 'V' + (y + r) + 'Q' + x + ' ' + y + ' ' + (x + r) + ' ' + y + 'H' + (x + w - r) + 'Q' + (x + w) + ' ' + y + ' ' + (x + w) + ' ' + (y + r) + 'V' + (y + h) + 'Z';
        }

        function renderTimeChart(d) {
            const el = byId('chartTime'), tip = byId('chartTip');
            const n = d.buckets.length;
            const W = Math.max(320, el.clientWidth || 800), H = 260, m = { l: 44, r: 12, t: 12, b: 32 };
            const pw = W - m.l - m.r, ph = H - m.t - m.b;
            const totals = d.user.map((u, i) => u + d.background[i]);
            const max = niceMax(Math.max.apply(null, totals.concat([1])));
            const band = pw / n, bw = Math.max(2, Math.min(24, band * 0.72)), baseY = m.t + ph, GAP = 2;

            let svg = '<svg viewBox="0 0 ' + W + ' ' + H + '" width="' + W + '" height="' + H + '" role="img" aria-label="Errors per ' + (d.hourly ? 'hour' : 'day') + ', stacked: errors people can run into and background errors">';
            // recessive grid + y ticks
            for (let k = 0; k <= 4; k++) {
                const v = max / 4 * k, y = m.t + ph - (v / max) * ph;
                svg += '<line class="g" x1="' + m.l + '" x2="' + (W - m.r) + '" y1="' + y + '" y2="' + y + '"/>';
                svg += '<text class="ax" x="' + (m.l - 8) + '" y="' + (y + 4) + '" text-anchor="end">' + fmtNum(v) + '</text>';
            }
            // x labels: only as many as fit
            const perLabel = Math.max(1, Math.ceil(n / Math.max(2, Math.floor(pw / 70))));
            let lastDay = '';
            for (let i = 0; i < n; i += perLabel) {
                const full = fmtServerStr(d.buckets[i]);
                let text = d.hourly ? full.slice(11, 16) : full.slice(5, 10);
                if (d.hourly && full.slice(0, 10) !== lastDay) { text = full.slice(5, 10) + ' ' + text; lastDay = full.slice(0, 10); }
                svg += '<text class="ax" x="' + (m.l + band * i + band / 2) + '" y="' + (H - 10) + '" text-anchor="middle">' + text + '</text>';
            }
            // stacked columns: 2px surface gap between segments, 4px rounded data end, square at the baseline
            for (let i = 0; i < n; i++) {
                const x = m.l + band * i + (band - bw) / 2;
                const hu = (d.user[i] / max) * ph, hb = (d.background[i] / max) * ph;
                if (hu > 0) {
                    const hUser = hb > 0 ? Math.max(1, hu - 0) : hu;
                    svg += hb > 0
                        ? '<rect class="s1" x="' + x + '" y="' + (baseY - hu) + '" width="' + bw + '" height="' + hUser + '"/>'
                        : '<path class="s1" d="' + topRoundedRect(x, baseY - hu, bw, hu, 4) + '"/>';
                }
                if (hb > 0) {
                    const yb = baseY - hu - (hu > 0 ? GAP : 0) - hb;
                    svg += '<path class="s2" d="' + topRoundedRect(x, yb, bw, hb, 4) + '"/>';
                }
                svg += '<rect class="hit" data-i="' + i + '" x="' + (m.l + band * i) + '" y="' + m.t + '" width="' + band + '" height="' + ph + '"/>';
            }
            svg += '</svg>';
            el.innerHTML = svg;
            el.appendChild(tip);

            const hide = () => tip.classList.add('hidden');
            el.querySelector('svg').addEventListener('pointermove', (e) => {
                const hit = e.target.closest ? e.target.closest('.hit') : null;
                if (!hit) { hide(); return; }
                const i = Number(hit.dataset.i);
                tip.textContent = '';
                const head = document.createElement('div'); head.className = 'tip-head'; head.textContent = bucketLabel(d.buckets[i], d.hourly, true) + (d.hourly ? ' hour' : '');
                tip.appendChild(head);
                [['s1', 'Errors people can run into', d.user[i]], ['s2', 'Background and sync errors', d.background[i]]].forEach(r => {
                    const row = document.createElement('div'); row.className = 'tip-row';
                    const key = document.createElement('i'); key.className = 'key ' + r[0];
                    const val = document.createElement('b'); val.textContent = String(r[2]);
                    const nm = document.createElement('span'); nm.textContent = r[1];
                    row.appendChild(key); row.appendChild(val); row.appendChild(nm); tip.appendChild(row);
                });
                tip.classList.remove('hidden');
                const box = el.getBoundingClientRect();
                let x = e.clientX - box.left + 14, y = e.clientY - box.top - 10;
                if (x + tip.offsetWidth > box.width) x = e.clientX - box.left - tip.offsetWidth - 14;
                tip.style.left = Math.max(0, x) + 'px'; tip.style.top = Math.max(0, y) + 'px';
            });
            el.querySelector('svg').addEventListener('pointerleave', hide);
        }

        function renderChartTable(d) {
            const rows = d.buckets.map((b, i) => '<tr><td>' + escapeHtml(bucketLabel(b, d.hourly, true)) + '</td><td class="r tabular">' + d.user[i] + '</td><td class="r tabular">' + d.background[i] + '</td></tr>').join('');
            byId('chartTable').innerHTML = '<table class="mini-table"><thead><tr><th>' + (d.hourly ? 'Hour' : 'Day') + '</th><th class="r">Errors people can run into</th><th class="r">Background and sync</th></tr></thead><tbody>' + rows + '</tbody></table>';
        }

        function barList(id, items) {
            const el = byId(id);
            if (!items.length) { el.innerHTML = '<div class="empty-body">Nothing in this range.</div>'; return; }
            const max = Math.max.apply(null, items.map(x => x.count).concat([1]));
            el.textContent = '';
            items.forEach((it) => {
                const row = document.createElement(it.pick ? 'button' : 'div');
                row.className = 'bl-row' + (it.pick ? ' pick' : '');
                if (it.pick) { row.type = 'button'; row.title = 'Open in the error list'; row.addEventListener('click', () => drillDown(it.pick)); }
                const name = document.createElement('span'); name.className = 'bl-name'; name.textContent = it.name; name.title = it.name;
                const track = document.createElement('span'); track.className = 'bl-track';
                const fill = document.createElement('i'); fill.style.width = Math.max(2, Math.round(it.count / max * 100)) + '%'; track.appendChild(fill);
                const val = document.createElement('span'); val.className = 'bl-val tabular'; val.textContent = fmtNum(it.count);
                row.appendChild(name); row.appendChild(track); row.appendChild(val);
                if (it.sub) { const sub = document.createElement('span'); sub.className = 'bl-sub'; sub.textContent = it.sub; row.appendChild(sub); }
                el.appendChild(row);
            });
        }

        function sparkline(per, w, h, buckets, hourly) {
            // fold long series into at most 48 bars; hovering a bar names the time it covers and its count
            const bins = Math.min(48, per.length), size = per.length / bins, vals = [], tips = [];
            for (let i = 0; i < bins; i++) {
                const first = Math.floor(i * size), last = Math.max(first, Math.floor((i + 1) * size) - 1);
                let sum = 0; for (let k = first; k <= last; k++) sum += per[k] || 0;
                vals.push(sum);
                const la = bucketLabel(buckets[first], hourly, true) + (hourly ? ' hour' : ''), lb = bucketLabel(buckets[last], hourly, true) + (hourly ? ' hour' : '');
                tips.push((first === last ? la : la + ' to ' + lb) + '|' + (sum === 0 ? 'No errors' : sum + (sum === 1 ? ' error' : ' errors')));
            }
            const max = Math.max.apply(null, vals.concat([1])), bw = w / bins;
            let out = '<svg class="spark" viewBox="0 0 ' + w + ' ' + h + '" width="' + w + '" height="' + h + '" role="img" aria-label="Errors over the range, total ' + vals.reduce((x, y) => x + y, 0) + '">';
            vals.forEach((v, i) => {
                if (!v) return;
                const bh = Math.max(2, v / max * (h - 2));
                out += '<rect class="s2" x="' + (i * bw + 0.5) + '" y="' + (h - bh) + '" width="' + Math.max(1, bw - 1.5) + '" height="' + bh + '" rx="1"/>';
            });
            vals.forEach((v, i) => { out += '<rect class="sp-hit" data-tip="' + escapeHtml(tips[i]) + '" x="' + (i * bw) + '" y="0" width="' + bw + '" height="' + h + '"/>'; });
            return out + '</svg>';
        }

        function renderJobs(d) {
            const el = byId('jobsBody');
            if (!d.jobs || !d.jobs.length) { el.innerHTML = '<div class="empty-body">No background or sync errors in this range.</div>'; return; }
            const now = Date.now();
            el.textContent = '';
            const table = document.createElement('table'); table.className = 'jobs-table';
            table.innerHTML = '<thead><tr><th>Job (page or module)</th><th>Status</th><th>Errors over the range</th><th class="r">Errors</th><th>Last error</th><th>Most common message</th></tr></thead>';
            const tb = document.createElement('tbody');
            d.jobs.forEach(j => {
                const lastEp = serverStrToEpoch(j.last), mins = lastEp === null ? 99999 : (now - lastEp) / 60000;
                const st = mins < 60 ? { cls: 'st-crit', icon: 'fa-circle-xmark', label: 'Failing now' }
                         : mins < 360 ? { cls: 'st-warn', icon: 'fa-triangle-exclamation', label: 'Recent errors' }
                         : { cls: 'st-ok', icon: 'fa-circle-check', label: 'Quiet' };
                const tr = document.createElement('tr');
                const td = (html) => { const c = document.createElement('td'); if (html !== undefined) c.innerHTML = html; tr.appendChild(c); return c; };
                const nameCell = td(); const nb = document.createElement('button'); nb.type = 'button'; nb.className = 'linkbtn job-name'; nb.textContent = j.name; nb.title = 'Open these errors in the error list';
                nb.addEventListener('click', () => drillDown({ job: j.name })); nameCell.appendChild(nb);
                td('<span class="status ' + st.cls + '"><i class="fa-solid ' + st.icon + '"></i> ' + st.label + '</span>');
                td(sparkline(j.perBucket, 150, 28, d.buckets, d.hourly));
                const c = td(String(j.count)); c.className = 'r tabular';
                const lc = td(); lc.textContent = timeAgo(lastEp === null ? null : new Date(lastEp)) + ', ' + fmtServerStr(j.last); lc.className = 'tabular';
                const mc = td(); mc.className = 'job-msg'; mc.textContent = j.topMessage; mc.title = j.topMessage;
                tb.appendChild(tr);
            });
            table.appendChild(tb); el.appendChild(table);
            bindFloatTip(el);
        }

        // Open the error list scoped to what was clicked, for the dashboard's time range.
        function ensureOption(id, value) {
            const sel = byId(id);
            if (!Array.from(sel.options).some(o => o.value === value)) { const o = document.createElement('option'); o.value = value; o.textContent = value; sel.appendChild(o); }
            sel.value = value; refreshSearchable(id);
        }
        // Filters set by a click on the dashboard or health page are temporary: coming back to the error-files tab
        // through the tab itself starts clean again. Filters the user set by hand are kept until Reset filters.
        let __drilled = false;
        function resetIpasFilters() {
            __drilled = false;
            ['serverFilter', 'typeFilter', 'callerFilter'].forEach(id => { byId(id).value = ''; refreshSearchable(id); });
            byId('moduleSearch').value = '';
            __selModules.clear(); renderModuleList(window.__moduleFacet || []);
            byId('customFilter').value = ''; byId('asyncOnly').checked = false;
            byId('showBackground').checked = !HIDE_BG_DEFAULT;
            byId('searchInput').value = '';
            applyDefaultRange();
            updateMoreCount();
        }

        function drillDown(pick) {
            if (pick.from != null) setFieldsFromEpoch(pick.from, pick.to);
            else if (__dashBounds) setFieldsFromEpoch(__dashBounds.from, __dashBounds.to);
            ['serverFilter', 'typeFilter', 'callerFilter'].forEach(id => { byId(id).value = ''; refreshSearchable(id); });
            byId('moduleSearch').value = '';
            __selModules.clear(); renderModuleList(window.__moduleFacet || []);
            byId('customFilter').value = ''; byId('asyncOnly').checked = false; byId('searchInput').value = '';
            byId('showBackground').checked = !!pick.job || !HIDE_BG_DEFAULT;
            if (pick.module) { __selModules.add(pick.module); renderModuleList(window.__moduleFacet || []); }
            if (pick.caller) ensureOption('callerFilter', pick.caller);
            if (pick.job) ensureOption('callerFilter', pick.job);
            if (pick.server) ensureOption('serverFilter', pick.server);
            if (pick.search) byId('searchInput').value = pick.search;
            __drilled = true;
            setMoreOpen(true);
            showView('ipas');
        }

        // ===================== Admin sign-in (small popup) and the Settings page =====================
        function wireAdmin() {
            const $ = byId;
            const modal = $('adminModal'), loginView = $('adminLoginView'), settingsView = $('adminSettingsView');
            const err = $('adminError'), saved = $('adminSaved');
            const allow = $('allowUserStyles'), box = $('userStylesBox');
            let dirty = false, warned = false, rulesCustom = false, webConfigRules = null, foldersCustom = false, webConfigFolders = null, limitsCustom = false, webConfigLimits = null;

            const closeModal = () => { modal.classList.add('hidden'); $('adminPass').value = ''; err.textContent = ''; $('adminBtn').focus(); };
            const markDirty = () => { dirty = true; warned = false; saved.textContent = ''; };
            const lines = (id) => $(id).value.split(/\r?\n/).map(x => x.trim()).filter(Boolean);
            const setLines = (id, arr) => { $(id).value = (arr || []).join('\n'); };
            const rulesNote = () => {
                $('rulesSource').textContent = rulesCustom
                    ? 'These rules were saved here and replace the ones in web.config. Background errors are tagged and counted, never deleted.'
                    : 'These rules come from web.config. Change anything below to take over from web.config. Background errors are tagged and counted, never deleted.';
            };

            const foldersNote = () => {
                $('foldersSource').textContent = foldersCustom
                    ? 'These folders were saved here and replace the ones in web.config.'
                    : 'These folders come from web.config. Change anything below to take over from web.config.';
            };
            const folderRow = (label, path, x) => {
                const state = x.exists === false ? '<span class="stat-bad">' + escapeHtml(x.error || 'Folder not found') + '</span>'
                    : x.canRead === false ? '<span class="stat-bad">' + escapeHtml(x.error || 'Cannot read') + '</span>'
                    : '<span class="stat-ok">Reachable</span>, ' + x.fileCount + ' files, newest ' + escapeHtml(x.newestFile || 'none') + (x.newestFileTime ? ' (' + escapeHtml(x.newestFileTime) + ' server time)' : '');
                return '<div class="stat-row"><div><b>' + escapeHtml(label || 'Folder') + '</b> <span class="mono">' + escapeHtml(path) + '</span></div><div>' + state + '</div></div>';
            };

            // time zone choices = the same list the page uses
            $('defZone').innerHTML = ['server', 'browser'].concat(ZONE_LIST.map(z => z[0]))
                .map(id => '<option value="' + escapeHtml(id) + '">' + escapeHtml(zoneLabel(id)) + '</option>').join('');

            // Settings sub-tabs
            const showTab = (name) => {
                settingsView.querySelectorAll('.tab').forEach(t => t.classList.toggle('active', t.dataset.tab === name));
                settingsView.querySelectorAll('.tab-panel').forEach(p => p.classList.toggle('hidden', p.dataset.panel !== name));
                if (name === 'status') loadState(false);
            };
            settingsView.querySelectorAll('.tab').forEach(t => t.addEventListener('click', () => showTab(t.dataset.tab)));

            const renderStatus = (st) => {
                const folderHtml = (st.status.folders || []).map(f => {
                    const x = f.status || {};
                    const state = x.exists === false ? '<span class="stat-bad">' + escapeHtml(x.error || 'Folder not found') + '</span>'
                        : x.canRead === false ? '<span class="stat-bad">' + escapeHtml(x.error || 'Cannot read') + '</span>'
                        : '<span class="stat-ok">Reachable</span>, ' + x.fileCount + ' files, newest ' + escapeHtml(x.newestFile || 'none') + (x.newestFileTime ? ' (' + escapeHtml(x.newestFileTime) + ' server time)' : '');
                    return '<div class="stat-row"><div><b>' + escapeHtml(f.label || 'Log folder') + '</b> <span class="mono">' + escapeHtml(f.path) + '</span></div><div>' + state + '</div></div>';
                }).join('');
                $('statusBody').innerHTML = folderHtml +
                    '<div class="stat-row">Remembered in memory: ' + st.status.cachedFiles + ' files (cap on files read per search: ' + st.status.maxSearchFiles + '). Server time ' + escapeHtml(st.status.serverTimeLocal) + ', UTC ' + escapeHtml(st.status.serverTimeUtc) + '.</div>';
                $('auditBox').textContent = (st.audit || []).map(l => l.replace(/\t/g, '  ')).join('\n') || 'Nothing recorded yet.';
            };

            // fillForm=false keeps unsaved edits and only refreshes the status tab
            async function loadState(fillForm) {
                let st = null;
                try { st = await pageMethod('AdminState'); } catch (e) { }
                if (!st || !st.ok) { saved.textContent = (st && st.error) || 'Could not load the settings.'; if (st && /sign in/i.test(st.error || '')) setAdminUI(false); if (st && /super admin/i.test(st.error || '')) showView('dashboard'); return; }
                renderStatus(st);
                if (fillForm === false) return;
                window.__UI = st.settings;
                $('appStyle').value = st.settings.appStyle || 'slate';
                $('adminStyle').value = st.settings.adminStyle || '';
                $('superStyle').value = st.settings.superStyle || '';
                $('defMode').value = st.settings.defaultMode || 'dark';
                allow.checked = !!st.settings.allowUserStyles;
                document.querySelectorAll('.userStyle').forEach(cb => { cb.checked = (st.settings.userStyles || []).indexOf(cb.value) >= 0; });
                box.classList.toggle('disabled', !allow.checked);
                rulesCustom = !st.rules.fromWebConfig;
                webConfigRules = st.rules.webConfig;
                setLines('rulePages', st.rules.pages); setLines('ruleModules', st.rules.modules); setLines('ruleAlways', st.rules.alwaysShow);
                $('ruleHide').checked = !!st.rules.hide;
                $('defRange').value = st.settings.defaultRange || 'today';
                $('defZone').value = st.settings.defaultZone || 'server';
                rulesNote();
                foldersCustom = !st.folders.fromWebConfig;
                webConfigFolders = st.folders.webConfig;
                setLines('folderLines', st.folders.folders);
                $('log4netFolder').value = st.folders.log4net || '';
                foldersNote();
                limitsCustom = !st.limits.fromWebConfig;
                webConfigLimits = st.limits.webConfig;
                $('limFiles').value = st.limits.maxFiles;
                $('limSearch').value = st.limits.maxSearchFiles;
                $('folderResult').textContent = '';
                dirty = false; warned = false;
            }
            window.__adminOpenSettings = () => { showTab('look'); loadState(!dirty); loadSgSettings(); };

            // sign-in popup
            const openLogin = (configured) => {
                err.textContent = '';
                $('adminLoginNote').textContent = configured
                    ? 'Sign in to see the dashboard and change how the Log Explorer looks and behaves for everyone.'
                    : 'Admin sign-in is not set up. Add AdminUsername and AdminPassword to web.config.';
                $('adminSignIn').disabled = !configured;
                modal.classList.remove('hidden');
                $('adminUser').focus();
            };
            $('adminBtn').addEventListener('click', async () => {
                let st = { admin: false, configured: false };
                try { st = await pageMethod('AdminStatus'); } catch (e) { }
                setAdminUI(st.admin, st.role);
                if (st.admin) showView('dashboard'); else openLogin(st.configured);
            });
            modal.addEventListener('click', (e) => { if (e.target.closest && e.target.closest('[data-close]')) closeModal(); });
            document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !modal.classList.contains('hidden')) closeModal(); });
            loginView.addEventListener('submit', async (e) => {
                e.preventDefault();
                err.textContent = '';
                const btn = $('adminSignIn'); btn.disabled = true;
                try {
                    const r = await pageMethod('AdminLogin', { username: $('adminUser').value, password: $('adminPass').value });
                    $('adminPass').value = '';
                    if (r && r.ok) { closeModal(); setAdminUI(true, r.role); showView('dashboard'); } else { err.textContent = (r && r.error) || 'Sign-in failed.'; }
                } catch (ex) { err.textContent = 'Could not reach the server.'; }
                btn.disabled = false;
            });

            // anything edited on the Settings page = unsaved changes
            allow.addEventListener('change', () => { box.classList.toggle('disabled', !allow.checked); markDirty(); });
            ['appStyle', 'adminStyle', 'superStyle', 'defMode', 'defRange', 'defZone', 'sgEnabled', 'sgVisible', 'sgMax', 'sgPerHour', 'sgPwMin', 'sgNeedSignIn', 'sgSignUpOpen'].forEach(id => $(id).addEventListener('change', markDirty));
            document.querySelectorAll('.userStyle').forEach(cb => cb.addEventListener('change', markDirty));
            ['rulePages', 'ruleModules', 'ruleAlways'].forEach(id => $(id).addEventListener('input', () => { rulesCustom = true; rulesNote(); markDirty(); }));
            $('ruleHide').addEventListener('change', () => { rulesCustom = true; rulesNote(); markDirty(); });
            $('rulesReset').addEventListener('click', () => {
                if (!webConfigRules) return;
                setLines('rulePages', webConfigRules.pages); setLines('ruleModules', webConfigRules.modules); setLines('ruleAlways', webConfigRules.alwaysShow);
                $('ruleHide').checked = !!webConfigRules.hide;
                rulesCustom = false; rulesNote(); markDirty();
            });

            ['limFiles', 'limSearch'].forEach(id => $(id).addEventListener('input', () => { limitsCustom = true; markDirty(); }));
            ['folderLines', 'log4netFolder'].forEach(id => $(id).addEventListener('input', () => { foldersCustom = true; foldersNote(); markDirty(); }));
            $('foldersReset').addEventListener('click', () => {
                if (!webConfigFolders) return;
                setLines('folderLines', webConfigFolders.folders);
                $('log4netFolder').value = webConfigFolders.log4net || '';
                foldersCustom = false; foldersNote(); markDirty();
            });
            $('testFolders').addEventListener('click', async () => {
                const out = $('folderResult');
                out.textContent = 'Checking…';
                try {
                    const r = await pageMethod('AdminTestFolders', { folders: lines('folderLines'), log4netFolder: $('log4netFolder').value.trim() });
                    if (!r || !r.ok) { out.textContent = (r && r.error) || 'Could not check the folders.'; return; }
                    let html = (r.result.folders || []).map(f => folderRow(f.label, f.path, f.status || {})).join('');
                    if (r.result.log4net) html += folderRow('log4net', r.result.log4net.path, r.result.log4net.status || {});
                    out.innerHTML = html || 'Nothing to check. Enter at least one folder.';
                } catch (ex) { out.textContent = 'Could not reach the server.'; }
            });

            $('adminSave').addEventListener('click', async () => {
                saved.textContent = 'Saving…';
                const styles = Array.from(document.querySelectorAll('.userStyle')).filter(cb => cb.checked).map(cb => cb.value);
                try {
                    const r = await pageMethod('SaveUiSettings', {
                        appStyle: $('appStyle').value, allowUserStyles: allow.checked, userStyles: styles,
                        useWebConfigRules: !rulesCustom,
                        backgroundPages: lines('rulePages'), backgroundModules: lines('ruleModules'), alwaysShow: lines('ruleAlways'),
                        hideBackground: $('ruleHide').checked,
                        defaultRange: $('defRange').value, defaultZone: $('defZone').value, defaultMode: $('defMode').value,
                        useWebConfigFolders: !foldersCustom, logFolders: lines('folderLines'), log4netFolder: $('log4netFolder').value.trim(),
                        useWebConfigLimits: !limitsCustom, maxFiles: Number($('limFiles').value) || 0, maxSearchFiles: Number($('limSearch').value) || 0,
                        adminStyle: $('adminStyle').value, superStyle: $('superStyle').value
                    });
                    if (r && r.ok) {
                        const r2 = await pageMethod('SaveSuggestionSettings', { enabled: $('sgEnabled').checked, visibleToUsers: $('sgVisible').checked,
                            maxChars: Number($('sgMax').value) || 1000, perHour: Number($('sgPerHour').value) || 5, passwordMin: Number($('sgPwMin').value) || 6,
                            needSignIn: $('sgNeedSignIn').checked, signUpOpen: $('sgSignUpOpen').checked });
                        window.__UI = r.settings;
                        if (r2 && r2.ok) { window.__UI.suggestionsEnabled = r2.config.enabled; $('sgMax').value = r2.config.maxChars; $('sgPerHour').value = r2.config.perHour; }
                        applySuggestTab(); buildStylePicker(); dirty = false; warned = false;
                        const bad = ((r.folderCheck && r.folderCheck.folders) || []).filter(f => f.status && (f.status.exists === false || f.status.canRead === false));
                        saved.textContent = 'Saved. The style and folders apply now; the other defaults apply the next time a page is opened.' +
                            (bad.length ? ' Warning: ' + bad.map(f => (f.label || f.path)).join(', ') + ' could not be reached. Check the Log folders tab.' : '');
                        loadState(false);
                    } else saved.textContent = (r && r.error) || 'Could not save.';
                } catch (ex) { saved.textContent = 'Could not reach the server.'; }
            });
            $('clearCacheBtn').addEventListener('click', async () => {
                try { const r = await pageMethod('AdminClearCache'); saved.textContent = r && r.ok ? 'Done. The next search reads the log files again.' : ((r && r.error) || 'Could not clear.'); loadState(false); }
                catch (ex) { saved.textContent = 'Could not reach the server.'; }
            });

            // sign out (Settings page and Dashboard): warn once about unsaved changes, then reload the page
            document.querySelectorAll('[data-signout]').forEach(btn => btn.addEventListener('click', async () => {
                if (dirty && !warned) {
                    warned = true; showView('settings');
                    saved.textContent = 'You have unsaved changes. Press Save, or choose Sign out again to discard them.';
                    return;
                }
                try { await pageMethod('AdminLogout'); } catch (e) { }
                location.reload();
            }));

            // dashboard controls
            document.querySelectorAll('[data-drange]').forEach(b => b.addEventListener('click', () => {
                __dashRange = b.dataset.drange;
                document.querySelectorAll('[data-drange]').forEach(x => x.classList.toggle('active', x === b));
                loadDashboard();
            }));
            $('dashRefresh').addEventListener('click', () => loadDashboard());
            document.querySelectorAll('[data-hrange]').forEach(b => b.addEventListener('click', () => {
                __healthRange = b.dataset.hrange;
                document.querySelectorAll('[data-hrange]').forEach(x => x.classList.toggle('active', x === b));
                loadHealth();
            }));
            $('healthRefresh').addEventListener('click', () => loadHealth());
            document.querySelectorAll('[data-hstatus]').forEach(b => b.addEventListener('click', () => setHealthStatus(b.dataset.hstatus)));
            $('healthModule').addEventListener('change', () => { __healthModule = $('healthModule').value; if (__healthData) renderHealth(__healthData); });
            $('healthClear').addEventListener('click', () => { __healthModule = ''; setHealthStatus('all'); });
            $('healthAuto').addEventListener('change', () => { if (__view === 'health') startDashTimer(); });
            $('dashModule').addEventListener('change', () => { __dashModule = $('dashModule').value; loadDashboard(); });
            $('dashAuto').addEventListener('change', () => { if (__view === 'dashboard') startDashTimer(); });
            let rz = null;
            window.addEventListener('resize', () => { clearTimeout(rz); rz = setTimeout(() => { if (__view === 'dashboard' && __dashData) renderTimeChart(__dashData); }, 150); });

            pageMethod('AdminStatus').then(st => setAdminUI(st && st.admin, st && st.role)).catch(() => { });
        }

        // ===================== Searchable dropdowns =====================
        // The native <select> stays in the page (hidden) as the single source of truth, so the rest of the code keeps
        // reading .value and listening for "change". The visible control adds a search box over its options.
        const __searchables = {};
        function makeSearchable(id) {
            const sel = document.getElementById(id);
            if (!sel || __searchables[id]) return;
            sel.style.display = 'none';

            const wrap = document.createElement('div');
            wrap.className = 'msel';
            wrap.innerHTML =
                '<button type="button" class="lv-input msel-btn" aria-haspopup="listbox" aria-expanded="false"><span></span><i class="fa-solid fa-chevron-down"></i></button>' +
                '<div class="msel-pop hidden"><div class="msel-top"><input type="search" class="lv-input msel-search" placeholder="Search" autocomplete="off" /></div>' +
                '<div class="msel-list pretty-scroll" role="listbox"></div></div>';
            sel.parentNode.insertBefore(wrap, sel);
            const btn = wrap.querySelector('.msel-btn'), pop = wrap.querySelector('.msel-pop');
            const input = wrap.querySelector('.msel-search'), list = wrap.querySelector('.msel-list');
            btn.style.width = sel.style.width || '14rem';
            btn.setAttribute('aria-label', sel.getAttribute('aria-label') || '');
            input.setAttribute('aria-label', 'Search ' + (sel.getAttribute('aria-label') || 'options'));
            let active = -1;

            const label = () => {
                const o = sel.options[sel.selectedIndex];
                btn.firstChild.textContent = o ? o.text : '';
                btn.title = o ? o.text : '';
                btn.classList.toggle('has-value', !!(o && o.value));
            };
            const items = () => Array.from(list.querySelectorAll('.msel-opt'));
            const highlightActive = () => items().forEach((el, i) => el.classList.toggle('active', i === active));
            const render = () => {
                const q = input.value.trim().toLowerCase();
                const opts = Array.from(sel.options).filter(o => !q || !o.value || o.text.toLowerCase().indexOf(q) >= 0);
                list.innerHTML = opts.length <= 1 && q
                    ? '<div class="msel-empty">No match</div>'
                    : opts.map(o => '<div class="msel-opt' + (o.value === sel.value ? ' sel' : '') + '" title="' + escapeHtml(o.text) + '" role="option" data-v="' + escapeHtml(o.value) + '">' + escapeHtml(o.text) + '</div>').join('');
                active = q ? Math.min(1, items().length - 1) : -1;
                highlightActive();
            };
            const close = () => { pop.classList.add('hidden'); btn.setAttribute('aria-expanded', 'false'); };
            const open = () => {
                document.querySelectorAll('.msel-pop').forEach(p => { if (p !== pop) p.classList.add('hidden'); });
                input.value = '';
                render();
                pop.classList.remove('hidden');
                btn.setAttribute('aria-expanded', 'true');
                input.focus();
                const cur = list.querySelector('.sel'); if (cur) cur.scrollIntoView({ block: 'nearest' });
            };
            const choose = (v) => {
                close();
                if (sel.value !== v) { sel.value = v; sel.dispatchEvent(new Event('change')); }
                label();
            };

            btn.addEventListener('click', (e) => { e.stopPropagation(); pop.classList.contains('hidden') ? open() : close(); });
            input.addEventListener('input', render);
            input.addEventListener('keydown', (e) => {
                const els = items();
                if (e.key === 'ArrowDown') { e.preventDefault(); active = Math.min(els.length - 1, active + 1); highlightActive(); els[active] && els[active].scrollIntoView({ block: 'nearest' }); }
                else if (e.key === 'ArrowUp') { e.preventDefault(); active = Math.max(0, active - 1); highlightActive(); els[active] && els[active].scrollIntoView({ block: 'nearest' }); }
                else if (e.key === 'Enter') { e.preventDefault(); const el = els[active >= 0 ? active : 0]; if (el) choose(el.dataset.v); }
                else if (e.key === 'Escape') { close(); btn.focus(); }
            });
            list.addEventListener('click', (e) => { const el = e.target.closest('.msel-opt'); if (el) choose(el.dataset.v); });
            document.addEventListener('click', (e) => { if (!wrap.contains(e.target)) close(); });

            label();
            __searchables[id] = { refresh: () => { label(); if (!pop.classList.contains('hidden')) render(); } };
        }
        function refreshSearchable(id) { if (__searchables[id]) __searchables[id].refresh(); }

        // ===================== Module multi-select =====================
        function wireModulePicker() {
            const btn = document.getElementById('moduleBtn');
            const pop = document.getElementById('modulePop');
            const close = () => { pop.classList.add('hidden'); btn.setAttribute('aria-expanded', 'false'); };
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const open = pop.classList.toggle('hidden') === false;
                btn.setAttribute('aria-expanded', open ? 'true' : 'false');
            });
            document.addEventListener('click', (e) => { if (!document.getElementById('moduleSel').contains(e.target)) close(); });
            document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });
            document.getElementById('moduleSearch').addEventListener('input', () => renderModuleList(window.__moduleFacet || []));
            btn.addEventListener('click', () => setTimeout(() => { if (!pop.classList.contains('hidden')) document.getElementById('moduleSearch').focus(); }, 0));
            let timer = null;
            document.getElementById('moduleClear').addEventListener('click', () => {
                clearTimeout(timer);                       // a tick a moment ago must not load a second time
                __selModules.clear();
                renderModuleList(window.__moduleFacet || []);
                loadLogs();
            });
            document.getElementById('moduleList').addEventListener('change', (e) => {
                const cb = e.target;
                if (!cb || cb.type !== 'checkbox') return;
                if (cb.checked) __selModules.add(cb.value); else __selModules.delete(cb.value);
                updateModuleLabel();
                clearTimeout(timer);
                timer = setTimeout(loadLogs, 350);
            });
        }

        function updateModuleLabel() {
            const n = __selModules.size;
            const label = document.getElementById('moduleLabel');
            label.textContent = n === 0 ? 'All modules' : (n === 1 ? modLabel(Array.from(__selModules)[0]) : n + ' modules');
            document.getElementById('moduleBtn').title = n === 0 ? 'All modules' : Array.from(__selModules).map(modOption).join('\n');
        }

        function renderModuleList(items) {
            window.__moduleFacet = items;
            // keep selected modules visible even if the current result no longer contains them
            const q = (document.getElementById('moduleSearch').value || '').trim().toLowerCase();
            const all = Array.from(new Set(items.concat(Array.from(__selModules))))
                .filter(m => !q || m.toLowerCase().indexOf(q) >= 0 || modLabel(m).toLowerCase().indexOf(q) >= 0 || __selModules.has(m))
                .sort((a, b) => modLabel(a).toLowerCase().localeCompare(modLabel(b).toLowerCase()) || a.toLowerCase().localeCompare(b.toLowerCase()));
            document.getElementById('moduleList').innerHTML = all.length === 0
                ? '<div class="msel-empty">No modules match</div>'
                : all.map(m => `<label class="msel-item" title="${escapeHtml(m)}"><input type="checkbox" value="${escapeHtml(m)}" ${__selModules.has(m) ? 'checked' : ''} /><span class="msel-text"><span>${escapeHtml(modLabel(m))}</span>${modLabel(m) !== m ? `<span class="msel-raw mono">${escapeHtml(m)}</span>` : ''}</span></label>`).join('');
            updateModuleLabel();
        }

        // ===================== grouped error-file view =====================
        const SEV_RANK = { error: 3, warning: 2, info: 1 };
        const SORTS = {
            severity: g => (SEV_RANK[g.Severity] || 0),
            message: g => (g.Message || '').toLowerCase(),
            module: g => (g.App || g.ErrorModule || '').toLowerCase(),
            caller: g => (g.Caller || '').toLowerCase(),
            server: g => (g.Servers || []).join(',').toLowerCase(),
            count: g => g.Count || 0,
            first: g => g.First || '',
            last: g => g.Last || ''
        };
        const DEFAULT_DIR = { severity: 'desc', message: 'asc', module: 'asc', caller: 'asc', server: 'asc', count: 'desc', first: 'desc', last: 'desc' };
        let __sort = { key: 'last', dir: 'desc' };   // newest activity first

        function ipasFilters() {
            return {
                server: document.getElementById('serverFilter').value,
                errorType: document.getElementById('typeFilter').value,
                modules: Array.from(__selModules),
                caller: document.getElementById('callerFilter').value,
                customMessage: document.getElementById('customFilter').value.trim(),
                asyncOnly: document.getElementById('asyncOnly').checked,
                showBackground: document.getElementById('showBackground').checked
            };
        }

        // Raw module value -> readable name ("Plant web service"). Filled from every answer the server sends.
        window.__modLabels = window.__modLabels || {};
        function learnLabels(map) { if (map) Object.keys(map).forEach(k => { window.__modLabels[k] = map[k]; }); }
        function modLabel(raw) { return (raw && window.__modLabels[raw]) || raw || ''; }
        // a dropdown option: the readable name, and the raw value when the two differ (several raw values can share a name)
        function modOption(raw) { const l = modLabel(raw); return l && l !== raw ? l + '  ·  ' + raw : raw; }

        function fillFacet(id, items, allLabel, labelOf) {
            const sel = document.getElementById(id);
            const current = sel.value;
            const list = (items || []).slice();
            if (current && list.indexOf(current) < 0) list.push(current);
            sel.innerHTML = [`<option value="">${escapeHtml(allLabel)}</option>`]
                .concat(list.map(x => `<option value="${escapeHtml(x)}">${escapeHtml(labelOf ? labelOf(x) : x)}</option>`)).join('');
            sel.value = current;
            refreshSearchable(id);
        }

        // The extra filters live behind one button. It shows how many are active so none is ever forgotten.
        function activeMoreFilters() {
            let n = 0;
            if (byId('serverFilter').value) n++;
            if (byId('typeFilter').value) n++;
            if (__selModules.size) n++;
            if (byId('callerFilter').value) n++;
            if (byId('customFilter').value.trim()) n++;
            if (byId('asyncOnly').checked) n++;
            if (byId('showBackground').checked !== !HIDE_BG_DEFAULT) n++;
            return n;
        }
        function updateMoreCount() {
            const n = activeMoreFilters(), c = byId('moreCount');
            c.textContent = n; c.classList.toggle('hidden', n === 0);
        }
        function setMoreOpen(open) {
            byId('ipasFilters').classList.toggle('collapsed', !open);
            byId('moreFiltersBtn').setAttribute('aria-expanded', open ? 'true' : 'false');
            lsSet('lv_more', open ? '1' : '0');
        }

        function loadLogs() {
            __page = 1;
            if (__source === 'ipas') updateMoreCount();
            if (__source === 'log4net') { loadLog4Net(); return; }
            const bounds = serverBounds();
            if (!bounds) return;
            const searchQuery = document.getElementById('searchInput').value.trim();
            const my = ++__listSeq; __listInFlight++;
            const query = Object.assign({ from: bounds.from, to: bounds.to, search: searchQuery }, ipasFilters());

            document.getElementById('messageArea').innerHTML = '';
            showLoading(true);
            setBusy(true); loadOverlay(true);
            updateDiag({ 'Status': 'Initializing Request...', 'From (server time)': bounds.from, 'To (server time)': bounds.to });

            fetch('Default.aspx/GetLogs', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(query)
            })
            .then(async (res) => {
                const text = await res.text();
                let json;
                try { json = JSON.parse(text); } catch (e) { throw new Error(`Non-JSON response (${res.status})`); }
                if (!res.ok) throw new Error(json && json.Message ? json.Message : `HTTP ${res.status}`);
                return json;
            })
            .then(res => {
                if (my !== __listSeq || __source !== 'ipas') return;     // a newer request (or another tab) owns the table now
                const data = res.d;
                if (!data || data.error) {
                    showMessage((data && data.error) || 'The server returned no data.', 'error');
                    __lastResult = null;
                    renderLogs([]);
                    return;
                }
                __lastResult = data; __lastQuery = query;
                updateDiag({ 'Status': 'Response Received', 'Files in range': data.filesInRange, 'Files read': data.filesExamined, 'Records': data.totalRecords });

                fillFacet('serverFilter', data.facets.servers, 'All servers');
                fillFacet('typeFilter', data.facets.errorTypes, 'All error types');
                fillFacet('callerFilter', data.facets.callers, 'All sources / callers');
                learnLabels(data.facets.moduleLabels);
                renderModuleList(data.facets.modules || []);

                renderLogs(data.groups || []);

                if (data.truncated) {
                    showMessage(`Only the newest ${data.filesExamined} of ${data.filesInRange} files in this range were read (a limit in web.config was reached). Narrow the date range, or add a search term, to see the rest.`, 'info', true);
                }
                (data.warnings || []).forEach(w => showMessage(w, 'info', true));
            })
            .catch(error => {
                if (my !== __listSeq || __source !== 'ipas') return;
                console.error('Error fetching logs:', error);
                updateDiag({ 'Status': 'Request Failed', 'Error': error.message });
                showMessage('Could not load the logs: ' + error.message, 'error');
                __lastResult = null;
                renderLogs([]);
            })
            .finally(() => { __listInFlight--; setBusy(false); loadOverlay(false); });
        }

        function sortedGroups(groups) {
            const get = SORTS[__sort.key] || SORTS.last;
            const sign = __sort.dir === 'asc' ? 1 : -1;
            return groups.slice().sort((a, b) => {
                const av = get(a), bv = get(b);
                if (av < bv) return -1 * sign;
                if (av > bv) return 1 * sign;
                // tie-breakers: newest, then most frequent
                if (a.Last !== b.Last) return a.Last < b.Last ? 1 : -1;
                return (b.Count || 0) - (a.Count || 0);
            });
        }

        function renderLogs(groups) {
            const tableBody = document.getElementById('logsTableBody');
            const resultsCount = document.getElementById('resultsCount');
            const groupsMeta = document.getElementById('groupsMeta');
            const bgNote = document.getElementById('bgNote');

            __lastGroupsRaw = Array.isArray(groups) ? groups.slice() : [];
            const sorted = sortedGroups(__lastGroupsRaw);
            window.__lastGroups = sorted;
            syncSortHeaders();

            const pageSize = __pageSize.ipas;
            const pageCount = Math.max(1, Math.ceil(sorted.length / pageSize));
            if (__page > pageCount) __page = pageCount;
            const pageStart = (__page - 1) * pageSize;
            const pageItems = sorted.slice(pageStart, pageStart + pageSize);

            // hide columns that would only show dashes, or the same server on every row
            const hasCaller = sorted.some(g => g.Caller);
            const hasSites = sorted.some(g => (g.SiteIds || []).some(x => x && x !== '0'));
            const serverSet = new Set(); sorted.forEach(g => (g.Servers || []).forEach(x => serverSet.add(x)));
            const tbl = byId('logsTable');
            tbl.classList.toggle('hide-caller', !hasCaller); tbl.classList.toggle('hide-sites', !hasSites); tbl.classList.toggle('hide-server', serverSet.size <= 1);
            tbl.style.minWidth = (1500 - (hasCaller ? 0 : 224) - (hasSites ? 0 : 96) - (serverSet.size > 1 ? 0 : 144)) + 'px';

            const totalOcc = sorted.reduce((n, g) => n + (g.Count || 0), 0);
            const maxOcc = sorted.reduce((n, g) => Math.max(n, g.Count || 0), 1);
            const plural = (n, w) => n + ' ' + w + (n === 1 ? '' : 's');
            resultsCount.textContent = sorted.length > 0
                ? plural(sorted.length, 'error group') + ' from ' + plural(totalOcc, 'occurrence')
                : 'No results';

            const hidden = __lastResult ? (__lastResult.backgroundHidden || 0) : 0;
            bgNote.innerHTML = hidden > 0
                ? `<span class="bg-note">${plural(hidden, 'background error')} hidden. <button type="button" class="linkbtn" id="bgShowBtn">Show them</button></span>`
                : '';
            const showBtn = document.getElementById('bgShowBtn');
            if (showBtn) showBtn.addEventListener('click', () => { document.getElementById('showBackground').checked = true; loadLogs(); });

            groupsMeta.textContent = sorted.length > 0
                ? 'Times in ' + zoneLabel(__tz) + '. Select a row to see each occurrence and its raw file text.'
                : '';

            if (sorted.length === 0) {
                renderPager(0);
                tableBody.innerHTML = `
                    <tr>
                        <td colspan="11">
                            <div class="empty">
                                <div class="empty-title">No errors in this time range</div>
                                <p class="empty-body">${hidden > 0 ? hidden + ' background or sync error' + (hidden === 1 ? ' was' : 's were') + ' found, but they are hidden.' : 'Nothing matches the dates and filters you chose.'}</p>
                                <div class="empty-actions">
                                    ${hidden > 0 ? '<button type="button" class="lv-copy-btn" id="emptyShowBg">Show background errors</button>' : ''}
                                    <button type="button" class="lv-copy-btn" id="emptyWeek">Last 7 days</button>
                                </div>
                                <p class="empty-hint">You can also clear the search box or remove a filter.</p>
                            </div>
                        </td>
                    </tr>`;
                wireEmptyActions(null);
                return;
            }

            const term = (__lastQuery && __lastQuery.search) || '';   // highlight what the list was searched for
            let html = '';
            pageItems.forEach((g, i) => {
                const index = pageStart + i;
                const sev = g.Severity || 'error';
                const bg = g.BackgroundCount || 0;
                const count = g.Count || 0;
                const pct = Math.max(4, Math.round((count / maxOcc) * 100));
                const siteIds = (g.SiteIds || []).filter(x => x && x !== '0');
                const siteTags = siteIds.slice(0, 3).map(id => `<span class="site-tag">${escapeHtml(id)}</span>`).join('')
                    + (siteIds.length > 3 ? `<span class="site-tag" title="${escapeHtml(siteIds.slice(3).join(', '))}">+${siteIds.length - 3}</span>` : '');
                const servers = g.Servers || [];
                const serverText = servers.length === 0 ? '—' : escapeHtml(servers[0]) + (servers.length > 1 ? ` <span class="lv-muted-2" title="${escapeHtml(servers.join(', '))}">+${servers.length - 1}</span>` : '');
                const firstEpoch = serverStrToEpoch(g.First), lastEpoch = serverStrToEpoch(g.Last);
                const tags = (g.IsAsync ? '<span class="tag" title="Wrapped async call. The real inner message and caller are shown.">async</span>' : '')
                    + (bg > 0 ? `<span class="tag tag-bg" title="Listed as a background/sync error in web.config">background${bg < count ? ' ' + bg + '/' + count : ''}</span>` : '');
                const note = g.ParseNote ? ` <i class="fa-solid fa-circle-info lv-muted-2" title="${escapeHtml(g.ParseNote)}"></i>` : '';

                html += `
                    <tr class="group-row lv-row" data-index="${index}" data-sev="${escapeHtml(sev)}" tabindex="0" role="button" aria-expanded="false" aria-label="Toggle occurrence details for: ${escapeHtml(g.Message || 'error group')}">
                        <td class="px-4 py-3 text-xs lv-muted-2 tabular align-top">${index + 1}</td>
                        <td class="px-4 py-3 align-top"><span class="badge badge-${escapeHtml(sev)}">${escapeHtml(g.Category || 'Error')}</span></td>
                        <td class="px-4 py-3 align-top">
                            <div class="cell-title line-clamp-2" title="${escapeHtml(g.Message || '')}">${highlight(g.Message || '', term)}${note}</div>
                            ${g.ErrorMethod ? `<div class="cell-sub">${highlight(g.ErrorMethod, term)}</div>` : ''}
                            ${g.CustomMessage ? `<div class="cell-note">${highlight(g.CustomMessage, term)}</div>` : ''}
                            ${tags ? `<div class="tags">${tags}</div>` : ''}
                        </td>
                        <td class="px-4 py-3 align-top" title="${escapeHtml(g.ErrorModule ? 'Module in the file: ' + g.ErrorModule : 'No module in the file')}">${g.App
                            ? `<div class="mod-app">${highlight(g.App, term)}</div>${g.AppDetail ? `<div class="mod-detail mono">${highlight(g.AppDetail, term)}</div>` : ''}`
                            : (g.ErrorModule ? `<div class="mod-detail mono">${highlight(g.ErrorModule, term)}</div>` : '<span class="lv-muted-2">—</span>')}</td>
                        <td class="col-caller px-4 py-3 align-top text-xs mono lv-muted" style="word-break:break-word" title="${escapeHtml(g.Caller || '')}">${g.Caller ? highlight(g.Caller, term) : '<span class="lv-muted-2">—</span>'}</td>
                        <td class="col-server px-4 py-3 align-top text-xs lv-muted">${serverText}</td>
                        <td class="px-4 py-3 align-top">
                            <div class="freq" title="${count} of ${totalOcc} occurrences">
                                <span class="freq-n tabular">${count}</span>
                                <span class="freq-bar"><i style="width:${pct}%"></i></span>
                            </div>
                        </td>
                        <td class="px-4 py-3 align-top">
                            <div class="t-rel tabular">${escapeHtml(timeAgo(lastEpoch === null ? null : new Date(lastEpoch)))}</div>
                            <div class="t-abs tabular">${escapeHtml(fmtServerStr(g.Last))}</div>
                        </td>
                        <td class="px-4 py-3 align-top">
                            <div class="t-rel tabular">${escapeHtml(timeAgo(firstEpoch === null ? null : new Date(firstEpoch)))}</div>
                            <div class="t-abs tabular">${escapeHtml(fmtServerStr(g.First))}</div>
                        </td>
                        <td class="col-sites px-4 py-3 align-top"><div class="sites">${siteTags || '<span class="lv-muted-2">—</span>'}</div></td>
                        <td class="px-4 py-3 text-right align-top">
                            <button class="expand-btn" data-index="${index}" tabindex="-1" aria-label="Toggle occurrence details"><i class="fa-solid fa-chevron-down text-[10px]"></i></button>
                        </td>
                    </tr>
                    <tr class="hidden" id="detailsRow-${index}">
                        <td colspan="11" class="p-0">
                            <div id="details-${index}" class="lv-detail-panel">
                                <div class="detail-sticky" data-sev="${escapeHtml(sev)}">
                                    <span class="badge badge-${escapeHtml(sev)}">${escapeHtml(g.Category || 'Error')}</span>
                                    <span class="detail-sticky-msg" title="${escapeHtml(g.Message || '')}">${escapeHtml(g.Message || '')}</span>
                                    <span class="detail-sticky-meta tabular">${count} occurrence${count === 1 ? '' : 's'}</span>
                                    <span class="det-pager" id="detPagerTop-${index}"></span>
                                    <button type="button" class="lv-copy-btn detail-collapse" data-collapse="${index}" title="Close this group and jump back to its row"><i class="fa-solid fa-chevron-up"></i> Collapse</button>
                                </div>
                                <div id="detailsBody-${index}"><div class="loading"><span class="spinner" aria-hidden="true"></span>Loading occurrences…</div></div>
                            </div>
                        </td>
                    </tr>`;
            });
            tableBody.innerHTML = html;
            renderPager(sorted.length);

            const headH = document.getElementById('tableHead').offsetHeight || 34;
            document.querySelector('.lv-table-container').style.setProperty('--thead-h', headH + 'px');
            tableBody.querySelectorAll('[data-collapse]').forEach(btn => btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const i = parseInt(btn.dataset.collapse, 10);
                toggleDetails(i);
                const row = document.querySelector(`tr[data-index="${i}"]`);
                if (row) { row.scrollIntoView({ block: 'nearest' }); row.focus({ preventScroll: true }); }
            }));
            tableBody.querySelectorAll('tr[data-index]').forEach(tr => {
                tr.addEventListener('click', () => toggleDetails(parseInt(tr.dataset.index, 10)));
                tr.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        toggleDetails(parseInt(tr.dataset.index, 10));
                    }
                });
            });
        }

        function toggleDetails(index) {
            const detailsRow = document.getElementById(`detailsRow-${index}`);
            const parentRow = document.querySelector(`tr[data-index="${index}"]`);
            const expandIcon = parentRow.querySelector('.expand-btn i');
            const isHidden = detailsRow.classList.contains('hidden');

            if (isHidden) {
                detailsRow.classList.remove('hidden');
                parentRow.classList.add('active');
                parentRow.setAttribute('aria-expanded', 'true');
                if (expandIcon) expandIcon.className = 'fa-solid fa-chevron-up text-[10px]';
                loadDetails(index);
            } else {
                detailsRow.classList.add('hidden');
                parentRow.classList.remove('active');
                parentRow.setAttribute('aria-expanded', 'false');
                if (expandIcon) expandIcon.className = 'fa-solid fa-chevron-down text-[10px]';
            }
        }

        window.__occRaw = {};
        const DET_SIZES = [10, 25, 50];
        let __detSize = Number(lsGet('lv_dsize')) || 10;

        function detPager(data, full) {
            const pages = Math.max(1, Math.ceil(data.total / data.pageSize));
            const a = data.total === 0 ? 0 : (data.page - 1) * data.pageSize + 1, b = a + data.shown - (data.total === 0 ? 0 : 1);
            const prev = '<button type="button" class="pg-btn" data-dpage="' + (data.page - 1) + '"' + (data.page <= 1 ? ' disabled' : '') + ' aria-label="Previous occurrences"><i class="fa-solid fa-chevron-left"></i></button>';
            const next = '<button type="button" class="pg-btn" data-dpage="' + (data.page + 1) + '"' + (data.page >= pages ? ' disabled' : '') + ' aria-label="Next occurrences"><i class="fa-solid fa-chevron-right"></i></button>';
            const info = full ? 'Page ' + data.page + ' of ' + pages + ' (' + a + '–' + b + ' of ' + data.total + ')' : a + '–' + b + ' of ' + data.total;
            const rows = full ? '<label class="pg-rows">Rows <select class="lv-input det-size">' + DET_SIZES.map(n => '<option value="' + n + '"' + (n === data.pageSize ? ' selected' : '') + '>' + n + '</option>').join('') + '</select></label>' : '';
            return prev + '<span class="pg-info tabular">' + info + '</span>' + next + rows;
        }

        async function loadDetails(index, page, scrollToTop) {
            const detailsContainer = document.getElementById(`detailsBody-${index}`);
            const panel = document.getElementById(`details-${index}`);
            if (!panel.dataset.wired) {
                panel.dataset.wired = '1';
                panel.addEventListener('click', (e) => {
                    const b = e.target.closest('[data-dpage]');
                    if (b && !b.disabled) { e.stopPropagation(); loadDetails(index, Number(b.dataset.dpage), true); }
                });
                panel.addEventListener('change', (e) => {
                    if (e.target.classList && e.target.classList.contains('det-size')) {
                        __detSize = Number(e.target.value); lsSet('lv_dsize', e.target.value);
                        loadDetails(index, 1, true);
                    }
                });
            }
            detailsContainer.innerHTML = '<div class="loading"><span class="spinner" aria-hidden="true"></span>Loading occurrences…</div>';

            const mySeq = panel._seq = (panel._seq || 0) + 1;
            try {
                const selectedGroup = window.__lastGroups[index];
                // the list on screen was asked with these values; typing in the boxes without applying must not change it
                const q = __lastQuery || Object.assign({ search: '' }, serverBounds() || {}, ipasFilters());
                if (!q.from) { detailsContainer.innerHTML = '<div class="notice notice-error">Choose a valid From and To first.</div>'; return; }
                const searchQuery = q.search || '';

                const response = await fetch('Default.aspx/GetLogDetails', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(Object.assign({}, q, { search: searchQuery, groupId: selectedGroup.Id, page: page || 1, pageSize: __detSize }))
                });

                const result = await response.json();
                if (mySeq !== panel._seq) return;       // a newer page was asked for meanwhile
                const data = result.d;
                if (!data || data.error) throw new Error((data && data.error) || 'No data');

                const items = data.occurrences || [];
                let html = '';
                items.forEach((o, n) => {
                    const key = index + '-' + n;
                    window.__occRaw[key] = o.RawText || '';
                    const site = (o.SiteID == null || o.SiteID === 0) ? '' : `<span><i class="fa-solid fa-location-dot"></i>Site ${escapeHtml(o.SiteID)}</span>`;
                    const tags = (o.IsAsync ? '<span class="tag">async</span>' : '') + (o.IsBackground ? '<span class="tag tag-bg">background</span>' : '');
                    const ctx = [];
                    if (o.Caller) ctx.push(`<span><b>Source/caller</b> <span class="mono">${highlight(o.Caller, searchQuery)}</span></span>`);
                    if (o.App) ctx.push(`<span><b>Part</b> ${highlight(o.App, searchQuery)}${o.AppDetail ? ` <span class="mono lv-muted">(${highlight(o.AppDetail, searchQuery)})</span>` : ''}</span>`);
                    if (o.Module) ctx.push(`<span><b>Module</b> <span class="mono">${highlight(o.Module, searchQuery)}</span></span>`);
                    if (o.CustomMessage) ctx.push(`<span><b>Custom message</b> ${highlight(o.CustomMessage, searchQuery)}</span>`);
                    if (o.ContextDetails) ctx.push(`<span><b>Details</b> ${highlight(o.ContextDetails, searchQuery)}</span>`);
                    html += `
                        <div class="trace-card">
                            <div class="trace-head">
                                <div class="trace-meta">
                                    <span><i class="fa-regular fa-clock"></i><b class="tabular">${escapeHtml(fmtServerStr(o.Timestamp))}</b></span>
                                    <span><i class="fa-solid fa-server"></i>${escapeHtml(o.ServerName || 'Unknown server')}</span>
                                    <span><i class="fa-regular fa-file-lines"></i><span class="mono">${escapeHtml(o.FileName)}</span></span>
                                    ${site}${tags}
                                </div>
                                <button type="button" onclick="handleCopy(this, window.__occRaw['${key}'])" class="lv-copy-btn">
                                    <i class="fa-regular fa-copy"></i> Copy file text
                                </button>
                            </div>
                            ${ctx.length ? `<div class="trace-ctx">${ctx.join('')}</div>` : ''}
                            ${o.ParseNote ? `<div class="trace-ctx"><span><i class="fa-solid fa-circle-info"></i> ${escapeHtml(o.ParseNote)}</span></div>` : ''}
                            <pre class="lv-pre max-h-[420px] pretty-scroll">${highlight(o.RawText || '', searchQuery)}</pre>
                        </div>`;
                });
                detailsContainer.innerHTML = items.length > 0 ? html + '<div class="det-pager det-pager-bot">' + detPager(data, true) + '</div>'
                    : '<div class="empty-body text-center py-6">No occurrences found for this group.</div>';
                const top = document.getElementById(`detPagerTop-${index}`);
                if (top) top.innerHTML = detPager(data, false);
                if (scrollToTop) { const row = document.querySelector(`tr[data-index="${index}"]`); if (row) row.scrollIntoView({ block: 'start' }); }
            } catch (err) {
                detailsContainer.innerHTML = '<div class="notice notice-error">Could not load the occurrences for this group. Try again, or check that the log folder is reachable.</div>';
            }
        }

        // ===================== Source switching =====================

        function switchSource(source) {
            __source = (source === 'log4net') ? 'log4net' : 'ipas';
            document.querySelectorAll('.src-tab').forEach(b =>
                b.classList.toggle('active', b.dataset.source === __source));
            const l4 = document.getElementById('log4netFilters');
            if (l4) l4.classList.toggle('hidden', __source !== 'log4net');
            const ip = document.getElementById('ipasFilters');
            if (ip) ip.classList.toggle('hidden', __source !== 'ipas');
            byId('moreFiltersBtn').classList.toggle('hidden', __source !== 'ipas');
            byId('l4nCsv').classList.toggle('hidden', __source !== 'log4net');
            document.getElementById('bgNote').innerHTML = '';
            setTableHeaderFor(__source);
            loadLogs();
        }

        const IPAS_COLS = [
            ['', '#', 'w-12'], ['severity', 'Severity', 'w-32'], ['message', 'Error', ''], ['module', 'Module', 'w-56'],
            ['caller', 'Source/caller', 'w-56 col-caller'], ['server', 'Server', 'w-36 col-server'], ['count', 'Occurrences', 'w-36'],
            ['last', 'Last seen', 'w-44'], ['first', 'First seen', 'w-44'], ['', 'Sites', 'w-24 col-sites'], ['', '', 'w-14']
        ];

        function setTableHeaderFor(source) {
            const head = document.getElementById('tableHead');
            if (!head) return;
            if (source === 'log4net') {
                head.innerHTML = `
                    <tr>
                        <th class="w-12">#</th>
                        <th class="w-44">Time</th>
                        <th class="w-24">Level</th>
                        <th class="w-44">Log file</th>
                        <th class="w-56">Logger</th>
                        <th>Message</th>
                        <th class="w-16"><span class="sr-only">Expand</span></th>
                    </tr>`;
            } else {
                head.innerHTML = '<tr>' + IPAS_COLS.map(c => {
                    if (!c[0]) return `<th class="${c[2]}">${c[1] || '<span class="sr-only">Expand</span>'}</th>`;
                    return `<th class="${c[2]}" data-sort-th="${c[0]}"><button type="button" class="th-sort" data-sort="${c[0]}" title="Sort by ${c[1]}">${c[1]}<span class="th-arrow" aria-hidden="true"></span></button></th>`;
                }).join('') + '</tr>';
                head.querySelectorAll('.th-sort').forEach(b => b.addEventListener('click', () => {
                    const key = b.dataset.sort;
                    if (__sort.key === key) __sort.dir = __sort.dir === 'asc' ? 'desc' : 'asc';
                    else __sort = { key: key, dir: DEFAULT_DIR[key] || 'asc' };
                    __page = 1;
                    renderLogs(__lastGroupsRaw || []);
                }));
                syncSortHeaders();
            }
        }

        function syncSortHeaders() {
            document.querySelectorAll('th[data-sort-th]').forEach(th => {
                const active = th.dataset.sortTh === __sort.key;
                th.setAttribute('aria-sort', active ? (__sort.dir === 'asc' ? 'ascending' : 'descending') : 'none');
                th.classList.toggle('th-active', active);
                const arrow = th.querySelector('.th-arrow');
                if (arrow) arrow.textContent = active ? (__sort.dir === 'asc' ? ' ▲' : ' ▼') : '';
            });
        }

        // ===================== log4net stream view =====================

        function getLevelInfo(level) {
            switch ((level || '').toUpperCase()) {
                case 'FATAL': return { cls: 'badge badge-fatal', sev: 'error' };
                case 'ERROR': return { cls: 'badge badge-error', sev: 'error' };
                case 'WARN':
                case 'WARNING': return { cls: 'badge badge-warning', sev: 'warning' };
                case 'INFO': return { cls: 'badge badge-info', sev: 'info' };
                case 'DEBUG': return { cls: 'badge badge-debug', sev: 'debug' };
                case 'TRACE': return { cls: 'badge badge-trace', sev: 'debug' };
                default: return { cls: 'badge badge-info', sev: 'info' };
            }
        }

        function loadLog4Net(quiet) {
            if (quiet) setField('toDate', epochToWallStr(__tz, Date.now()));   // Follow: the range always ends now
            const bounds = serverBounds();
            if (!bounds) return;
            const searchQuery = document.getElementById('searchInput').value.trim();
            const channel = document.getElementById('channelFilter').value;
            const logger = document.getElementById('loggerFilter').value;
            const levels = Array.from(__activeLevels).join(',');

            const my = ++__listSeq; __listInFlight++;
            if (!quiet) { document.getElementById('messageArea').innerHTML = ''; showLoading(true); setBusy(true); loadOverlay(true); }
            updateDiag({ 'Status': 'Loading log4net...', 'From (server time)': bounds.from, 'To (server time)': bounds.to, 'Channel': channel || '(all)' });

            fetch('Default.aspx/GetLog4NetLogs', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ from: bounds.from, to: bounds.to, search: searchQuery, levels: levels, logger: logger, channel: channel })
            })
            .then(async (res) => {
                const text = await res.text();
                let json;
                try { json = JSON.parse(text); } catch (e) { throw new Error(`Non-JSON response (${res.status})`); }
                if (!res.ok) throw new Error(`HTTP ${res.status}`);
                return json;
            })
            .then(res => {
                if (my !== __listSeq || __source !== 'log4net') return;
                const data = res.d;
                if (data && data.error) {
                    if (quiet) return;                    // Follow: keep what is on screen; the next tick tries again
                    showMessage(data.error, 'error');
                    renderStream([]);
                    return;
                }
                if (quiet) document.getElementById('messageArea').innerHTML = '';   // a good refresh clears an old error
                const entries = (data && data.entries) ? data.entries : [];
                window.__l4nNewest = data && data.newest ? data.newest : null;
                populateLog4NetFacets(data);
                updateDiag({ 'Status': 'Response Received', 'Entries': entries.length, 'Truncated': data && data.truncated ? 'Yes' : 'No' });
                renderStream(entries);
                if (data && data.truncated) {
                    showMessage('Showing the most recent entries only (result was truncated). Narrow the date range or filters for the full set.', 'info');
                }
            })
            .catch(error => {
                if (my !== __listSeq || __source !== 'log4net') return;
                console.error('Error fetching log4net logs:', error);
                updateDiag({ 'Status': 'Request Failed', 'Error': error.message });
                if (quiet) return;                        // Follow: a network blip must not empty the list
                showMessage('Error fetching logs: ' + error.message, 'error');
                renderStream([]);
            })
            .finally(() => { __listInFlight--; if (!quiet) { setBusy(false); loadOverlay(false); } });
        }

        function populateLog4NetFacets(data) {
            if (!data) return;
            const fill = (id, items) => {
                const sel = document.getElementById(id);
                if (!sel) return;
                const current = sel.value;
                const allLabel = id === 'channelFilter' ? 'All log files' : 'All loggers';
                const opts = [`<option value="">${allLabel}</option>`].concat(
                    (items || []).map(x => `<option value="${escapeHtml(x)}">${escapeHtml(x)}</option>`)
                );
                sel.innerHTML = opts.join('');
                if (current && (items || []).indexOf(current) >= 0) sel.value = current;
                refreshSearchable(id);
            };
            fill('channelFilter', data.channels);
            fill('loggerFilter', data.loggers);
        }

        // buttons inside the "nothing found" messages
        function wireEmptyActions(newestEpoch) {
            const jump = byId('l4nJump');
            if (jump && newestEpoch !== null) jump.addEventListener('click', () => {
                // the whole day of the newest entry, in the selected time zone
                const t = epochToWallStr(__tz, newestEpoch).split(/[- :]/).map(Number);
                const from = wallToEpoch(__tz, t[0], t[1], t[2], 0, 0, 0);
                setFieldsFromEpoch(from, from + 86400000 - 1000);
                loadLogs();
            });
            const wk = byId('emptyWeek'); if (wk) wk.addEventListener('click', () => setRange(168));
            const bg = byId('emptyShowBg'); if (bg) bg.addEventListener('click', () => { byId('showBackground').checked = true; loadLogs(); });
        }

        // "Follow new entries": refresh every 10 seconds, newest on top, and leave the screen alone while a row is open
        let __l4nTimer = null;
        function updateFollow() {
            if (__l4nTimer) { clearInterval(__l4nTimer); __l4nTimer = null; }
            if (byId('l4nFollow').checked && __view === 'log4net') {
                __l4nTimer = setInterval(() => {
                    if (__view !== 'log4net' || document.hidden) return;
                    if (document.querySelector('#logsTableBody tr.lv-row.active')) return;
                    if (__listInFlight > 0) return;       // the last refresh has not answered yet: don't stack another
                    loadLog4Net(true);
                }, 10000);
            }
        }

        // Download what is on screen (every entry that matches the filters, not just this page) as a spreadsheet file
        function downloadCsv() {
            const rows = window.__streamEntries || [];
            if (!rows.length) return;
            const cell = (v) => {
                let s = String(v == null ? '' : v).replace(/\r?\n/g, ' / ');
                if (/^[=+\-@\t]/.test(s)) s = "'" + s;       // stop a spreadsheet treating text as a formula
                return '"' + s.replace(/"/g, '""') + '"';
            };
            const head = ['Time (' + zoneLabel(__tz) + ')', 'Level', 'Log file', 'Logger', 'Thread', 'Message', 'Details'];
            const lines = [head.map(cell).join(',')].concat(rows.map(e =>
                [formatTimestamp(e.Timestamp), e.Level, e.Channel ? e.Channel + '.log' : '', e.Logger, e.Thread, e.Message, e.Notes].map(cell).join(',')));
            const blob = new Blob(['\uFEFF' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
            const a = document.createElement('a');
            const now = epochToWallStr(__tz, Date.now()).replace(/[- :]/g, '').replace(/^(\d{8})(\d{6}).*/, '$1-$2');
            a.href = URL.createObjectURL(blob); a.download = 'log4net-' + now + '.csv';
            document.body.appendChild(a); a.click(); a.remove();
            setTimeout(() => URL.revokeObjectURL(a.href), 2000);
        }

        function renderStream(entries) {
            const tableBody = document.getElementById('logsTableBody');
            const resultsCount = document.getElementById('resultsCount');
            const groupsMeta = document.getElementById('groupsMeta');

            window.__streamEntries = Array.isArray(entries) ? entries : [];
            const count = window.__streamEntries.length;
            byId('logsTable').style.minWidth = '';
            const lSize = __pageSize.log4net;
            const lPages = Math.max(1, Math.ceil(count / lSize));
            if (__page > lPages) __page = lPages;
            const lStart = (__page - 1) * lSize;
            byId('l4nCsv').disabled = count === 0;

            resultsCount.textContent = count > 0 ? `${count} log ${count === 1 ? 'entry' : 'entries'}` : 'No results';
            groupsMeta.textContent = count > 0 ? 'Times in ' + zoneLabel(__tz) + '. Newest first. Select any row to read the whole message.' : '';

            if (count === 0) {
                renderPager(0);
                const newest = window.__l4nNewest ? serverStrToEpoch(window.__l4nNewest) : null;
                const when = newest === null ? '' : escapeHtml(fmtServerStr(window.__l4nNewest)) + (Date.now() - newest < 7 * 86400000 ? ', ' + escapeHtml(timeAgo(new Date(newest))) : '');
                tableBody.innerHTML = `
                    <tr>
                        <td colspan="${currentColspan()}">
                            <div class="empty">
                                <div class="empty-title">No log4net entries in this time range</div>
                                <p class="empty-body">${newest === null ? 'The log4net files have no entries yet.' : 'The newest entry in the log4net files is from <b>' + when + '</b>.'}</p>
                                <div class="empty-actions">
                                    ${newest === null ? '' : '<button type="button" class="lv-copy-btn" id="l4nJump">Show that day</button>'}
                                    <button type="button" class="lv-copy-btn" id="emptyWeek">Last 7 days</button>
                                </div>
                                <p class="empty-hint">You can also clear the search box or turn more levels on.</p>
                            </div>
                        </td>
                    </tr>`;
                wireEmptyActions(newest);
                return;
            }

            let html = '';
            window.__streamEntries.slice(lStart, lStart + lSize).forEach((e, i) => {
                const index = lStart + i;
                const lvl = getLevelInfo(e.Level);
                const hasNotes = !!(e.Notes && String(e.Notes).trim().length > 0);
                const msg = escapeHtml(e.Message || '');
                const file = e.Channel ? e.Channel + '.log' : '';

                html += `
                    <tr class="lv-row" data-sindex="${index}" data-sev="${lvl.sev}" tabindex="0" role="button" aria-expanded="false" aria-label="Log entry: ${msg}">
                        <td class="px-4 py-3 text-xs lv-muted tabular align-top">${index + 1}</td>
                        <td class="px-4 py-3 text-xs tabular whitespace-nowrap align-top mono lv-text">${escapeHtml(formatTimestamp(e.Timestamp))}</td>
                        <td class="px-4 py-3 align-top"><span class="${lvl.cls}">${escapeHtml(e.Level || '')}</span></td>
                        <td class="px-4 py-3 text-xs lv-muted align-top mono" style="word-break:break-word">${escapeHtml(file)}</td>
                        <td class="px-4 py-3 text-xs lv-muted-2 align-top mono" style="word-break:break-word">${escapeHtml(e.Logger || '')}</td>
                        <td class="px-4 py-3 align-top"><div class="text-[13px] lv-text line-clamp-2" title="${msg}">${msg}</div></td>
                        <td class="px-4 py-3 text-right align-top"><button class="expand-btn" tabindex="-1" aria-label="Expand entry"><i class="fa-solid fa-chevron-down text-[10px]"></i></button></td>
                    </tr>`;

                const traceHtml = hasNotes ? formatStackTraceHtml(e.Notes) : '';
                const copyArg = hasNotes ? encodeURIComponent(formatStackTrace(e.Notes)).replace(/'/g, "\\'") : '';
                html += `
                    <tr class="hidden" id="sdetail-${index}">
                        <td colspan="${currentColspan()}" class="p-0">
                            <div class="lv-detail-panel">
                                <div class="trace-meta mb-3">
                                    <span><i class="fa-regular fa-clock"></i> ${escapeHtml(formatTimestamp(e.Timestamp))}</span>
                                    ${file ? `<span><i class="fa-regular fa-file-lines"></i> ${escapeHtml(file)}</span>` : ''}
                                    <span><i class="fa-solid fa-hashtag"></i> ${escapeHtml(e.Logger || '')}</span>
                                    ${e.Thread ? `<span><i class="fa-solid fa-microchip"></i> Thread ${escapeHtml(e.Thread)}</span>` : ''}
                                    ${(e.SiteID && e.SiteID !== 0) ? `<span><i class="fa-solid fa-location-dot"></i>Site ${escapeHtml(e.SiteID)}</span>` : ''}
                                    <button type="button" class="lv-copy-btn" data-copy-entry="${index}" style="margin-left:auto"><i class="fa-regular fa-copy"></i> Copy entry</button>
                                </div>
                                <div class="text-[13px] lv-text whitespace-pre-wrap break-words mb-2">${msg}</div>
                                ${hasNotes ? `
                                <div class="group lv-trace-container">
                                    <button onclick="handleCopy(this, decodeURIComponent('${copyArg}'))" class="lv-copy-btn" style="position:absolute; top:.5rem; right:.5rem;"><i class="fa-regular fa-copy"></i> Copy trace</button>
                                    <pre class="lv-pre max-h-[420px] pretty-scroll">${traceHtml}</pre>
                                </div>` : ''}
                            </div>
                        </td>
                    </tr>`;
            });
            tableBody.innerHTML = html;
            renderPager(count);

            tableBody.querySelectorAll('[data-copy-entry]').forEach(btn => btn.addEventListener('click', (ev) => {
                ev.stopPropagation();
                const e = window.__streamEntries[Number(btn.dataset.copyEntry)] || {};
                handleCopy(btn, [formatTimestamp(e.Timestamp), e.Level, (e.Channel ? e.Channel + '.log ' : '') + (e.Logger || '') + ' -', e.Message].filter(Boolean).join(' ') + (e.Notes ? '\n' + e.Notes : ''));
            }));
            tableBody.querySelectorAll('tr[data-sindex]').forEach(tr => {
                tr.addEventListener('click', () => toggleStream(parseInt(tr.dataset.sindex, 10)));
                tr.addEventListener('keydown', (e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        toggleStream(parseInt(tr.dataset.sindex, 10));
                    }
                });
            });
        }

        function toggleStream(index) {
            const detail = document.getElementById(`sdetail-${index}`);
            if (!detail) return;
            const row = document.querySelector(`tr[data-sindex="${index}"]`);
            const icon = row ? row.querySelector('.expand-btn i') : null;
            const isHidden = detail.classList.contains('hidden');

            if (isHidden) {
                detail.classList.remove('hidden');
                if (row) { row.classList.add('active'); row.setAttribute('aria-expanded', 'true'); }
                if (icon) icon.className = 'fa-solid fa-chevron-up text-[10px]';
            } else {
                detail.classList.add('hidden');
                if (row) { row.classList.remove('active'); row.setAttribute('aria-expanded', 'false'); }
                if (icon) icon.className = 'fa-solid fa-chevron-down text-[10px]';
            }
        }
    </script>
</body>
</html>


