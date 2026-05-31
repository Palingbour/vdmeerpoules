<script setup>
import { ref, onMounted, computed } from 'vue'
import { useAuthStore } from '../stores/auth.js'
import { supabase } from '../lib/supabase.js'

const auth = useAuthStore()

const fullName = ref(auth.profile?.full_name || '')
const saving = ref(false)
const saved = ref(false)
const error = ref('')

const paymentSettings = ref(null)
const loadingPayment = ref(true)

async function loadPaymentSettings() {
  loadingPayment.value = true
  const { data, error: err } = await supabase
    .from('payment_settings')
    .select('*')
    .eq('id', 1)
    .maybeSingle()
  if (!err) paymentSettings.value = data
  loadingPayment.value = false
}

async function save() {
  error.value = ''
  saved.value = false
  if (!fullName.value.trim()) {
    error.value = 'Naam mag niet leeg zijn.'
    return
  }
  saving.value = true
  try {
    await auth.updateProfile({ full_name: fullName.value.trim() })
    saved.value = true
  } catch (e) {
    error.value = e.message
  } finally {
    saving.value = false
  }
}

const statusLabel = computed(() => {
  if (auth.profile?.status === 'active') return 'Actief'
  if (auth.profile?.status === 'awaiting_payment') return 'Wacht op betaling'
  return 'Inactief'
})

const statusClass = computed(() => {
  if (auth.profile?.status === 'active') return 'badge-active'
  if (auth.profile?.status === 'awaiting_payment') return 'badge-pending'
  return 'badge-inactive'
})

onMounted(() => {
  loadPaymentSettings()
  // Direct scrollen naar betaalsectie als URL hash #betaling bevat
  if (window.location.hash === '#betaling') {
    setTimeout(() => {
      document.getElementById('betaling')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }, 200)
  }
})
</script>

<template>
  <main class="page page-narrow">
    <p class="eyebrow">Mijn gegevens</p>
    <h1>Profiel</h1>

    <div class="card stack">
      <div class="field">
        <label>E-mailadres</label>
        <input :value="auth.profile?.email" type="email" disabled />
        <span class="hint">Dit adres gebruik je om in te loggen.</span>
      </div>

      <div class="field">
        <label for="full_name">Naam</label>
        <input
          id="full_name"
          v-model="fullName"
          type="text"
          autocomplete="name"
        />
      </div>

      <div class="row" style="gap: var(--s-3)">
        <span class="muted">Status:</span>
        <span class="badge" :class="statusClass">{{ statusLabel }}</span>
        <span v-if="auth.isAdmin" class="badge badge-admin">Beheerder</span>
      </div>

      <div v-if="error" class="alert alert-error">{{ error }}</div>
      <div v-if="saved" class="alert alert-success">Opgeslagen.</div>

      <button class="btn btn-primary" @click="save" :disabled="saving">
        {{ saving ? 'Opslaan…' : 'Opslaan' }}
      </button>
    </div>

    <!-- BETAALSECTIE — alleen tonen voor awaiting_payment users -->
    <div v-if="auth.isAwaitingPayment" id="betaling" class="card payment-card">
      <h2 style="margin-top: 0">💸 Betaling</h2>

      <div v-if="loadingPayment" class="muted">Laden…</div>

      <template v-else>
        <p>
          Om officieel mee te tellen in de stand, voldoe je de inleg van
          <strong>{{ paymentSettings?.amount || '€ 5,-' }}</strong>.
        </p>

        <p class="muted instructions">{{ paymentSettings?.instructions || 'Maak het bedrag over via Tikkie of bankoverschrijving aan de beheerder.' }}</p>

        <!-- Betaallink: opent op mobiel direct de bankapp -->
        <div v-if="paymentSettings?.payment_link" class="paylink-block">
          <p v-if="paymentSettings?.payment_text" class="paylink-text">
            {{ paymentSettings.payment_text }}
          </p>
          <a :href="paymentSettings.payment_link" target="_blank" rel="noopener" class="btn btn-primary paylink-btn">
            Betaal {{ paymentSettings?.amount || '€ 10,-' }} via je bankapp →
          </a>
          <p class="muted paylink-hint">
            Op je telefoon opent de knop direct je bank. Zit je op een computer?
            Scan dan de QR-code hieronder met je telefoon.
          </p>
        </div>

        <div v-if="paymentSettings?.qr_image_data" class="qr-container">
          <img :src="paymentSettings.qr_image_data" alt="QR-code voor betaling" class="qr-image" />
          <p class="muted" style="text-align: center; font-size: 0.8125rem; margin-top: var(--s-2)">
            Scan deze QR-code met je telefoon
          </p>
        </div>
        <div v-else class="muted" style="font-style: italic">
          De beheerder heeft nog geen QR-code geüpload. Neem contact op met
          de beheerder voor betaalinstructies.
        </div>

        <div class="payment-note">
          <strong>Na betaling:</strong> de beheerder activeert je account
          handmatig. Je voorspellingen die je nu al invult blijven bewaard
          en tellen mee zodra je geactiveerd bent.
        </div>
      </template>
    </div>

    <!-- Voor actieve gebruikers: korte bevestiging -->
    <div v-else-if="auth.isActive" class="card" style="background: rgba(45, 128, 69, 0.05); margin-top: var(--s-5)">
      <p style="margin: 0">
        ✓ Je inleg is bevestigd. Je doet officieel mee aan de toto.
      </p>
    </div>
  </main>
</template>

<style scoped>
.payment-card {
  margin-top: var(--s-5);
  border-left: 4px solid var(--accent, #d4561d);
}
.instructions {
  white-space: pre-wrap;
  line-height: 1.5;
}
.qr-container {
  margin: var(--s-4) 0;
  padding: var(--s-4);
  background: white;
  border: 1px solid var(--line);
  border-radius: var(--r-md);
  text-align: center;
}
.qr-image {
  max-width: 280px;
  width: 100%;
  height: auto;
  border-radius: var(--r-sm);
}
.payment-note {
  background: var(--bg-elev);
  padding: var(--s-3) var(--s-4);
  border-radius: var(--r-sm);
  margin-top: var(--s-3);
  font-size: 0.875rem;
  line-height: 1.5;
}

/* Betaallink-blok */
.paylink-block {
  margin: var(--s-4) 0;
  padding: var(--s-4);
  background: rgba(45, 128, 69, 0.06);
  border: 1px solid rgba(45, 128, 69, 0.25);
  border-radius: var(--r-md);
}
.paylink-text {
  margin: 0 0 var(--s-3);
  font-size: 0.9375rem;
  line-height: 1.5;
}
.paylink-btn {
  display: block;
  width: 100%;
  text-align: center;
  font-size: 1.0625rem;
  padding: 14px 20px;
}
.paylink-hint {
  margin: var(--s-3) 0 0;
  font-size: 0.8125rem;
  line-height: 1.4;
}
.badge-pending { background: var(--accent, #d4561d); color: white; }
.badge-inactive { background: var(--ink-mute); color: white; }

@media (max-width: 640px) {
  .qr-image {
    max-width: 220px;
  }
  .qr-container {
    padding: var(--s-3);
  }
  .payment-card {
    margin-top: var(--s-4);
  }
}
</style>
