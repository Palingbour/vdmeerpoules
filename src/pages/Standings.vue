<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../lib/supabase.js'
import { useAuthStore } from '../stores/auth.js'

const auth = useAuthStore()
const standings = ref([])
const totalMatchesFinished = ref(0)
const loading = ref(true)
let channel = null

async function load() {
  loading.value = true
  try {
    const [{ data: rows, error }, { count }] = await Promise.all([
      supabase
        .from('user_standings')
        .select('*')
        .order('total_points', { ascending: false })
        .order('exact_count', { ascending: false })
        .order('full_name'),
      supabase
        .from('matches')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'finished')
    ])
    if (error) {
      console.error('[Standings] load error:', error)
    }
    standings.value = rows || []
    totalMatchesFinished.value = count || 0
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  load()
  // Realtime — herlaad zodra een wedstrijd-uitslag of voorspelling verandert
  channel = supabase
    .channel('standings-watch')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'matches' }, () => load())
    .on('postgres_changes', { event: '*', schema: 'public', table: 'match_predictions' }, () => load())
    .subscribe()
})

onUnmounted(() => {
  if (channel) supabase.removeChannel(channel)
})

const myRank = computed(() => {
  if (!auth.profile?.id) return null
  const idx = standings.value.findIndex(s => s.id === auth.profile.id)
  return idx >= 0 ? idx + 1 : null
})

const myEntry = computed(() => {
  if (!auth.profile?.id) return null
  return standings.value.find(s => s.id === auth.profile.id)
})

// Helper: bepaalt of twee opeenvolgende rijen op dezelfde positie staan
function sharedRank(idx) {
  if (idx === 0) return 1
  const cur = standings.value[idx]
  const prev = standings.value[idx - 1]
  if (cur.total_points === prev.total_points && cur.exact_count === prev.exact_count) {
    return sharedRank(idx - 1)
  }
  return idx + 1
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Stand</p>
    <h1>Wie staat aan kop?</h1>

    <!-- Jouw eigen positie -->
    <div v-if="myEntry && myRank" class="my-rank-card">
      <div>
        <span class="my-label">Jij staat op plek</span>
        <div class="my-position mono">
          <span class="my-num">{{ myRank }}</span>
          <span class="my-of">van {{ standings.length }}</span>
        </div>
      </div>
      <div class="my-points">
        <span class="my-points-num mono">{{ myEntry.total_points }}</span>
        <span class="my-points-label">punten</span>
      </div>
    </div>

    <!-- Status: hoeveel wedstrijden zijn er gespeeld -->
    <div class="card" style="margin-bottom: var(--s-5)">
      <p class="muted" style="margin: 0">
        <template v-if="totalMatchesFinished === 0">
          Nog geen wedstrijden afgelopen. De stand vult zich vanaf de eerste
          uitslag op <strong>11 juni 2026</strong>.
        </template>
        <template v-else>
          <strong>{{ totalMatchesFinished }}</strong> van 72 poulewedstrijden
          afgelopen. Punten: <strong>2</strong> voor winnaar correct,
          <strong>5</strong> voor exacte uitslag.
        </template>
      </p>
    </div>

    <div v-if="loading" class="muted">Laden…</div>

    <!-- Leaderboard -->
    <div v-else-if="standings.length === 0" class="muted">
      Nog geen actieve deelnemers.
    </div>

    <div v-else class="leaderboard">
      <table class="lb-table">
        <thead>
          <tr>
            <th class="col-rank">#</th>
            <th class="col-name">Deelnemer</th>
            <th class="col-r1">R1</th>
            <th class="col-exact">Exact</th>
            <th class="col-total">Totaal</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="(row, idx) in standings"
            :key="row.id"
            :class="{ 'is-me': row.id === auth.profile?.id }"
          >
            <td class="col-rank mono">
              <span class="rank-num">{{ sharedRank(idx) }}</span>
              <span v-if="idx < 3 && row.total_points > 0" class="medal">
                {{ idx === 0 ? '🥇' : idx === 1 ? '🥈' : '🥉' }}
              </span>
            </td>
            <td class="col-name">
              <strong>{{ row.full_name }}</strong>
              <span v-if="row.role === 'admin'" class="admin-tag mono">admin</span>
            </td>
            <td class="col-r1 mono">{{ row.r1_points }}</td>
            <td class="col-exact mono">{{ row.exact_count }}</td>
            <td class="col-total mono"><strong>{{ row.total_points }}</strong></td>
          </tr>
        </tbody>
      </table>

      <p class="muted footer-note">
        Bij gelijke punten wint wie de meeste exacte uitslagen heeft.
        Daarna alfabetisch.
      </p>
    </div>
  </main>
</template>

<style scoped>
.my-rank-card {
  background: linear-gradient(135deg, var(--field), var(--field-soft));
  color: var(--bg-card);
  border-radius: var(--r-lg);
  padding: var(--s-5) var(--s-6);
  margin-bottom: var(--s-5);
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: var(--s-4);
  box-shadow: 0 6px 24px rgba(31, 75, 58, 0.18);
}
.my-label {
  font-size: 0.875rem;
  opacity: 0.85;
  letter-spacing: 0.02em;
}
.my-position {
  display: flex;
  align-items: baseline;
  gap: var(--s-2);
  margin-top: 4px;
}
.my-num {
  font-family: var(--font-display);
  font-size: 2.5rem;
  font-weight: 600;
  line-height: 1;
}
.my-of {
  font-size: 0.875rem;
  opacity: 0.7;
}
.my-points {
  text-align: right;
}
.my-points-num {
  font-family: var(--font-display);
  font-size: 2.5rem;
  font-weight: 600;
  display: block;
  line-height: 1;
}
.my-points-label {
  font-size: 0.875rem;
  opacity: 0.85;
}

.leaderboard {
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-md);
  overflow: hidden;
}
.lb-table {
  width: 100%;
  border-collapse: collapse;
}
.lb-table thead th {
  background: var(--bg-elev);
  text-align: left;
  font-size: 0.6875rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--ink-mute);
  padding: var(--s-3) var(--s-4);
  border-bottom: 1px solid var(--line);
  font-family: var(--font-mono);
}
.lb-table tbody td {
  padding: var(--s-3) var(--s-4);
  border-bottom: 1px solid var(--line-soft);
  font-size: 0.9375rem;
}
.lb-table tbody tr:last-child td {
  border-bottom: none;
}
.lb-table tbody tr.is-me {
  background: rgba(31, 75, 58, 0.06);
}
.lb-table tbody tr.is-me td {
  font-weight: 500;
}
.col-rank {
  width: 60px;
  text-align: center;
}
.rank-num {
  display: inline-block;
  color: var(--ink-soft);
  font-weight: 600;
}
.medal {
  display: inline-block;
  margin-left: 4px;
}
.col-r1, .col-exact, .col-total {
  text-align: right;
  width: 70px;
}
.col-total {
  width: 90px;
}
.admin-tag {
  display: inline-block;
  margin-left: 6px;
  background: var(--bg-elev);
  padding: 1px 6px;
  border-radius: var(--r-sm);
  font-size: 0.625rem;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--ink-mute);
}
.footer-note {
  padding: var(--s-3) var(--s-4);
  font-size: 0.8125rem;
  background: var(--bg-elev);
  margin: 0;
  border-top: 1px solid var(--line);
}

@media (max-width: 640px) {
  .lb-table .col-exact { display: none; }
  .my-rank-card { flex-direction: column; align-items: flex-start; gap: var(--s-3); }
  .my-points { text-align: left; }
}
</style>
