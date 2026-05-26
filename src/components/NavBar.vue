<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { useAuthStore } from '../stores/auth.js'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase.js'

const auth = useAuthStore()
const router = useRouter()
const adminOpen = ref(false)
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

onMounted(() => {
  loadPendingCount()
  // Realtime subscriptie: zodra een profiel verandert (nieuwe aanmelding,
  // goedkeuring, etc.) verversen we de teller. Geen polling nodig.
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
        <router-link to="/">Stand</router-link>
        <router-link to="/voorspellen/poules">Voorspellen</router-link>
        <router-link to="/profiel">Profiel</router-link>

        <div
          v-if="auth.isAdmin"
          class="admin-dropdown"
          @mouseenter="adminOpen = true"
          @mouseleave="adminOpen = false"
        >
          <span class="admin-trigger" @click="adminOpen = !adminOpen">
            Beheer
            <span v-if="pendingCount > 0" class="badge">{{ pendingCount }}</span>
            ▾
          </span>
          <div v-if="adminOpen" class="dropdown-menu">
            <router-link to="/beheer/leden" @click="adminOpen = false">
              Leden
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
  cursor: pointer;
}
.admin-trigger {
  color: var(--ink-soft);
  font-size: 0.9375rem;
  font-weight: 500;
  padding: 4px 0;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
.admin-trigger:hover { color: var(--ink); }
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
  top: calc(100% + 8px);
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
