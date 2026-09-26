import { Panel } from '../ui/Panel'
import { formatInt, formatPct } from '../../utils/format'

export interface Resposta {
  resposta: string
  leads: number
}

/**
 * Barras horizontais para as perguntas de opção em FRASE ("Tenho dinheiro e
 * investimentos, mas ainda não sigo…"). Feito com divs porque o eixo do
 * Recharts corta rótulo longo numa linha só; aqui o texto quebra por cima da
 * barra e a frase inteira fica legível.
 *
 * Uma cor só: as opções são categorias sem ordem, e a barra já diz o tamanho.
 * Ordem por volume — responde "o que mais aparece".
 *
 * `base` é quem respondeu. Em pergunta de múltipla marcação cada lead conta em
 * várias opções, os % somam mais de 100% — `multipla` avisa isso no rodapé.
 */
export function BarrasRespostas({
  titulo,
  linhas,
  base,
  multipla = false,
  className = '',
}: {
  titulo: string
  linhas: Resposta[]
  base: number
  multipla?: boolean
  className?: string
}) {
  const dados = [...linhas].sort((a, b) => b.leads - a.leads)
  const max = Math.max(1, ...dados.map((d) => d.leads))

  return (
    <Panel className={`flex flex-col p-5 ${className}`}>
      <div className="mb-4 flex items-baseline justify-between gap-4">
        <h3 className="titulo">{titulo}</h3>
        <span className="numero shrink-0 text-xs text-muted">
          {formatInt(base)} {base === 1 ? 'respondeu' : 'responderam'}
        </span>
      </div>

      {dados.length === 0 ? (
        <p className="flex flex-1 items-center justify-center py-6 text-sm text-faint">
          Sem respostas no período.
        </p>
      ) : (
        <ul className="flex flex-col gap-3.5">
          {dados.map((d) => {
            const pct = base > 0 ? (100 * d.leads) / base : null
            return (
              <li
                key={d.resposta}
                title={`${d.resposta}\n${formatInt(d.leads)} leads · ${formatPct(pct, 1)}`}
              >
                <p className="text-[13px] leading-snug text-ink">{d.resposta}</p>
                <div className="mt-1.5 flex items-center gap-3">
                  <div className="h-2.5 flex-1 overflow-hidden rounded-full bg-card-alt">
                    <div
                      className="h-full rounded-full bg-laranja"
                      style={{ width: `${(d.leads / max) * 100}%` }}
                    />
                  </div>
                  <span className="numero w-10 shrink-0 text-right text-sm font-semibold text-ink">
                    {formatInt(d.leads)}
                  </span>
                  <span className="numero w-11 shrink-0 text-right text-xs text-muted">
                    {formatPct(pct, 0)}
                  </span>
                </div>
              </li>
            )
          })}
        </ul>
      )}

      {multipla && dados.length > 0 && (
        <p className="mt-4 text-[11px] text-faint">
          Múltipla escolha: cada lead pode marcar mais de uma opção, então os % somam mais de 100%.
        </p>
      )}
    </Panel>
  )
}
