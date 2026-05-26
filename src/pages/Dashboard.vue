<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { supabase } from '../lib/supabase.js'
import { useAuthStore } from '../stores/auth.js'

const auth = useAuthStore()
const firstName = auth.profile?.full_name?.split(' ')[0] || 'speler'

const rounds = ref([])
const matchPredCount = ref(0)
const groupPredCount = ref(0)
const bonusPredCount = ref(0)
const totalMatches = ref(0)
const totalGroups = ref(0)
const totalBonus = ref(0)
const myStanding = ref(null)         // { rank, total, totalMembers, totalPoints }
const loading = ref(true)
const now = ref(new Date())
const tickInterval = ref(null)
const announcements = ref([])

onMounted(() => {
  load()
  tickInterval.value = setInterval(() => { now.value = new Date() }, 1000)
})
onUnmounted(() => {
  if (tickInterval.value) clearInterval(tickInterval.value)
})

async function load() {
  loading.value = true

  try {
    if (!auth.profile?.id) {
      console.warn('Dashboard: auth.profile not yet loaded, skipping queries')
      return
    }

    // Promise.allSettled zodat één gefaalde query niet alles blokkeert.
    const results = await Promise.allSettled([
      supabase.from('rounds').select('*').order('nr'),
      supabase.from('match_predictions').select('match_id', { count: 'exact', head: true }).eq('user_id', auth.profile.id),
      supabase.from('group_predictions').select('group_letter', { count: 'exact', head: true }).eq('user_id', auth.profile.id),
      supabase.from('bonus_predictions').select('question_id', { count: 'exact', head: true }).eq('user_id', auth.profile.id),
      supabase.from('matches').select('id', { count: 'exact', head: true }).eq('round_nr', 1),
      supabase.from('groups').select('letter', { count: 'exact', head: true }),
      supabase.from('bonus_questions').select('id', { count: 'exact', head: true }),
      supabase.from('announcements').select('*').order('created_at', { ascending: false }).limit(3),
      supabase.from('user_standings').select('id, total_points').order('total_points', { ascending: false }).order('exact_count', { ascending: false }).order('full_name')
    ])

    const labels = ['rounds', 'match_predictions', 'group_predictions', 'bonus_predictions', 'matches', 'groups', 'bonus_questions', 'announcements', 'user_standings']
    results.forEach((r, i) => {
      if (r.status === 'rejected') {
        console.error(`[Dashboard] Query ${labels[i]} faalde:`, r.reason)
      } else if (r.value?.error) {
        console.error(`[Dashboard] Query ${labels[i]} gaf error:`, r.value.error)
      }
    })

    const get = (idx) => results[idx].status === 'fulfilled' ? results[idx].value : { data: null, count: null }

    rounds.value = get(0).data || []
    matchPredCount.value = get(1).count || 0
    groupPredCount.value = get(2).count || 0
    bonusPredCount.value = get(3).count || 0
    totalMatches.value = get(4).count || 0
    totalGroups.value = get(5).count || 0
    totalBonus.value = get(6).count || 0
    announcements.value = get(7).data || []

    // Mijn positie in de stand
    const allStandings = get(8).data || []
    if (allStandings.length > 0 && auth.profile?.id) {
      const myIdx = allStandings.findIndex(s => s.id === auth.profile.id)
      const me = allStandings.find(s => s.id === auth.profile.id)
      myStanding.value = {
        rank: myIdx >= 0 ? myIdx + 1 : null,
        totalMembers: allStandings.length,
        totalPoints: me?.total_points || 0
      }
    }
  } catch (e) {
    console.error('[Dashboard] Algemene fout in load():', e)
  } finally {
    loading.value = false
  }
}

const nextDeadline = computed(() => {
  const future = rounds.value
    .filter((r) => r.deadline && new Date(r.deadline) > now.value)
    .sort((a, b) => new Date(a.deadline) - new Date(b.deadline))
  return future[0] || null
})

// Alle openstaande deadlines die op het EERSTKOMENDE tijdstip vallen
// (zo zien gebruikers dat R1, R2 en R8 allemaal op 11 juni 18:00 sluiten)
const upcomingDeadlines = computed(() => {
  if (!nextDeadline.value) return []
  const targetTime = new Date(nextDeadline.value.deadline).getTime()
  return rounds.value
    .filter((r) => r.deadline && new Date(r.deadline).getTime() === targetTime)
    .sort((a, b) => a.nr - b.nr)
})

const countdown = computed(() => {
  if (!nextDeadline.value) return null
  const diff = new Date(nextDeadline.value.deadline) - now.value
  if (diff <= 0) return null
  const days = Math.floor(diff / 86400000)
  const hours = Math.floor((diff % 86400000) / 3600000)
  const minutes = Math.floor((diff % 3600000) / 60000)
  const seconds = Math.floor((diff % 60000) / 1000)
  return { days, hours, minutes, seconds }
})

