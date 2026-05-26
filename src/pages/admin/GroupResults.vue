<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../lib/supabase.js'

const teamsByGroup = ref({})
const orders = ref({})           // letter -> [team_id, team_id, team_id, team_id]
const hasResult = ref({})        // letter -> bool (al ingevuld?)
const saving = ref({})
const loading = ref(true)
const error = ref('')
const draggingFrom = ref(null)

async function load() {
  loading.value = true
  error.value = ''

  const [teamsRes, resultsRes] = await Promise.all([
    supabase.from('teams').select('*').order('group_letter').order('name'),
    supabase.from('group_results').select('*')
  ])

  if (teamsRes.error) error.value = teamsRes.error.message
  if (resultsRes.error) error.value = resultsRes.error.message

  const grouped = {}
  for (const t of teamsRes.data || []) {
    if (!grouped[t.group_letter]) grouped[t.group_letter] = []
    grouped[t.group_letter].push(t)
  }
  teamsByGroup.value = grouped

  const orderMap = {}
  const hasMap = {}
  for (const letter of Object.keys(grouped)) {
    orderMap[letter] = grouped[letter].map((t) => t.id)
    hasMap[letter] = false
  }
  for (const r of resultsRes.data || []) {
    orderMap[r.group_letter] = [r.pos1_team_id, r.pos2_team_id, r.pos3_team_id, r.pos4_team_id]
    hasMap[r.group_letter] = true
  }
  orders.value = orderMap
  hasResult.value = hasMap

  loading.value = false
}

onMounted(load)

function getTeam(letter, idx) {
  const teamId = orders.value[letter]?.[idx]
  if (!teamId) return null
  return teamsByGroup.value[letter]?.find((t) => t.id === teamId)
}

function onDragStart(letter, idx, ev) {
  draggingFrom.value = { letter, idx }
  ev.dataTransfer.effectAllowed = 'move'
}
function onDragOver(ev) { ev.preventDefault() }
function onDrop(letter, toIdx) {
  if (!draggingFrom.value || draggingFrom.value.letter !== letter) {
    draggingFrom.value = null
    return
  }
  const fromIdx = draggingFrom.value.idx
  draggingFrom.value = null
  if (fromIdx === toIdx) return
  const arr = [...orders.value[letter]]
  const [moved] = arr.splice(fromIdx, 1)
  arr.splice(toIdx, 0, moved)
  orders.value[letter] = arr
}
function moveUp(letter, idx) {
  if (idx === 0) return
  const arr = [...orders.value[letter]]
  ;[arr[idx - 1], arr[idx]] = [arr[idx], arr[idx - 1]]
  orders.value[letter] = arr
}
function moveDown(letter, idx) {
  if (idx === 3) return
  const arr = [...orders.value[letter]]
  ;[arr[idx], arr[idx + 1]] = [arr[idx + 1], arr[idx]]
  orders.value[letter] = arr
}

async function saveGroup(letter) {
  saving.value[letter] = true
  error.value = ''
  const arr = orders.value[letter]
  const { error: err } = await supabase
    .from('group_results')
    .upsert(
      {
        group_letter: letter,
        pos1_team_id: arr[0],
        pos2_team_id: arr[1],
        pos3_team_id: arr[2],
        pos4_team_id: arr[3]
      },
      { onConflict: 'group_letter' }
    )
  saving.value[letter] = false
  if (err) {
    error.value = err.message
    return
  }
  hasResult.value[letter] = true
}

async function clearGroup(letter) {
  if (!confirm(`Echt de uitslag van poule ${letter} verwijderen? Alle gerelateerde voorspellings-punten gaan dan op 0.`)) return
  const { error: err } = await supabase
    .from('group_results')
    .delete()
    .eq('group_letter', letter)
  if (err) {
    error.value = err.message
    return
  }
  hasResult.value[letter] = false
}

const groupLetters = computed(() => Object.keys(teamsByGroup.value).sort())
const filledCount = computed(() => Object.values(hasResult.value).filter(Boolean).length)
</script>

<template>
  <main class="page">
    <p class="eyebrow">Beheer</p>
    <h1>Eindstanden poules (R2)</h1>

    <div class="card" style="margin-bottom: var(--s-5)">
      <p class="muted" style="margin-top: 0">
        Vul hier de werkelijke eindstand per poule in zodra de poulefase is
        afgelopen (na 27 juni 2026). Punten van R2-voorspellingen worden
        automatisch berekend: 1 punt per land op de juiste positie.
      </p>
      <div class="row-between" style="margin-top: var(--s-3)">
        <strong>{{ filledCount }} / 12 poules ingevuld</strong>
      </div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="muted">Laden…</div>

    <div v-else class="groups-grid">
      <div v-for="letter in groupLetters" :key="letter" class="group-card" :class="{ 'is-filled': hasResult[letter] }">
        <div class="group-header">
          <h3 style="margin: 0">Poule {{ letter }}</h3>
          <span v-if="hasResult[letter]" class="status-pill filled">✓ ingevuld</span>
          <span v-else class="status-pill empty">leeg</span>
        </div>

        <div class="standings">
          <div
            v-for="(_, idx) in [0,1,2,3]"
            :key="idx"
            class="standing-row"
            draggable="true"
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
              <button class="arrow" @click="moveUp(letter, idx)" :disabled="idx === 0" aria-label="Omhoog">↑</button>
              <button class="arrow" @click="moveDown(letter, idx)" :disabled="idx === 3" aria-label="Omlaag">↓</button>
            </div>
          </div>
        </div>

        <div class="group-actions">
          <button
            class="btn btn-primary btn-sm"
            @click="saveGroup(letter)"
            :disabled="saving[letter]"
          >
            {{ saving[letter] ? 'Opslaan…' : (hasResult[letter] ? 'Bijwerken' : 'Opslaan') }}
          </button>
          <button
            v-if="hasResult[letter]"
            class="btn btn-secondary btn-sm"
            @click="clearGroup(letter)"
          >
            Wissen
          </button>
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
}
.group-card.is-filled {
  border-left: 4px solid #2d8045;
}
.group-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--s-3);
}
.status-pill {
  font-family: var(--font-mono);
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  padding: 2px 8px;
  border-radius: 999px;
}
.status-pill.filled { background: #2d8045; color: white; }
.status-pill.empty { background: var(--bg-elev); color: var(--ink-mute); }
.standings {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-bottom: var(--s-3);
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
}
.standing-row:active { cursor: grabbing; }
.pos { font-weight: 700; font-size: 1.0625rem; color: var(--ink-soft); text-align: center; }
.flag { width: 28px; height: 19px; object-fit: cover; border-radius: 2px; }
.team-name { font-weight: 500; font-size: 0.9375rem; }
.arrows { display: flex; flex-direction: column; gap: 1px; }
.arrow {
  background: transparent;
  border: 1px solid var(--line);
  width: 22px;
  height: 18px;
  font-size: 11px;
  color: var(--ink-soft);
  border-radius: 3px;
}
.arrow:hover:not(:disabled) { background: var(--bg-card); border-color: var(--field); color: var(--field); }
.arrow:disabled { opacity: 0.3; cursor: not-allowed; }
.group-actions { display: flex; gap: var(--s-2); }
</style>
