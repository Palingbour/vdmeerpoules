<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../lib/supabase.js'

const matches = ref([])
const teams = ref([])
const groupResults = ref([])
const loading = ref(true)
const error = ref('')
const filterRound = ref(1)
const editing = ref(null)
const editForm = ref({})
const saving = ref(false)

async function load() {
  loading.value = true
  try {
    const [matchesRes, teamsRes, grRes] = await Promise.all([
      supabase
        .from('matches')
        .select(`
          *,
          team_home:teams!matches_team_home_id_fkey(id, name, flag_url),
          team_away:teams!matches_team_away_id_fkey(id, name, flag_url)
        `)
        .order('kickoff_at')
        .order('match_number'),
      supabase.from('teams').select('id, name, group_letter, flag_url').order('group_letter').order('name'),
      supabase.from('group_results').select('*')
    ])
    if (matchesRes.error) error.value = matchesRes.error.message
    matches.value = matchesRes.data || []
    teams.value = teamsRes.data || []
    groupResults.value = grRes.data || []
  } catch (e) {
    console.error('[admin/Matches] load error:', e)
    error.value = e.message || 'Er ging iets mis bij het laden.'
  } finally {
    loading.value = false
  }
}

onMounted(load)

const filtered = computed(() => matches.value.filter((m) => m.round_nr === filterRound.value))

