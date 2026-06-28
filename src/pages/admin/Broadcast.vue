<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../lib/supabase.js'
import { useAuthStore } from '../../stores/auth.js'

const auth = useAuthStore()

const subject = ref('')
const heading = ref('')
const body = ref('')
const includeStandings = ref(true)

const recipientCount = ref(0)
const top5 = ref([])           // [{rank, name, points}] voor de preview
const myStanding = ref(null)   // { rank, total, points } voor {mijn_stand}-preview
const myRoundPoints = ref({})  // { 1: x, 2: y, ... } voor {mijn_punten_rX}-preview
const sending = ref(false)
const sentInfo = ref(null)     // { count } na verzturen
const error = ref('')

const bodyRef = ref(null)

async function load() {
  // Aantal ontvangers (alles behalve inactive)
  const { count } = await supabase
    .from('profiles')
    .select('id', { count: 'exact', head: true })
    .neq('status', 'inactive')
  recipientCount.value = count || 0

  // Volledige stand voor top 5 + mijn eigen positie
  const { data } = await supabase
    .from('user_standings')
    .select('id, full_name, total_points, exact_count, r1_points, r2_points, r3_points, r4_points, r5_points, r6_points, r7_points, r8_points')
    .order('total_points', { ascending: false })
    .order('exact_count', { ascending: false })
    .order('full_name')
  const rows = data || []

  top5.value = rows.slice(0, 5).map((r, i) => ({
    rank: i + 1, name: r.full_name, points: r.total_points
  }))

  const myIdx = rows.findIndex((r) => r.id === auth.profile?.id)
  if (myIdx >= 0) {
    const me = rows[myIdx]
    myStanding.value = { rank: myIdx + 1, total: rows.length, points: me.total_points }
    myRoundPoints.value = {
      1: me.r1_points, 2: me.r2_points, 3: me.r3_points, 4: me.r4_points,
      5: me.r5_points, 6: me.r6_points, 7: me.r7_points, 8: me.r8_points
    }
  }
}
onMounted(load)

const myFirstName = computed(() =>
  auth.profile?.full_name?.split(' ')[0] || 'speler'
)

// Variabele invoegen op de cursorpositie in het body-tekstvak
function insertVar(token) {
  const el = bodyRef.value
  if (!el) { body.value += token; return }
  const start = el.selectionStart ?? body.value.length
  const end = el.selectionEnd ?? body.value.length
  body.value = body.value.slice(0, start) + token + body.value.slice(end)
  // cursor na het token zetten
  requestAnimationFrame(() => {
    el.focus()
    const pos = start + token.length
    el.setSelectionRange(pos, pos)
  })
}

function onRoundInsert(ev) {
  const token = ev.target.value
  if (token) insertVar(token)
  ev.target.value = ''  // dropdown terugzetten
}

const medals = { 1: '🥇', 2: '🥈', 3: '🥉' }

// Converteer een ruwe textarea-tekst naar nette HTML voor de mail.
// - Enkele newline → <br>
// - Lege regel (dubbele newline) → nieuwe <p> alinea
// - **vet** → <strong>, *cursief* → <em>
// - [tekst](url) → <a href>
// Bestaande HTML-tags blijven ongemoeid, dus <p>, <strong>, etc. kan ook direct.
function formatBodyHtml(raw) {
  if (!raw) return ''
  let s = raw
  s = s.replace(/\*\*([^*\n]+?)\*\*/g, '<strong>$1</strong>')
  s = s.replace(/(?<![*\w])\*([^*\n]+?)\*(?![*\w])/g, '<em>$1</em>')
  s = s.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, '<a href="$2" style="color:#b8861a">$1</a>')
  const paras = s.split(/\n\s*\n/).map(p => {
    const inner = p.replace(/\n/g, '<br>')
    return inner.trim() ? `<p style="margin:0 0 12px">${inner}</p>` : ''
  }).filter(Boolean)
  return paras.join('')
}

