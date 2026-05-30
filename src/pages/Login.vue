<script setup>
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth.js'
import { useRouter } from 'vue-router'

const auth = useAuthStore()
const router = useRouter()

const mode = ref('login') // 'login' | 'signup' | 'check-email'
const email = ref('')
const password = ref('')
const fullName = ref('')
const error = ref('')
const submitting = ref(false)

async function handleSubmit() {
  error.value = ''
  if (!email.value.trim()) { error.value = 'Vul je e-mailadres in.'; return }
  if (!password.value) { error.value = 'Vul je wachtwoord in.'; return }
  if (password.value.length < 6) { error.value = 'Wachtwoord is minstens 6 tekens.'; return }
  if (mode.value === 'signup' && !fullName.value.trim()) {
    error.value = 'Vul je naam in zodat de beheerder weet wie je bent.'
    return
  }

  submitting.value = true
  try {
    if (mode.value === 'signup') {
      await auth.signUp(email.value.trim(), password.value, fullName.value.trim())
      // Altijd naar check-email screen tonen. Email confirmation staat aan in
      // Supabase, dus de gebruiker MOET sowieso eerst klikken op de
      // bevestigingslink — ongeacht of we hier een session krijgen of niet.
      mode.value = 'check-email'
    } else {
      await auth.signInWithPassword(email.value.trim(), password.value)
      router.push(auth.isActive ? '/' : '/wachten')
    }
  } catch (e) {
    error.value = humanizeError(e.message)
  } finally {
    submitting.value = false
  }
}

function humanizeError(msg) {
  if (!msg) return 'Er ging iets mis. Probeer het opnieuw.'
  if (msg.includes('Invalid login credentials')) return 'E-mail of wachtwoord klopt niet — óf je e-mail is nog niet bevestigd via de mail die je hebt gekregen.'
  if (msg.includes('User already registered')) return 'Dit e-mailadres heeft al een account. Klik op "Inloggen".'
  if (msg.includes('Password should be')) return 'Wachtwoord moet minimaal 6 tekens zijn.'
  if (msg.includes('Email not confirmed')) return 'Je moet eerst je e-mail bevestigen via de mail die je hebt gekregen.'
  if (msg.includes('rate limit')) return 'Te veel pogingen. Wacht een minuutje en probeer opnieuw.'
  return msg
}

function backToLogin() {
  mode.value = 'login'
  password.value = ''
  error.value = ''
}
</script>

<template>
  <main class="page page-narrow">
    <div class="login-hero">
      <p class="eyebrow">WK 2026 · familietoto</p>
      <h1>Fam. van der Meer WK poule 2026</h1>
      <p class="muted">
        De familietraditie, nu digitaal. Voorspel uitslagen, jaag op de pot
        en schop het tot kampioen.
      </p>
      <p class="muted" style="margin-top: var(--s-2)">
        Er zijn meerdere winnaars, zo blijft het leuk voor iedereen!
      </p>
      <div class="cost-pill">
        <span class="cost-label">Inleg</span>
        <span class="cost-amount">€ 10,-</span>
        <span class="cost-note">per persoon</span>
      </div>
    </div>

    <!-- Check-mail scherm na signup -->
    <div class="card" v-if="mode === 'check-email'">
      <h3>Check je mail 📬</h3>
      <p>
        We hebben een bevestigings-mail gestuurd naar <strong>{{ email }}</strong>.
        Klik op de link in die mail om je account te activeren.
      </p>
      <p class="muted" style="margin-top: var(--s-4)">
        Geen mail ontvangen? Kijk in je spamfolder. Of
        <a href="#" @click.prevent="backToLogin">probeer opnieuw aan te melden</a>.
      </p>
    </div>

    <!-- Login + signup formulier -->
    <div class="card" v-else>
      <div class="row-between" style="margin-bottom: var(--s-5)">
        <button
          type="button"
          class="btn btn-sm"
          :class="mode === 'login' ? 'btn-primary' : 'btn-secondary'"
          @click="mode = 'login'; error = ''"
        >Inloggen</button>
        <button
          type="button"
          class="btn btn-sm"
          :class="mode === 'signup' ? 'btn-primary' : 'btn-secondary'"
          @click="mode = 'signup'; error = ''"
        >Account aanmaken</button>
      </div>

      <form @submit.prevent="handleSubmit">
        <div v-if="mode === 'signup'" class="field">
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
        </div>

        <div class="field">
          <label for="password">Wachtwoord</label>
          <input
            id="password"
            v-model="password"
            type="password"
            :autocomplete="mode === 'signup' ? 'new-password' : 'current-password'"
            placeholder="Minimaal 6 tekens"
            required
          />
          <span v-if="mode === 'signup'" class="hint">
            Kies iets dat je makkelijk onthoudt.
          </span>
        </div>

        <div v-if="error" class="alert alert-error">{{ error }}</div>

        <button
          type="submit"
          class="btn btn-primary"
          style="width: 100%"
          :disabled="submitting"
        >
          {{ submitting ? 'Even geduld…' : (mode === 'signup' ? 'Account aanmaken' : 'Inloggen') }}
        </button>
      </form>

      <p v-if="mode === 'login'" class="muted" style="margin-top: var(--s-4); font-size: 0.875rem; text-align: center">
        Wachtwoord vergeten? Vraag de beheerder om 'm te resetten.
      </p>
    </div>
  </main>
</template>

<style scoped>
.login-hero { text-align: center; margin-bottom: var(--s-7); }
.login-hero p.muted { max-width: 36ch; margin-left: auto; margin-right: auto; }

.cost-pill {
  display: inline-flex;
  align-items: baseline;
  gap: 8px;
  margin-top: var(--s-4);
  padding: 8px 16px;
  background: rgba(212, 160, 23, 0.12);
  border: 1px solid rgba(212, 160, 23, 0.3);
  border-radius: 999px;
  font-size: 0.875rem;
}
.cost-label {
  font-family: var(--font-mono);
  font-size: 0.6875rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--ink-mute);
}
.cost-amount {
  font-family: var(--font-mono);
  font-size: 1rem;
  font-weight: 700;
  color: #b8861a;
}
.cost-note { color: var(--ink-soft); font-size: 0.8125rem; }

@media (max-width: 640px) {
  .login-hero { margin-bottom: var(--s-5); }
}
</style>
