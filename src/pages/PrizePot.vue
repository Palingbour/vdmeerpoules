<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../lib/supabase.js'
import { useAuthStore } from '../stores/auth.js'

const auth = useAuthStore()

const config = ref(null)
const paidCount = ref(0)
const winners = ref([])          // [{slot_type, slot_key, profile_id, winner_name}]
const participants = ref([])     // admin: keuzelijst
const loading = ref(true)
const savingInleg = ref(false)
const inlegInput = ref('')

const isAdmin = computed(() => auth.isAdmin)

const euro = (n) =>
  new Intl.NumberFormat('nl-NL', { style: 'currency', currency: 'EUR' }).format(n || 0)

const roundNames = {
  1: 'Poulewedstrijden', 2: 'Eindklassering poules', 3: 'Zestiende finales',
  4: 'Achtste finales', 5: 'Kwartfinales', 6: 'Halve finales',
  7: 'Finale', 8: 'Bonusvragen'
}
const placeNames = { 1: '1e plaats', 2: '2e plaats', 3: '3e plaats', 4: '4e plaats', 5: '5e plaats' }

async function load() {
  loading.value = true
  try {
    const [cfg, cnt, win] = await Promise.all([
      supabase.from('prize_pot_config').select('*').eq('id', 1).single(),
      supabase.rpc('paid_participant_count'),
      supabase.from('prize_winners').select('slot_type, slot_key, profile_id, winner_name')
    ])
    if (cfg.error) console.error('[Prijzenpot] config:', cfg.error)
    config.value = cfg.data
    inlegInput.value = cfg.data?.inleg_per_person ?? ''
    paidCount.value = (typeof cnt.data === 'number' ? cnt.data : 0)
    winners.value = win.data || []

    if (isAdmin.value) {
      const { data } = await supabase
        .from('profiles')
        .select('id, full_name, status')
        .neq('status', 'inactive')
        .order('full_name')
      participants.value = data || []
    }
  } finally {
    loading.value = false
  }
}
onMounted(load)

// ---- afgeleide bedragen --------------------------------------------------
const inleg = computed(() => Number(config.value?.inleg_per_person ?? 0))
const pot = computed(() => paidCount.value * inleg.value)
const roundsPot = computed(() => pot.value * (config.value?.pct_rounds ?? 40) / 100)
const perRound = computed(() => roundsPot.value / 8)
const standingsPot = computed(() => pot.value * (config.value?.pct_standings ?? 60) / 100)

const useLarge = computed(() => paidCount.value >= (config.value?.top_threshold ?? 25))
const splitPcts = computed(() => {
  const s = useLarge.value ? config.value?.split_large : config.value?.split_small
  return Array.isArray(s) ? s : (useLarge.value ? [35, 25, 15, 15, 10] : [50, 30, 20])
})
const standingPrizes = computed(() =>
  splitPcts.value.map((pct, i) => ({ place: i + 1, amount: standingsPot.value * pct / 100, pct }))
)

function winnerName(slotType, slotKey) {
  const w = winners.value.find((x) => x.slot_type === slotType && x.slot_key === slotKey)
  return w?.winner_name || null
}
function winnerProfileId(slotType, slotKey) {
  const w = winners.value.find((x) => x.slot_type === slotType && x.slot_key === slotKey)
  return w?.profile_id || ''
}

// ---- admin-acties --------------------------------------------------------
async function saveInleg() {
  if (!isAdmin.value) return
  const val = Number(inlegInput.value)
  if (isNaN(val) || val < 0) return
  savingInleg.value = true
  try {
    const { error } = await supabase
      .from('prize_pot_config')
      .update({ inleg_per_person: val, updated_at: new Date().toISOString() })
      .eq('id', 1)
    if (error) throw error
    if (config.value) config.value.inleg_per_person = val
  } catch (e) {
    console.error('[Prijzenpot] inleg opslaan:', e)
    alert('Opslaan van het inlegbedrag is niet gelukt.')
  } finally {
    savingInleg.value = false
  }
}

async function setWinner(slotType, slotKey, profileId) {
  if (!isAdmin.value) return
  const person = participants.value.find((p) => p.id === profileId)
  const patch = {
    profile_id: profileId || null,
    winner_name: person ? person.full_name : null,
    updated_at: new Date().toISOString()
  }
  const { error } = await supabase
    .from('prize_winners')
    .update(patch)
    .eq('slot_type', slotType)
    .eq('slot_key', slotKey)
  if (error) {
    console.error('[Prijzenpot] winnaar opslaan:', error)
    alert('Opslaan van de winnaar is niet gelukt.')
    return
  }
  // lokaal bijwerken
  const w = winners.value.find((x) => x.slot_type === slotType && x.slot_key === slotKey)
  if (w) { w.profile_id = patch.profile_id; w.winner_name = patch.winner_name }
}

