<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { useAuthStore } from '../stores/auth.js'
import { useRouter, useRoute } from 'vue-router'
import { supabase } from '../lib/supabase.js'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const adminOpen = ref(false)
const voorspellenOpen = ref(false)
const mobileOpen = ref(false)
const dropdownRef = ref(null)
const voorspellenRef = ref(null)
const pendingCount = ref(0)
let channel = null

const isOnPredictRoute = computed(() => route.path.startsWith('/voorspellen'))
const isOnAdminRoute = computed(() => route.path.startsWith('/beheer'))

async function handleLogout() {
  await auth.signOut()
  router.push({ name: 'login' })
}

async function loadPendingCount() {
  if (!auth.isAdmin) return
  const { count, error } = await supabase
    .from('profiles')
    .select('id', { count: 'exact', head: true })
    .eq('status', 'awaiting_payment')
  if (!error) pendingCount.value = count || 0
}

function handleClickOutside(e) {
  if (dropdownRef.value && !dropdownRef.value.contains(e.target)) {
    adminOpen.value = false
  }
  if (voorspellenRef.value && !voorspellenRef.value.contains(e.target)) {
    voorspellenOpen.value = false
  }
}

function closeMobile() {
  mobileOpen.value = false
  adminOpen.value = false
  voorspellenOpen.value = false
}

// Sluit mobiel menu bij navigatie
watch(() => route.path, () => {
  closeMobile()
})

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
      <router-link to="/" class="brand" @click="closeMobile">
        <svg class="trophy-mark" viewBox="0 0 24 28" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
          <path d="M6 3h12v2.5c0 .8.6 1.5 1.4 1.5H21c1.1 0 2 .9 2 2v2c0 2.5-2 4.5-4.5 4.5h-.7c-.6 1.7-2 3-3.8 3.4V21h2c.6 0 1 .4 1 1s-.4 1-1 1H8c-.6 0-1-.4-1-1s.4-1 1-1h2v-2.1c-1.8-.4-3.2-1.7-3.8-3.4h-.7C3 15.5 1 13.5 1 11V9c0-1.1.9-2 2-2h1.6c.8 0 1.4-.7 1.4-1.5V3z" fill="currentColor"/>
          <path d="M5 9v2c0 1.4 1.1 2.5 2.5 2.5H8V9H5zm14 0h-3v4.5h.5c1.4 0 2.5-1.1 2.5-2.5V9z" fill="var(--bg-card)" fill-opacity="0.95"/>
          <path d="M12 6.5l.8 1.7 1.9.2-1.4 1.3.4 1.8L12 10.6 10.3 11.5l.4-1.8L9.3 8.4l1.9-.2z" fill="var(--bg-card)" fill-opacity="0.9"/>
        </svg>
        <span class="brand-text">Van der Meer WK poule 2026</span>
        <span class="brand-text-short">VdM WK 2026</span>
      </router-link>

      <!-- Hamburger (alleen mobiel) -->
      <button
        class="mobile-toggle"
        :class="{ open: mobileOpen }"
        @click.stop="mobileOpen = !mobileOpen"
        aria-label="Menu"
      >
        <span></span>
        <span></span>
        <span></span>
        <span v-if="pendingCount > 0 && auth.isAdmin" class="mobile-badge">{{ pendingCount }}</span>
      </button>

      <!-- Desktop nav links -->
      <div class="nav-links nav-links-desktop">
        <router-link to="/">Overzicht</router-link>
        <router-link to="/stand">Stand</router-link>

        <div class="admin-dropdown" ref="voorspellenRef">
          <button
            type="button"
            class="admin-trigger"
            :class="{ open: voorspellenOpen, 'is-active-route': isOnPredictRoute }"
            @click.stop="voorspellenOpen = !voorspellenOpen"
          >
            Voorspellen
            <span class="caret">▾</span>
          </button>
          <div v-if="voorspellenOpen" class="dropdown-menu dropdown-menu-wide">
            <router-link to="/voorspellen/poules" @click="voorspellenOpen = false">R1 Poulewedstrijden</router-link>
            <router-link to="/voorspellen/eindstanden" @click="voorspellenOpen = false">R2 Eindklasseringen</router-link>
            <div class="dropdown-divider"></div>
            <router-link to="/voorspellen/16e-finales" @click="voorspellenOpen = false">R3 16e finales</router-link>
            <router-link to="/voorspellen/8e-finales" @click="voorspellenOpen = false">R4 8e finales</router-link>
            <router-link to="/voorspellen/kwartfinales" @click="voorspellenOpen = false">R5 Kwartfinales</router-link>
            <router-link to="/voorspellen/halve-finales" @click="voorspellenOpen = false">R6 Halve finales</router-link>
            <router-link to="/voorspellen/finales" @click="voorspellenOpen = false">R7 Troostfinale &amp; Finale</router-link>
            <div class="dropdown-divider"></div>
            <router-link to="/voorspellen/bonusvragen" @click="voorspellenOpen = false">R8 Bonusvragen</router-link>
          </div>
        </div>

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
            <router-link to="/beheer/betalingen" @click="adminOpen = false">Betaalinstellingen</router-link>
          </div>
        </div>

        <button class="btn btn-secondary btn-sm" @click="handleLogout">Uitloggen</button>
      </div>
    </div>

    <!-- MOBIEL drawer (visible bij mobileOpen) -->
    <Transition name="mobile-drawer">
      <div v-if="mobileOpen" class="mobile-drawer" @click.self="closeMobile">
        <div class="mobile-drawer-inner">
          <router-link to="/" class="mobile-link" @click="closeMobile">Overzicht</router-link>
          <router-link to="/stand" class="mobile-link" @click="closeMobile">Stand</router-link>

          <div class="mobile-section">
            <div class="mobile-section-title">Voorspellen</div>
            <router-link to="/voorspellen/poules" class="mobile-sublink" @click="closeMobile">R1 Poulewedstrijden</router-link>
            <router-link to="/voorspellen/eindstanden" class="mobile-sublink" @click="closeMobile">R2 Eindklasseringen</router-link>
            <router-link to="/voorspellen/16e-finales" class="mobile-sublink" @click="closeMobile">R3 16e finales</router-link>
            <router-link to="/voorspellen/8e-finales" class="mobile-sublink" @click="closeMobile">R4 8e finales</router-link>
            <router-link to="/voorspellen/kwartfinales" class="mobile-sublink" @click="closeMobile">R5 Kwartfinales</router-link>
            <router-link to="/voorspellen/halve-finales" class="mobile-sublink" @click="closeMobile">R6 Halve finales</router-link>
            <router-link to="/voorspellen/finales" class="mobile-sublink" @click="closeMobile">R7 Troostfinale &amp; Finale</router-link>
            <router-link to="/voorspellen/bonusvragen" class="mobile-sublink" @click="closeMobile">R8 Bonusvragen</router-link>
          </div>

          <router-link to="/profiel" class="mobile-link" @click="closeMobile">Profiel</router-link>

          <div v-if="auth.isAdmin" class="mobile-section">
            <div class="mobile-section-title">
              Beheer
              <span v-if="pendingCount > 0" class="badge badge-inline">{{ pendingCount }}</span>
            </div>
            <router-link to="/beheer/leden" class="mobile-sublink" @click="closeMobile">
              Leden
              <span v-if="pendingCount > 0" class="badge badge-inline">{{ pendingCount }}</span>
            </router-link>
            <router-link to="/beheer/wedstrijden" class="mobile-sublink" @click="closeMobile">Wedstrijden</router-link>
            <router-link to="/beheer/eindstanden" class="mobile-sublink" @click="closeMobile">Eindstanden poules</router-link>
            <router-link to="/beheer/deadlines" class="mobile-sublink" @click="closeMobile">Deadlines</router-link>
            <router-link to="/beheer/bonusantwoorden" class="mobile-sublink" @click="closeMobile">Bonusantwoorden</router-link>
            <router-link to="/beheer/betalingen" class="mobile-sublink" @click="closeMobile">Betaalinstellingen</router-link>
          </div>

          <button class="mobile-link mobile-logout" @click="handleLogout">Uitloggen</button>
        </div>
      </div>
    </Transition>
  </nav>
