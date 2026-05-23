import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth.js'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('../pages/Login.vue'),
    meta: { public: true }
  },
  {
    path: '/wachten',
    name: 'pending',
    component: () => import('../pages/PendingApproval.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/',
    name: 'dashboard',
    component: () => import('../pages/Dashboard.vue'),
    meta: { requiresAuth: true, requiresActive: true }
  },
  {
    path: '/profiel',
    name: 'profile',
    component: () => import('../pages/Profile.vue'),
    meta: { requiresAuth: true, requiresActive: true }
  },
  {
    path: '/beheer/leden',
    name: 'admin-members',
    component: () => import('../pages/admin/Members.vue'),
    meta: { requiresAuth: true, requiresActive: true, requiresAdmin: true }
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/'
  }
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

  // Active users die per ongeluk naar /wachten gaan
  if (to.name === 'pending' && auth.isActive) {
    return { name: 'dashboard' }
  }

  return true
})
