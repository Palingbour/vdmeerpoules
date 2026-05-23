<script setup>
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth.js'

const auth = useAuthStore()

const email = ref('')
const fullName = ref('')
const isFirstTime = ref(false)
const sent = ref(false)
const error = ref('')

async function handleSubmit() {
  error.value = ''
  if (!email.value.trim()) {
    error.value = 'Vul je e-mailadres in.'
    return
  }
  if (isFirstTime.value && !fullName.value.trim()) {
    error.value = 'Vul je naam in zodat de beheerder weet wie je bent.'
    return
  }
  try {
    await auth.signInWithMagicLink(
      email.value.trim(),
      isFirstTime.value ? fullName.value.trim() : null
    )
    sent.value = true
  } catch (e) {
    error.value = e.message || 'Er ging iets mis. Probeer het opnieuw.'
  }
}
</script>

<template>
  <main class="page page-narrow">
    <div class="login-hero">
      <p class="eyebrow">WK 2026 · familietoto</p>
      <h1>Van der Meer Poules</h1>
      <p class="muted">
        De familietraditie sinds 2012, nu digitaal. Voorspel
        uitslagen, jaag op de pot, schop de neef van zijn troon.
      </p>
    </div>

    <div class="card" v-if="!sent">
      <div class="row-between" style="margin-bottom: var(--s-5)">
        <button
          type="button"
          class="btn btn-sm"
          :class="!isFirstTime ? 'btn-primary' : 'btn-secondary'"
          @click="isFirstTime = false"
        >
          Ik doe al mee
        </button>
        <button
          type="button"
          class="btn btn-sm"
          :class="isFirstTime ? 'btn-primary' : 'btn-secondary'"
          @click="isFirstTime = true"
        >
          Voor het eerst
        </button>
      </div>

      <form @submit.prevent="handleSubmit">
        <div v-if="isFirstTime" class="field">
          <label for="name">Hoe heet je?</label>
          <input
            id="name"
            v-model="fullName"
            type="text"
            autocomplete="name"
            placeholder="Bijv. Ronald van der Meer"
          />
          <span class="hint">Zodat de beheerder weet wie je bent bij goedkeuring.</span>
        </div>

        <div class="field">
          <label for="email">E-mailadres</label>
          <input
            id="email"
            v-model="email"
            type="email"
            autocomplete="email"
            placeholder="naam@voorbeeld.nl"
            required
          />
          <span class="hint">Je ontvangt een inloglink, geen wachtwoord nodig.</span>
        </div>

        <div v-if="error" class="alert alert-error">{{ error }}</div>

        <button
          type="submit"
          class="btn btn-primary"
          style="width: 100%"
          :disabled="auth.loading"
        >
          {{ auth.loading ? 'Even geduld…' : 'Stuur me een inloglink' }}
        </button>
      </form>
    </div>

    <div class="card" v-else>
      <h3>Check je mail</h3>
      <p>
        We hebben een inloglink gestuurd naar
        <strong>{{ email }}</strong>. Klik op de link in de mail
        om in te loggen. De link werkt eenmalig en verloopt na een uur.
      </p>
      <p class="muted" style="margin-top: var(--s-4)">
        Geen mail ontvangen? Kijk in je spamfolder, of
        <a href="#" @click.prevent="sent = false">probeer opnieuw</a>.
      </p>
    </div>
  </main>
</template>

<style scoped>
.login-hero {
  text-align: center;
  margin-bottom: var(--s-7);
}
.login-hero p.muted {
  max-width: 36ch;
  margin-left: auto;
  margin-right: auto;
}
</style>