</template>

<style scoped>
.navbar {
  background: var(--bg-card);
  border-bottom: 1px solid var(--line);
  position: sticky;
  top: 0;
  z-index: 50;
}
.navbar-inner {
  max-width: 1080px;
  margin: 0 auto;
  padding: var(--s-3) var(--s-5);
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: var(--s-4);
}
.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  font-family: var(--font-display);
  font-size: 1.1rem;
  font-weight: 600;
  color: var(--field);
  text-decoration: none;
  letter-spacing: -0.01em;
}
.brand:hover { text-decoration: none; }
.trophy-mark {
  width: 24px;
  height: 28px;
  color: #d4a017;
  flex-shrink: 0;
}
.brand-text-short { display: none; }

/* ============================================================
   DESKTOP NAV
   ============================================================ */
.nav-links-desktop {
  display: flex;
  align-items: center;
  gap: var(--s-2);
}
.nav-links a {
  padding: 8px 14px;
  font-size: 0.9375rem;
  font-weight: 500;
  color: var(--ink);
  text-decoration: none;
  border-radius: var(--r-sm);
}
.nav-links a:hover {
  background: var(--bg-elev);
  text-decoration: none;
}
.nav-links a.router-link-active {
  color: var(--field);
  background: var(--bg-elev);
  font-weight: 600;
}

