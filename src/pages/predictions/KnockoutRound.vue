<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { supabase } from '../../lib/supabase.js'
import { useAuthStore } from '../../stores/auth.js'
import { useRoute } from 'vue-router'

const props = defineProps({
  roundNr: { type: Number, required: true },
  roundName: { type: String, required: true }
})

const auth = useAuthStore()
const route = useRoute()

const round = ref(null)
const matches = ref([])
const teams = ref([])
const allPriorMatches = ref([])     // alle matches uit eerdere rondes, voor dep-lookups
const predictions = ref({})       // match_id -> { pred_home, pred_away, score_home, score_away, saved, points_awarded }
const loading = ref(true)
const error = ref('')
const now = ref(new Date())
const saveTimers = {}
let channel = null
let nowTicker = null

// Per-wedstrijd deadline check
// Score-deadline: 1 uur voor kickoff. Bepaalt of score-invulling nog open is.
function isMatchDeadlinePassed(m) {
  if (!m?.kickoff_at) return false
  const oneHourBefore = new Date(new Date(m.kickoff_at).getTime() - 60 * 60 * 1000)
  return oneHourBefore < now.value
}

// Team-deadline: het originele prediction_deadline_at (1u voor eerste dep match).
// Wanneer die is gepasseerd staan land-keuzes vast.
function isTeamDeadlinePassed(m) {
  if (!m?.prediction_deadline_at) return false
  return new Date(m.prediction_deadline_at) < now.value
}

// Teamkeuze locked check.
// Voor R3 staan teamkeuzes vast vanaf 11 juni — alleen scores aanpasbaar.
// Voor R4-R7 volgen team-keuzes hun eigen team-deadline; scores blijven
// open tot 1u voor kickoff.
function isTeamLocked(m) {
  if (props.roundNr === 3) return true
  return isTeamDeadlinePassed(m)
}

const openCount = computed(() => {
  return matches.value.filter((m) => !isMatchDeadlinePassed(m)).length
})

const filledCount = computed(() => {
  return matches.value.filter((m) => {
    const p = predictions.value[m.id]
    if (!p) return false
    const homeOK = isSlotBonus(m.slot_home_type) || p.pred_home
    const awayOK = isSlotBonus(m.slot_away_type) || p.pred_away
    return homeOK && awayOK && p.score_home !== '' && p.score_away !== ''
  }).length
})

const blockedCount = computed(() => {
  return matches.value.filter((m) =>
    isSlotBlocked(m.slot_home_type, m.slot_home_match_dep) ||
    isSlotBlocked(m.slot_away_type, m.slot_away_match_dep)
  ).length
})

async function load(opts = {}) {
  const silent = opts.silent === true
  if (!silent) loading.value = true
  error.value = ''

  try {
    const [roundRes, matchesRes, allMatchesRes, teamsRes, predsRes] = await Promise.all([
      supabase.from('rounds').select('*').eq('nr', props.roundNr).single(),
      supabase
        .from('matches')
        .select(`
          id, match_number, kickoff_at, city, stadium,
          prediction_deadline_at,
          team_home_placeholder, team_away_placeholder,
          slot_home_type, slot_home_groups, slot_home_match_dep,
          slot_away_type, slot_away_groups, slot_away_match_dep,
          team_home_id, team_away_id,
          score_home, score_away, status,
          team_home:teams!matches_team_home_id_fkey(id, name, code, group_letter, flag_url),
          team_away:teams!matches_team_away_id_fkey(id, name, code, group_letter, flag_url)
        `)
        .eq('round_nr', props.roundNr)
        .order('kickoff_at')
        .order('match_number'),
      // Alle matches uit prior rondes voor dep-lookups
      supabase
        .from('matches')
        .select('id, match_number, team_home_id, team_away_id, status, score_home, score_away, slot_home_type, slot_home_groups, slot_away_type, slot_away_groups, team_home_placeholder, team_away_placeholder')
        .lt('round_nr', props.roundNr),
      supabase.from('teams').select('*').order('group_letter').order('name'),
      supabase
        .from('match_predictions')
        .select('match_id, pred_team_home_id, pred_team_away_id, pred_home_via_match, pred_home_via_side, pred_away_via_match, pred_away_via_side, score_home, score_away, points_awarded')
        .eq('user_id', auth.profile.id)
    ])

    if (roundRes.error) console.error(roundRes.error)
    if (matchesRes.error) error.value = matchesRes.error.message
    if (teamsRes.error) error.value = teamsRes.error.message
    if (predsRes.error) error.value = predsRes.error.message

    round.value = roundRes.data
    matches.value = matchesRes.data || []
    teams.value = teamsRes.data || []
    allPriorMatches.value = allMatchesRes.data || []

    const map = {}
    for (const m of matches.value) {
      map[m.id] = {
        pred_home: '',
        pred_away: '',
        score_home: '',
        score_away: '',
        saved: null,
        points_awarded: 0
      }
    }
    for (const p of predsRes.data || []) {
      if (map[p.match_id]) {
        map[p.match_id] = {
          pred_home: buildPredValue(p, 'home'),
          pred_away: buildPredValue(p, 'away'),
          score_home: p.score_home ?? '',
          score_away: p.score_away ?? '',
          saved: 'ok',
          points_awarded: p.points_awarded || 0
        }
      }
    }
    predictions.value = map
  } catch (e) {
    console.error('[KnockoutRound] load error:', e)
    error.value = e.message
  } finally {
    loading.value = false
  }
}

