import { useState } from 'react'

/**
 * Reprocessa os dados na hora: refaz as cópias no banco e recarrega o painel.
 *
 * O servidor tem trava de 2 minutos (o Anchor não aguenta cópias seguidas);
 * quando ela segura o pedido, o painel só recarrega e o botão avisa que os
 * dados já estavam frescos — em vez de fingir que reprocessou.
 */
export function BotaoAtualizar({
  onAtualizar,
}: {
  onAtualizar: () => Promise<{ atualizado_em: string; reprocessou: boolean } | null>
}) {
  const [rodando, setRodando] = useState(false)
  const [aviso, setAviso] = useState<string | null>(null)

  async function clicar() {
    setRodando(true)
    setAviso(null)
    try {
      const r = await onAtualizar()
      const hora = r
        ? new Date(r.atualizado_em).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
        : null
      setAviso(
        !r ? 'Atualizado' : r.reprocessou ? `Atualizado às ${hora}` : `Já estava atualizado (${hora})`,
      )
    } catch (e) {
      setAviso(`Falhou: ${(e as Error).message}`)
    } finally {
      setRodando(false)
      window.setTimeout(() => setAviso(null), 6000)
    }
  }

  return (
    <button
      type="button"
      onClick={clicar}
      disabled={rodando}
      title={aviso ?? 'Refaz as cópias do banco agora (cadastros, anúncios, CRM e contratos) e recarrega o painel.'}
      className="flex items-center gap-2 rounded-full border border-line bg-card px-4 py-2 text-xs font-semibold tracking-wide text-ink transition hover:border-laranja/60 disabled:opacity-60"
    >
      <svg
        viewBox="0 0 24 24"
        aria-hidden="true"
        className={`h-3.5 w-3.5 ${rodando ? 'animate-spin' : ''}`}
        fill="none"
        stroke="currentColor"
        strokeWidth={2.2}
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M21 12a9 9 0 1 1-2.64-6.36" />
        <polyline points="21 3 21 9 15 9" />
      </svg>
      {rodando ? 'ATUALIZANDO…' : aviso ? aviso.toUpperCase() : 'ATUALIZAR'}
    </button>
  )
}