function roundStatus(r) {
  if (!r.deadline) return { label: 'nog niet open', cls: 'pending' }
  const deadlineDate = new Date(r.deadline)
  if (deadlineDate < now.value) return { label: 'gesloten', cls: 'closed' }
  return { label: 'open', cls: 'open' }
}

function roundProgress(r) {
  if (r.nr === 1) return { filled: matchPredCount.value, total: totalMatches.value }
  if (r.nr === 2) return { filled: groupPredCount.value, total: totalGroups.value }
  if (r.nr === 8) return { filled: bonusPredCount.value, total: totalBonus.value }
  return null
}

function roundRoute(r) {
  if (r.nr === 1) return '/voorspellen/poules'
  if (r.nr === 2) return '/voorspellen/eindstanden'
  if (r.nr === 8) return '/voorspellen/bonusvragen'
  return null
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Welkom terug</p>
    <h1>Hoi {{ firstName }}.</h1>

    <div v-if="loading" class="muted">Laden…</div>

    <template v-else>
      <!-- Mijn stand-samenvatting -->
      <div v-if="myStanding && myStanding.rank" class="standing-summary">
        <div class="ss-rank">
          <span class="ss-label">Plek</span>
          <span class="ss-rank-num mono">{{ myStanding.rank }}</span>
          <span class="ss-of">van {{ myStanding.totalMembers }}</span>
        </div>
        <div class="ss-divider"></div>
        <div class="ss-points">
          <span class="ss-label">Puntentotaal</span>
          <span class="ss-points-num mono">{{ myStanding.totalPoints }}</span>
        </div>
        <router-link to="/stand" class="ss-link">Volledige stand →</router-link>
      </div>

      <!-- Aftelklok met alle drie de rondes die op dezelfde deadline sluiten -->
      <div v-if="countdown" class="countdown-card">
        <div class="countdown-header">
          <div class="countdown-label">Eerstvolgende deadline</div>
          <div class="countdown-deadlines">
            <span v-for="r in upcomingDeadlines" :key="r.nr" class="deadline-pill mono">
              R{{ r.nr }} {{ r.name }}
            </span>
          </div>
        </div>
        <div class="countdown-clock mono">
          <div class="clock-cell">
            <span class="num">{{ countdown.days }}</span>
            <span class="unit">d</span>
          </div>
          <div class="clock-cell">
            <span class="num">{{ countdown.hours }}</span>
            <span class="unit">u</span>
          </div>
          <div class="clock-cell">
            <span class="num">{{ String(countdown.minutes).padStart(2, '0') }}</span>
            <span class="unit">m</span>
          </div>
          <div class="clock-cell">
            <span class="num">{{ String(countdown.seconds).padStart(2, '0') }}</span>
            <span class="unit">s</span>
          </div>
        </div>
        <div v-if="upcomingDeadlines.length > 1" class="countdown-note">
          {{ upcomingDeadlines.length }} rondes sluiten tegelijk op
          {{ new Date(nextDeadline.deadline).toLocaleString('nl-NL', { weekday: 'long', day: '2-digit', month: 'long', hour: '2-digit', minute: '2-digit' }) }}
        </div>
      </div>

      <div v-else class="card" style="margin-bottom: var(--s-5)">
        <p class="muted" style="margin: 0">Geen openstaande deadlines op dit moment.</p>
      </div>

      <div v-if="announcements.length" class="ann-block" style="margin-bottom: var(--s-5)">
        <h3 style="margin-bottom: var(--s-3)">Mededelingen</h3>
        <div v-for="a in announcements" :key="a.id" class="ann-item">
          <div class="ann-title">{{ a.title }}</div>
          <div class="ann-body">{{ a.body }}</div>
          <div class="ann-meta muted mono">{{ new Date(a.created_at).toLocaleDateString('nl-NL') }}</div>
        </div>
      </div>

      <h3>Rondes</h3>
      <div class="rounds-grid">
        <div v-for="r in rounds" :key="r.nr" class="round-card">
          <div class="round-header">
            <div>
              <span class="round-num mono">R{{ r.nr }}</span>
              <strong>{{ r.name }}</strong>
            </div>
            <span class="round-status" :class="`status-${roundStatus(r).cls}`">
              {{ roundStatus(r).label }}
            </span>
          </div>

          <div v-if="roundProgress(r)" class="round-progress">
            <div class="progress-text mono">{{ roundProgress(r).filled }} / {{ roundProgress(r).total }}</div>
            <div class="progress-bar">
              <div class="progress-fill" :style="{ width: (roundProgress(r).filled / Math.max(1, roundProgress(r).total) * 100) + '%' }"></div>
            </div>
          </div>
          <div v-else class="muted" style="font-size: 0.875rem">Beschikbaar in een latere fase</div>

          <router-link v-if="roundRoute(r) && roundStatus(r).cls === 'open'" :to="roundRoute(r)" class="btn btn-primary btn-sm" style="margin-top: var(--s-3); display: inline-flex">Voorspellen →</router-link>
          <router-link v-else-if="roundRoute(r)" :to="roundRoute(r)" class="btn btn-secondary btn-sm" style="margin-top: var(--s-3); display: inline-flex">Bekijken</router-link>
        </div>
      </div>
    </template>
  </main>
</template>

<style scoped>
/* Stand-samenvatting bovenaan */
.standing-summary {
  display: flex;
  align-items: center;
  gap: var(--s-5);
  padding: var(--s-4) var(--s-5);
  background: linear-gradient(135deg, var(--gold-soft), var(--gold));
  border-radius: var(--r-md);
  margin-bottom: var(--s-4);
  box-shadow: 0 3px 12px rgba(212, 160, 23, 0.18);
  color: var(--ink);
}
.ss-rank, .ss-points {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.ss-label {
  font-family: var(--font-mono);
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  opacity: 0.7;
}
.ss-rank-num, .ss-points-num {
  font-family: var(--font-display);
  font-size: 2rem;
  font-weight: 700;
  line-height: 1;
}
.ss-of {
  font-size: 0.8125rem;
  opacity: 0.7;
}
.ss-divider {
  width: 1px;
  height: 40px;
  background: rgba(30, 42, 30, 0.15);
}
.ss-link {
  margin-left: auto;
  color: var(--ink);
  font-weight: 600;
  font-size: 0.875rem;
  opacity: 0.8;
}
.ss-link:hover { opacity: 1; text-decoration: none; }

/* Countdown card met meerdere ronde-pills */
.countdown-card {
  background: linear-gradient(135deg, var(--field), var(--field-soft));
  color: var(--bg-card);
  border-radius: var(--r-lg);
  padding: var(--s-5) var(--s-6);
  margin-bottom: var(--s-5);
  box-shadow: 0 6px 24px rgba(31, 75, 58, 0.18);
}
.countdown-header { margin-bottom: var(--s-4); }
.countdown-label {
  font-size: 0.875rem;
  opacity: 0.85;
  margin-bottom: var(--s-3);
  letter-spacing: 0.02em;
}
.countdown-deadlines {
  display: flex;
  flex-wrap: wrap;
  gap: var(--s-2);
}
.deadline-pill {
  display: inline-flex;
  align-items: center;
  background: rgba(255, 255, 255, 0.18);
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.02em;
}
.countdown-note {
  font-size: 0.8125rem;
  opacity: 0.8;
  margin-top: var(--s-3);
  font-style: italic;
}
.countdown-clock { display: flex; gap: var(--s-4); }
.clock-cell { display: flex; flex-direction: column; align-items: flex-start; line-height: 1; }
.clock-cell .num {
  font-family: var(--font-display);
  font-size: 2.75rem;
  font-weight: 600;
  font-variation-settings: "opsz" 144;
  letter-spacing: -0.02em;
  line-height: 1;
}
.clock-cell .unit {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  opacity: 0.75;
  margin-top: 4px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.ann-item {
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-md);
  padding: var(--s-3) var(--s-4);
  margin-bottom: var(--s-2);
}
.ann-title { font-weight: 600; margin-bottom: 2px; }
.ann-body { font-size: 0.9375rem; color: var(--ink-soft); }
.ann-meta { font-size: 0.6875rem; margin-top: var(--s-2); }
.rounds-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: var(--s-3); }
.round-card { background: var(--bg-card); border: 1px solid var(--line); border-radius: var(--r-md); padding: var(--s-4); }
.round-header { display: flex; justify-content: space-between; align-items: center; gap: var(--s-2); margin-bottom: var(--s-3); }
.round-num {
  background: var(--bg-elev);
  padding: 2px 8px;
  border-radius: var(--r-sm);
  font-size: 0.6875rem;
  font-weight: 700;
  margin-right: var(--s-2);
  color: var(--ink-soft);
}
.round-status {
  font-family: var(--font-mono);
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  padding: 2px 8px;
  border-radius: 999px;
}
.status-open { background: #ebf4e1; color: var(--ok); }
.status-closed { background: var(--bg-elev); color: var(--ink-mute); }
.status-pending { background: #fbf3dc; color: var(--warn); }
.round-progress { margin-top: var(--s-3); }
.progress-text { font-size: 0.8125rem; color: var(--ink-soft); margin-bottom: 6px; }
.progress-bar { height: 6px; background: var(--bg-elev); border-radius: 3px; overflow: hidden; }
.progress-fill { height: 100%; background: var(--field); transition: width 0.3s; }
</style>
