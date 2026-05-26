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
        <span class="brand-mark"></span>Van der Meer Poules
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
