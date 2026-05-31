<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../../lib/supabase.js'
import { useAuthStore } from '../../stores/auth.js'

const auth = useAuthStore()

const round = ref(null)
const matches = ref([])
const predictions = ref({})        // match_id -> { score_home, score_away, saved }
const loading = ref(true)
const error = ref('')
const filterGroup = ref('all')
const saveTimers = {}

const deadlinePassed = computed(() => {
  if (!round.value?.deadline) return false
  return new Date(round.value.deadline) < new Date()
})

const filteredMatches = computed(() => {
  if (filterGroup.value === 'all') return matches.value
  return matches.value.filter((m) => m.team_home.group_letter === filterGroup.value)
})

const filledCount = computed(() => {
  return matches.value.filter((m) => {
    const p = predictions.value[m.id]
    return p && p.score_home !== '' && p.score_away !== ''
  }).length
})

async function load() {
  loading.value = true
  error.value = ''

  const [roundRes, matchesRes, predsRes] = await Promise.all([
    supabase.from('rounds').select('*').eq('nr', 1).single(),
    supabase
      .from('matches')
      .select(`
        id, match_number, kickoff_at, city, stadium,
        score_home, score_away, status,
        team_home:teams!matches_team_home_id_fkey(id, name, code, group_letter, flag_url),
        team_away:teams!matches_team_away_id_fkey(id, name, code, group_letter, flag_url)
      `)
      .eq('round_nr', 1)
      .order('kickoff_at')
      .order('match_number'),
    supabase
      .from('match_predictions')
      .select('*')
      .eq('user_id', auth.profile.id)
  ])

  if (roundRes.error) error.value = roundRes.error.message
  if (matchesRes.error) error.value = matchesRes.error.message
  if (predsRes.error) error.value = predsRes.error.message

  round.value = roundRes.data
  matches.value = matchesRes.data || []

  const map = {}
  for (const m of matches.value) {
    map[m.id] = { score_home: '', score_away: '', saved: null, points_awarded: 0 }
  }
  for (const p of predsRes.data || []) {
    if (map[p.match_id]) {
      map[p.match_id] = {
        score_home: p.score_home,
        score_away: p.score_away,
        saved: 'ok',
        points_awarded: p.points_awarded || 0
      }
    }
  }
  predictions.value = map

  loading.value = false
}

onMounted(load)

