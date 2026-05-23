/* ============================================================
   Design tokens
   ============================================================ */
:root {
  /* Colour palette — warm editorial */
  --bg:          #f7f1e3;
  --bg-card:    #fffaee;
  --bg-elev:    #f0e8d1;
  --ink:         #1e2a1e;
  --ink-soft:    #4a5544;
  --ink-mute:    #8a8472;
  --line:        #d9cfb2;
  --line-soft:  #e8dfc4;
  --field:       #1f4b3a;
  --field-soft: #2c6a52;
  --accent:      #d4561d;
  --accent-soft: #e88a4a;
  --warn:        #b8860b;
  --ok:          #5a7d3a;
  --err:         #a83232;

  /* Typography */
  --font-display: 'Fraunces', Georgia, serif;
  --font-body:    'DM Sans', system-ui, sans-serif;
  --font-mono:    'JetBrains Mono', monospace;

  /* Spacing */
  --s-1: 4px;
  --s-2: 8px;
  --s-3: 12px;
  --s-4: 16px;
  --s-5: 24px;
  --s-6: 32px;
  --s-7: 48px;
  --s-8: 64px;

  /* Radius */
  --r-sm: 6px;
  --r-md: 10px;
  --r-lg: 16px;
}

/* ============================================================
   Reset
   ============================================================ */
*, *::before, *::after { box-sizing: border-box; }
html, body { margin: 0; padding: 0; }
body {
  font-family: var(--font-body);
  font-size: 16px;
  line-height: 1.55;
  color: var(--ink);
  background: var(--bg);
  -webkit-font-smoothing: antialiased;
}
button, input, select, textarea { font: inherit; color: inherit; }
button { cursor: pointer; }
a { color: var(--field); text-decoration: none; }
a:hover { text-decoration: underline; }

/* ============================================================
   Typography classes
   ============================================================ */
h1, h2, h3, h4 {
  font-family: var(--font-display);
  font-weight: 600;
  letter-spacing: -0.01em;
  margin: 0 0 var(--s-4);
  font-variation-settings: "opsz" 50;
}
h1 { font-size: clamp(2rem, 5vw, 3.2rem); line-height: 1.05; font-variation-settings: "opsz" 144; letter-spacing: -0.02em; }
h2 { font-size: 1.75rem; line-height: 1.15; }
h3 { font-size: 1.25rem; line-height: 1.25; }

.eyebrow {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  color: var(--ink-mute);
  margin-bottom: var(--s-3);
}

.mono { font-family: var(--font-mono); }
.muted { color: var(--ink-mute); }

/* ============================================================
   Layout helpers
   ============================================================ */
.app-shell {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}
.page {
  max-width: 1080px;
  margin: 0 auto;
  padding: var(--s-7) var(--s-5);
  width: 100%;
  flex: 1;
}
.page-narrow {
  max-width: 520px;
}

/* ============================================================
   Card
   ============================================================ */
.card {
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-lg);
  padding: var(--s-6);
  box-shadow: 0 1px 0 rgba(30,42,30,0.04);
}

/* ============================================================
   Form controls
   ============================================================ */
.field {
  display: flex;
  flex-direction: column;
  gap: var(--s-2);
  margin-bottom: var(--s-4);
}
.field label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--ink-soft);
}
.field input,
.field select,
.field textarea {
  border: 1px solid var(--line);
  background: var(--bg-card);
  border-radius: var(--r-md);
  padding: var(--s-3) var(--s-4);
  font-size: 1rem;
  transition: border-color 0.15s, box-shadow 0.15s;
}
.field input:focus,
.field select:focus,
.field textarea:focus {
  outline: none;
  border-color: var(--field);
  box-shadow: 0 0 0 3px rgba(31, 75, 58, 0.12);
}
.field .hint {
  font-size: 0.8125rem;
  color: var(--ink-mute);
}

/* ============================================================
   Buttons
   ============================================================ */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: var(--s-2);
  padding: var(--s-3) var(--s-5);
  border-radius: var(--r-md);
  border: 1px solid transparent;
  font-weight: 500;
  font-size: 0.9375rem;
  transition: background 0.15s, border-color 0.15s, transform 0.05s;
}
.btn:active { transform: translateY(1px); }
.btn:disabled { opacity: 0.5; cursor: not-allowed; }

