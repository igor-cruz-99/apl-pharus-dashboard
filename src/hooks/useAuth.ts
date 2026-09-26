import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabaseAuth } from '../lib/supabase'

/**
 * Estado de autenticação via Supabase Auth (projeto de funcionários).
 * - session: sessão atual (null = deslogado)
 * - loading: enquanto verifica a sessão inicial
 * - erro:    falha na volta do login com Google, para a tela de login mostrar
 */
export function useAuth() {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [erro, setErro] = useState<string | null>(null)

  useEffect(() => {
    if (!supabaseAuth) {
      setLoading(false)
      return
    }
    const auth = supabaseAuth.auth

    // Reage a login/logout/refresh de token.
    const { data: sub } = auth.onAuthStateChange((_event, s) => {
      setSession(s)
    })

    async function iniciar() {
      // Volta do Google: a URL traz ?code= (sucesso) ou ?error_description=
      // (o provedor recusou). Nos dois casos a URL é limpa em seguida — um
      // code é de uso único, e recarregar a página com ele daria erro de novo.
      const params = new URLSearchParams(window.location.search)
      const code = params.get('code')
      const erroUrl = params.get('error_description') ?? params.get('error')

      if (code || erroUrl) {
        window.history.replaceState({}, '', window.location.pathname)
      }
      if (erroUrl) {
        setErro(`Login com Google recusado: ${erroUrl}`)
      } else if (code) {
        const { error } = await auth.exchangeCodeForSession(code)
        if (error) setErro(`Não foi possível concluir o login com Google: ${error.message}`)
      }

      // Sessão inicial (persistida no localStorage pelo supabase-js).
      const { data } = await auth.getSession()
      setSession(data.session)
      setLoading(false)
    }
    iniciar()

    return () => sub.subscription.unsubscribe()
  }, [])

  return { session, loading, erro }
}
