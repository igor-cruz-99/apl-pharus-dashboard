import { supabaseAuth } from './supabase'
import { DEV_SKIP_AUTH } from './devAuth'
import type {
  CicloLinha,
  DiaSerie,
  Kpis,
  MacroLinha,
  Meta,
  PerfilLinha,
  TrafegoLinha,
} from '../types'

/**
 * Toda leitura de dado passa por aqui — e daqui para `/api/dashboard`.
 * O navegador nunca fala com o banco: só com o porteiro, que valida a sessão.
 */
async function chamar<T>(fn: string, params: Record<string, unknown> = {}): Promise<T[]> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }

  if (!DEV_SKIP_AUTH) {
    const { data } = await supabaseAuth!.auth.getSession()
    const token = data.session?.access_token
    if (!token) throw new Error('Sessão expirada. Faça login novamente.')
    headers.Authorization = `Bearer ${token}`
  }

  const r = await fetch('/api/dashboard', {
    method: 'POST',
    headers,
    body: JSON.stringify({ fn, params }),
  })

  const corpo = (await r.json()) as { data?: T[]; error?: string }
  if (!r.ok) throw new Error(corpo.error ?? 'Falha ao consultar os dados.')
  return corpo.data ?? []
}

/**
 * Todas as leituras são das funções do APL (sql/apl/04_funil.sql), que devolvem
 * o mesmo formato das do SE. Só recebem período: o APL não tem filtro de origem.
 */
export async function fetchKpis(inicio: string, fim: string): Promise<Kpis | null> {
  const linhas = await chamar<Kpis>('apl_kpis', { p_ini: inicio, p_fim: fim })
  return linhas[0] ?? null
}

export async function fetchSerie(inicio: string, fim: string): Promise<DiaSerie[]> {
  return chamar<DiaSerie>('apl_serie_diaria', { p_ini: inicio, p_fim: fim })
}

export async function fetchTrafego(inicio: string, fim: string): Promise<TrafegoLinha[]> {
  return chamar<TrafegoLinha>('apl_trafego', { p_ini: inicio, p_fim: fim })
}

export async function fetchCiclo(inicio: string, fim: string): Promise<CicloLinha[]> {
  return chamar<CicloLinha>('apl_ciclo_vendas', { p_ini: inicio, p_fim: fim })
}

/** Respostas do formulário do APL — sql/apl/03_perfil.sql. Sem filtro de origem. */
export async function fetchPerfil(inicio: string, fim: string): Promise<PerfilLinha[]> {
  return chamar<PerfilLinha>('apl_perfil', { p_ini: inicio, p_fim: fim })
}

/**
 * A matriz macro NÃO recebe período: mostra sempre o ano corrente,
 * independente do filtro da página. Ver mkt_apl.fn_macro (sql/apl/04).
 */
export async function fetchMacro(): Promise<MacroLinha[]> {
  return chamar<MacroLinha>('apl_macro', {})
}

/**
 * Metas são opcionais: se a tabela ainda não existir ou vier vazia, os badges
 * saem em cor neutra em vez de derrubar o painel inteiro.
 */
export async function fetchMetas(): Promise<Record<string, Meta>> {
  try {
    const linhas = await chamar<Meta>('apl_metas')
    return Object.fromEntries(linhas.map((m) => [m.chave, m]))
  } catch {
    return {}
  }
}
