<script setup>
import { ref } from 'vue'
import { useAuthStore } from '../stores/auth.js'
import { useRouter } from 'vue-router'

const auth = useAuthStore()
const router = useRouter()
const adminOpen = ref(false)

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
        <router-link to="/voorspellen/poules">Voorspellen</router-link>
        <router-link to="/profiel">Profiel</router-link>

        <div v-if="auth.isAdmin" class="admin-dropdown" @click="adminOpen = !adminOpen" @mouseleave="adminOpen = false">
          <span class="admin-trigger">Beheer ▾</span>
          <div v-if="adminOpen" class="dropdown-menu">
            <router-link to="/beheer/leden" @click="adminOpen = false">Leden</router-link>
            <router-link to="/beheer/wedstrijden" @click="adminOpen = false">Wedstrijden</router-link>
            <router-link to="/beheer/deadlines" @click="adminOpen = false">Deadlines</router-link>
            <router-link to="/beheer/bonusantwoorden" @click="adminOpen = false">Bonusantwoorden</router-link>
          </div>
        </div>

        <button class="btn btn-secondary btn-sm" @click="handleLogout">Uitloggen</button>
      </div>
    </div>
  </nav>
</template>

<style scoped>
.admin-dropdown {
  position: relative;
  cursor: pointer;
}
.admin-trigger {
  color: var(--ink-soft);
  font-size: 0.9375rem;
  font-weight: 500;
  padding: 4px 0;
}
.admin-trigger:hover { color: var(--ink); }
.dropdown-menu {
  position: absolute;
  top: calc(100% + 8px);
  right: 0;
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-md);
  padding: 6px;
  min-width: 200px;
  box-shadow: 0 8px 20px rgba(30, 42, 30, 0.12);
  z-index: 100;
  display: flex;
  flex-direction: column;
}
.dropdown-menu a {
  padding: 8px 12px;
  font-size: 0.9375rem;
  border-radius: var(--r-sm);
  color: var(--ink);
}
.dropdown-menu a:hover {
  background: var(--bg-elev);
  text-decoration: none;
}
.dropdown-menu a.router-link-active {
  background: var(--bg-elev);
  color: var(--field);
  font-weight: 600;
}
</style>
