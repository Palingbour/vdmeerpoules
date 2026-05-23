<script setup>
import { useAuthStore } from '../stores/auth.js'

const auth = useAuthStore()
const firstName = auth.profile?.full_name?.split(' ')[0] || 'speler'
</script>

<template>
  <main class="page">
    <p class="eyebrow">Welkom terug</p>
    <h1>Hoi {{ firstName }}.</h1>

    <div class="card">
      <p>
        Je bent ingelogd en goedgekeurd. De voorspellingsschermen en de stand
        verschijnen hier zodra ze klaar zijn (volgende milestone).
      </p>
      <p class="muted">
        Voor nu kun je via het menu naar je profielpagina, of (als beheerder)
        naar het ledenoverzicht.
      </p>
    </div>
  </main>
</template>
