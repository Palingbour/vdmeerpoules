<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../../lib/supabase.js'

const rounds = ref([])
const editedDeadlines = ref({})
const editedAmounts = ref({})
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
    editedAmounts.value[r.nr] = r.prize_amount
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
    .update({
      deadline,
      prize_amount: parseFloat(editedAmounts.value[r.nr])
    })
    .eq('nr', r.nr)
  if (err) error.value = err.message
  saving.value[r.nr] = false
  if (!err) await load()
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Beheer</p>
    <h1>Deadlines &amp; prijzen</h1>

    <div class="card">
      <p class="muted" style="margin-top: 0">
        Per ronde stel je de deadline in (vanaf wanneer voorspellingen vastgezet
        zijn) en het prijsbedrag voor de winnaar van die ronde. Standaard €5 per ronde.
      </p>

      <div v-if="error" class="alert alert-error">{{ error }}</div>

      <table class="table" style="margin-top: var(--s-4)">
        <thead>
          <tr>
            <th>#</th>
            <th>Naam</th>
            <th>Deadline</th>
            <th>Rondeprijs (€)</th>
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
              <input
                type="number"
                step="0.50"
                min="0"
                v-model="editedAmounts[r.nr]"
                class="amount-input"
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
.amount-input {
  width: 90px;
  padding: 6px 8px;
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  font-family: var(--font-mono);
  font-size: 0.875rem;
}
</style>
