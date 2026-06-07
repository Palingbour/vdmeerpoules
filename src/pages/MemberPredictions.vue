<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase.js'
import { useAuthStore } from '../stores/auth.js'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const userId = computed(() => route.params.userId)
const isMe = computed(() => userId.value === auth.profile?.id)

const profile = ref(null)
const standing = ref(null)
const matches = ref([])
const teams = ref([])
const matchPreds = ref({})    // match_id -> { pred_team_home_id, pred_team_away_id, score_home, score_away, points_awarded, pred_home_via_match, pred_home_via_side, ... }
const groupPreds = ref({})    // group_letter -> { pos1, pos2, pos3, pos4, points_awarded }
const bonusQuestions = ref([])
const bonusPreds = ref({})    // question_id -> { answer, points_awarded }
const rounds = ref({})        // round_nr -> rounds row
const loading = ref(true)
const error = ref('')
const now = ref(new Date())
let ticker = null

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [profRes, standRes, roundsRes, matchesRes, teamsRes, mpRes, gpRes, bqRes, bpRes] = await Promise.all([
      supabase.from('profiles').select('id, full_name, role, status').eq('id', userId.value).maybeSingle(),
      supabase.from('standings_overview').select('*').eq('id', userId.value).maybeSingle(),
      supabase.from('rounds').select('*').order('nr'),
      supabase.from('matches').select(`
        id, match_number, round_nr, kickoff_at, prediction_deadline_at,
        team_home_id, team_away_id,
        team_home_placeholder, team_away_placeholder,
        slot_home_type, slot_home_groups, slot_home_match_dep,
        slot_away_type, slot_away_groups, slot_away_match_dep,
        score_home, score_away, status,
        team_home:teams!matches_team_home_id_fkey(id, name, code, flag_url, group_letter),
        team_away:teams!matches_team_away_id_fkey(id, name, code, flag_url, group_letter)
      `).order('round_nr').order('kickoff_at').order('match_number'),
      supabase.from('teams').select('id, name, code, flag_url, group_letter').order('group_letter').order('name'),
      supabase.from('match_predictions').select('*').eq('user_id', userId.value),
      supabase.from('group_predictions').select('*').eq('user_id', userId.value),
      supabase.from('bonus_questions').select('*').order('display_order'),
      supabase.from('bonus_predictions').select('*').eq('user_id', userId.value)
    ])

    if (profRes.error) error.value = profRes.error.message
    profile.value = profRes.data
    standing.value = standRes.data

    const roundsMap = {}
    for (const r of roundsRes.data || []) roundsMap[r.nr] = r
    rounds.value = roundsMap

    matches.value = matchesRes.data || []
    teams.value = teamsRes.data || []
    bonusQuestions.value = bqRes.data || []

    const mpMap = {}
    for (const p of mpRes.data || []) mpMap[p.match_id] = p
    matchPreds.value = mpMap

    const gpMap = {}
    for (const p of gpRes.data || []) gpMap[p.group_letter] = p
    groupPreds.value = gpMap

    const bpMap = {}
    for (const p of bpRes.data || []) bpMap[p.question_id] = p
    bonusPreds.value = bpMap
  } catch (e) {
    console.error('[MemberPredictions] load error:', e)
    error.value = e.message || 'Er ging iets mis bij het laden.'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  load()
  ticker = setInterval(() => { now.value = new Date() }, 30000)
})

watch(userId, load)

// Per-match helpers
function teamById(id) {
  return teams.value.find(t => t.id === id)
}

function teamName(id) {
  return teamById(id)?.name || '?'
}

function isMatchDeadlinePassed(m) {
  if (!m?.prediction_deadline_at) return false
  return new Date(m.prediction_deadline_at) < now.value
}

// Resolve voorspelling-team voor een R4-R7 slot, rekening houdend met
// placeholder verwijzingen (pred_*_via_match + side)
function resolvePredTeam(pred, side) {
  if (!pred) return null
  const teamId = side === 'home' ? pred.pred_team_home_id : pred.pred_team_away_id
  if (teamId) return { type: 'team', team: teamById(teamId) }
  const viaMatch = side === 'home' ? pred.pred_home_via_match : pred.pred_away_via_match
  const viaSide = side === 'home' ? pred.pred_home_via_side : pred.pred_away_via_side
  if (viaMatch && viaSide) {
    const depMatch = matches.value.find(m => m.id === viaMatch)
    if (depMatch) {
      const label = depSlotLabel(depMatch, viaSide)
      return { type: 'placeholder', label: `${label} (uit M${depMatch.match_number})` }
    }
  }
  return null
}

