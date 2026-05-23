<script setup>
import { useAuthStore } from '../stores/auth.js'
import { useRouter } from 'vue-router'

const auth = useAuthStore()
const router = useRouter()

async function handleLogout() {
  await auth.signOut()
  router.push({ name: 'login' })
}
</script>

<template>
  <nav class="navbar">
    <div class="navbar-inner">
      <router-link to="/" class="brand">
        <span class="brand-mark"></span>Van der Meer Poules
      </router-link>
      <div class="nav-links">
        <router-link to="/">Stand</router-link>
        <router-link to="/profiel">Profiel</router-link>
        <router-link v-if="auth.isAdmin" to="/beheer/leden">Beheer</router-link>
        <button class="btn btn-secondary btn-sm" @click="handleLogout">
          Uitloggen
        </button>
      </div>
    </div>
  </nav>
</template>
