<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../../lib/supabase.js'

const questions = ref([])
const teams = ref([])
const answers = ref({})
const saving = ref({})
const loading = ref(true)
const error = ref('')

async function load() {
  loading.value = true
  try {
    const [qRes, tRes] = await Promise.all([
      supabase.from('bonus_questions').select('*').order('display_order'),
      supabase.from('teams').select('id, name, group_letter').order('name')
    ])
    if (qRes.error) error.value = qRes.error.message
    if (tRes.error) error.value = tRes.error.message

    questions.value = qRes.data || []
    teams.value = tRes.data || []
    for (const q of questions.value) {
      answers.value[q.id] = q.correct_answer ?? ''
    }
  } catch (e) {
    console.error('[BonusAnswers] load error:', e)
    error.value = e.message || 'Er ging iets mis bij het laden.'
  } finally {
    loading.value = false
  }
}

onMounted(load)

async function save(q) {
  saving.value[q.id] = true
  error.value = ''
  const val = answers.value[q.id] === '' ? null : String(answers.value[q.id])
  const { error: err } = await supabase
    .from('bonus_questions')
    .update({ correct_answer: val })
    .eq('id', q.id)
  saving.value[q.id] = false
  if (err) error.value = err.message
}
</script>

<template>
  <main class="page page-narrow">
    <p class="eyebrow">Beheer</p>
    <h1>Antwoorden bonusvragen</h1>

    <div class="card">
      <p class="muted" style="margin-top: 0">
        Vul hier de juiste antwoorden in zodra het toernooi voorbij is. Punten
        worden automatisch berekend (closest: 10/5/2 voor de drie dichtstbij,
        exact: 5 punten bij precies goed). Leeg laten = nog niet beoordeeld.
      </p>

      <div v-if="error" class="alert alert-error">{{ error }}</div>
      <div v-if="loading" class="muted">Laden…</div>

      <div v-else class="answer-list">
        <div v-for="q in questions" :key="q.id" class="answer-row">
          <div class="q-meta">
            <span class="q-type mono">{{ q.scoring_type }} · {{ q.answer_type }}</span>
            <span class="q-text">{{ q.question_text }}</span>
          </div>
          <div class="answer-input">
            <input
              v-if="q.answer_type === 'numeric'"
              type="number"
              v-model="answers[q.id]"
              placeholder="—"
            />
            <select v-else-if="q.answer_type === 'team'" v-model="answers[q.id]">
              <option value="">— nog niet bekend —</option>
              <option v-for="t in teams" :key="t.id" :value="t.name">
                {{ t.name }}
              </option>
            </select>
            <input v-else type="text" v-model="answers[q.id]" placeholder="—" />

            <button class="btn btn-primary btn-sm" @click="save(q)" :disabled="saving[q.id]">
              {{ saving[q.id] ? '…' : 'OK' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </main>
</template>

<style scoped>
.answer-list { display: flex; flex-direction: column; gap: var(--s-3); }
.answer-row {
  display: flex;
  flex-direction: column;
  gap: var(--s-2);
  padding: var(--s-3) var(--s-4);
  background: var(--bg);
  border: 1px solid var(--line-soft);
  border-radius: var(--r-md);
}
.q-meta { display: flex; flex-direction: column; gap: 4px; }
.q-type {
  font-size: 0.6875rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--ink-mute);
}
.q-text { font-size: 0.9375rem; font-weight: 500; }
.answer-input {
  display: flex;
  gap: var(--s-2);
  align-items: center;
}
.answer-input input, .answer-input select {
  flex: 1;
  padding: 8px 10px;
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  font-size: 0.9375rem;
}
</style>