function depSlotLabel(depMatch, side) {
  const slotType = side === 'home' ? depMatch.slot_home_type : depMatch.slot_away_type
  const slotGroups = side === 'home' ? depMatch.slot_home_groups : depMatch.slot_away_groups
  if (slotType === 'group_winner' && slotGroups?.length) return `Winnaar ${slotGroups[0]}`
  if (slotType === 'group_runner' && slotGroups?.length) return `Runner-up ${slotGroups[0]}`
  if (slotType === 'third_place') return 'Beste 3'
  return (side === 'home' ? depMatch.team_home_placeholder : depMatch.team_away_placeholder) || 'Onbekend'
}

// Computed per ronde
const r1Matches = computed(() => matches.value.filter(m => m.round_nr === 1))
const r3Matches = computed(() => matches.value.filter(m => m.round_nr === 3))
const r4Matches = computed(() => matches.value.filter(m => m.round_nr === 4))
const r5Matches = computed(() => matches.value.filter(m => m.round_nr === 5))
const r6Matches = computed(() => matches.value.filter(m => m.round_nr === 6))
const r7Matches = computed(() => matches.value.filter(m => m.round_nr === 7))

const r2Visible = computed(() => {
  // R2: voorspellingen zichtbaar voor zelf altijd, voor anderen na R2 deadline
  if (isMe.value) return true
  const r2 = rounds.value[2]
  if (!r2?.deadline) return false
  return new Date(r2.deadline) < now.value
})

const r8Visible = computed(() => {
  if (isMe.value) return true
  const r8 = rounds.value[8]
  if (!r8?.deadline) return false
  return new Date(r8.deadline) < now.value
})

const teamsByGroup = computed(() => {
  const map = {}
  for (const t of teams.value) {
    if (!map[t.group_letter]) map[t.group_letter] = []
    map[t.group_letter].push(t)
  }
  return map
})

function fmtDate(d) {
  return new Date(d).toLocaleString('nl-NL', {
    weekday: 'short', day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit'
  })
}

function goBack() {
  router.push('/stand')
}
</script>

