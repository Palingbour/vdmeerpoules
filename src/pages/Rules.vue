<script setup>
import { onMounted, ref } from 'vue'
import { supabase } from '../lib/supabase.js'

const paymentSettings = ref(null)

onMounted(async () => {
  const { data } = await supabase
    .from('payment_settings')
    .select('amount')
    .eq('id', 1)
    .maybeSingle()
  paymentSettings.value = data
})
</script>

<template>
  <main class="page">
    <p class="eyebrow">Spelregels &amp; uitleg</p>
    <h1>Hoe werkt deze poule?</h1>

    <div class="card intro-block">
      <p>
        Dit jaar weer dezelfde gezellige WK-toto, maar nu volledig digitaal.
        Voorspel uitslagen, eindstanden en bonusvragen — wie de meeste punten
        haalt wint mee in de pot. <strong>Er zijn meerdere winnaars</strong>,
        dus 't blijft tot de finale leuk om te volgen.
      </p>
    </div>

    <h2 style="margin-top: var(--s-6)">Wat voorspel je?</h2>
    <div class="rules-grid">
      <div class="rule-card">
        <div class="rule-tag mono">R1</div>
        <h3>Poulewedstrijden</h3>
        <p>Voorspel de uitslag van alle 72 poulewedstrijden.</p>
        <ul class="scoring">
          <li><strong>2 pt</strong> als je de winnaar (of gelijkspel) goed hebt</li>
          <li><strong>5 pt</strong> als je de uitslag exact goed hebt</li>
        </ul>
      </div>

      <div class="rule-card">
        <div class="rule-tag mono">R2</div>
        <h3>Eindstanden poules</h3>
        <p>Voorspel per poule wie 1e, 2e, 3e en 4e wordt.</p>
        <ul class="scoring">
          <li><strong>1 pt</strong> per land op de juiste positie</li>
        </ul>
        <p class="hint">
          Tussentijds zie je al hoeveel je nu zou krijgen op basis van de
          actuele tussenstand.
        </p>
      </div>

      <div class="rule-card">
        <div class="rule-tag mono">R3 — R7</div>
        <h3>Knock-out rondes</h3>
        <p>16e finales, 8e finales, kwartfinales, halve finales, finale
        en troostfinale. Voorspel per wedstrijd de twee landen + de uitslag.</p>
        <ul class="scoring">
          <li><strong>5 pt</strong> per goed voorspeld land (max 10 voor 2 landen)</li>
          <li><strong>2 pt</strong> als je de winnaar correct hebt</li>
          <li><strong>5 pt</strong> als je de uitslag exact hebt (vervangt de 2 pt winnaar)</li>
          <li><strong>20 pt</strong> als je <em>alles</em> goed hebt: beide landen + exacte uitslag</li>
        </ul>
        <p class="hint">
          Sommige plekken in de 16e finales worden automatisch goed gerekend
          ("beste 3 cadeau"), zo verdient iedereen daar wat punten.
        </p>
      </div>

      <div class="rule-card">
        <div class="rule-tag mono">R8</div>
        <h3>Bonusvragen</h3>
        <p>Twaalf vragen over het toernooi: topscoorder, kampioen, aantal
        rode kaarten, enzovoort.</p>
        <ul class="scoring">
          <li><strong>Variabel</strong> per vraag — soms 5 pt voor exact goed,
          soms punten voor wie het dichtste zit</li>
        </ul>
      </div>
    </div>

    <h2 style="margin-top: var(--s-6)">Wanneer moet ik klaar zijn?</h2>
    <div class="card">
      <table class="deadline-table">
        <thead>
          <tr><th>Ronde</th><th>Deadline</th></tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>R1 Poulewedstrijden</strong></td>
            <td class="mono">do 11 juni · 18:00</td>
          </tr>
          <tr>
            <td><strong>R2 Eindstanden poules</strong></td>
            <td class="mono">do 11 juni · 18:00</td>
          </tr>
          <tr>
            <td><strong>R8 Bonusvragen</strong></td>
            <td class="mono">do 11 juni · 18:00</td>
          </tr>
          <tr>
            <td><strong>R3 16e finales</strong></td>
            <td class="mono">zo 28 juni · 16:00</td>
          </tr>
          <tr>
            <td><strong>R4 8e finales</strong></td>
            <td class="mono">za 4 juli · 16:00</td>
          </tr>
          <tr>
            <td><strong>R5 Kwartfinales</strong></td>
            <td class="mono">do 9 juli · 19:00</td>
          </tr>
          <tr>
            <td><strong>R6 Halve finales</strong></td>
            <td class="mono">di 14 juli · 19:00</td>
          </tr>
          <tr>
            <td><strong>R7 Troostfinale &amp; finale</strong></td>
            <td class="mono">za 18 juli · 19:00</td>
          </tr>
        </tbody>
      </table>
      <p class="hint" style="margin-top: var(--s-3)">
        Drie rondes (R1, R2, R8) sluiten tegelijk vóór de eerste wedstrijd.
        Voor de KO-rondes vul je telkens vlak na de vorige ronde in, zodra
        bekend is welke twee landen er kunnen winnen.
      </p>
    </div>

    <h2 style="margin-top: var(--s-6)">Inleg &amp; winnen</h2>
    <div class="card">
      <p>
        Inleg per persoon: <strong>{{ paymentSettings?.amount || '€ 10,-' }}</strong>.
        Te betalen via de QR-code op je profielpagina (of handmatig overmaken).
      </p>
      <p>
        Zodra de admin je betaling heeft bevestigd, doe je officieel mee in
        de stand. Tot die tijd zie je een banner met de oproep om te betalen,
        maar je kunt al wel voorspellingen invullen die meetellen zodra je
        bent geactiveerd.
      </p>
      <p>
        Aan het eind van het toernooi wordt de pot verdeeld onder meerdere
        winnaars — exacte verdeling kondigt de beheerder voor het toernooi
        nog aan.
      </p>
    </div>

    <h2 style="margin-top: var(--s-6)">Tips</h2>
    <div class="card">
      <ul class="tips">
        <li>
          <strong>Alles wordt automatisch opgeslagen</strong> terwijl je typt
          of sleept. Je hoeft niets op "Opslaan" te drukken.
        </li>
        <li>
          <strong>Stand updatet live</strong>: zodra een wedstrijd klaar is,
          tellen alle voorspellingen automatisch mee. Vernieuwen hoeft niet.
        </li>
        <li>
          <strong>Voorspel zo laat mogelijk</strong> als je twijfelt, maar
          niet ná de deadline: dan kan het niet meer.
        </li>
        <li>
          <strong>Mobiel werkt</strong>: open de site op je telefoon, log in,
          en je kunt overal voorspellen waar je bent.
        </li>
      </ul>
    </div>

    <p class="muted" style="text-align: center; margin-top: var(--s-6); font-size: 0.875rem">
      Veel succes! 🏆 Vragen? Vraag het de beheerder.
    </p>
  </main>