function fmtDate(d) {
  const dt = new Date(d)
  return dt.toLocaleString('nl-NL', {
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

function onScoreChange(matchId) {
  const p = predictions.value[matchId]
  if (p.score_home === '' || p.score_away === '') {
    p.saved = null
    return
  }

  if (parseInt(p.score_home) < 0 || parseInt(p.score_away) < 0) {
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
        score_home: parseInt(p.score_home),
        score_away: parseInt(p.score_away)
      },
      { onConflict: 'user_id,match_id' }
    )
  if (err) {
    p.saved = 'error'
    p.saveError = err.message
  } else {
    p.saved = 'ok'
  }
}

const groupLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L']

function hasPredictionFor(m) {
  const p = predictions.value[m.id]
  return p && p.score_home !== '' && p.score_away !== '' && p.score_home !== null
}

function getScoreClass(m) {
  if (m.status !== 'finished') return ''
  if (!hasPredictionFor(m)) return 'scored scored-none'
  const pts = predictions.value[m.id]?.points_awarded || 0
  return `scored scored-${pts}`
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Ronde 1 · poulewedstrijden</p>
    <h1>Voorspel alle 72 wedstrijden.</h1>

    <div class="round-info card" style="margin-bottom: var(--s-5)">
      <div class="row-between">
        <div>
          <strong>{{ filledCount }} / {{ matches.length }}</strong>
          <span class="muted"> ingevuld</span>
        </div>
        <div class="muted">
          Deadline:
          <span class="mono">{{ fmtDeadline(round?.deadline) }}</span>
        </div>
      </div>
      <p class="muted" style="margin: var(--s-3) 0 0; font-size: 0.9375rem">
        Winnend land = 2 punten · Exacte uitslag = 5 punten. Je voorspellingen
        worden automatisch opgeslagen tijdens het typen.
      </p>
    </div>

    <div v-if="deadlinePassed" class="alert alert-warn">
      De deadline is verstreken. Voorspellingen zijn vastgezet.
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="muted">Laden…</div>

    <template v-else>
      <div class="filter-row">
        <button
          class="filter-pill"
          :class="{ active: filterGroup === 'all' }"
          @click="filterGroup = 'all'"
        >Alle poules</button>
        <button
          v-for="g in groupLetters"
          :key="g"
          class="filter-pill"
          :class="{ active: filterGroup === g }"
          @click="filterGroup = g"
        >{{ g }}</button>
      </div>

      <div class="matches-list">
        <div
          v-for="m in filteredMatches"
          :key="m.id"
          class="match-card"
          :class="getScoreClass(m)"
        >
          <div class="match-meta">
            <span class="match-num mono">#{{ m.match_number }}</span>
            <span class="match-group">Poule {{ m.team_home.group_letter }}</span>
            <span class="match-date mono">{{ fmtDate(m.kickoff_at) }}</span>
            <span class="match-city muted">{{ m.city }}</span>
            <span v-if="m.status === 'finished'" class="match-finished mono">
              gespeeld: {{ m.score_home }}–{{ m.score_away }}
            </span>
            <span
              v-if="m.status === 'finished' && hasPredictionFor(m)"
              class="points-badge"
              :class="`points-${predictions[m.id].points_awarded}`"
            >
              {{ predictions[m.id].points_awarded > 0 ? '+' : '' }}{{ predictions[m.id].points_awarded }} pt
            </span>
          </div>

          <div class="match-teams">
            <div class="team team-home">
              <img :src="m.team_home.flag_url" :alt="m.team_home.name" class="flag" />
              <span class="team-name">{{ m.team_home.name }}</span>
            </div>

            <div class="score-input">
              <input
                type="number"
                min="0"
                max="20"
                v-model="predictions[m.id].score_home"
                @input="onScoreChange(m.id)"
                :disabled="deadlinePassed"
                class="score-box"
                inputmode="numeric"
              />
              <span class="dash">–</span>
              <input
                type="number"
                min="0"
                max="20"
                v-model="predictions[m.id].score_away"
                @input="onScoreChange(m.id)"
                :disabled="deadlinePassed"
                class="score-box"
                inputmode="numeric"
              />
            </div>

            <div class="team team-away">
              <span class="team-name">{{ m.team_away.name }}</span>
              <img :src="m.team_away.flag_url" :alt="m.team_away.name" class="flag" />
            </div>
          </div>

          <div class="save-indicator">
            <span v-if="predictions[m.id].saved === 'ok'" class="save-ok">✓ opgeslagen</span>
            <span v-else-if="predictions[m.id].saved === 'saving'" class="save-saving">opslaan…</span>
            <span v-else-if="predictions[m.id].saved === 'error'" class="save-err">
              fout: {{ predictions[m.id].saveError }}
            </span>
          </div>
        </div>
      </div>
    </template>
  </main>
</template>

<style scoped>
.filter-row {
  display: flex;
  gap: 6px;
  flex-wrap: wrap;
  margin-bottom: var(--s-5);
}
.filter-pill {
  padding: 6px 12px;
  border-radius: var(--r-sm);
  border: 1px solid var(--line);
  background: var(--bg-card);
  font-family: var(--font-mono);
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--ink-soft);
  transition: all 0.15s;
}
.filter-pill:hover { background: var(--bg-elev); }
.filter-pill.active {
  background: var(--field);
  color: var(--bg-card);
  border-color: var(--field);
}
.matches-list {
  display: flex;
  flex-direction: column;
  gap: var(--s-3);
}
.match-card {
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-md);
  padding: var(--s-4) var(--s-5);
  border-left: 4px solid var(--line);
  transition: border-left-color 0.2s;
}
.match-card.scored-5 {
  border-left-color: #2d8045;
  background: linear-gradient(to right, rgba(45, 128, 69, 0.06), var(--bg-card) 40%);
}
.match-card.scored-2 {
  border-left-color: #c8541d;
  background: linear-gradient(to right, rgba(200, 84, 29, 0.06), var(--bg-card) 40%);
}
.match-card.scored-0 {
  border-left-color: #b8b8b8;
}
.match-card.scored-none {
  border-left-color: var(--line);
  opacity: 0.7;
}
.match-finished {
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
.points-badge.points-5 {
  background: #2d8045;
  color: white;
}
.points-badge.points-2 {
  background: #c8541d;
  color: white;
}
.points-badge.points-0 {
  background: var(--bg-elev);
  color: var(--ink-mute);
}
.match-meta {
  display: flex;
  align-items: center;
  gap: var(--s-3);
  font-size: 0.8125rem;
  margin-bottom: var(--s-3);
  flex-wrap: wrap;
}
.match-num {
  color: var(--ink-mute);
  font-weight: 600;
}
.match-group {
  background: var(--bg-elev);
  padding: 2px 8px;
  border-radius: var(--r-sm);
  font-family: var(--font-mono);
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--ink-soft);
}
.match-date { color: var(--ink-soft); font-weight: 500; }
.match-city { font-size: 0.8125rem; }
.match-teams {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  align-items: center;
  gap: var(--s-3);
}
.team {
  display: flex;
  align-items: center;
  gap: var(--s-3);
  font-weight: 500;
}
.team-home { justify-content: flex-end; text-align: right; }
.team-away { justify-content: flex-start; text-align: left; }
.team-name { font-size: 1.0625rem; }
.flag {
  width: 36px;
  height: 24px;
  object-fit: cover;
  border-radius: 3px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.1);
  flex-shrink: 0;
}
.score-input {
  display: flex;
  align-items: center;
  gap: 6px;
}
.score-box {
  width: 48px;
  height: 44px;
  text-align: center;
  font-size: 1.25rem;
  font-weight: 600;
  font-family: var(--font-mono);
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  background: var(--bg);
  transition: border-color 0.15s, box-shadow 0.15s;
}
.score-box:focus {
  outline: none;
  border-color: var(--field);
  box-shadow: 0 0 0 3px rgba(31, 75, 58, 0.15);
}
.score-box:disabled { opacity: 0.6; background: var(--bg-elev); }
.dash { color: var(--ink-mute); font-weight: 600; }
.save-indicator {
  margin-top: 6px;
  font-size: 0.75rem;
  font-family: var(--font-mono);
  text-align: right;
  min-height: 1.1em;
}
.save-ok { color: var(--ok); }
.save-saving { color: var(--ink-mute); }
.save-err { color: var(--err); }

