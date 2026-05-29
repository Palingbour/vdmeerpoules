import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth.js'

const routes = [
  { path: '/login', name: 'login', component: () => import('../pages/Login.vue'), meta: { public: true } },
  { path: '/wachten', name: 'pending', component: () => import('../pages/PendingApproval.vue'), meta: { requiresAuth: true } },

  { path: '/', name: 'dashboard', component: () => import('../pages/Dashboard.vue'), meta: { requiresAuth: true, requiresActive: true } },
  { path: '/stand', name: 'standings', component: () => import('../pages/Standings.vue'), meta: { requiresAuth: true, requiresActive: true } },
  { path: '/profiel', name: 'profile', component: () => import('../pages/Profile.vue'), meta: { requiresAuth: true, requiresActive: true } },

  // Voorspellingsschermen
  { path: '/voorspellen/poules', name: 'predict-round1', component: () => import('../pages/predictions/Round1Matches.vue'), meta: { requiresAuth: true, requiresActive: true } },
  { path: '/voorspellen/eindstanden', name: 'predict-round2', component: () => import('../pages/predictions/Round2Standings.vue'), meta: { requiresAuth: true, requiresActive: true } },
  { path: '/voorspellen/bonusvragen', name: 'predict-round8', component: () => import('../pages/predictions/Round8Bonus.vue'), meta: { requiresAuth: true, requiresActive: true } },

  // KO-rondes — gebruiken één gedeelde component met props
  { path: '/voorspellen/16e-finales', name: 'predict-round3', component: () => import('../pages/predictions/KnockoutRound.vue'),
    props: { roundNr: 3, roundName: '16e finales' }, meta: { requiresAuth: true, requiresActive: true } },
  { path: '/voorspellen/8e-finales', name: 'predict-round4', component: () => import('../pages/predictions/KnockoutRound.vue'),
    props: { roundNr: 4, roundName: '8e finales' }, meta: { requiresAuth: true, requiresActive: true } },
  { path: '/voorspellen/kwartfinales', name: 'predict-round5', component: () => import('../pages/predictions/KnockoutRound.vue'),
    props: { roundNr: 5, roundName: 'Kwartfinales' }, meta: { requiresAuth: true, requiresActive: true } },
  { path: '/voorspellen/halve-finales', name: 'predict-round6', component: () => import('../pages/predictions/KnockoutRound.vue'),
    props: { roundNr: 6, roundName: 'Halve finales' }, meta: { requiresAuth: true, requiresActive: true } },
  { path: '/voorspellen/finales', name: 'predict-round7', component: () => import('../pages/predictions/KnockoutRound.vue'),
    props: { roundNr: 7, roundName: 'Troostfinale & Finale' }, meta: { requiresAuth: true, requiresActive: true } },

  // Admin
  { path: '/beheer/leden', name: 'admin-members', component: () => import('../pages/admin/Members.vue'), meta: { requiresAuth: true, requiresActive: true, requiresAdmin: true } },
  { path: '/beheer/wedstrijden', name: 'admin-matches', component: () => import('../pages/admin/Matches.vue'), meta: { requiresAuth: true, requiresActive: true, requiresAdmin: true } },
  { path: '/beheer/eindstanden', name: 'admin-group-results', component: () => import('../pages/admin/GroupResults.vue'), meta: { requiresAuth: true, requiresActive: true, requiresAdmin: true } },
  { path: '/beheer/deadlines', name: 'admin-deadlines', component: () => import('../pages/admin/Deadlines.vue'), meta: { requiresAuth: true, requiresActive: true, requiresAdmin: true } },
  { path: '/beheer/bonusantwoorden', name: 'admin-bonus', component: () => import('../pages/admin/BonusAnswers.vue'), meta: { requiresAuth: true, requiresActive: true, requiresAdmin: true } },

  { path: '/:pathMatch(.*)*', redirect: '/' }
]

export const router = createRouter({
  history: createWebHistory(),
  routes
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  if (!auth.initialized) await auth.init()

  if (to.meta.public) {
    if (auth.isLoggedIn && to.name === 'login') {
      return { name: auth.isActive ? 'dashboard' : 'pending' }
    }
    return true
  }

  if (to.meta.requiresAuth && !auth.isLoggedIn) {
    return { name: 'login' }
  }

  if (to.meta.requiresActive && !auth.isActive) {
    return { name: 'pending' }
  }

  if (to.meta.requiresAdmin && !auth.isAdmin) {
    return { name: 'dashboard' }
  }

  if (to.name === 'pending' && auth.isActive) {
    return { name: 'dashboard' }
  }

  return true
})
