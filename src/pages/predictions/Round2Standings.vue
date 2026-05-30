<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../../lib/supabase.js'
import { useAuthStore } from '../../stores/auth.js'

const auth = useAuthStore()

const round = ref(null)
const teamsByGroup = ref({})
const orders = ref({})              // group_letter -> array of team_ids in order 1-4
const savedStatus = ref({})         // group_letter -> 'ok'|'saving'|'error'|null
const groupResults = ref({})        // group_letter -> {pos1,pos2,pos3,pos4} actual ranking
const groupPoints = ref({})         // group_letter -> definitieve points_awarded
const liveRankings = ref({})        // group_letter -> [team_id, team_id, team_id, team_id] = actuele positie 1-4
const liveStats = ref({})           // group_letter -> { matches_played }
const livePoints = ref({})          // group_letter -> live punten (voorspelling vs huidige stand)
const loading = ref(true)
const error = ref('')
const draggingFrom = ref(null)
const saveTimers = {}
let channel = null

const deadlinePassed = computed(() => {
  if (!round.value?.deadline) return false
  return new Date(round.value.deadline) < new Date()
})

const filledCount = computed(() => {
  return Object.values(orders.value).filter(
    (arr) => arr && arr.length === 4 && !arr.includes(null)
  ).length
})

const totalLivePoints = computed(() => {
  return Object.values(livePoints.value).reduce((sum, n) => sum + (n || 0), 0)
})

async function load() {
  loading.value = true
  error.value = ''

  const [roundRes, teamsRes, predsRes, resultsRes, liveRankRes, liveScoreRes] = await Promise.all([
    supabase.from('rounds').select('*').eq('nr', 2).single(),
    supabase.from('teams').select('*').order('group_letter').order('name'),
    supabase
      .from('group_predictions')
      .select('*')
      .eq('user_id', auth.profile.id),
    supabase.from('group_results').select('*'),
    supabase.from('live_group_rankings').select('*').order('group_letter').order('position'),
    supabase.from('live_r2_scoring').select('*').eq('user_id', auth.profile.id)
  ])

  if (roundRes.error) error.value = roundRes.error.message
  if (teamsRes.error) error.value = teamsRes.error.message
  if (predsRes.error) error.value = predsRes.error.message
  if (resultsRes.error) error.value = resultsRes.error.message

  round.value = roundRes.data

  const grouped = {}
  for (const t of teamsRes.data || []) {
    if (!grouped[t.group_letter]) grouped[t.group_letter] = []
    grouped[t.group_letter].push(t)
  }
  teamsByGroup.value = grouped

  const orderMap = {}
  const statusMap = {}
  const pointsMap = {}
  for (const letter of Object.keys(grouped)) {
    orderMap[letter] = grouped[letter].map((t) => t.id)
    statusMap[letter] = null
    pointsMap[letter] = 0
  }
  for (const p of predsRes.data || []) {
    orderMap[p.group_letter] = [p.pos1_team_id, p.pos2_team_id, p.pos3_team_id, p.pos4_team_id]
    statusMap[p.group_letter] = 'ok'
    pointsMap[p.group_letter] = p.points_awarded || 0
  }
  orders.value = orderMap
  savedStatus.value = statusMap
  groupPoints.value = pointsMap

  const resMap = {}
  for (const r of resultsRes.data || []) {
    resMap[r.group_letter] = [r.pos1_team_id, r.pos2_team_id, r.pos3_team_id, r.pos4_team_id]
  }
  groupResults.value = resMap

  // Live ranking per poule: positie 1-4 op basis van actuele R1 uitslagen
  const liveRankMap = {}
  const liveStatsMap = {}
  for (const row of liveRankRes.data || []) {
    if (!liveRankMap[row.group_letter]) liveRankMap[row.group_letter] = [null, null, null, null]
    liveRankMap[row.group_letter][row.position - 1] = row.team_id
    liveStatsMap[row.group_letter] = { matchesPlayed: row.played }
  }
  liveRankings.value = liveRankMap
  liveStats.value = liveStatsMap

  // Live punten van mijn R2 voorspelling tegen huidige stand
  const liveScoreMap = {}
  for (const row of liveScoreRes.data || []) {
    liveScoreMap[row.group_letter] = row.live_points
  }
  livePoints.value = liveScoreMap

  loading.value = false
}

