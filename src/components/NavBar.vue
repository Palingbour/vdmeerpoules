<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useAuthStore } from '../stores/auth.js'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase.js'

const auth = useAuthStore()
const router = useRouter()
const adminOpen = ref(false)
const dropdownRef = ref(null)
const pendingCount = ref(0)
let channel = null

async function handleLogout() {
  await auth.signOut()
  router.push({ name: 'login' })
}

async function loadPendingCount() {
  if (!auth.isAdmin) return
  const { count, error } = await supabase
    .from('profiles')
    .select('id', { count: 'exact', head: true })
    .eq('status', 'pending')
  if (!error) pendingCount.value = count || 0
}

function handleClickOutside(e) {
  if (dropdownRef.value && !dropdownRef.value.contains(e.target)) {
    adminOpen.value = false
  }
}

onMounted(() => {
  loadPendingCount()
  document.addEventListener('click', handleClickOutside)
  channel = supabase
    .channel('navbar-profiles-watch')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'profiles' },
      () => loadPendingCount()
    )
    .subscribe()
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
  if (channel) supabase.removeChannel(channel)
})
</script>

<template>
  <nav class="navbar">
    <div class="navbar-inner">
      <router-link to="/" class="brand">
        <svg class="trophy-mark" viewBox="0 0 24 28" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <!-- Trofee/cup met handvatten -->
          <path d="M6 3h12v2.5c0 .8.6 1.5 1.4 1.5H21c1.1 0 2 .9 2 2v2c0 2.5-2 4.5-4.5 4.5h-.7c-.6 1.7-2 3-3.8 3.4V21h2c.6 0 1 .4 1 1s-.4 1-1 1H8c-.6 0-1-.4-1-1s.4-1 1-1h2v-2.1c-1.8-.4-3.2-1.7-3.8-3.4h-.7C3 15.5 1 13.5 1 11V9c0-1.1.9-2 2-2h1.6c.8 0 1.4-.7 1.4-1.5V3z" fill="currentColor"/>
          <path d="M5 9v2c0 1.4 1.1 2.5 2.5 2.5H8V9H5zm14 0h-3v4.5h.5c1.4 0 2.5-1.1 2.5-2.5V9z" fill="var(--bg-card)" fill-opacity="0.95"/>
          <!-- Ster op de cup -->
          <path d="M12 6.5l.8 1.7 1.9.2-1.4 1.3.4 1.8L12 10.6 10.3 11.5l.4-1.8L9.3 8.4l1.9-.2z" fill="var(--bg-card)" fill-opacity="0.9"/>
        </svg>
        <span>Van der Meer WK poule 2026</span>
      </router-link>
      <div class="nav-links">
        <router-link to="/">Overzicht</router-link>
        <router-link to="/stand">Stand</router-link>
        <router-link to="/voorspellen/poules">Voorspellen</router-link>
        <router-link to="/profiel">Profiel</router-link>

        <div v-if="auth.isAdmin" class="admin-dropdown" ref="dropdownRef">
          <button
            type="button"
            class="admin-trigger"
            :class="{ open: adminOpen }"
            @click.stop="adminOpen = !adminOpen"
          >
            Beheer
            <span v-if="pendingCount > 0" class="badge">{{ pendingCount }}</span>
            <span class="caret">▾</span>
          </button>
          <div v-if="adminOpen" class="dropdown-menu">
            <router-link to="/beheer/leden" @click="adminOpen = false">
              <span>Leden</span>
              <span v-if="pendingCount > 0" class="badge badge-inline">{{ pendingCount }}</span>
            </router-link>
            <router-link to="/beheer/wedstrijden" @click="adminOpen = false">Wedstrijden</router-link>
            <router-link to="/beheer/eindstanden" @click="adminOpen = false">Eindstanden poules</router-link>
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
}
.admin-trigger {
  background: transparent;
  border: none;
  color: var(--ink-soft);
  font-size: 0.9375rem;
  font-weight: 500;
  padding: 6px 8px;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  font-family: inherit;
  border-radius: var(--r-sm);
  transition: background 0.1s, color 0.1s;
}
.admin-trigger:hover { color: var(--ink); background: var(--bg-elev); }
.admin-trigger.open { color: var(--ink); background: var(--bg-elev); }
.caret {
  font-size: 0.75rem;
  transition: transform 0.15s;
}
.admin-trigger.open .caret {
  transform: rotate(180deg);
}
.badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  background: var(--accent, #c8541d);
  color: white;
  border-radius: 9px;
  font-size: 0.6875rem;
  font-weight: 700;
  font-family: var(--font-mono);
  line-height: 1;
}
.badge-inline {
  margin-left: auto;
}
.dropdown-menu {
  position: absolute;
  top: calc(100% + 4px);
  right: 0;
  background: var(--bg-card);
  border: 1px solid var(--line);
  border-radius: var(--r-md);
  padding: 6px;
  min-width: 220px;
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
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  text-decoration: none;
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