function onWinnerChange(slotType, slotKey, ev) {
  setWinner(slotType, slotKey, ev.target.value)
}
</script>

<template>
  <main class="page">
    <p class="eyebrow">Prijzenpot</p>
    <h1>De pot &amp; de verdeling</h1>

    <div v-if="loading" class="muted">Laden…</div>

    <template v-else>
      <!-- Pot-hero -->
      <div class="pot-hero">
        <div class="pot-main">
          <span class="pot-label">Totale prijzenpot</span>
          <span class="pot-amount mono">{{ euro(pot) }}</span>
          <span class="pot-sub">
            {{ paidCount }} betaalde deelnemer{{ paidCount === 1 ? '' : 's' }} × {{ euro(inleg) }}
          </span>
        </div>
        <div class="pot-split">
          <div class="split-row">
            <span class="mono">{{ config?.pct_rounds ?? 40 }}%</span>
            <span>rondeprijzen</span>
            <span class="mono">{{ euro(roundsPot) }}</span>
          </div>
          <div class="split-row">
            <span class="mono">{{ config?.pct_standings ?? 60 }}%</span>
            <span>eindstand</span>
            <span class="mono">{{ euro(standingsPot) }}</span>
          </div>
        </div>
      </div>

      <p class="muted" style="margin-bottom: var(--s-5)">
        100% van de inleg wordt uitgekeerd. Een rondeprijs gaat naar de hoogste
        score van die ronde die nog géén rondeprijs heeft gewonnen — heeft die
        speler al een ronde gewonnen, dan schuift de prijs door naar de
        nummer twee.
      </p>

      <!-- Admin: inleg instellen -->
      <div v-if="isAdmin" class="admin-box">
        <div class="admin-box-title mono">Beheer · inleg</div>
        <div class="inleg-row">
          <label for="inleg">Inleg per persoon (€)</label>
          <input id="inleg" v-model="inlegInput" type="number" min="0" step="0.50" class="inleg-input" />
          <button class="btn btn-primary btn-sm" :disabled="savingInleg" @click="saveInleg">
            {{ savingInleg ? 'Opslaan…' : 'Opslaan' }}
          </button>
        </div>
        <p class="muted" style="font-size: 0.8125rem; margin: var(--s-2) 0 0">
          Kies hieronder per ronde en plek de winnaar. Aanpassen kan altijd.
          Verdeel-percentages staan in <span class="mono">prize_pot_config</span>.
        </p>
      </div>

      <!-- Rondeprijzen -->
      <h3>Rondeprijzen ({{ config?.pct_rounds ?? 40 }}%)</h3>
      <div class="prize-list">
        <div v-for="nr in 8" :key="'r' + nr" class="prize-row">
          <span class="prize-slot mono">R{{ nr }}</span>
          <span class="prize-name">{{ roundNames[nr] }}</span>
          <span class="prize-amount mono">{{ euro(perRound) }}</span>
          <span class="prize-winner">
            <template v-if="isAdmin">
              <select class="winner-select" :value="winnerProfileId('round', nr)"
                      @change="(e) => onWinnerChange('round', nr, e)">
                <option value="">— nog niet bekend —</option>
                <option v-for="p in participants" :key="p.id" :value="p.id">{{ p.full_name }}</option>
              </select>
            </template>
            <template v-else>
              <span v-if="winnerName('round', nr)" class="winner-badge">🏆 {{ winnerName('round', nr) }}</span>
              <span v-else class="muted">nog niet bekend</span>
            </template>
          </span>
        </div>
      </div>

      <!-- Eindstand -->
      <h3 style="margin-top: var(--s-6)">
        Eindstand ({{ config?.pct_standings ?? 60 }}%) — top {{ standingPrizes.length }}
      </h3>
      <div class="prize-list">
        <div v-for="sp in standingPrizes" :key="'s' + sp.place" class="prize-row">
          <span class="prize-slot mono">{{ sp.place }}e</span>
          <span class="prize-name">{{ placeNames[sp.place] }} <span class="muted">({{ sp.pct }}%)</span></span>
          <span class="prize-amount mono">{{ euro(sp.amount) }}</span>
          <span class="prize-winner">
            <template v-if="isAdmin">
              <select class="winner-select" :value="winnerProfileId('standing', sp.place)"
                      @change="(e) => onWinnerChange('standing', sp.place, e)">
                <option value="">— nog niet bekend —</option>
                <option v-for="p in participants" :key="p.id" :value="p.id">{{ p.full_name }}</option>
              </select>
            </template>
            <template v-else>
              <span v-if="winnerName('standing', sp.place)" class="winner-badge">🏆 {{ winnerName('standing', sp.place) }}</span>
              <span v-else class="muted">nog niet bekend</span>
            </template>
          </span>
        </div>
      </div>

      <p class="muted footer-note">
        De top {{ standingPrizes.length }} geldt bij
        {{ useLarge ? config?.top_threshold + ' of meer' : 'minder dan ' + (config?.top_threshold ?? 25) }}
        deelnemers. Bedragen schalen automatisch mee met de pot.
      </p>

      <router-link to="/stand" class="back-link">← Naar de stand</router-link>
    </template>
  </main>
