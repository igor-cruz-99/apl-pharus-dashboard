/**
 * Seletor de origem do lead — Typeform × Forms Nativo.
 *
 * Seleção ÚNICA com "Todas": com duas origens, marcar e desmarcar caixas só
 * criaria um terceiro estado inútil (nenhuma marcada). Filtra tráfego pela
 * campanha e leads pela coluna `origem` do cadastro; agendamentos e vendas
 * seguem a origem do lead (sql/apl/07).
 */
export const ORIGENS = ['Typeform', 'Forms Nativo'] as const
export type Origem = (typeof ORIGENS)[number]

export function FiltroOrigem({
  valor,
  onMudar,
}: {
  valor: Origem | null
  onMudar: (o: Origem | null) => void
}) {
  const opcoes: { chave: Origem | null; texto: string }[] = [
    { chave: null, texto: 'TODAS' },
    ...ORIGENS.map((o) => ({ chave: o, texto: o.toUpperCase() })),
  ]
  return (
    <div
      role="radiogroup"
      aria-label="Origem do lead"
      className="flex items-center gap-1 rounded-full border border-line bg-card p-1"
    >
      {opcoes.map((o) => {
        const ativo = valor === o.chave
        return (
          <button
            key={o.texto}
            role="radio"
            aria-checked={ativo}
            onClick={() => onMudar(o.chave)}
            className={`rounded-full px-4 py-1.5 text-xs font-semibold tracking-wide transition ${
              ativo ? 'bg-laranja text-ink' : 'text-muted hover:text-ink'
            }`}
          >
            {o.texto}
          </button>
        )
      })}
    </div>
  )
}
