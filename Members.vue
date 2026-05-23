<script setup>
import { computed } from 'vue'
import { useAuthStore } from './stores/auth.js'
import NavBar from './components/NavBar.vue'

const auth = useAuthStore()
const showNav = computed(() => auth.isLoggedIn && auth.isActive)
</script>

<template>
  <div class="app-shell">
    <NavBar v-if="showNav" />
    <router-view />
  </div>
</template>
