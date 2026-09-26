import { useEffect, useState, type ReactNode } from 'react'

/**
 * Bloco recolhível. O conteúdo só é montado quando aberto: os gráficos do
 * Recharts medem a largura do pai ao montar, e montados escondidos nasceriam
 * com largura zero.
 *
 * O estado fica no navegador (`chave`): quem fechou um bloco não precisa
 * fechar de novo a cada visita. Falha de storage (aba anônima, bloqueio) cai
 * no padrão sem quebrar nada.
 */
export function Sanfona({
  chave,
  titulo,
  resumo,
  abertaPadrao = false,
  children,
}: {
  chave: string
  titulo: string
  resumo?: string
  abertaPadrao?: boolean
  children: ReactNode
}) {
  const [aberta, setAberta] = useState(() => {
    try {
      const v = window.localStorage.getItem(chave)
      return v == null ? abertaPadrao : v === '1'
    } catch {
      return abertaPadrao
    }
  })

  useEffect(() => {
    try {
      window.localStorage.setItem(chave, aberta ? '1' : '0')
    } catch {
      /* sem storage: só não lembra */
    }
  }, [chave, aberta])

  return (
    <section className="rounded-2xl border border-line bg-card/60">
      <button
        type="button"
        onClick={() => setAberta((a) => !a)}
        aria-expanded={aberta}
        className="flex w-full items-center justify-between gap-4 px-5 py-3.5 text-left transition hover:bg-card-alt/60"
      >
        <span className="flex items-baseline gap-3">
          <span className="titulo">{titulo}</span>
          {resumo && <span className="text-xs text-faint">{resumo}</span>}
        </span>
        <svg
          viewBox="0 0 24 24"
          aria-hidden="true"
          className={`h-4 w-4 shrink-0 text-muted transition-transform ${aberta ? 'rotate-180' : ''}`}
          fill="none"
          stroke="currentColor"
          strokeWidth={2}
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <polyline points="6 9 12 15 18 9" />
        </svg>
      </button>
      {aberta && <div className="border-t border-line p-4">{children}</div>}
    </section>
  )
}
