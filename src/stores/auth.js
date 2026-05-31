import { defineStore } from 'pinia'
import { supabase } from '../lib/supabase.js'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    session: null,
    profile: null,
    initialized: false,
    loading: false,
    realtimeChannel: null
  }),

  getters: {
    user: (s) => s.session?.user ?? null,
    isLoggedIn: (s) => !!s.session,
    // 'awaiting_payment' wacht op betalingsbevestiging maar mag wel meedoen
    isAwaitingPayment: (s) => s.profile?.status === 'awaiting_payment',
    isActive: (s) => s.profile?.status === 'active',
    // 'isParticipant' — kan voorspellen, dashboard zien, etc. — active OF awaiting_payment
    isParticipant: (s) => s.profile?.status === 'active' || s.profile?.status === 'awaiting_payment',
    // Admin behoudt rechten ook bij awaiting_payment (admin moet zichzelf
    // kunnen activeren). Alleen 'inactive' admins verliezen toegang.
    isAdmin: (s) => s.profile?.role === 'admin' && s.profile?.status !== 'inactive'
  },

  actions: {
    async init() {
      if (this.initialized) return

      const { data } = await supabase.auth.getSession()
      this.session = data.session

      if (this.session) {
        await this.loadProfile()
        this.subscribeProfile()
      }

      supabase.auth.onAuthStateChange(async (_event, session) => {
        this.session = session
        if (session) {
          await this.loadProfile()
          this.subscribeProfile()
        } else {
          this.profile = null
          this.unsubscribeProfile()
        }
      })

      this.initialized = true
    },

    async loadProfile() {
      if (!this.session?.user?.id) {
        this.profile = null
        return
      }
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', this.session.user.id)
        .single()
      if (error) {
        // Trigger draait normaal direct, maar als profiel om wat voor reden
        // toch ontbreekt: log en laat profile op null.
        // eslint-disable-next-line no-console
        console.error('Profiel niet gevonden:', error.message)
        this.profile = null
        return
      }
      this.profile = data
    },

    subscribeProfile() {
      if (this.realtimeChannel || !this.session?.user?.id) return
      this.realtimeChannel = supabase
        .channel(`profile:${this.session.user.id}`)
        .on(
          'postgres_changes',
          {
            event: 'UPDATE',
            schema: 'public',
            table: 'profiles',
            filter: `id=eq.${this.session.user.id}`
          },
          (payload) => {
            this.profile = payload.new
          }
        )
        .subscribe()
    },

    unsubscribeProfile() {
      if (this.realtimeChannel) {
        supabase.removeChannel(this.realtimeChannel)
        this.realtimeChannel = null
      }
    },

    async signInWithPassword(email, password) {
      this.loading = true
      try {
        const { error } = await supabase.auth.signInWithPassword({ email, password })
        if (error) throw error
      } finally {
        this.loading = false
      }
    },

    async signUp(email, password, fullName) {
      this.loading = true
      try {
        const { data, error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: { full_name: fullName },
            emailRedirectTo: window.location.origin + '/auth/callback'
          }
        })
        if (error) throw error
        return data
      } finally {
        this.loading = false
      }
    },

    async updateProfile(patch) {
      if (!this.session?.user?.id) throw new Error('Niet ingelogd')
      // Upsert (insert-of-update) zodat een ontbrekend profiel zichzelf
      // herstelt — vangrail tegen handmatige database-mutaties of zeldzame
      // race condities met de auth trigger.
      const { data, error } = await supabase
        .from('profiles')
        .upsert(
          {
            id: this.session.user.id,
            email: this.session.user.email,
            ...patch
          },
          { onConflict: 'id' }
        )
        .select()
        .single()
      if (error) throw error
      this.profile = data
      return data
    },

    async signOut() {
      this.unsubscribeProfile()
      await supabase.auth.signOut()
      this.session = null
      this.profile = null
    }
  }
})
