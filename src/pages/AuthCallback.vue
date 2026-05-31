<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const state = ref('success') // 'success' | 'error'
const errorDetail = ref('')

onMounted(() => {
  // Supabase zet fouten in de hash (#error=...&error_description=...),
  // soms in de query (?error=...). Een geslaagde bevestiging komt terug
  // met ?code=...  — die hoeven we niet in te wisselen: de e-mail is op dat
  // moment al server-side bevestigd. We tonen alleen het resultaat.
  const hash = new URLSearchParams(window.location.hash.replace(/^#/, ''))
  const query = new URLSearchParams(window.location.search)

  const err =
    hash.get('error') || query.get('error') ||
    hash.get('error_code') || query.get('error_code')

  if (err) {
    state.value = 'error'
    const desc = hash.get('error_description') || query.get('error_description') || ''
    errorDetail.value = decodeURIComponent(desc.replace(/\+/g, ' '))
  } else {
    state.value = 'success'
  }

  // Adresbalk opschonen: code/tokens/fout uit de URL halen.
  if (window.history?.replaceState) {
    window.history.replaceState({}, document.title, '/auth/callback')
  }
})

function goToLogin() {
  router.push({ name: 'login' })
}
</script>

<template>
  <main class="page page-narrow">
    <p class="eyebrow">Account · bevestiging</p>

    <template v-if="state === 'success'">
      <h1>Je account is bevestigd! 🎉</h1>
      <div class="card stack">
        <h3>Top, dat is gelukt.</h3>
        <p>
          Je e-mailadres is bevestigd. Log nu in met je e-mailadres en wachtwoord
          om verder te gaan.
        </p>
        <p class="muted">
          Na het inloggen sta je nog op <strong>in afwachting</strong> totdat de
          beheerder je inleg heeft bevestigd — daarna kun je voorspellen.
        </p>
        <button class="btn btn-primary" style="width: 100%" @click="goToLogin">
          Naar inloggen
        </button>
      </div>
    </template>

    <template v-else>
      <h1>Hm, dat lukte net niet.</h1>
      <div class="card stack">
        <h3>De bevestigingslink werkt niet meer</h3>
        <p>
          Waarschijnlijk is de link verlopen of al een keer gebruikt. Geen zorgen —
          je kunt je gewoon opnieuw aanmelden, dan sturen we een nieuwe mail.
        </p>
        <div v-if="errorDetail" class="alert alert-error">{{ errorDetail }}</div>
        <button class="btn btn-primary" style="width: 100%" @click="goToLogin">
          Terug naar inloggen
        </button>
      </div>
    </template>
  </main>
</template>