onMounted(() => {
  load()
  // Realtime: ververs zodra een wedstrijd of voorspelling wijzigt
  channel = supabase
    .channel('r2-live-watch')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'matches' }, () => load())
    .on('postgres_changes', { event: '*', schema: 'public', table: 'group_results' }, () => load())
    .on('postgres_changes', { event: '*', schema: 'public', table: 'group_predictions' }, (payload) => {
      if (payload.new?.user_id === auth.profile?.id || payload.old?.user_id === auth.profile?.id) {
        load()
      }
    })
    .subscribe()
})

onUnmounted(() => {
  if (channel) supabase.removeChannel(channel)
})

function getTeam(letter, idx) {
  const teamId = orders.value[letter]?.[idx]
  if (!teamId) return null
  return teamsByGroup.value[letter]?.find((t) => t.id === teamId)
}

function onDragStart(letter, idx, ev) {
  draggingFrom.value = { letter, idx }
  ev.dataTransfer.effectAllowed = 'move'
}

function onDragOver(ev) {
  ev.preventDefault()
  ev.dataTransfer.dropEffect = 'move'
}

function onDrop(letter, toIdx) {
  if (!draggingFrom.value) return
  if (draggingFrom.value.letter !== letter) {
    draggingFrom.value = null
    return
  }
  const fromIdx = draggingFrom.value.idx
  if (fromIdx === toIdx) {
    draggingFrom.value = null
    return
  }

  const arr = [...orders.value[letter]]
  const [moved] = arr.splice(fromIdx, 1)
  arr.splice(toIdx, 0, moved)
  orders.value[letter] = arr
  draggingFrom.value = null
  scheduleSave(letter)
}

function moveUp(letter, idx) {
  if (idx === 0) return
  const arr = [...orders.value[letter]]
  ;[arr[idx - 1], arr[idx]] = [arr[idx], arr[idx - 1]]
  orders.value[letter] = arr
  scheduleSave(letter)
}

function moveDown(letter, idx) {
  if (idx === 3) return
  const arr = [...orders.value[letter]]
  ;[arr[idx], arr[idx + 1]] = [arr[idx + 1], arr[idx]]
  orders.value[letter] = arr
  scheduleSave(letter)
}

function scheduleSave(letter) {
  savedStatus.value[letter] = 'saving'
  if (saveTimers[letter]) clearTimeout(saveTimers[letter])
  saveTimers[letter] = setTimeout(() => savePrediction(letter), 400)
}