function toLocalDateTime(iso) {
  const d = new Date(iso)
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function startEdit(m) {
  editing.value = m.id
  editForm.value = {
    kickoff_at: toLocalDateTime(m.kickoff_at),
    city: m.city || '',
    stadium: m.stadium || '',
    team_home_id: m.team_home_id || null,
    team_away_id: m.team_away_id || null,
    score_home: m.score_home ?? '',
    score_away: m.score_away ?? '',
    winner_team_id: m.winner_team_id || null,
    status: m.status
  }
}

function cancelEdit() {
  editing.value = null
  editForm.value = {}
}

// Bouw team-opties voor een slot. Voor third_place met meerdere groepen:
// alleen de nr.3 van elke groep (zoals officieel toegewezen). Voor andere
// slot types: relevante teams gefilterd op groep / dep-match.
function teamOptionsForSlot(slotType, slotGroups, slotMatchDep) {
  if (slotType === 'group_winner' || slotType === 'group_runner') {
    return teams.value.filter(t => slotGroups?.includes(t.group_letter))
  }
  if (slotType === 'third_place') {
    if (slotGroups?.length === 1) {
      // Alleen pos3 team van die ene groep (na poule klaar) of alle teams uit die groep als fallback
      const gr = groupResults.value.find(g => g.group_letter === slotGroups[0])
      if (gr?.pos3_team_id) {
        return teams.value.filter(t => t.id === gr.pos3_team_id)
      }
      return teams.value.filter(t => slotGroups.includes(t.group_letter))
    }
    if (slotGroups?.length > 1) {
      // Multi-group: pos3 teams uit alle groepen
      const validIds = []
      for (const letter of slotGroups) {
        const gr = groupResults.value.find(g => g.group_letter === letter)
        if (gr?.pos3_team_id) validIds.push(gr.pos3_team_id)
      }
      if (validIds.length) return teams.value.filter(t => validIds.includes(t.id))
      // Fallback: alle teams uit die groepen
      return teams.value.filter(t => slotGroups.includes(t.group_letter))
    }
    return teams.value
  }
  if (slotType === 'match_winner' || slotType === 'match_loser') {
    const depMatch = matches.value.find(m => m.id === slotMatchDep)
    if (!depMatch) return []
    return teams.value.filter(t => t.id === depMatch.team_home_id || t.id === depMatch.team_away_id)
  }
  return teams.value
}

const editingMatch = computed(() => matches.value.find(m => m.id === editing.value) || null)
const homeTeamOptions = computed(() => {
  if (!editingMatch.value) return []
  return teamOptionsForSlot(editingMatch.value.slot_home_type, editingMatch.value.slot_home_groups, editingMatch.value.slot_home_match_dep)
})
const awayTeamOptions = computed(() => {
  if (!editingMatch.value) return []
  return teamOptionsForSlot(editingMatch.value.slot_away_type, editingMatch.value.slot_away_groups, editingMatch.value.slot_away_match_dep)
})

async function save() {
  saving.value = true
  error.value = ''
  const patch = {
    kickoff_at: new Date(editForm.value.kickoff_at).toISOString(),
    city: editForm.value.city,
    stadium: editForm.value.stadium,
    team_home_id: editForm.value.team_home_id || null,
    team_away_id: editForm.value.team_away_id || null,
    score_home: editForm.value.score_home === '' ? null : parseInt(editForm.value.score_home),
    score_away: editForm.value.score_away === '' ? null : parseInt(editForm.value.score_away),
    winner_team_id: editForm.value.winner_team_id || null,
    status: editForm.value.status
  }
  const { error: err } = await supabase
    .from('matches')
    .update(patch)
    .eq('id', editing.value)
  saving.value = false
  if (err) {
    error.value = err.message
    return
  }
  cancelEdit()
  await load()
}

function fmtDate(iso) {
  return new Date(iso).toLocaleString('nl-NL', {
    weekday: 'short',
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit'
  })
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Beheer</p>
    <h1>Wedstrijden</h1>

    <div class="card">
      <div class="row" style="gap: var(--s-2); margin-bottom: var(--s-4)">
        <button
          v-for="n in 7"
          :key="n"
          class="btn btn-sm"
          :class="filterRound === n ? 'btn-primary' : 'btn-secondary'"
          @click="filterRound = n"
        >Ronde {{ n }}</button>
      </div>

      <p class="muted" style="font-size: 0.875rem">
        Klik op een rij om aanvangstijd, stadion of uitslag aan te passen.
        Uitslagen tellen na 90 min. Knock-out rondes (R3-R7) vullen zich automatisch
        in M4 als de feed-integratie staat.
      </p>

      <div v-if="error" class="alert alert-error">{{ error }}</div>

      <div v-if="loading" class="muted">Laden…</div>

      <div v-else-if="filtered.length === 0" class="muted">
        Nog geen wedstrijden voor deze ronde.
      </div>

      <div v-else class="table-scroll">
      <table class="table">
        <thead>
          <tr>
            <th>#</th>
            <th>Wanneer</th>
            <th>Wedstrijd</th>
            <th>Stad</th>
            <th>Uitslag</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <template v-for="m in filtered" :key="m.id">
            <tr v-if="editing !== m.id">
              <td class="mono">{{ m.match_number }}</td>
              <td class="mono" style="font-size: 0.8125rem">{{ fmtDate(m.kickoff_at) }}</td>
              <td>
                <div class="row" style="gap: var(--s-2)">
                  <img v-if="m.team_home" :src="m.team_home.flag_url" class="mini-flag" />
                  <span>{{ m.team_home?.name || m.team_home_placeholder }}</span>
                  <span class="muted">—</span>
                  <span>{{ m.team_away?.name || m.team_away_placeholder }}</span>
                  <img v-if="m.team_away" :src="m.team_away.flag_url" class="mini-flag" />
                </div>
              </td>
              <td class="muted" style="font-size: 0.875rem">{{ m.city }}</td>
              <td class="mono">
                <span v-if="m.score_home !== null && m.score_away !== null">
                  {{ m.score_home }} - {{ m.score_away }}
                </span>
                <span v-else class="muted">—</span>
              </td>
              <td>
                <button class="btn btn-secondary btn-sm" @click="startEdit(m)">Bewerken</button>
              </td>
            </tr>
            <tr v-else>
              <td colspan="6">
                <div class="edit-form">
                  <div class="field" style="margin: 0">
                    <label>Aanvangstijd</label>
                    <input type="datetime-local" v-model="editForm.kickoff_at" />
                  </div>
                  <div class="field" style="margin: 0">
                    <label>Stad</label>
                    <input type="text" v-model="editForm.city" />
                  </div>
                  <div class="field" style="margin: 0">
                    <label>Stadion</label>
                    <input type="text" v-model="editForm.stadium" />
                  </div>
                  <div class="field" style="margin: 0" v-if="editingMatch && editingMatch.round_nr >= 3">
                    <label>Thuis team</label>
                    <select v-model="editForm.team_home_id">
                      <option :value="null">— auto / leeg —</option>
                      <option v-for="t in homeTeamOptions" :key="t.id" :value="t.id">
                        {{ t.name }}<template v-if="t.group_letter"> ({{ t.group_letter }})</template>
                      </option>
                    </select>
                  </div>
                  <div class="field" style="margin: 0" v-if="editingMatch && editingMatch.round_nr >= 3">
                    <label>Uit team</label>
                    <select v-model="editForm.team_away_id">
                      <option :value="null">— auto / leeg —</option>
                      <option v-for="t in awayTeamOptions" :key="t.id" :value="t.id">
                        {{ t.name }}<template v-if="t.group_letter"> ({{ t.group_letter }})</template>
                      </option>
                    </select>
                  </div>
                  <div class="field" style="margin: 0">
                    <label>Uitslag thuis</label>
                    <input type="number" min="0" v-model="editForm.score_home" />
                  </div>
                  <div class="field" style="margin: 0">
                    <label>Uitslag uit</label>
                    <input type="number" min="0" v-model="editForm.score_away" />
                  </div>
                  <div class="field" style="margin: 0; grid-column: span 2"
                       v-if="editingMatch && editingMatch.round_nr >= 3">
                    <label>Winnaar <span style="opacity:.7; font-weight: normal">(alleen invullen bij gelijkspel na 90 min)</span></label>
                    <select v-model="editForm.winner_team_id">
                      <option :value="null">— auto (afgeleid uit score) —</option>
                      <option v-if="editForm.team_home_id" :value="editForm.team_home_id">
                        {{ teams.find(t => t.id === editForm.team_home_id)?.name || 'Thuis team' }} wint
                      </option>
                      <option v-if="editForm.team_away_id" :value="editForm.team_away_id">
                        {{ teams.find(t => t.id === editForm.team_away_id)?.name || 'Uit team' }} wint
                      </option>
                    </select>
                  </div>
                  <div class="field" style="margin: 0">
                    <label>Status</label>
                    <select v-model="editForm.status">
                      <option value="scheduled">Gepland</option>
                      <option value="live">Live</option>
                      <option value="finished">Gespeeld</option>
                      <option value="cancelled">Afgelast</option>
                    </select>
                  </div>
                  <div class="form-actions">
                    <button class="btn btn-secondary btn-sm" @click="cancelEdit">Annuleren</button>
                    <button class="btn btn-primary btn-sm" @click="save" :disabled="saving">
                      {{ saving ? 'Opslaan…' : 'Opslaan' }}
                    </button>
                  </div>
                </div>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
      </div>
    </div>
  </main>
</template>

<style scoped>
.mini-flag { width: 22px; height: 15px; object-fit: cover; border-radius: 2px; }
.edit-form {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: var(--s-3);
  align-items: end;
  padding: var(--s-3) 0;
}
.edit-form .field label {
  font-size: 0.6875rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  font-family: var(--font-mono);
  color: var(--ink-mute);
}
.edit-form input, .edit-form select {
  padding: 6px 8px;
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  font-size: 0.875rem;
  width: 100%;
}
.form-actions {
  display: flex;
  gap: var(--s-2);
  grid-column: 1 / -1;
  justify-content: flex-end;
  padding-top: var(--s-2);
}

@media (max-width: 900px) {
  .edit-form { grid-template-columns: 1fr 1fr; }
}
@media (max-width: 640px) {
  .edit-form { grid-template-columns: 1fr; }
}
</style>
