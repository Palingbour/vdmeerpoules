<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../lib/supabase.js'
import { useAuthStore } from '../../stores/auth.js'

const auth = useAuthStore()

const round = ref(null)
const questions = ref([])
const teams = ref([])
const answers = ref({})              // question_id -> answer
const savedStatus = ref({})
const questionPoints = ref({})       // question_id -> points_awarded
const loading = ref(true)
const error = ref('')
const saveTimers = {}

const deadlinePassed = computed(() => {
  if (!round.value?.deadline) return false
  return new Date(round.value.deadline) < new Date()
})

const filledCount = computed(() => {
  return questions.value.filter((q) => {
    const a = answers.value[q.id]
    return a !== undefined && a !== '' && a !== null
  }).length
})

async function load() {
  loading.value = true
  error.value = ''

  const [roundRes, questionsRes, teamsRes, predsRes] = await Promise.all([
    supabase.from('rounds').select('*').eq('nr', 8).single(),
    supabase.from('bonus_questions').select('*').order('display_order'),
    supabase.from('teams').select('id, name, flag_url, group_letter').order('name'),
    supabase
      .from('bonus_predictions')
      .select('*')
      .eq('user_id', auth.profile.id)
  ])

  if (roundRes.error) error.value = roundRes.error.message
  if (questionsRes.error) error.value = questionsRes.error.message
  if (predsRes.error) error.value = predsRes.error.message

  round.value = roundRes.data
  questions.value = questionsRes.data || []
  teams.value = teamsRes.data || []

  const ansMap = {}
  const statusMap = {}
  const pointsMap = {}
  for (const q of questions.value) {
    ansMap[q.id] = ''
    statusMap[q.id] = null
    pointsMap[q.id] = 0
  }
  for (const p of predsRes.data || []) {
    ansMap[p.question_id] = p.answer
    statusMap[p.question_id] = 'ok'
    pointsMap[p.question_id] = p.points_awarded || 0
  }
  answers.value = ansMap
  savedStatus.value = statusMap
  questionPoints.value = pointsMap

  loading.value = false
}

onMounted(load)

function onChange(questionId) {
  const val = answers.value[questionId]
  if (val === '' || val === null) {
    savedStatus.value[questionId] = null
    return
  }
  savedStatus.value[questionId] = 'saving'
  if (saveTimers[questionId]) clearTimeout(saveTimers[questionId])
  saveTimers[questionId] = setTimeout(() => save(questionId), 400)
}

async function save(questionId) {
  const { error: err } = await supabase
    .from('bonus_predictions')
    .upsert(
      {
        user_id: auth.profile.id,
        question_id: questionId,
        answer: String(answers.value[questionId])
      },
      { onConflict: 'user_id,question_id' }
    )
  if (err) {
    savedStatus.value[questionId] = 'error'
  } else {
    savedStatus.value[questionId] = 'ok'
  }
}

function fmtDeadline(d) {
  if (!d) return 'nog niet ingesteld'
  return new Date(d).toLocaleString('nl-NL', {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
    hour: '2-digit',
    minute: '2-digit'
  })
}

function scoringLabel(q) {
  if (q.scoring_type === 'closest') return '10 / 5 / 2 pt voor de drie dichtstbij'
  return '5 pt bij exact goed'
}

function hasCorrectAnswer(q) {
  return q.correct_answer !== null && q.correct_answer !== ''
}

function getQuestionClass(q) {
  if (!hasCorrectAnswer(q)) return ''
  const pts = questionPoints.value[q.id] || 0
  if (pts >= 10) return 'scored scored-q-10'
  if (pts >= 5) return 'scored scored-q-5'
  if (pts >= 2) return 'scored scored-q-2'
  return 'scored scored-q-0'
}
</script>

