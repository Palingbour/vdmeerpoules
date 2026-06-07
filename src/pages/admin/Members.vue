<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../../lib/supabase.js'
import { useAuthStore } from '../../stores/auth.js'

const auth = useAuthStore()

const members = ref([])
const loading = ref(true)
const error = ref('')
const filter = ref('all')

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data, error: err } = await supabase
      .from('profiles')
      .select('*')
      .order('created_at', { ascending: false })
    if (err) {
      error.value = err.message
    } else {
      members.value = data
    }
  } catch (e) {
    console.error('[admin/Members] load error:', e)
    error.value = e.message || 'Er ging iets mis bij het laden.'
  } finally {
    loading.value = false
  }
}

onMounted(load)

const filtered = computed(() => {
  if (filter.value === 'all') return members.value
  return members.value.filter((m) => m.status === filter.value)
})

const counts = computed(() => ({
  all: members.value.length,
  awaiting_payment: members.value.filter((m) => m.status === 'awaiting_payment').length,
  active: members.value.filter((m) => m.status === 'active').length,
  inactive: members.value.filter((m) => m.status === 'inactive').length
}))

async function activate(member) {
  if (!confirm(`Betaling van ${member.full_name || member.email} bevestigen en activeren?`)) return
  const { error: err } = await supabase
    .from('profiles')
    .update({
      status: 'active',
      paid_at: new Date().toISOString(),
      approved_by: auth.profile.id,
      approved_at: new Date().toISOString()
    })
    .eq('id', member.id)
  if (err) {
    alert('Fout: ' + err.message)
    return
  }
  await load()
}

async function deactivate(member) {
  if (!confirm(`${member.full_name || member.email} deactiveren? Telt niet meer mee in stand.`)) return
  const { error: err } = await supabase
    .from('profiles')
    .update({ status: 'inactive' })
    .eq('id', member.id)
  if (err) {
    alert('Fout: ' + err.message)
    return
  }
  await load()
}

async function reactivate(member) {
  if (!confirm(`${member.full_name || member.email} weer activeren?`)) return
  const { error: err } = await supabase
    .from('profiles')
    .update({ status: 'active' })
    .eq('id', member.id)
  if (err) {
    alert('Fout: ' + err.message)
    return
  }
  await load()
}

async function toggleAdmin(member) {
  const newRole = member.role === 'admin' ? 'member' : 'admin'

  if (member.id === auth.profile.id && newRole === 'member') {
    const otherAdmins = members.value.filter(
      (m) => m.role === 'admin' && m.status === 'active' && m.id !== member.id
    )
    if (otherAdmins.length === 0) {
      alert('Je kunt jezelf niet demoten als er geen andere actieve beheerder is.')
      return
    }
    if (!confirm('Weet je zeker dat je jezelf wilt demoten? Je verliest toegang tot beheer.')) return
  } else {
    const action = newRole === 'admin' ? 'tot beheerder maken' : 'als beheerder verwijderen'
    if (!confirm(`${member.full_name || member.email} ${action}?`)) return
  }

  const { error: err } = await supabase
    .from('profiles')
    .update({ role: newRole })
    .eq('id', member.id)
  if (err) {
    alert('Fout: ' + err.message)
    return
  }
  await load()
}

function fmtDate(d) {
  if (!d) return '—'
  return new Date(d).toLocaleDateString('nl-NL', {
    day: '2-digit', month: 'short', year: 'numeric'
  })
}

function statusLabel(status) {
  return {
    awaiting_payment: 'Wacht op betaling',
    active: 'Actief',
    inactive: 'Inactief'
  }[status] || status
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Beheer</p>
    <h1>Leden</h1>

    <div class="card">
      <div class="row filter-row">
        <button class="btn btn-sm" :class="filter === 'all' ? 'btn-primary' : 'btn-secondary'" @click="filter = 'all'">
          Alle ({{ counts.all }})
        </button>
        <button class="btn btn-sm" :class="filter === 'awaiting_payment' ? 'btn-primary' : 'btn-secondary'" @click="filter = 'awaiting_payment'">
          💸 Wacht op betaling ({{ counts.awaiting_payment }})
        </button>
        <button class="btn btn-sm" :class="filter === 'active' ? 'btn-primary' : 'btn-secondary'" @click="filter = 'active'">
          ✓ Actief ({{ counts.active }})
        </button>
        <button class="btn btn-sm" :class="filter === 'inactive' ? 'btn-primary' : 'btn-secondary'" @click="filter = 'inactive'">
          Inactief ({{ counts.inactive }})
        </button>
      </div>

      <div v-if="error" class="alert alert-error">{{ error }}</div>
      <div v-if="loading" class="muted">Laden…</div>

      <div v-else-if="filtered.length === 0" class="muted">
        Niemand in deze categorie.
      </div>

      <div v-else class="table-wrap">
        <table class="table">
          <thead>
            <tr>
              <th>Naam</th>
              <th>E-mail</th>
              <th>Status</th>
              <th>Betaald op</th>
              <th>Aangemeld</th>
              <th>Acties</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="m in filtered" :key="m.id">
              <td>
                <strong>{{ m.full_name || '—' }}</strong>
                <span v-if="m.role === 'admin'" class="badge badge-admin" style="margin-left: var(--s-2)">Admin</span>
                <span v-if="m.id === auth.profile.id" class="muted" style="margin-left: var(--s-2)">(jij)</span>
              </td>
              <td class="mono email-col">{{ m.email }}</td>
              <td>
                <span class="badge" :class="`badge-${m.status}`">
                  {{ statusLabel(m.status) }}
                </span>
              </td>
              <td class="muted mono date-col">{{ fmtDate(m.paid_at) }}</td>
              <td class="muted mono date-col">{{ fmtDate(m.created_at) }}</td>
              <td>
                <div class="row" style="gap: var(--s-2); flex-wrap: wrap">
                  <button
                    v-if="m.status === 'awaiting_payment'"
                    class="btn btn-primary btn-sm"
                    @click="activate(m)"
                  >
                    Betaling ontvangen → activeren
                  </button>
                  <button
                    v-if="m.status === 'inactive'"
                    class="btn btn-primary btn-sm"
                    @click="reactivate(m)"
                  >
                    Weer activeren
                  </button>
                  <button
                    v-if="m.status === 'active' && m.id !== auth.profile.id"
                    class="btn btn-secondary btn-sm"
                    @click="deactivate(m)"
                  >
                    Deactiveren
                  </button>
                  <button
                    v-if="m.status === 'active'"
                    class="btn btn-secondary btn-sm"
                    @click="toggleAdmin(m)"
                  >
                    {{ m.role === 'admin' ? 'Admin af' : 'Admin maken' }}
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </main>
</template>

<style scoped>
.filter-row {
  margin-bottom: var(--s-5);
  gap: var(--s-2);
  flex-wrap: wrap;
}
.table-wrap {
  overflow-x: auto;
}
.email-col {
  font-size: 0.875rem;
}
.date-col {
  font-size: 0.8125rem;
  white-space: nowrap;
}
.badge-awaiting_payment { background: var(--accent, #d4561d); color: white; }
.badge-active { background: #2d8045; color: white; }
.badge-inactive { background: var(--ink-mute); color: white; }

@media (max-width: 720px) {
  .table { font-size: 0.875rem; }
  .table th, .table td { padding: 8px 6px; }
}
</style>