<template>
  <main class="page">
    <button class="back-link" @click="goBack">← Terug naar de stand</button>

    <div v-if="loading" class="muted">Laden…</div>
    <div v-else-if="error" class="alert alert-error">{{ error }}</div>
    <div v-else-if="!profile" class="alert alert-warn">Speler niet gevonden.</div>

    <template v-else>
      <p class="eyebrow">Voorspellingen van</p>
      <h1>{{ profile.full_name }}<span v-if="isMe" class="me-tag"> (jij)</span></h1>

      <!-- Stand-samenvatting -->
      <div v-if="standing" class="stand-card">
        <div>
          <span class="muted">Plek</span>
          <strong class="mono"> {{ standing.rank }}</strong>
        </div>
        <div class="divider"></div>
        <div>
          <span class="muted">Totaal</span>
          <strong class="mono"> {{ standing.total_points }} pt</strong>
        </div>
      </div>

      <!-- R1 — Poulewedstrijden -->
      <section class="round-section">
        <h2>R1 · Poulewedstrijden</h2>
        <p v-if="!isMe && rounds[1]?.deadline && new Date(rounds[1].deadline) >= now" class="muted small">
          🔒 Voorspellingen worden zichtbaar na de deadline ({{ fmtDate(rounds[1].deadline) }}).
        </p>
        <div v-else class="match-grid">
          <div v-for="m in r1Matches" :key="m.id" class="match-row">
            <span class="m-num mono">M{{ m.match_number }}</span>
            <span class="m-teams">
              {{ m.team_home?.name }}
              <span class="m-pred mono">
                <template v-if="matchPreds[m.id] && matchPreds[m.id].score_home !== null">
                  {{ matchPreds[m.id].score_home }}–{{ matchPreds[m.id].score_away }}
                </template>
                <span v-else class="muted">—</span>
              </span>
              {{ m.team_away?.name }}
            </span>
            <span v-if="m.status === 'finished'" class="m-actual muted mono">
              ({{ m.score_home }}–{{ m.score_away }})
            </span>
            <span v-if="m.status === 'finished' && matchPreds[m.id]" class="m-points mono"
                  :class="`pts-${matchPreds[m.id].points_awarded}`">
              {{ matchPreds[m.id].points_awarded > 0 ? '+' : '' }}{{ matchPreds[m.id].points_awarded || 0 }}
            </span>
          </div>
        </div>
      </section>

      <!-- R2 — Eindstanden poules -->
      <section class="round-section">
        <h2>R2 · Eindstanden poules</h2>
        <p v-if="!r2Visible" class="muted small">
          🔒 Zichtbaar na de deadline ({{ rounds[2]?.deadline ? fmtDate(rounds[2].deadline) : '?' }}).
        </p>
        <div v-else class="poule-grid">
          <div v-for="letter in Object.keys(teamsByGroup).sort()" :key="letter" class="poule-card">
            <div class="poule-header mono">Poule {{ letter }}</div>
            <ol v-if="groupPreds[letter]" class="poule-list">
              <li>{{ teamName(groupPreds[letter].pos1_team_id) }}</li>
              <li>{{ teamName(groupPreds[letter].pos2_team_id) }}</li>
              <li>{{ teamName(groupPreds[letter].pos3_team_id) }}</li>
              <li>{{ teamName(groupPreds[letter].pos4_team_id) }}</li>
            </ol>
            <p v-else class="muted small">geen voorspelling</p>
            <div v-if="groupPreds[letter]?.points_awarded" class="poule-points mono">
              {{ groupPreds[letter].points_awarded }} pt
            </div>
          </div>
        </div>
      </section>

      <!-- R3-R7 — KO rondes -->
      <section v-for="rn in [3, 4, 5, 6, 7]" :key="rn" class="round-section">
        <h2>
          R{{ rn }} ·
          <template v-if="rn === 3">16e finales</template>
          <template v-else-if="rn === 4">8e finales</template>
          <template v-else-if="rn === 5">Kwartfinales</template>
          <template v-else-if="rn === 6">Halve finales</template>
          <template v-else-if="rn === 7">Troostfinale &amp; Finale</template>
        </h2>
        <div class="match-grid">
          <div
            v-for="m in matches.filter(x => x.round_nr === rn)"
            :key="m.id"
            class="match-row"
          >
            <span class="m-num mono">M{{ m.match_number }}</span>

            <!-- Voor anderen: alleen tonen als deadline verstreken -->
            <template v-if="!isMe && !isMatchDeadlinePassed(m)">
              <span class="muted small">🔒 deadline nog open</span>
            </template>

            <template v-else>
              <span class="m-teams">
                <!-- Home -->
                <template v-if="resolvePredTeam(matchPreds[m.id], 'home')">
                  <template v-if="resolvePredTeam(matchPreds[m.id], 'home').type === 'team'">
                    {{ resolvePredTeam(matchPreds[m.id], 'home').team?.name }}
                  </template>
                  <em v-else class="placeholder-pred">
                    {{ resolvePredTeam(matchPreds[m.id], 'home').label }}
                  </em>
                </template>
                <span v-else class="muted">—</span>

                <span class="m-pred mono">
                  <template v-if="matchPreds[m.id] && matchPreds[m.id].score_home !== null">
                    {{ matchPreds[m.id].score_home }}–{{ matchPreds[m.id].score_away }}
                  </template>
                  <span v-else class="muted">vs</span>
                </span>

                <!-- Away -->
                <template v-if="resolvePredTeam(matchPreds[m.id], 'away')">
                  <template v-if="resolvePredTeam(matchPreds[m.id], 'away').type === 'team'">
                    {{ resolvePredTeam(matchPreds[m.id], 'away').team?.name }}
                  </template>
                  <em v-else class="placeholder-pred">
                    {{ resolvePredTeam(matchPreds[m.id], 'away').label }}
                  </em>
                </template>
                <span v-else class="muted">—</span>
              </span>

              <span v-if="m.status === 'finished'" class="m-actual muted mono">
                ({{ m.team_home?.name }} {{ m.score_home }}–{{ m.score_away }} {{ m.team_away?.name }})
              </span>
              <span v-if="m.status === 'finished' && matchPreds[m.id]" class="m-points mono"
                    :class="`pts-${matchPreds[m.id].points_awarded}`">
                {{ matchPreds[m.id].points_awarded > 0 ? '+' : '' }}{{ matchPreds[m.id].points_awarded || 0 }}
              </span>
            </template>
          </div>
        </div>
      </section>

      <!-- R8 — Bonusvragen -->
      <section class="round-section">
        <h2>R8 · Bonusvragen</h2>
        <p v-if="!r8Visible" class="muted small">
          🔒 Zichtbaar na de deadline ({{ rounds[8]?.deadline ? fmtDate(rounds[8].deadline) : '?' }}).
        </p>
        <div v-else class="bonus-list">
          <div v-for="q in bonusQuestions" :key="q.id" class="bonus-row">
            <div class="bonus-q">{{ q.question }}</div>
            <div class="bonus-a mono">
              <template v-if="bonusPreds[q.id]?.answer">
                {{ bonusPreds[q.id].answer }}
              </template>
              <span v-else class="muted">—</span>
            </div>
            <div v-if="bonusPreds[q.id]?.points_awarded" class="bonus-pts mono">
              {{ bonusPreds[q.id].points_awarded }} pt
            </div>
          </div>
        </div>
      </section>
    </template>
  </main>