/* Dropdown trigger button */
.admin-dropdown {
  position: relative;
  display: inline-flex;
}
.admin-trigger {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 14px;
  font-size: 0.9375rem;
  font-weight: 500;
  color: var(--ink);
  background: transparent;
  border: none;
  cursor: pointer;
  border-radius: var(--r-sm);
  font-family: inherit;
}
.admin-trigger:hover { background: var(--bg-elev); }
.admin-trigger.open { background: var(--bg-elev); }
.admin-trigger.is-active-route {
  color: var(--ink);
  background: var(--bg-elev);
}
.caret {
  font-size: 0.625rem;
  transition: transform 0.15s;
}
.admin-trigger.open .caret { transform: rotate(180deg); }
.badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--accent, #d4561d);
  color: white;
  font-size: 0.6875rem;
  font-weight: 700;
  padding: 0 6px;
  border-radius: 999px;
  min-width: 18px;
  height: 18px;
}
.badge-inline {
  background: var(--accent, #d4561d);
  color: white;
  font-size: 0.6875rem;
}
.dropdown-menu {
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: 6px;
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
.dropdown-menu-wide { min-width: 250px; }
.dropdown-divider {
  height: 1px;
  background: var(--line);
  margin: 4px 8px;
}

/* ============================================================
   MOBIEL HAMBURGER + DRAWER
   ============================================================ */
.mobile-toggle {
  display: none;
  position: relative;
  width: 44px;
  height: 44px;
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 12px 10px;
  border-radius: var(--r-sm);
}
.mobile-toggle:hover { background: var(--bg-elev); }
.mobile-toggle span {
  display: block;
  width: 24px;
  height: 2.5px;
  background: var(--ink);
  border-radius: 2px;
  transition: all 0.25s;
  margin: 4px 0;
}
.mobile-toggle.open span:nth-child(1) {
  transform: translateY(6.5px) rotate(45deg);
}
.mobile-toggle.open span:nth-child(2) {
  opacity: 0;
}
.mobile-toggle.open span:nth-child(3) {
  transform: translateY(-6.5px) rotate(-45deg);
}
.mobile-badge {
  position: absolute;
  top: 4px;
  right: 4px;
  background: var(--accent, #d4561d);
  color: white;
  font-size: 0.625rem;
  font-weight: 700;
  font-family: var(--font-mono);
  min-width: 16px;
  height: 16px;
  border-radius: 999px;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 4px;
}

.mobile-drawer {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(30, 42, 30, 0.35);
  z-index: 200;
  display: flex;
  justify-content: flex-end;
}
.mobile-drawer-inner {
  width: min(320px, 88%);
  height: 100%;
  background: var(--bg-card);
  overflow-y: auto;
  padding: var(--s-5) var(--s-4) var(--s-7);
  box-shadow: -8px 0 32px rgba(30, 42, 30, 0.18);
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.mobile-link {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 12px;
  font-size: 1rem;
  font-weight: 500;
  color: var(--ink);
  text-decoration: none;
  border-radius: var(--r-sm);
  min-height: 44px;
}
.mobile-link:hover { background: var(--bg-elev); text-decoration: none; }
.mobile-link.router-link-active {
  background: var(--bg-elev);
  color: var(--field);
  font-weight: 600;
}
.mobile-section {
  margin: var(--s-3) 0 var(--s-2);
  padding: var(--s-2) 0;
  border-top: 1px solid var(--line);
}
.mobile-section-title {
  padding: 10px 12px 6px;
  font-family: var(--font-mono);
  font-size: 0.6875rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--ink-mute);
  display: flex;
  align-items: center;
  gap: 8px;
}
.mobile-sublink {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 11px 16px;
  font-size: 0.9375rem;
  color: var(--ink);
  text-decoration: none;
  border-radius: var(--r-sm);
  min-height: 44px;
}
.mobile-sublink:hover { background: var(--bg-elev); text-decoration: none; }
.mobile-sublink.router-link-active {
  background: var(--bg-elev);
  color: var(--field);
  font-weight: 600;
}
.mobile-logout {
  background: transparent;
  border: 1px solid var(--line);
  cursor: pointer;
  font-family: inherit;
  margin-top: var(--s-3);
  text-align: center;
  justify-content: center;
}

/* Drawer transitions */
.mobile-drawer-enter-active,
.mobile-drawer-leave-active {
  transition: opacity 0.2s;
}
.mobile-drawer-enter-active .mobile-drawer-inner,
.mobile-drawer-leave-active .mobile-drawer-inner {
  transition: transform 0.25s ease-out;
}
.mobile-drawer-enter-from,
.mobile-drawer-leave-to {
  opacity: 0;
}
.mobile-drawer-enter-from .mobile-drawer-inner,
.mobile-drawer-leave-to .mobile-drawer-inner {
  transform: translateX(100%);
}

/* ============================================================
   RESPONSIVE BREAKPOINTS
   ============================================================ */
@media (max-width: 920px) {
  .brand-text { display: none; }
  .brand-text-short { display: inline; }
  .navbar-inner { padding: var(--s-3) var(--s-4); }
}
@media (max-width: 768px) {
  .nav-links-desktop { display: none; }
  .mobile-toggle { display: block; }
}
</style>
