<script setup>
import { ref, onMounted, computed } from 'vue'
import { supabase } from '../../lib/supabase.js'

const settings = ref(null)
const loading = ref(true)
const saving = ref(false)
const saved = ref(false)
const error = ref('')

const amount = ref('')
const instructions = ref('')
const qrImageData = ref(null)
const fileInput = ref(null)

async function load() {
  loading.value = true
  const { data, error: err } = await supabase
    .from('payment_settings')
    .select('*')
    .eq('id', 1)
    .single()
  if (err) {
    error.value = err.message
  } else {
    settings.value = data
    amount.value = data.amount || ''
    instructions.value = data.instructions || ''
    qrImageData.value = data.qr_image_data || null
  }
  loading.value = false
}

onMounted(load)

const previewImage = computed(() => qrImageData.value)

function onFileSelected(event) {
  const file = event.target.files?.[0]
  if (!file) return

  if (!file.type.startsWith('image/')) {
    error.value = 'Selecteer een afbeeldingsbestand (PNG, JPG, etc.)'
    return
  }

  // Max ~1MB om de database niet te belasten
  if (file.size > 1024 * 1024) {
    error.value = 'Afbeelding is te groot (max 1MB). Probeer een kleinere QR-code.'
    return
  }

  const reader = new FileReader()
  reader.onload = (e) => {
    qrImageData.value = e.target.result
    error.value = ''
  }
  reader.onerror = () => {
    error.value = 'Kon bestand niet inlezen.'
  }
  reader.readAsDataURL(file)
}

function clearImage() {
  qrImageData.value = null
  if (fileInput.value) fileInput.value.value = ''
}

async function save() {
  error.value = ''
  saved.value = false
  saving.value = true
  const { error: err } = await supabase
    .from('payment_settings')
    .update({
      amount: amount.value,
      instructions: instructions.value,
      qr_image_data: qrImageData.value,
      updated_at: new Date().toISOString()
    })
    .eq('id', 1)
  saving.value = false
  if (err) {
    error.value = err.message
  } else {
    saved.value = true
    setTimeout(() => { saved.value = false }, 3000)
  }
}
</script>

<template>
  <main class="page page-narrow">
    <p class="eyebrow">Beheer</p>
    <h1>Betaalinstellingen</h1>

    <div class="card" style="margin-bottom: var(--s-5)">
      <p class="muted" style="margin-top: 0">
        Deze instellingen zijn zichtbaar voor alle leden die nog op betaling
        wachten, in hun profielpagina.
      </p>
    </div>

    <div v-if="loading" class="muted">Laden…</div>

    <div v-else class="card stack">
      <div class="field">
        <label for="amount">Bedrag</label>
        <input
          id="amount"
          v-model="amount"
          type="text"
          placeholder="bv. € 5,-"
        />
        <span class="hint">Hoe je dit opschrijft is hoe leden het zien.</span>
      </div>

      <div class="field">
        <label for="instructions">Betalingsinstructie</label>
        <textarea
          id="instructions"
          v-model="instructions"
          rows="4"
          placeholder="bv. Tikkie naar Ronald op +31..."
        ></textarea>
        <span class="hint">Vrije tekst. Komt onder het bedrag te staan.</span>
      </div>

      <div class="field">
        <label>QR-code afbeelding</label>
        <div v-if="previewImage" class="qr-preview">
          <img :src="previewImage" alt="QR voorbeeld" />
          <button class="btn btn-secondary btn-sm" @click="clearImage" type="button">
            Verwijderen
          </button>
        </div>
        <input
          ref="fileInput"
          type="file"
          accept="image/*"
          @change="onFileSelected"
          class="file-input"
        />
        <span class="hint">
          Upload een QR-code (bv. Tikkie-QR exporteren). Max 1 MB.
          Wordt opgeslagen in de database zelf.
        </span>
      </div>

      <div v-if="error" class="alert alert-error">{{ error }}</div>
      <div v-if="saved" class="alert alert-success">Opgeslagen ✓</div>

      <button class="btn btn-primary" @click="save" :disabled="saving">
        {{ saving ? 'Opslaan…' : 'Opslaan' }}
      </button>
    </div>
  </main>
</template>

<style scoped>
.qr-preview {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--s-3);
  margin-bottom: var(--s-3);
  padding: var(--s-3);
  background: white;
  border: 1px solid var(--line);
  border-radius: var(--r-md);
}
.qr-preview img {
  max-width: 200px;
  max-height: 200px;
  border-radius: var(--r-sm);
}
.file-input {
  padding: 8px;
  font-size: 0.875rem;
}
</style>