.btn-primary {
  background: var(--field);
  color: #fffaee;
}
.btn-primary:hover:not(:disabled) { background: var(--field-soft); text-decoration: none; }

.btn-secondary {
  background: transparent;
  border-color: var(--line);
  color: var(--ink);
}
.btn-secondary:hover:not(:disabled) { background: var(--bg-elev); text-decoration: none; }

.btn-accent {
  background: var(--accent);
  color: #fffaee;
}
.btn-accent:hover:not(:disabled) { background: var(--accent-soft); text-decoration: none; }

.btn-danger {
  background: transparent;
  border-color: var(--err);
  color: var(--err);
}
.btn-danger:hover:not(:disabled) { background: rgba(168, 50, 50, 0.06); text-decoration: none; }

.btn-sm { padding: var(--s-2) var(--s-3); font-size: 0.875rem; }

/* ============================================================
   Banners / alerts
   ============================================================ */
.alert {
  border-radius: var(--r-md);
  padding: var(--s-3) var(--s-4);
  font-size: 0.9375rem;
  margin-bottom: var(--s-4);
  border: 1px solid;
}
.alert-info    { background: #eef2ea; border-color: #c9d6c0; color: var(--field); }
.alert-success { background: #ebf4e1; border-color: #b9d39d; color: var(--ok); }
.alert-warn    { background: #fbf3dc; border-color: #e8d49a; color: var(--warn); }
.alert-error   { background: #f7e0e0; border-color: #d9a6a6; color: var(--err); }

/* ============================================================
   Tables
   ============================================================ */
.table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9375rem;
}
.table th, .table td {
  padding: var(--s-3) var(--s-4);
  text-align: left;
  border-bottom: 1px solid var(--line-soft);
}
.table th {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--ink-mute);
}
.table tr:last-child td { border-bottom: none; }
.table tr:hover td { background: rgba(31, 75, 58, 0.03); }

/* ============================================================
   Badge / status pills
   ============================================================ */
.badge {
  display: inline-flex;
  align-items: center;
  font-family: var(--font-mono);
  font-size: 0.6875rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  padding: 3px 8px;
  border-radius: 999px;
  border: 1px solid;
}
.badge-pending { background: #fbf3dc; border-color: #e8d49a; color: var(--warn); }
.badge-active  { background: #ebf4e1; border-color: #b9d39d; color: var(--ok); }
.badge-admin   { background: rgba(212, 86, 29, 0.10); border-color: var(--accent-soft); color: var(--accent); }
.badge-rejected{ background: #f7e0e0; border-color: #d9a6a6; color: var(--err); }

/* ============================================================
   Nav
   ============================================================ */
.navbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--s-4) var(--s-5);
  border-bottom: 1px solid var(--line);
  background: var(--bg-card);
}
.navbar-inner {
  max-width: 1080px;
  width: 100%;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--s-5);
}
.brand {
  font-family: var(--font-display);
  font-weight: 700;
  font-size: 1.25rem;
  color: var(--ink);
  letter-spacing: -0.02em;
}
.brand:hover { text-decoration: none; }
.brand-mark {
  display: inline-block;
  width: 10px;
  height: 10px;
  border-radius: 2px;
  background: var(--accent);
  margin-right: 10px;
  vertical-align: middle;
  transform: rotate(45deg);
}
.nav-links {
  display: flex;
  gap: var(--s-5);
  align-items: center;
}
.nav-links a {
  color: var(--ink-soft);
  font-size: 0.9375rem;
  font-weight: 500;
}
.nav-links a.router-link-active {
  color: var(--ink);
  position: relative;
}
.nav-links a.router-link-active::after {
  content: "";
  position: absolute;
  bottom: -4px;
  left: 0;
  right: 0;
  height: 2px;
  background: var(--accent);
}

/* ============================================================
   Utility
   ============================================================ */
.stack > * + * { margin-top: var(--s-4); }
.row { display: flex; gap: var(--s-3); align-items: center; }
.row-between { display: flex; gap: var(--s-3); align-items: center; justify-content: space-between; }
.right { margin-left: auto; }

/* ============================================================
   Mobile
   ============================================================ */
@media (max-width: 640px) {
  .page { padding: var(--s-5) var(--s-4); }
  .card { padding: var(--s-5); }
  .navbar { padding: var(--s-3) var(--s-4); }
  .nav-links { gap: var(--s-4); }
  h1 { font-size: 2rem; }
}