<template>
  <main class="page page-narrow">
    <p class="eyebrow">Ronde 8 · bonusvragen</p>
    <h1>Twaalf vragen voor extra punten.</h1>

    <div class="card" style="margin-bottom: var(--s-5)">
      <div class="row-between">
        <div>
          <strong>{{ filledCount }} / {{ questions.length }}</strong>
          <span class="muted"> beantwoord</span>
        </div>
        <div class="muted">
          Deadline:
          <span class="mono">{{ fmtDeadline(round?.deadline) }}</span>
        </div>
      </div>
      <p class="muted" style="margin: var(--s-3) 0 0; font-size: 0.9375rem">
        Voorspellingen worden automatisch opgeslagen. Antwoorden worden na
        afloop van het WK ingevoerd door de beheerder.
      </p>
    </div>

    <div v-if="deadlinePassed" class="alert alert-warn">
      De deadline is verstreken. Voorspellingen zijn vastgezet.
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="muted">Laden…</div>

    <div v-else class="questions-list">
      <div
        v-for="q in questions"
        :key="q.id"
        class="question-card"
        :class="getQuestionClass(q)"
      >
        <div class="q-header">
          <span class="q-num mono">{{ q.display_order / 10 | 0 }}{{ q.is_bonus ? '·bonus' : '' }}</span>
          <span class="q-scoring">{{ scoringLabel(q) }}</span>
          <span v-if="hasCorrectAnswer(q)" class="points-badge" :class="`points-${questionPoints[q.id] || 0}`">
            {{ questionPoints[q.id] > 0 ? '+' : '' }}{{ questionPoints[q.id] || 0 }} pt
          </span>
          <span v-else class="save-pill" :class="`save-${savedStatus[q.id] || 'none'}`">
            {{ { ok: '✓', saving: '⟳', error: '✕', none: '' }[savedStatus[q.id] || 'none'] }}
          </span>
        </div>
        <p class="q-text">{{ q.question_text }}</p>

        <div v-if="hasCorrectAnswer(q)" class="correct-answer">
          <span class="ca-label">Juiste antwoord:</span>
          <strong>{{ q.correct_answer }}</strong>
        </div>

        <div class="q-input">
          <!-- Numeric -->
          <input
            v-if="q.answer_type === 'numeric'"
            type="number"
            v-model="answers[q.id]"
            @input="onChange(q.id)"
            :disabled="deadlinePassed"
            class="num-input"
            inputmode="numeric"
          />

          <!-- Team selector -->
          <select
            v-else-if="q.answer_type === 'team'"
            v-model="answers[q.id]"
            @change="onChange(q.id)"
            :disabled="deadlinePassed"
            class="team-select"
          >
            <option value="">— kies een land —</option>
            <option v-for="t in teams" :key="t.id" :value="t.name">
              {{ t.name }} ({{ t.group_letter }})
            </option>
          </select>

          <!-- Free text -->
          <input
            v-else
            type="text"
            v-model="answers[q.id]"
            @input="onChange(q.id)"
            :disabled="deadlinePassed"
            class="text-input"
            placeholder="…"
          />
        </div>
      </div>
    </div>
  </main>
</template>

<style scoped>
.questions-list {
  display: flex;
  flex-direction: column;
  gap: var(--s-3);
}
.question-card {
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-md);
  padding: var(--s-4) var(--s-5);
  border-left: 4px solid var(--line);
  transition: border-left-color 0.2s;
}
.question-card.scored-q-10 { border-left-color: #2d8045; background: linear-gradient(to right, rgba(45, 128, 69, 0.08), var(--bg-card) 40%); }
.question-card.scored-q-5 { border-left-color: #4a9963; background: linear-gradient(to right, rgba(74, 153, 99, 0.05), var(--bg-card) 40%); }
.question-card.scored-q-2 { border-left-color: #c8541d; background: linear-gradient(to right, rgba(200, 84, 29, 0.05), var(--bg-card) 40%); }
.question-card.scored-q-0 { border-left-color: #b8b8b8; opacity: 0.85; }
.points-badge {
  margin-left: auto;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 0.6875rem;
  font-weight: 700;
  font-family: var(--font-mono);
  letter-spacing: 0.05em;
  text-transform: uppercase;
}
.points-badge.points-10 { background: #2d8045; color: white; }
.points-badge.points-5 { background: #4a9963; color: white; }
.points-badge.points-2 { background: #c8541d; color: white; }
.points-badge.points-0 { background: var(--bg-elev); color: var(--ink-mute); }
.correct-answer {
  margin: var(--s-2) 0 var(--s-3);
  padding: var(--s-2) var(--s-3);
  background: var(--bg-elev);
  border-radius: var(--r-sm);
  font-size: 0.875rem;
  display: flex;
  gap: 6px;
  align-items: center;
}
.ca-label {
  color: var(--ink-mute);
  font-size: 0.6875rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  font-family: var(--font-mono);
  font-weight: 600;
}
.q-header {
  display: flex;
  align-items: center;
  gap: var(--s-3);
  margin-bottom: var(--s-2);
}
.q-num {
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--ink-mute);
  letter-spacing: 0.05em;
  text-transform: uppercase;
}
.q-scoring {
  font-size: 0.75rem;
  color: var(--ink-mute);
  flex: 1;
}
.save-pill {
  font-family: var(--font-mono);
  font-size: 0.875rem;
  font-weight: 600;
}
.save-ok { color: var(--ok); }
.save-saving { color: var(--ink-mute); }
.save-error { color: var(--err); }
.q-text {
  font-size: 1.0625rem;
  font-weight: 500;
  margin: 0 0 var(--s-3);
  color: var(--ink);
}
.q-input { display: flex; }
.num-input, .text-input, .team-select {
  width: 100%;
  padding: var(--s-3);
  border: 1px solid var(--line);
  border-radius: var(--r-sm);
  background: var(--bg);
  font-size: 1rem;
}
.num-input { max-width: 180px; font-family: var(--font-mono); }
.num-input:focus, .text-input:focus, .team-select:focus {
  outline: none;
  border-color: var(--field);
  box-shadow: 0 0 0 3px rgba(31, 75, 58, 0.12);
}
.num-input:disabled, .text-input:disabled, .team-select:disabled {
  opacity: 0.6;
  background: var(--bg-elev);
}
</style>