async function savePrediction(letter) {
  const arr = orders.value[letter]
  const { error: err } = await supabase
    .from('group_predictions')
    .upsert(
      {
        user_id: auth.profile.id,
        group_letter: letter,
        pos1_team_id: arr[0],
        pos2_team_id: arr[1],
        pos3_team_id: arr[2],
        pos4_team_id: arr[3]
      },
      { onConflict: 'user_id,group_letter' }
    )
  if (err) {
    savedStatus.value[letter] = 'error'
  } else {
    savedStatus.value[letter] = 'ok'
  }
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

const groupLetters = computed(() => Object.keys(teamsByGroup.value).sort())

function isPositionCorrect(letter, idx) {
  const actual = groupResults.value[letter]
  if (!actual) return null
  return orders.value[letter]?.[idx] === actual[idx]
}

function hasResultFor(letter) {
  return !!groupResults.value[letter]
}

// Live status: of mijn voorspelde team op positie idx OOK op die positie staat
// in de actuele tussenstand. Alleen relevant als poule nog niet definitief is.
function isLivePositionCorrect(letter, idx) {
  if (hasResultFor(letter)) return null  // definitieve uitslag heeft voorrang
  const live = liveRankings.value[letter]
  if (!live) return null
  const predTeam = orders.value[letter]?.[idx]
  if (!predTeam || !live[idx]) return null
  return predTeam === live[idx]
}

function liveMatchesPlayed(letter) {
  return liveStats.value[letter]?.matchesPlayed || 0
}

function liveScoreFor(letter) {
  return livePoints.value[letter] ?? 0
}

function getCardClass(letter) {
  if (!hasResultFor(letter)) return ''
  const pts = groupPoints.value[letter] || 0
  return `scored scored-r2-${pts}`
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Ronde 2 · eindklasseringen</p>
    <h1>Hoe eindigt elke poule?</h1>

    <div class="card" style="margin-bottom: var(--s-5)">
      <div class="row-between">
        <div>
          <strong>{{ filledCount }} / 12</strong>
          <span class="muted"> poules ingevuld</span>
        </div>
        <div class="muted">
          Deadline:
          <span class="mono">{{ fmtDeadline(round?.deadline) }}</span>
        </div>
      </div>
      <p class="muted" style="margin: var(--s-3) 0 0; font-size: 0.9375rem">
        Sleep landen in de juiste eindvolgorde, of gebruik de pijltjes. Per goed
        land op de juiste positie = 1 punt. Automatisch opgeslagen.
      </p>
      <div v-if="totalLivePoints > 0" class="live-total">
        <span class="live-dot"></span>
        Op basis van huidige tussenstand sta je nu op <strong>{{ totalLivePoints }} punten</strong> voor R2.
        Dit kan nog veranderen tot alle 72 poulewedstrijden gespeeld zijn.
      </div>
    </div>

    <div v-if="deadlinePassed" class="alert alert-warn">
      De deadline is verstreken. Voorspellingen zijn vastgezet.
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="muted">Laden…</div>

    <div v-else class="groups-grid">
      <div v-for="letter in groupLetters" :key="letter" class="group-card" :class="getCardClass(letter)">
        <div class="group-header">
          <h3 style="margin: 0">Poule {{ letter }}</h3>
          <span v-if="hasResultFor(letter)" class="points-badge" :class="`points-r2-${groupPoints[letter] || 0}`">
            {{ groupPoints[letter] > 0 ? '+' : '' }}{{ groupPoints[letter] || 0 }} pt
          </span>
          <span v-else-if="liveMatchesPlayed(letter) > 0" class="live-badge" :title="`Tussenstand na ${liveMatchesPlayed(letter)} wedstrijden`">
            <span class="live-dot"></span>
            {{ liveScoreFor(letter) }} pt live
          </span>
          <span v-else class="save-pill" :class="`save-${savedStatus[letter] || 'none'}`">
            {{ {
              ok: '✓ opgeslagen',
              saving: 'opslaan…',
              error: 'fout',
              none: ''
            }[savedStatus[letter] || 'none'] }}
          </span>
        </div>

        <div class="standings">
          <div
            v-for="(_, idx) in [0,1,2,3]"
            :key="idx"
            class="standing-row"
            :class="{
              'pos-correct': isPositionCorrect(letter, idx) === true,
              'pos-wrong':   isPositionCorrect(letter, idx) === false,
              'pos-live-correct': isLivePositionCorrect(letter, idx) === true,
              'pos-live-wrong':   isLivePositionCorrect(letter, idx) === false
            }"
            :draggable="!deadlinePassed && !hasResultFor(letter)"
            @dragstart="onDragStart(letter, idx, $event)"
            @dragover="onDragOver"
            @drop="onDrop(letter, idx)"
          >
            <span class="pos mono">{{ idx + 1 }}</span>
            <img
              v-if="getTeam(letter, idx)"
              :src="getTeam(letter, idx).flag_url"
              :alt="getTeam(letter, idx).name"
              class="flag"
            />
            <span class="team-name">{{ getTeam(letter, idx)?.name }}</span>
            <div class="arrows">
              <button
                class="arrow"
                @click="moveUp(letter, idx)"
                :disabled="idx === 0 || deadlinePassed"
                aria-label="Omhoog"
              >↑</button>
              <button
                class="arrow"
                @click="moveDown(letter, idx)"
                :disabled="idx === 3 || deadlinePassed"
                aria-label="Omlaag"
              >↓</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>

<style scoped>
.groups-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: var(--s-4);
}
.group-card {
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-md);
  padding: var(--s-4);
  border-left: 4px solid var(--line);
  transition: border-left-color 0.2s;
}
.group-card.scored-r2-4 { border-left-color: #2d8045; background: linear-gradient(to right, rgba(45, 128, 69, 0.06), var(--bg-card) 30%); }
.group-card.scored-r2-3 { border-left-color: #4a9963; background: linear-gradient(to right, rgba(74, 153, 99, 0.05), var(--bg-card) 30%); }
.group-card.scored-r2-2 { border-left-color: #c8541d; background: linear-gradient(to right, rgba(200, 84, 29, 0.05), var(--bg-card) 30%); }
.group-card.scored-r2-1 { border-left-color: #d99358; }
.group-card.scored-r2-0 { border-left-color: #b8b8b8; }

.live-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 0.6875rem;
  font-weight: 600;
  font-family: var(--font-mono);
  letter-spacing: 0.03em;
  background: rgba(31, 75, 58, 0.1);
  color: var(--field);
  border: 1px solid rgba(31, 75, 58, 0.2);
}
.live-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: #2d8045;
  animation: live-pulse 1.5s ease-in-out infinite;
}
@keyframes live-pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.8); }
}
.live-total {
  margin-top: var(--s-3);
  padding: var(--s-2) var(--s-3);
  background: rgba(31, 75, 58, 0.06);
  border-left: 3px solid var(--field);
  border-radius: var(--r-sm);
  font-size: 0.875rem;
  display: flex;
  align-items: center;
  gap: var(--s-2);
}
.standing-row.pos-live-correct {
  background: rgba(45, 128, 69, 0.07);
  border-color: rgba(45, 128, 69, 0.2);
}
.standing-row.pos-live-wrong {
  background: rgba(200, 84, 29, 0.04);
}
.points-badge {
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 0.6875rem;
  font-weight: 700;
  font-family: var(--font-mono);
  letter-spacing: 0.05em;
  text-transform: uppercase;
}
.points-badge.points-r2-4 { background: #2d8045; color: white; }
.points-badge.points-r2-3 { background: #4a9963; color: white; }
.points-badge.points-r2-2 { background: #c8541d; color: white; }
.points-badge.points-r2-1 { background: #d99358; color: white; }
.points-badge.points-r2-0 { background: var(--bg-elev); color: var(--ink-mute); }
.standing-row.pos-correct {
  background: rgba(45, 128, 69, 0.1);
  border-color: rgba(45, 128, 69, 0.3);
}
.standing-row.pos-wrong {
  background: rgba(220, 70, 70, 0.04);
  opacity: 0.85;
}
.group-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--s-3);
}
.save-pill {
  font-family: var(--font-mono);
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}
.save-ok { color: var(--ok); }
.save-saving { color: var(--ink-mute); }
.save-error { color: var(--err); }
.standings {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.standing-row {
  display: grid;
  grid-template-columns: 32px 32px 1fr auto;
  align-items: center;
  gap: var(--s-3);
  padding: var(--s-2) var(--s-3);
  background: var(--bg);
  border: 1px solid var(--line-soft);
  border-radius: var(--r-sm);
  cursor: grab;
  transition: background 0.1s;
}
.standing-row:hover { background: var(--bg-elev); }
.standing-row:active { cursor: grabbing; }
.pos {
  font-weight: 700;
  font-size: 1.0625rem;
  color: var(--ink-soft);
  text-align: center;
}
.flag {
  width: 28px;
  height: 19px;
  object-fit: cover;
  border-radius: 2px;
}
.team-name {
  font-weight: 500;
  font-size: 0.9375rem;
}
.arrows {
  display: flex;
  flex-direction: column;
  gap: 1px;
}
.arrow {
  background: transparent;
  border: 1px solid var(--line);
  width: 22px;
  height: 18px;
  font-size: 11px;
  color: var(--ink-soft);
  border-radius: 3px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0;
}
.arrow:hover:not(:disabled) { background: var(--bg-card); border-color: var(--field); color: var(--field); }
.arrow:disabled { opacity: 0.3; cursor: not-allowed; }

/* Mobiel */
@media (max-width: 768px) {
  .groups-grid {
    grid-template-columns: 1fr;
    gap: var(--s-3);
  }
}
@media (max-width: 640px) {
  .standing-row {
    grid-template-columns: 28px 24px 1fr auto;
    gap: var(--s-2);
    padding: 10px var(--s-2);
  }
  .arrow {
    width: 28px;
    height: 22px;
    font-size: 14px;
  }
  .pos { font-size: 1rem; }
  .flag { width: 22px; height: 15px; }
}
</style>
