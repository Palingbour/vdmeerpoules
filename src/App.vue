<script setup>
import { computed } from 'vue'
import { useAuthStore } from './stores/auth.js'
import NavBar from './components/NavBar.vue'
import { useRouter } from 'vue-router'

const auth = useAuthStore()
const router = useRouter()
const showNav = computed(() => auth.isLoggedIn && auth.isParticipant)
const showPaymentBanner = computed(() => auth.isAwaitingPayment)

function goToPayment() {
  router.push('/profiel#betaling')
}
</script>

<template>
  <div class="app-shell">
    <NavBar v-if="showNav" />
    <div v-if="showPaymentBanner" class="payment-banner">
      <span class="banner-icon">💸</span>
      <span class="banner-text">
        Welkom! Je doet mee, maar je telt pas mee in de officiële stand
        zodra je betaling is bevestigd.
      </span>
      <button class="banner-btn" @click="goToPayment">
        Bekijk betaalinstructies
      </button>
    </div>
    <router-view />
  </div>
</template>

<style scoped>
.payment-banner {
  background: linear-gradient(135deg, var(--accent, #d4561d), var(--accent-soft, #e88a4a));
  color: white;
  padding: 12px 24px;
  display: flex;
  align-items: center;
  gap: 16px;
  font-size: 0.9375rem;
  font-weight: 500;
  box-shadow: 0 2px 8px rgba(212, 86, 29, 0.15);
}
.banner-icon { font-size: 1.25rem; }
.banner-text { flex: 1; }
.banner-btn {
  background: rgba(255, 255, 255, 0.95);
  color: var(--accent, #d4561d);
  border: none;
  padding: 7px 14px;
  border-radius: 6px;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
  transition: background 0.15s;
}
.banner-btn:hover {
  background: white;
}
@media (max-width: 640px) {
  .payment-banner {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
    padding: 12px 16px;
  }
  .banner-btn { align-self: flex-start; }
}
</style>