</template>

<style scoped>
.back-link {
  background: none;
  border: none;
  color: var(--ink-soft);
  font-size: 0.875rem;
  cursor: pointer;
  padding: 0;
  margin-bottom: var(--s-4);
}
.back-link:hover { color: var(--ink); }

.me-tag {
  color: var(--ink-soft);
  font-weight: 400;
  font-size: 0.875rem;
}

.stand-card {
  display: flex;
  align-items: center;
  gap: var(--s-4);
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-lg);
  padding: var(--s-4) var(--s-5);
  margin-bottom: var(--s-6);
}
.stand-card .divider {
  width: 1px;
  background: var(--line);
  align-self: stretch;
}

.round-section {
  margin-bottom: var(--s-7);
}
.round-section h2 {
  font-size: 1.125rem;
  margin: 0 0 var(--s-3);
  padding-bottom: var(--s-2);
  border-bottom: 1px solid var(--line);
}

.match-grid {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.match-row {
  display: flex;
  align-items: center;
  gap: var(--s-3);
  padding: 8px 12px;
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  font-size: 0.875rem;
  flex-wrap: wrap;
}
.m-num {
  color: var(--ink-mute);
  font-size: 0.75rem;
  min-width: 36px;
}
.m-teams {
  flex: 1;
  min-width: 200px;
}
.m-pred {
  display: inline-block;
  padding: 1px 8px;
  margin: 0 6px;
  background: var(--bg-elev);
  border-radius: var(--r-sm);
  font-weight: 600;
}
.m-actual {
  font-size: 0.75rem;
  font-style: italic;
}
.m-points {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 700;
}
.pts-0 { background: rgba(120,120,120,0.12); color: var(--ink-mute); }
.pts-2, .pts-5 { background: rgba(212,160,23,0.15); color: #8a6b18; }
.pts-7, .pts-10, .pts-12 { background: rgba(56,142,60,0.15); color: #2d6f30; }
.pts-15, .pts-20 { background: rgba(56,142,60,0.25); color: #2d6f30; }

.placeholder-pred {
  font-style: italic;
  color: #8a6b18;
}

.poule-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
  gap: var(--s-3);
}
.poule-card {
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  padding: var(--s-3);
}
.poule-header {
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--ink-mute);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 6px;
}
.poule-list {
  margin: 0;
  padding-left: var(--s-4);
  font-size: 0.875rem;
}
.poule-list li {
  padding: 2px 0;
}
.poule-points {
  margin-top: 6px;
  font-size: 0.75rem;
  color: var(--ink-soft);
}

.bonus-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.bonus-row {
  display: flex;
  align-items: center;
  gap: var(--s-3);
  padding: 8px 12px;
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  font-size: 0.875rem;
}
.bonus-q {
  flex: 1;
}
.bonus-a {
  padding: 1px 8px;
  background: var(--bg-elev);
  border-radius: var(--r-sm);
  font-weight: 600;
}
.bonus-pts {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 0.75rem;
  background: rgba(56,142,60,0.15);
  color: #2d6f30;
}

.small { font-size: 0.875rem; }

@media (max-width: 640px) {
  .match-row { font-size: 0.8125rem; padding: 6px 10px; }
  .m-teams { min-width: 0; }
  .poule-grid { grid-template-columns: 1fr 1fr; }
}
</style>
