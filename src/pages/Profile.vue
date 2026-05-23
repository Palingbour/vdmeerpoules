<script setup>
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth.js'

const auth = useAuthStore()

const fullName = ref(auth.profile?.full_name || '')
const saving = ref(false)
const saved = ref(false)
const error = ref('')

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
        <span
          class="badge"
          :class="auth.profile?.status === 'active' ? 'badge-active' : 'badge-pending'"
        >
          {{ auth.profile?.status === 'active' ? 'Actief' : 'In afwachting' }}
        </span>
        <span v-if="auth.isAdmin" class="badge badge-admin">Beheerder</span>
      </div>

      <div v-if="auth.profile?.paid_at" class="muted">
        Inleg geregistreerd op
        <span class="mono">{{ new Date(auth.profile.paid_at).toLocaleDateString('nl-NL') }}</span>
      </div>

      <div v-if="error" class="alert alert-error">{{ error }}</div>
      <div v-if="saved" class="alert alert-success">Opgeslagen.</div>

      <button class="btn btn-primary" @click="save" :disabled="saving">
        {{ saving ? 'Opslaan…' : 'Opslaan' }}
      </button>
    </div>
  </main>
</template>
