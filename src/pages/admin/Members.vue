<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../../lib/supabase.js'
import { useAuthStore } from '../../stores/auth.js'

const auth = useAuthStore()

const members = ref([])
const loading = ref(true)
const error = ref('')
const filter = ref('all')   // all | pending | active

async function load() {
  loading.value = true
  error.value = ''
  const { data, error: err } = await supabase
    .from('profiles')
    .select('*')
    .order('created_at', { ascending: false })
  if (err) {
    error.value = err.message
  } else {
    members.value = data
  }
  loading.value = false
}

onMounted(load)

const filtered = computed(() => {
  if (filter.value === 'all') return members.value
  return members.value.filter((m) => m.status === filter.value)
})

const counts = computed(() => ({
  all: members.value.length,
  pending: members.value.filter((m) => m.status === 'pending').length,
  active: members.value.filter((m) => m.status === 'active').length
}))

async function approve(member) {
  if (!confirm(`${member.full_name || member.email} goedkeuren als actief lid?`)) return
  const { error: err } = await supabase
    .from('profiles')
    .update({
      status: 'active',
      paid_at: member.paid_at || new Date().toISOString(),
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

async function markPaid(member) {
  const { error: err } = await supabase
    .from('profiles')
    .update({ paid_at: new Date().toISOString() })
    .eq('id', member.id)
  if (err) {
    alert('Fout: ' + err.message)
    return
  }
  await load()
}

async function reject(member) {
  if (!confirm(`Aanmelding van ${member.full_name || member.email} afwijzen?`)) return
  const { error: err } = await supabase
    .from('profiles')
    .update({ status: 'rejected' })
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
    if (!confirm('Weet je zeker dat je jezelf wilt demoten? Je verliest toegang tot het beheerpaneel.')) return
  } else {
    const action = newRole === 'admin' ? 'tot beheerder promoveren' : 'als beheerder verwijderen'
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
</script>

<template>
  <main class="page">
    <p class="eyebrow">Beheer</p>
    <h1>Leden</h1>

    <div class="card">
      <div class="row" style="margin-bottom: var(--s-5); gap: var(--s-2)">
        <button
          class="btn btn-sm"
          :class="filter === 'all' ? 'btn-primary' : 'btn-secondary'"
          @click="filter = 'all'"
        >
          Alle ({{ counts.all }})
        </button>
        <button
          class="btn btn-sm"
          :class="filter === 'pending' ? 'btn-primary' : 'btn-secondary'"
          @click="filter = 'pending'"
        >
          In afwachting ({{ counts.pending }})
        </button>
        <button
          class="btn btn-sm"
          :class="filter === 'active' ? 'btn-primary' : 'btn-secondary'"
          @click="filter = 'active'"
        >
          Actief ({{ counts.active }})
        </button>
      </div>

      <div v-if="error" class="alert alert-error">{{ error }}</div>

      <div v-if="loading" class="muted">Laden…</div>

      <div v-else-if="filtered.length === 0" class="muted">
        Niemand in deze categorie.
      </div>

      <table v-else class="table">
        <thead>
          <tr>
            <th>Naam</th>
            <th>E-mail</th>
            <th>Status</th>
            <th>Inleg</th>
            <th>Aangemeld</th>
            <th>Acties</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="m in filtered" :key="m.id">
            <td>
              <strong>{{ m.full_name || '—' }}</strong>
              <span v-if="m.role === 'admin'" class="badge badge-admin" style="margin-left: var(--s-2)">
                Admin
              </span>
              <span v-if="m.id === auth.profile.id" class="muted" style="margin-left: var(--s-2)">(jij)</span>
            </td>
            <td class="mono" style="font-size: 0.875rem">{{ m.email }}</td>
            <td>
              <span class="badge" :class="`badge-${m.status}`">
                {{ {
                  pending: 'Afwachten',
                  active: 'Actief',
                  rejected: 'Afgewezen'
                }[m.status] }}
              </span>
            </td>
            <td>
              <span v-if="m.paid_at" class="muted mono" style="font-size: 0.8125rem">
                {{ fmtDate(m.paid_at) }}
              </span>
              <button v-else class="btn btn-secondary btn-sm" @click="markPaid(m)">
                Betaald
              </button>
            </td>
            <td class="muted mono" style="font-size: 0.8125rem">{{ fmtDate(m.created_at) }}</td>
            <td>
              <div class="row" style="gap: var(--s-2)">
                <button
                  v-if="m.status === 'pending'"
                  class="btn btn-primary btn-sm"
                  @click="approve(m)"
                >
                  Goedkeuren
                </button>
                <button
                  v-if="m.status === 'pending'"
                  class="btn btn-danger btn-sm"
                  @click="reject(m)"
                >
                  Afwijzen
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
  </main>
</template>