</template>

<style scoped>
.intro-block {
  background: linear-gradient(135deg, rgba(212, 160, 23, 0.08), rgba(212, 160, 23, 0.02));
  border-left: 4px solid #d4a017;
}
.intro-block p { margin: 0; line-height: 1.6; }

.rules-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: var(--s-4);
}
.rule-card {
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-lg);
  padding: var(--s-5);
  display: flex;
  flex-direction: column;
}
.rule-card h3 {
  margin: 0 0 var(--s-2);
  font-size: 1.125rem;
}
.rule-card p {
  margin: 0 0 var(--s-3);
  line-height: 1.5;
}
.rule-tag {
  display: inline-block;
  font-size: 0.6875rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--field);
  background: var(--bg-elev);
  padding: 3px 10px;
  border-radius: 999px;
  margin-bottom: var(--s-3);
  align-self: flex-start;
}
.scoring {
  list-style: none;
  padding: 0;
  margin: 0 0 var(--s-3);
}
.scoring li {
  padding: 6px 0;
  font-size: 0.9375rem;
  border-bottom: 1px solid var(--line-soft);
}
.scoring li:last-child { border-bottom: none; }
.hint {
  font-size: 0.8125rem;
  color: var(--ink-soft);
  font-style: italic;
  margin-top: auto;
  padding-top: var(--s-2);
}

.deadline-table {
  width: 100%;
  border-collapse: collapse;
}
.deadline-table th, .deadline-table td {
  text-align: left;
  padding: 10px 12px;
  border-bottom: 1px solid var(--line);
}
.deadline-table th {
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--ink-mute);
}
.deadline-table td:last-child { text-align: right; color: var(--ink-soft); }

.tips {
  margin: 0;
  padding-left: var(--s-4);
}
.tips li {
  padding: 4px 0;
  line-height: 1.5;
}

@media (max-width: 640px) {
  .rules-grid { grid-template-columns: 1fr; }
}
</style>
