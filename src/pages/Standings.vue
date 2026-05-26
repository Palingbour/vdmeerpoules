<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase.js'

const totalMembers = ref(0)
const loading = ref(true)

async function load() {
  loading.value = true
  try {
    const { count } = await supabase
      .from('profiles')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'active')
    totalMembers.value = count || 0
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<template>
  <main class="page page-narrow">
    <p class="eyebrow">Stand</p>
    <h1>De stand komt binnenkort.</h1>

    <div class="card">
      <p>
        Vanaf de eerste wedstrijd op <strong>11 juni 2026</strong> verschijnt
        hier het overzicht van alle deelnemers met hun punten per ronde en hun
        totaalscore.
      </p>

      <p class="muted">
        Op dit moment zijn er <strong>{{ loading ? '…' : totalMembers }}</strong>
        actieve deelnemers. Andere familieleden kunnen zich nog aanmelden tot
        de eerste deadline (11 juni 18:00).
      </p>

      <div class="hint-block">
        <strong>Hoe straks de stand eruit gaat zien:</strong>
        <ul>
          <li>Plek &amp; naam per deelnemer</li>
          <li>Punten per ronde (R1 t/m R8)</li>
          <li>Totaalscore + pijltjes-indicator voor verandering</li>
          <li>Filter per ronde, bij gelijkstand tie-breaker zichtbaar</li>
        </ul>
      </div>
    </div>
  </main>
</template>

<style scoped>
.hint-block {
  margin-top: var(--s-5);
  padding: var(--s-4);
  background: var(--bg-elev);
  border-radius: var(--r-md);
  font-size: 0.9375rem;
}
.hint-block ul {
  margin: var(--s-2) 0 0 var(--s-4);
  padding: 0;
}
.hint-block li {
  margin: 4px 0;
  color: var(--ink-soft);
}
</style>