@media (max-width: 640px) {
  .match-card { padding: var(--s-3); }
  /* Compact naast elkaar houden: land — uitslag — land blijft op één rij */
  .match-teams {
    grid-template-columns: 1fr auto 1fr;
    gap: var(--s-2);
    align-items: center;
  }
  .team { gap: 6px; min-width: 0; }            /* min-width:0 laat de naam inkorten */
  .team-home { justify-content: flex-end; text-align: right; }
  .team-away { justify-content: flex-start; text-align: left; }
  .team-name {
    font-size: 0.8125rem;
    line-height: 1.15;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    min-width: 0;
  }
  .flag { width: 24px; height: 16px; }
  .score-input { gap: 3px; }
  .score-box { width: 38px; height: 40px; font-size: 1.05rem; }
  .dash { font-size: 0.8125rem; }
  .match-meta { gap: var(--s-2); font-size: 0.75rem; }
}

/* Heel smal (oude/kleine telefoons): vlag boven de naam, nog steeds 3 koloms */
@media (max-width: 380px) {
  .team { flex-direction: column; gap: 3px; }
  .team-home, .team-away { text-align: center; justify-content: center; }
  .team-name { font-size: 0.75rem; white-space: normal; }
  .flag { width: 26px; height: 17px; }
}
</style>
