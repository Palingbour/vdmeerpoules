<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../../lib/supabase.js'

const rounds = ref([])
const editedDeadlines = ref({})
const saving = ref({})
const error = ref('')

async function load() {
  const { data, error: err } = await supabase
    .from('rounds')
    .select('*')
    .order('nr')
  if (err) { error.value = err.message; return }
  rounds.value = data
  for (const r of data) {
    editedDeadlines.value[r.nr] = r.deadline ? toLocalDateTime(r.deadline) : ''
  }
}

onMounted(load)

// ISO naar 'YYYY-MM-DDTHH:MM' voor <input type="datetime-local">
function toLocalDateTime(iso) {
  const d = new Date(iso)
  const pad = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

async function save(r) {
  saving.value[r.nr] = true
  error.value = ''
  const deadline = editedDeadlines.value[r.nr]
    ? new Date(editedDeadlines.value[r.nr]).toISOString()
    : null
  const { error: err } = await supabase
    .from('rounds')
    .update({ deadline })
    .eq('nr', r.nr)
  if (err) error.value = err.message
  saving.value[r.nr] = false
  if (!err) await load()
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Beheer</p>
    <h1>Deadlines</h1>

    <div class="card">
      <p class="muted" style="margin-top: 0">
        Per ronde stel je de deadline in: vanaf dat moment zijn de voorspellingen
        voor die ronde vastgezet. De prijsbedragen beheer je op de
        <router-link to="/prijzenpot">prijzenpot-pagina</router-link>.
      </p>

      <div v-if="error" class="alert alert-error">{{ error }}</div>

      <div class="table-scroll" style="margin-top: var(--s-4)">
      <table class="table">
        <thead>
          <tr>
            <th>#</th>
            <th>Naam</th>
            <th>Deadline</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in rounds" :key="r.nr">
            <td><strong>R{{ r.nr }}</strong></td>
            <td>{{ r.name }}</td>
            <td>
              <input
                type="datetime-local"
                v-model="editedDeadlines[r.nr]"
                class="dt-input"
              />
            </td>
            <td>
              <button
                class="btn btn-primary btn-sm"
                @click="save(r)"
                :disabled="saving[r.nr]"
              >
                {{ saving[r.nr] ? '…' : 'Opslaan' }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      </div>
    </div>
  </main>
</template>

<style scoped>
.dt-input {
  padding: 6px 8px;
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  font-family: var(--font-mono);
  font-size: 0.875rem;
}
</style>
