<script setup>
import { ref, computed } from 'vue'
import { useAuthStore } from '../stores/auth.js'

const auth = useAuthStore()

const editingName = computed(() => !auth.profile?.full_name?.trim())
const nameInput = ref('')
const saving = ref(false)
const error = ref('')

async function saveName() {
  if (!nameInput.value.trim()) {
    error.value = 'Vul je naam in.'
    return
  }
  saving.value = true
  error.value = ''
  try {
    await auth.updateProfile({ full_name: nameInput.value.trim() })
  } catch (e) {
    error.value = e.message || 'Opslaan mislukt.'
  } finally {
    saving.value = false
  }
}

async function handleLogout() {
  await auth.signOut()
}
</script>

<template>
  <main class="page page-narrow">
    <p class="eyebrow">Status · in afwachting</p>
    <h1>Bijna binnen.</h1>

    <div class="card stack">
      <template v-if="editingName">
        <h3>Eerst nog even — wie ben jij?</h3>
        <p class="muted">
          De beheerder ziet straks in het overzicht aan wie hij goedkeuring moet
          geven. Een herkenbare naam helpt.
        </p>

        <div class="field">
          <label for="name">Je naam</label>
          <input
            id="name"
            v-model="nameInput"
            type="text"
            autocomplete="name"
            placeholder="Bijv. Ronald van der Meer"
          />
        </div>

        <div v-if="error" class="alert alert-error">{{ error }}</div>

        <button
          class="btn btn-primary"
          @click="saveName"
          :disabled="saving"
        >
          {{ saving ? 'Opslaan…' : 'Opslaan' }}
        </button>
      </template>

      <template v-else>
        <h3>Hoi {{ auth.profile?.full_name?.split(' ')[0] }} — je bent ingelogd.</h3>
        <p>
          Je aanmelding staat klaar. Zodra de beheerder je hebt goedgekeurd en de
          inleg van <strong>€5</strong> heeft ontvangen, krijg je toegang tot de
          voorspellingen en de stand.
        </p>

        <div class="alert alert-info">
          <strong>Inleg overmaken:</strong> €5 via Tikkie / bankoverschrijving
          (vraag de beheerder om de gegevens als je die nog niet hebt).
        </div>

        <p class="muted">
          Deze pagina ververst zich automatisch zodra je bent goedgekeurd —
          je hoeft hier niet te blijven zitten. Je krijgt ook een mail.
        </p>

        <div class="row" style="margin-top: var(--s-3)">
          <button class="btn btn-secondary btn-sm" @click="handleLogout">
            Uitloggen
          </button>
        </div>
      </template>
    </div>
  </main>
</template>