// Preview: zet variabelen om naar HTML zoals de mail 'm toont (met jouw eigen data)
const previewHtml = computed(() => {
  let html = formatBodyHtml(body.value)
  html = html.replace(/\{voornaam\}/g, myFirstName.value)

  const standText = myStanding.value
    ? `op plek ${myStanding.value.rank} van ${myStanding.value.total} met ${myStanding.value.points} punten`
    : 'nog niet in de stand'
  html = html.replace(/\{mijn_stand\}/g, standText)

  for (let n = 1; n <= 8; n++) {
    html = html.replace(new RegExp(`\\{mijn_punten_r${n}\\}`, 'g'), String(myRoundPoints.value[n] ?? 0))
  }

  let top5Html = '<table style="width:100%;border-collapse:collapse;margin:8px 0;">'
  for (const row of top5.value) {
    top5Html +=
      '<tr>' +
      `<td style="padding:6px 8px;border-bottom:1px solid #eee;color:#6b7280;width:30px;">${medals[row.rank] || row.rank}</td>` +
      `<td style="padding:6px 8px;border-bottom:1px solid #eee;font-weight:bold;">${row.name}</td>` +
      `<td style="padding:6px 8px;border-bottom:1px solid #eee;color:#b8861a;text-align:right;">${row.points} pt</td>` +
      '</tr>'
  }
  top5Html += '</table>'
  html = html.replace(/\{top5\}/g, top5Html)

  return html
})

