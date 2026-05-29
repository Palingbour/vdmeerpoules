<script setup>
import { ref, computed, onMounted, watch } from 'vue'
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
const saveTimers = {}

const deadlinePassed = computed(() => {
  if (!round.value?.deadline) return false
  return new Date(round.value.deadline) < new Date()
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

async function load() {
  loading.value = true
  error.value = ''

  try {
    const [roundRes, matchesRes, allMatchesRes, teamsRes, predsRes] = await Promise.all([
      supabase.from('rounds').select('*').eq('nr', props.roundNr).single(),
      supabase
        .from('matches')
        .select(`
          id, match_number, kickoff_at, city, stadium,
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
        .select('id, match_number, team_home_id, team_away_id, status, score_home, score_away')
        .lt('round_nr', props.roundNr),
      supabase.from('teams').select('*').order('group_letter').order('name'),
      supabase
        .from('match_predictions')
        .select('*')
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
        pred_home: null,
        pred_away: null,
        score_home: '',
        score_away: '',
        saved: null,
        points_awarded: 0
      }
    }
    for (const p of predsRes.data || []) {
      if (map[p.match_id]) {
        map[p.match_id] = {
          pred_home: p.pred_team_home_id,
          pred_away: p.pred_team_away_id,
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

onMounted(load)

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

function isSlotBlocked(slotType, slotMatchDep) {
  if (slotType !== 'match_winner' && slotType !== 'match_loser') return false
  if (!slotMatchDep) return true
  const depMatch = allPriorMatches.value.find(m => m.id === slotMatchDep)
  return !depMatch || !depMatch.team_home_id || !depMatch.team_away_id
}

function isSlotBonus(slotType) {
  return slotType === 'third_place'
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
  const p = predictions.value[matchId]
  const { error: err } = await supabase
    .from('match_predictions')
    .upsert(
      {
        user_id: auth.profile.id,
        match_id: matchId,
        pred_team_home_id: p.pred_home,
        pred_team_away_id: p.pred_away,
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
          Deadline: <span class="mono">{{ fmtDeadline(round?.deadline) }}</span>
        </div>
      </div>
      <p class="muted" style="margin: var(--s-3) 0 0; font-size: 0.9375rem">
        Kies twee landen per wedstrijd en voorspel de uitslag (na 90 min).
        Per goed land 5 pt, juiste winnaar 2 pt, exacte uitslag 5 pt extra.
        <strong>Alles goed = 20 pt vlak.</strong>
      </p>
    </div>

    <div v-if="deadlinePassed" class="alert alert-warn">
      De deadline is verstreken. Voorspellingen zijn vastgezet.
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

            <!-- Geblokkeerd: wacht op vorige wedstrijd -->
            <div v-else-if="isSlotBlocked(m.slot_home_type, m.slot_home_match_dep)" class="blocked-tile">
              ⏳ Wacht op uitslag wedstrijd #{{ getDepMatchNumber(m.slot_home_match_dep) }}
            </div>

            <!-- Normaal: dropdown -->
            <select
              v-else
              v-model="predictions[m.id].pred_home"
              @change="onChange(m.id)"
              :disabled="deadlinePassed"
              class="team-select"
            >
              <option :value="null">— kies land —</option>
              <option
                v-for="t in getOptions(m.slot_home_type, m.slot_home_groups, m.slot_home_match_dep)"
                :key="t.id"
                :value="t.id"
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
              :disabled="deadlinePassed || isSlotBlocked(m.slot_home_type, m.slot_home_match_dep) || isSlotBlocked(m.slot_away_type, m.slot_away_match_dep)"
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
              :disabled="deadlinePassed || isSlotBlocked(m.slot_home_type, m.slot_home_match_dep) || isSlotBlocked(m.slot_away_type, m.slot_away_match_dep)"
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
              ⏳ Wacht op uitslag wedstrijd #{{ getDepMatchNumber(m.slot_away_match_dep) }}
            </div>

            <select
              v-else
              v-model="predictions[m.id].pred_away"
              @change="onChange(m.id)"
              :disabled="deadlinePassed"
              class="team-select"
            >
              <option :value="null">— kies land —</option>
              <option
                v-for="t in getOptions(m.slot_away_type, m.slot_away_groups, m.slot_away_match_dep)"
                :key="t.id"
                :value="t.id"
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
  .ko-pairing { grid-template-columns: 1fr; gap: var(--s-2); }
  .slot-away { text-align: left; }
  .slot-away .slot-label { text-align: left; }
  .score-input { justify-content: center; padding: var(--s-2) 0; }
}
</style>