</template>

<style scoped>
.pot-hero {
  background: linear-gradient(135deg, var(--gold-soft, #f0d98a), var(--gold, #d4a017));
  color: var(--ink, #1e2a1e);
  border-radius: var(--r-lg);
  padding: var(--s-5) var(--s-6);
  margin-bottom: var(--s-4);
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: var(--s-5);
  box-shadow: 0 6px 24px rgba(212, 160, 23, 0.2);
  flex-wrap: wrap;
}
.pot-main { display: flex; flex-direction: column; gap: 2px; }
.pot-label {
  font-family: var(--font-mono); font-size: 0.6875rem; font-weight: 700;
  letter-spacing: 0.08em; text-transform: uppercase; opacity: 0.7;
}
.pot-amount { font-family: var(--font-display); font-size: 2.75rem; font-weight: 700; line-height: 1; }
.pot-sub { font-size: 0.8125rem; opacity: 0.75; }
.pot-split { display: flex; flex-direction: column; gap: var(--s-2); min-width: 220px; }
.split-row {
  display: grid; grid-template-columns: 48px 1fr auto; gap: var(--s-2);
  align-items: baseline; font-size: 0.9375rem;
  padding: 6px 10px; background: rgba(255,255,255,0.35); border-radius: var(--r-sm);
}

.admin-box {
  background: var(--bg-elev, #f4f1e8); border: 1px dashed var(--line, #d8d2c2);
  border-radius: var(--r-md); padding: var(--s-4); margin-bottom: var(--s-5);
}
.admin-box-title {
  font-size: 0.6875rem; font-weight: 700; letter-spacing: 0.06em;
  text-transform: uppercase; color: var(--ink-mute); margin-bottom: var(--s-3);
}
.inleg-row { display: flex; align-items: center; gap: var(--s-3); flex-wrap: wrap; }
.inleg-input {
  width: 110px; padding: 8px 10px; border: 1px solid var(--line);
  border-radius: var(--r-sm); font-family: var(--font-mono);
}

.prize-list {
  background: var(--bg-card); border: 1px solid var(--line);
  border-radius: var(--r-md); overflow: hidden;
}
.prize-row {
  display: grid;
  grid-template-columns: 44px 1fr auto minmax(150px, 1.2fr);
  gap: var(--s-3); align-items: center;
  padding: var(--s-3) var(--s-4);
  border-bottom: 1px solid var(--line-soft, #ececec);
}
.prize-row:last-child { border-bottom: none; }
.prize-slot {
  background: var(--bg-elev); padding: 2px 8px; border-radius: var(--r-sm);
  font-size: 0.6875rem; font-weight: 700; color: var(--ink-soft); text-align: center;
}
.prize-name { font-size: 0.9375rem; }
.prize-amount { font-weight: 700; text-align: right; color: #b8861a; }
.prize-winner { text-align: right; }
.winner-badge { font-weight: 600; font-size: 0.9rem; }
.winner-select {
  width: 100%; max-width: 220px; padding: 6px 8px;
  border: 1px solid var(--line); border-radius: var(--r-sm);
  font-size: 0.875rem; background: var(--bg-card);
}
.footer-note {
  padding: var(--s-3) 0; font-size: 0.8125rem; margin: var(--s-3) 0 0;
}
.back-link {
  display: inline-block; margin-top: var(--s-4);
  color: var(--field, #1f4b3a); font-weight: 600; font-size: 0.9375rem;
}
.back-link:hover { text-decoration: none; opacity: 0.8; }

@media (max-width: 640px) {
  .pot-hero { flex-direction: column; align-items: flex-start; padding: var(--s-4); }
  .pot-split { width: 100%; }
  .prize-row {
    grid-template-columns: 40px 1fr auto;
    grid-template-areas: "slot name amount" "win win win";
    row-gap: var(--s-2);
  }
  .prize-slot { grid-area: slot; }
  .prize-name { grid-area: name; }
  .prize-amount { grid-area: amount; }
  .prize-winner { grid-area: win; text-align: left; }
  .winner-select { max-width: none; }
}
</style>