async function send() {
  error.value = ''
  sentInfo.value = null

  if (!subject.value.trim()) { error.value = 'Vul een onderwerp in.'; return }
  if (!body.value.trim())    { error.value = 'Het bericht is leeg.'; return }

  const total = recipientCount.value
  if (!confirm(`Dit bericht wordt naar ${total} deelnemer${total === 1 ? '' : 's'} verstuurd. Doorgaan?`)) return

  sending.value = true
  try {
    const { data, error: err } = await supabase.rpc('send_broadcast', {
      p_subject: subject.value,
      p_heading: heading.value || subject.value,
      p_body_html: formatBodyHtml(body.value),
      p_include_standings: includeStandings.value
    })
    if (err) throw err
    sentInfo.value = { count: data }
    // velden leegmaken na succes
    subject.value = ''
    heading.value = ''
    body.value = ''
  } catch (e) {
    console.error('[Broadcast] versturen mislukt:', e)
    error.value = e.message || 'Versturen is niet gelukt.'
  } finally {
    sending.value = false
  }
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Beheer</p>
    <h1>Berichten</h1>

    <div class="card" style="margin-bottom: var(--s-5)">
      <p class="muted" style="margin: 0">
        Stuur een bericht naar alle <strong>{{ recipientCount }}</strong> deelnemers
        (iedereen behalve uitgeschreven leden). De mail gaat via dezelfde
        afzender en stijl als de rest.
      </p>
    </div>

    <div class="card stack">
      <div class="field">
        <label for="subject">Onderwerp</label>
        <input id="subject" v-model="subject" type="text" placeholder="bv. De achtste finales zitten erop!" />
      </div>

      <div class="field">
        <label for="heading">Kop in de mail</label>
        <input id="heading" v-model="heading" type="text" placeholder="Leeg = zelfde als onderwerp" />
      </div>

      <div class="field">
        <label for="body">Bericht</label>
        <div class="var-row">
          <span class="var-label">Invoegen:</span>
          <button type="button" class="var-chip" @click="insertVar('{voornaam}')">{voornaam}</button>
          <button type="button" class="var-chip" @click="insertVar('{mijn_stand}')">{mijn_stand}</button>
          <button type="button" class="var-chip" @click="insertVar('{top5}')">{top5}</button>
          <select class="var-select" @change="onRoundInsert($event)">
            <option value="">+ rondepunten…</option>
            <option v-for="n in 8" :key="n" :value="`{mijn_punten_r${n}}`">{mijn_punten_r{{ n }}}</option>
          </select>
        </div>
        <textarea
          id="body"
          ref="bodyRef"
          v-model="body"
          rows="8"
          placeholder="Schrijf hier je bericht. Lege regel = nieuwe alinea, **vet**, *cursief*, [link tekst](https://url). Gebruik {voornaam} voor een persoonlijke aanhef en {top5} om de actuele top 5 in te voegen."
        ></textarea>
        <span class="hint">
          <strong>Opmaak:</strong> enter = nieuwe regel, lege regel = nieuwe alinea,
          <code>**vet**</code>, <code>*cursief*</code>, <code>[tekst](url)</code> voor links.<br>
          <strong>Variabelen:</strong> <code>{voornaam}</code> en <code>{mijn_stand}</code>
          ("op plek X van Y met Z punten") worden per persoon ingevuld.
          <code>{mijn_punten_rX}</code> toont iemands punten in die ronde.
          <code>{top5}</code> voegt de actuele top 5 in (momentopname).
        </span>
      </div>

      <label class="check-row">
        <input type="checkbox" v-model="includeStandings" />
        <span>Knop "Bekijk de volledige stand" onderaan toevoegen</span>
      </label>

      <!-- Preview -->
      <div class="preview-block">
        <div class="preview-label mono">Voorbeeld (met jouw naam als test)</div>
        <div class="preview-card">
          <div class="preview-heading">{{ heading || subject || 'Kop van de mail' }}</div>
          <div class="preview-body" v-html="previewHtml || '<p style=\'color:#9a958a\'>Je bericht verschijnt hier…</p>'"></div>
          <div v-if="includeStandings" class="preview-cta">Bekijk de volledige stand</div>
        </div>
      </div>

      <div v-if="error" class="alert alert-error">{{ error }}</div>
      <div v-if="sentInfo" class="alert alert-success">
        Verstuurd naar {{ sentInfo.count }} deelnemer{{ sentInfo.count === 1 ? '' : 's' }} ✓
        De mails worden binnen een minuut bezorgd.
      </div>

      <button class="btn btn-primary" @click="send" :disabled="sending">
        {{ sending ? 'Versturen…' : `Verstuur naar ${recipientCount} deelnemers` }}
      </button>
    </div>
  </main>
</template>

<style scoped>
.var-row {
  display: flex;
  align-items: center;
  gap: var(--s-2);
  margin-bottom: 6px;
  flex-wrap: wrap;
}
.var-label {
  font-size: 0.75rem;
  color: var(--ink-mute);
  font-family: var(--font-mono);
}
.var-chip {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  padding: 3px 8px;
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  background: var(--bg-elev);
  color: var(--field);
  cursor: pointer;
}
.var-chip:hover { border-color: var(--field); }
.var-select {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  padding: 3px 6px;
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  background: var(--bg-elev);
  color: var(--field);
  cursor: pointer;
}
.check-row {
  display: flex;
  align-items: center;
  gap: var(--s-2);
  font-size: 0.9375rem;
  cursor: pointer;
}
.check-row input { width: auto; }
.preview-block { margin-top: var(--s-2); }
.preview-label {
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--ink-mute);
  margin-bottom: var(--s-2);
}
.preview-card {
  background: #ffffff;
  border: 1px solid var(--line);
  border-radius: var(--r-md);
  padding: var(--s-4) var(--s-5);
}
.preview-heading {
  font-family: Arial, Helvetica, sans-serif;
  font-size: 1.25rem;
  font-weight: bold;
  color: #1f2933;
  margin-bottom: var(--s-3);
}
.preview-body {
  font-family: Arial, Helvetica, sans-serif;
  font-size: 0.9375rem;
  line-height: 1.6;
  color: #1f2933;
}
.preview-body :deep(p) { margin: 0 0 12px; }
.preview-body :deep(table) { width: 100%; }
.preview-cta {
  display: inline-block;
  margin-top: var(--s-3);
  padding: 10px 22px;
  background: #e8590c;
  color: #fff;
  font-family: Arial, Helvetica, sans-serif;
  font-size: 0.9375rem;
  font-weight: bold;
  border-radius: 8px;
}
</style>