// Reload als roundNr verandert (bv. user navigeert tussen KO rondes)
watch(() => props.roundNr, load)

onMounted(() => {
  load()
  // Tikt elke minuut zodat per-wedstrijd deadlines live verlopen
  nowTicker = setInterval(() => { now.value = new Date() }, 30000)
  // Realtime: ververs bij externe wijzigingen (admin zet uitslag etc.)
  // Eigen voorspelling-events negeren — die heeft de gebruiker zelf
  // net gemaakt, geen reload nodig (en voorkomt scroll-jump).
  channel = supabase
    .channel(`knockout-watch-r${props.roundNr}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'matches' }, () => load({ silent: true }))
    .on('postgres_changes', { event: '*', schema: 'public', table: 'match_predictions' }, (payload) => {
      // Skip eigen voorspellingen — die hebben we zelf net opgeslagen
      const ownEvent = payload.new?.user_id === auth.profile?.id ||
                       payload.old?.user_id === auth.profile?.id
      if (ownEvent) return
      load({ silent: true })
    })
    .subscribe()
})

onUnmounted(() => {
  if (channel) supabase.removeChannel(channel)
  if (nowTicker) clearInterval(nowTicker)
})

function getOptions(slotType, slotGroups, slotMatchDep) {
  // Bonus: geen dropdown, slot wordt anders gerenderd
  if (slotType === 'third_place') return []

  // Match dependency: 2 opties uit voorgaande wedstrijd
  if ((slotType === 'match_winner' || slotType === 'match_loser') && slotMatchDep) {
    const depMatch = allPriorMatches.value.find(m => m.id === slotMatchDep)
    if (!depMatch || !depMatch.team_home_id || !depMatch.team_away_id) return []
    return teams.value.filter(t =>
      t.id === depMatch.team_home_id || t.id === depMatch.team_away_id
    )
  }

  // Group winner/runner: filter op poule
  if ((slotType === 'group_winner' || slotType === 'group_runner') && slotGroups?.length) {
    return teams.value.filter((t) => slotGroups.includes(t.group_letter))
  }

  // Fallback (oude 'open' types die we niet meer gebruiken): alle teams
  return teams.value
}

function getDepMatchNumber(slotMatchDep) {
  if (!slotMatchDep) return null
  const depMatch = allPriorMatches.value.find(m => m.id === slotMatchDep)
  return depMatch?.match_number || null
}

// R3 group slots blijven open zolang ronde-deadline niet verlopen.
// R4-R7 match_winner/loser slots: geblokkeerd als dep-match nog GEEN
// enkele team heeft (vóór groepsfase / vóór vorige KO-ronde).
function isSlotBlocked(slotType, slotMatchDep) {
  if (slotType !== 'match_winner' && slotType !== 'match_loser') return false
  if (!slotMatchDep) return true
  const depMatch = allPriorMatches.value.find(m => m.id === slotMatchDep)
  if (!depMatch) return true
  // Open zodra dep-match minstens 1 team-slot gevuld heeft
  return !depMatch.team_home_id && !depMatch.team_away_id
}

function isSlotBonus(slotType) {
  return slotType === 'third_place'
}

// Label voor placeholder optie: gebruikt bij voorkeur de DB placeholder
// ("Winnaar J", "Nr. 3 Poule C/E/F/H/I", etc.) en valt anders terug op
// het slot-type
function depSlotLabel(depMatch, side) {
  const placeholder = side === 'home' ? depMatch.team_home_placeholder : depMatch.team_away_placeholder
  if (placeholder) return placeholder
  const slotType = side === 'home' ? depMatch.slot_home_type : depMatch.slot_away_type
  const slotGroups = side === 'home' ? depMatch.slot_home_groups : depMatch.slot_away_groups
  if (slotType === 'group_winner' && slotGroups?.length) return `Winnaar ${slotGroups[0]}`
  if (slotType === 'group_runner' && slotGroups?.length) return `Runner-up ${slotGroups[0]}`
  if (slotType === 'third_place') return 'Nr. 3'
  return 'Onbekend'
}

// Opties voor R4-R7 slot: concrete team(s) + placeholders voor lege slots in dep
function getKoSlotOptions(slotMatchDep) {
  if (!slotMatchDep) return []
  const depMatch = allPriorMatches.value.find(m => m.id === slotMatchDep)
  if (!depMatch) return []

  const opts = []

  // Home van dep match
  if (depMatch.team_home_id) {
    const t = teams.value.find(t => t.id === depMatch.team_home_id)
    if (t) opts.push({ value: `team-${t.id}`, label: t.name })
  } else {
    opts.push({
      value: `via-${depMatch.id}-home`,
      label: `${depSlotLabel(depMatch, 'home')} (uit M${depMatch.match_number})`
    })
  }

  // Away van dep match
  if (depMatch.team_away_id) {
    const t = teams.value.find(t => t.id === depMatch.team_away_id)
    if (t) opts.push({ value: `team-${t.id}`, label: t.name })
  } else {
    opts.push({
      value: `via-${depMatch.id}-away`,
      label: `${depSlotLabel(depMatch, 'away')} (uit M${depMatch.match_number})`
    })
  }

  return opts
}

// Build value-string voor v-model uit DB row (per slot)
function buildPredValue(row, side) {
  const teamId = side === 'home' ? row.pred_team_home_id : row.pred_team_away_id
  const viaMatch = side === 'home' ? row.pred_home_via_match : row.pred_away_via_match
  const viaSide = side === 'home' ? row.pred_home_via_side : row.pred_away_via_side
  if (teamId) return `team-${teamId}`
  if (viaMatch && viaSide) return `via-${viaMatch}-${viaSide}`
  return ''
}

// Parse value-string terug naar DB-velden
function parsePredValue(val) {
  if (!val) return { teamId: null, viaMatch: null, viaSide: null }
  if (val.startsWith('team-')) return { teamId: parseInt(val.slice(5)), viaMatch: null, viaSide: null }
  if (val.startsWith('via-')) {
    const parts = val.split('-')  // ['via', matchId, side]
    return { teamId: null, viaMatch: parseInt(parts[1]), viaSide: parts[2] }
  }
  return { teamId: null, viaMatch: null, viaSide: null }
}

function fmtDate(d) {
  return new Date(d).toLocaleString('nl-NL', {
    weekday: 'short',
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit'
  })
}

function fmtDeadline(d) {
  if (!d) return 'nog niet ingesteld'
  return new Date(d).toLocaleString('nl-NL', {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
    hour: '2-digit',
    minute: '2-digit'
  })
}

function onChange(matchId) {
  const m = matches.value.find(x => x.id === matchId)
  const p = predictions.value[matchId]
  if (!m || !p) return

  // Per-wedstrijd deadline verlopen? Niet meer opslaan
  if (isMatchDeadlinePassed(m)) {
    p.saved = null
    return
  }

  // Bonus slots vereisen géén team-voorspelling
  const homeOK = isSlotBonus(m.slot_home_type) || p.pred_home
  const awayOK = isSlotBonus(m.slot_away_type) || p.pred_away

  // Geblokkeerde slots kunnen niet ingevuld worden — sla niet op
  if (isSlotBlocked(m.slot_home_type, m.slot_home_match_dep) ||
      isSlotBlocked(m.slot_away_type, m.slot_away_match_dep)) {
    p.saved = null
    return
  }

  if (!homeOK || !awayOK || p.score_home === '' || p.score_away === '') {
    p.saved = null
    return
  }
  p.saved = 'saving'
  if (saveTimers[matchId]) clearTimeout(saveTimers[matchId])
  saveTimers[matchId] = setTimeout(() => savePrediction(matchId), 400)
}

async function savePrediction(matchId) {
  const m = matches.value.find(x => x.id === matchId)
  const p = predictions.value[matchId]
  if (!m || !p) return

  // Parse pred-strings naar concrete team-ids of via-references
  // Bonus slots blijven volledig null (telt automatisch goed)
  const homeBonus = isSlotBonus(m.slot_home_type)
  const awayBonus = isSlotBonus(m.slot_away_type)
  const homeData = homeBonus ? { teamId: null, viaMatch: null, viaSide: null } : parsePredValue(p.pred_home)
  const awayData = awayBonus ? { teamId: null, viaMatch: null, viaSide: null } : parsePredValue(p.pred_away)

  const { error: err } = await supabase
    .from('match_predictions')
    .upsert(
      {
        user_id: auth.profile.id,
        match_id: matchId,
        pred_team_home_id: homeData.teamId,
        pred_team_away_id: awayData.teamId,
        pred_home_via_match: homeData.viaMatch,
        pred_home_via_side: homeData.viaSide,
        pred_away_via_match: awayData.viaMatch,
        pred_away_via_side: awayData.viaSide,
        score_home: parseInt(p.score_home),
        score_away: parseInt(p.score_away)
      },
      { onConflict: 'user_id,match_id' }
    )
  if (err) {
    p.saved = 'error'
    console.error('[KnockoutRound] save error:', err)
  } else {
    p.saved = 'ok'
  }
}

function getScoreClass(m) {
  if (m.status !== 'finished') return ''
  const p = predictions.value[m.id]
  if (!p?.pred_home) return 'scored scored-none'
  return `scored scored-${p.points_awarded}`
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Ronde {{ roundNr }} · {{ roundName }}</p>
    <h1>Voorspel de {{ roundName.toLowerCase() }}.</h1>

    <div class="card" style="margin-bottom: var(--s-5)">
      <div class="row-between">
        <div>
          <strong>{{ filledCount }} / {{ matches.length }}</strong>
          <span class="muted"> ingevuld</span>
          <span v-if="blockedCount > 0" class="muted"> · {{ blockedCount }} wachten op eerdere uitslagen</span>
        </div>
        <div class="muted">
          <strong>{{ openCount }}</strong> nog open
        </div>
      </div>
      <p class="muted" style="margin: var(--s-3) 0 0; font-size: 0.9375rem">
        Kies twee landen per wedstrijd en voorspel de uitslag (na 90 min).
        Per goed land 5 pt, juiste winnaar 2 pt, exacte uitslag 5 pt extra.
        <strong>Alles goed = 20 pt vlak.</strong>
      </p>
      <p class="muted" style="margin: var(--s-2) 0 0; font-size: 0.8125rem; font-style: italic">
        Elke wedstrijd heeft een eigen deadline — vlak voordat de eerste
        voorgaande wedstrijd start. Vul op tijd in!
      </p>
      <div v-if="roundNr === 3" class="r3-note">
        <strong>⚠️ Schema bijgewerkt naar FIFA-bracket.</strong>
        Je teamkeuzes zijn overgenomen en staan vast sinds 11 juni. Je kunt
        nog wel je <strong>scores aanpassen</strong> tot zondag 28 juni 20:00.
      </div>
      <div v-if="roundNr >= 4" class="r3-note">
        <strong>ℹ️ Landen staan vast, scores nog aanpasbaar.</strong>
        De deadline voor het kiezen van landen is voor deze ronde verlopen —
        die keuzes staan vast. Je kunt wél nog je <strong>scores aanpassen</strong>
        tot 1 uur voor aftrap.
      </div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="muted">Laden…</div>

    <div v-else-if="matches.length === 0" class="muted">
      Nog geen wedstrijden voor deze ronde.
    </div>

    <div v-else class="ko-list">
      <div
        v-for="m in matches"
        :key="m.id"
        class="ko-card"
        :class="getScoreClass(m)"
      >
        <div class="ko-meta">
          <span class="ko-num mono">#{{ m.match_number }}</span>
          <span class="ko-date mono">{{ fmtDate(m.kickoff_at) }}</span>
          <span class="ko-city muted">{{ m.city }}</span>
          <span v-if="m.prediction_deadline_at && !isMatchDeadlinePassed(m)" class="ko-deadline mono">
            sluit: {{ fmtDate(m.prediction_deadline_at) }}
          </span>
          <span v-if="isMatchDeadlinePassed(m) && m.status !== 'finished'" class="ko-closed mono">
            🔒 gesloten
          </span>
          <span v-if="m.status === 'finished' && m.team_home && m.team_away" class="ko-finished mono">
            gespeeld: {{ m.team_home.name }} {{ m.score_home }}–{{ m.score_away }} {{ m.team_away.name }}
          </span>
          <span
            v-if="m.status === 'finished' && predictions[m.id]?.pred_home"
            class="points-badge"
            :class="`points-${predictions[m.id].points_awarded}`"
          >
            {{ predictions[m.id].points_awarded > 0 ? '+' : '' }}{{ predictions[m.id].points_awarded }} pt
          </span>
        </div>

        <div class="ko-pairing">
          <!-- HOME slot -->
          <div class="slot">
            <div class="slot-label mono">{{ m.team_home_placeholder }}</div>

            <!-- Bonus slot: 🎁 cadeau -->
            <div v-if="isSlotBonus(m.slot_home_type)" class="bonus-tile">
              🎁 Bonus — automatisch goed
            </div>

            <!-- Geblokkeerd: dep-match heeft nog geen teams (R4-R7 vroeg) -->
            <div v-else-if="isSlotBlocked(m.slot_home_type, m.slot_home_match_dep)" class="blocked-tile">
              ⏳ Wacht op uitslag groepsfase
            </div>

            <!-- R4-R7: dropdown met concrete teams + placeholders -->
            <select
              v-else-if="m.slot_home_type === 'match_winner' || m.slot_home_type === 'match_loser'"
              v-model="predictions[m.id].pred_home"
              @change="onChange(m.id)"
              :disabled="isTeamLocked(m)"
              class="team-select"
            >
              <option value="">— kies team —</option>
              <option
                v-for="opt in getKoSlotOptions(m.slot_home_match_dep)"
                :key="opt.value"
                :value="opt.value"
              >
                {{ opt.label }}
              </option>
            </select>

            <!-- R3 group-slot: dropdown met 4 teams uit poule -->
            <select
              v-else
              v-model="predictions[m.id].pred_home"
              @change="onChange(m.id)"
              :disabled="isTeamLocked(m)"
              class="team-select"
            >
              <option value="">— kies land —</option>
              <option
                v-for="t in getOptions(m.slot_home_type, m.slot_home_groups, m.slot_home_match_dep)"
                :key="t.id"
                :value="`team-${t.id}`"
              >
                {{ t.name }}<template v-if="t.group_letter"> ({{ t.group_letter }})</template>
              </option>
            </select>
          </div>

          <!-- SCORE -->
          <div class="score-input">
            <input
              type="number"
              min="0"
              max="20"
              v-model="predictions[m.id].score_home"
              @input="onChange(m.id)"
              :disabled="isMatchDeadlinePassed(m) || isSlotBlocked(m.slot_home_type, m.slot_home_match_dep) || isSlotBlocked(m.slot_away_type, m.slot_away_match_dep)"
              class="score-box"
              inputmode="numeric"
              placeholder="?"
            />
            <span class="dash">–</span>
            <input
              type="number"
              min="0"
              max="20"
              v-model="predictions[m.id].score_away"
              @input="onChange(m.id)"
              :disabled="isMatchDeadlinePassed(m) || isSlotBlocked(m.slot_home_type, m.slot_home_match_dep) || isSlotBlocked(m.slot_away_type, m.slot_away_match_dep)"
              class="score-box"
              inputmode="numeric"
              placeholder="?"
            />
          </div>

          <!-- AWAY slot -->
          <div class="slot slot-away">
            <div class="slot-label mono">{{ m.team_away_placeholder }}</div>

            <div v-if="isSlotBonus(m.slot_away_type)" class="bonus-tile">
              🎁 Bonus — automatisch goed
            </div>

            <div v-else-if="isSlotBlocked(m.slot_away_type, m.slot_away_match_dep)" class="blocked-tile">
              ⏳ Wacht op uitslag groepsfase
            </div>

            <!-- R4-R7: dropdown met concrete teams + placeholders -->
            <select
              v-else-if="m.slot_away_type === 'match_winner' || m.slot_away_type === 'match_loser'"
              v-model="predictions[m.id].pred_away"
              @change="onChange(m.id)"
              :disabled="isTeamLocked(m)"
              class="team-select"
            >
              <option value="">— kies team —</option>
              <option
                v-for="opt in getKoSlotOptions(m.slot_away_match_dep)"
                :key="opt.value"
                :value="opt.value"
              >
                {{ opt.label }}
              </option>
            </select>

            <!-- R3 group-slot -->
            <select
              v-else
              v-model="predictions[m.id].pred_away"
              @change="onChange(m.id)"
              :disabled="isTeamLocked(m)"
              class="team-select"
            >
              <option value="">— kies land —</option>
              <option
                v-for="t in getOptions(m.slot_away_type, m.slot_away_groups, m.slot_away_match_dep)"
                :key="t.id"
                :value="`team-${t.id}`"
              >
                {{ t.name }}<template v-if="t.group_letter"> ({{ t.group_letter }})</template>
              </option>
            </select>
          </div>
        </div>

        <div class="save-indicator">
          <span v-if="predictions[m.id].saved === 'ok'" class="save-ok">✓ opgeslagen</span>
          <span v-else-if="predictions[m.id].saved === 'saving'" class="save-saving">opslaan…</span>
          <span v-else-if="predictions[m.id].saved === 'error'" class="save-err">fout bij opslaan</span>
        </div>
      </div>
    </div>
  </main>
</template>

<style scoped>
.ko-list {
  display: flex;
  flex-direction: column;
  gap: var(--s-3);
}
.ko-card {
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-md);
  padding: var(--s-4) var(--s-5);
  border-left: 4px solid var(--line);
  transition: border-left-color 0.2s;
}
.ko-card.scored-20 { border-left-color: #d4a017; background: linear-gradient(to right, rgba(212, 160, 23, 0.10), var(--bg-card) 40%); }
.ko-card.scored-12 { border-left-color: #2d8045; background: linear-gradient(to right, rgba(45, 128, 69, 0.07), var(--bg-card) 40%); }
.ko-card.scored-10 { border-left-color: #4a9963; }
.ko-card.scored-5 { border-left-color: #c8541d; }
.ko-card.scored-0, .ko-card.scored-none { border-left-color: #b8b8b8; opacity: 0.85; }

.ko-meta {
  display: flex;
  align-items: center;
  gap: var(--s-3);
  font-size: 0.8125rem;
  margin-bottom: var(--s-3);
  flex-wrap: wrap;
}
.ko-num { color: var(--ink-mute); font-weight: 600; }
.ko-date { color: var(--ink-soft); font-weight: 500; }
.ko-city { font-size: 0.8125rem; }
.ko-finished {
  background: var(--bg-elev);
  padding: 2px 8px;
  border-radius: var(--r-sm);
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.03em;
  color: var(--ink-soft);
}
.ko-deadline {
  background: rgba(212, 160, 23, 0.12);
  color: #8a6b18;
  padding: 2px 8px;
  border-radius: var(--r-sm);
  font-size: 0.6875rem;
  font-weight: 600;
  border: 1px solid rgba(212, 160, 23, 0.25);
}

.r3-note {
  margin-top: var(--s-3);
  padding: var(--s-3) var(--s-4);
  background: rgba(212, 160, 23, 0.12);
  border-left: 4px solid #d4a017;
  border-radius: var(--r-sm);
  font-size: 0.875rem;
  color: var(--ink);
  line-height: 1.45;
}
.ko-closed {
  background: rgba(120, 120, 120, 0.12);
  color: var(--ink-mute);
  padding: 2px 8px;
  border-radius: var(--r-sm);
  font-size: 0.6875rem;
  font-weight: 600;
}
.points-badge {
  margin-left: auto;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 0.6875rem;
  font-weight: 700;
  font-family: var(--font-mono);
  letter-spacing: 0.05em;
  text-transform: uppercase;
}
.points-badge.points-20 { background: #d4a017; color: white; }
.points-badge.points-12 { background: #2d8045; color: white; }
.points-badge.points-10 { background: #4a9963; color: white; }
.points-badge.points-5 { background: #c8541d; color: white; }
.points-badge.points-0 { background: var(--bg-elev); color: var(--ink-mute); }

.ko-pairing {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  gap: var(--s-3);
  align-items: end;
}
.slot {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.slot-label {
  font-size: 0.6875rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--ink-mute);
}
.slot-away { text-align: right; }
.slot-away .slot-label { text-align: right; }
.team-select {
  padding: 8px 10px;
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  background: var(--bg);
  font-size: 0.9375rem;
  width: 100%;
}
.team-select:focus {
  outline: none;
  border-color: var(--field);
  box-shadow: 0 0 0 3px rgba(31, 75, 58, 0.12);
}
.team-select:disabled { opacity: 0.6; background: var(--bg-elev); }

.bonus-tile {
  padding: 10px 12px;
  border-radius: var(--r-sm);
  background: linear-gradient(135deg, rgba(212, 160, 23, 0.15), rgba(212, 160, 23, 0.05));
  border: 1px dashed #d4a017;
  color: var(--ink);
  font-size: 0.875rem;
  font-weight: 500;
  text-align: center;
}
.blocked-tile {
  padding: 10px 12px;
  border-radius: var(--r-sm);
  background: var(--bg-elev);
  border: 1px dashed var(--line);
  color: var(--ink-mute);
  font-size: 0.8125rem;
  font-style: italic;
  text-align: center;
}
.score-input {
  display: flex;
  align-items: center;
  gap: 6px;
  align-self: end;
  padding-bottom: 2px;
}
.score-box {
  width: 44px;
  height: 40px;
  text-align: center;
  font-size: 1.0625rem;
  font-weight: 600;
  font-family: var(--font-mono);
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  background: var(--bg);
}
.score-box:focus {
  outline: none;
  border-color: var(--field);
  box-shadow: 0 0 0 3px rgba(31, 75, 58, 0.15);
}
.score-box:disabled { opacity: 0.6; background: var(--bg-elev); }
.dash { color: var(--ink-mute); font-weight: 600; }
.save-indicator {
  margin-top: var(--s-2);
  font-size: 0.75rem;
  font-family: var(--font-mono);
  text-align: right;
  min-height: 1.1em;
}
.save-ok { color: var(--ok); }
.save-saving { color: var(--ink-mute); }
.save-err { color: var(--err); }

@media (max-width: 720px) {
  .ko-card { padding: var(--s-3) var(--s-4); }
  /* Dropdowns met lange landnamen blijven leesbaar = gestapeld, maar nette
     volgorde: thuis → uitslag (gecentreerd) → uit. */
  .ko-pairing {
    grid-template-columns: 1fr;
    gap: var(--s-3);
  }
  .slot-away { text-align: left; }
  .slot-away .slot-label { text-align: left; }
  .score-input {
    justify-content: center;
    padding: var(--s-2) 0;
    align-self: center;
  }
  .ko-meta { gap: var(--s-2); font-size: 0.75rem; }
  .team-select { font-size: 1rem; }   /* 16px voorkomt inzoomen op iOS */
}
</style>
