<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../lib/supabase.js'

const matches = ref([])
const loading = ref(true)
const error = ref('')
const filterRound = ref(1)
const editing = ref(null)
const editForm = ref({})
const saving = ref(false)

async function load() {
  loading.value = true
  try {
    const { data, error: err } = await supabase
      .from('matches')
      .select(`
        *,
        team_home:teams!matches_team_home_id_fkey(id, name, flag_url),
        team_away:teams!matches_team_away_id_fkey(id, name, flag_url)
      `)
      .order('kickoff_at')
      .order('match_number')
    if (err) error.value = err.message
    matches.value = data || []
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
    score_home: m.score_home ?? '',
    score_away: m.score_away ?? '',
    status: m.status
  }
}

function cancelEdit() {
  editing.value = null
  editForm.value = {}
}

async function save() {
  saving.value = true
  error.value = ''
  const patch = {
    kickoff_at: new Date(editForm.value.kickoff_at).toISOString(),
    city: editForm.value.city,
    stadium: editForm.value.stadium,
    score_home: editForm.value.score_home === '' ? null : parseInt(editForm.value.score_home),
    score_away: editForm.value.score_away === '' ? null : parseInt(editForm.value.score_away),
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
                  <div class="field" style="margin: 0">
                    <label>Uitslag thuis</label>
                    <input type="number" min="0" v-model="editForm.score_home" />
                  </div>
                  <div class="field" style="margin: 0">
                    <label>Uitslag uit</label>
                    <input type="number" min="0" v-model="editForm.score_away" />
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
  grid-template-columns: 2fr 1fr 1fr 60px 60px 1fr;
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
