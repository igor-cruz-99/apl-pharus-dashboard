import { useId } from 'react'
import { Panel } from '../ui/Panel'
import { formatBRL, formatInt, formatPct } from '../../utils/format'
import type { Kpis } from '../../types'

/**
 * Funil de aquisição — trapézios centralizados, taxas à esquerda e custos à
 * direita, alinhados às JUNÇÕES entre as etapas (é ali que a conversão de uma
 * etapa para a próxima acontece).
 *
 * O alinhamento sai do flex: a coluna central tem 8 faixas de peso 1; as
 * laterais têm meia faixa de folga, 7 faixas de peso 1 e outra meia folga.
 * Somam os mesmos 8, então as laterais caem exatamente entre as centrais —
 * sem número mágico de padding que quebraria em outra altura de tela.
 *
 * A largura de cada faixa é proporcional à POSIÇÃO na sequência, não ao valor:
 * o funil real cai de 763 mil impressões para 9 vendas, e um trapézio
 * proporcional ao número viraria uma linha invisível já na terceira etapa.
 */

const TOPO = [0xfb, 0xc9, 0x9f]
const BASE = [0xd9, 0x57, 0x0a]

/** Interpola do laranja claro no topo até o mais forte — degradê contínuo no funil. */
function tom(t: number): string {
  const c = TOPO.map((v, i) => Math.round(v + (BASE[i] - v) * Math.min(Math.max(t, 0), 1)))
  return `rgb(${c[0]},${c[1]},${c[2]})`
}

/** Raio do canto dos trapézios, em px. */
const RAIO = 4

interface Etapa {
  nome: string
  valor: string
}
interface Junta {
  taxa?: { rotulo: string; valor: string }
  custo: { rotulo: string; valor: string }
}

export function Funnel({ k }: { k: Kpis | null }) {
  // Id único por instância: os degradês do SVG são referenciados por id.
  const idBase = `funil${useId().replace(/:/g, '')}`

  if (!k) {
    return (
      <Panel className="flex h-full flex-col pb-5">
        <h2 className="titulo px-6 pt-4 text-center">Funil de aquisição</h2>
        <div className="flex flex-1 items-center justify-center text-sm text-faint">
          Sem dados no período.
        </div>
      </Panel>
    )
  }

  const etapas: Etapa[] = [
    { nome: 'Investimento', valor: formatBRL(k.investimento) },
    { nome: 'Impressões', valor: formatInt(k.impressoes) },
    { nome: 'Cliques', valor: formatInt(k.cliques) },
    { nome: 'Leads', valor: formatInt(k.leads) },
    { nome: 'MQL', valor: formatInt(k.mql) },
    { nome: 'Agendamentos', valor: formatInt(k.agendamentos) },
    { nome: 'Calls', valor: formatInt(k.calls) },
    { nome: 'Vendas', valor: formatInt(k.vendas) },
  ]

  const juntas: Junta[] = [
    { custo: { rotulo: 'CPM', valor: formatBRL(k.cpm) } },
    { taxa: { rotulo: 'CTR', valor: formatPct(k.ctr) }, custo: { rotulo: 'CPC', valor: formatBRL(k.cpc) } },
    { taxa: { rotulo: '%Leads', valor: formatPct(k.pct_leads) }, custo: { rotulo: 'CPL', valor: formatBRL(k.cpl) } },
    { taxa: { rotulo: '%MQL', valor: formatPct(k.pct_mql) }, custo: { rotulo: 'CPMQL', valor: formatBRL(k.cpmql) } },
    { taxa: { rotulo: '%Agend', valor: formatPct(k.pct_agend) }, custo: { rotulo: 'CPA', valor: formatBRL(k.cpa) } },
    { taxa: { rotulo: 'Comparecimento', valor: formatPct(k.pct_comparecimento) }, custo: { rotulo: 'CCall', valor: formatBRL(k.ccall) } },
    { taxa: { rotulo: 'Conversão', valor: formatPct(k.pct_conversao) }, custo: { rotulo: 'CAC', valor: formatBRL(k.cac) } },
  ]

  const total = etapas.length
  const larguraDe = (i: number) => 100 - (i / total) * 60

  return (
    <Panel className="flex h-full flex-col pb-5">
      <h2 className="titulo px-6 pt-4 text-center">Funil de aquisição</h2>

      <div className="mt-3 grid flex-1 grid-cols-[minmax(110px,1fr)_minmax(0,340px)_minmax(110px,1fr)] gap-x-5 px-6">
        {/* taxas — meia faixa de folga em cima e embaixo para cair nas junções */}
        <div className="flex flex-col">
          <div className="flex-[0.5]" />
          {juntas.map((j, i) => (
            <div key={i} className="flex flex-1 flex-col items-end justify-center text-right">
              {j.taxa && (
                <>
                  <span className="rotulo text-[11px]">{j.taxa.rotulo}</span>
                  <span className="numero text-base font-semibold text-ink">{j.taxa.valor}</span>
                </>
              )}
            </div>
          ))}
          <div className="flex-[0.5]" />
        </div>

        {/* os trapézios
            ⚠️ SVG, não clip-path: clip-path não arredonda canto. O canto
            redondo sai do contorno da própria cor com `strokeLinejoin="round"`
            — o traço de RAIO*2 px engorda o trapézio RAIO px para cada lado e
            arredonda as quinas. `non-scaling-stroke` mantém o traço em px
            mesmo com o SVG esticado (preserveAspectRatio="none"); sem ele o
            canto sairia oval. A folga entre etapas desconta esse engorde. */}
        <div className="flex flex-col py-1">
          {etapas.map((e, i) => {
            const topoEsq = (100 - larguraDe(i)) / 2
            const baseEsq = (100 - larguraDe(i + 1)) / 2
            const grad = `${idBase}-${i}`
            return (
            <div
              key={e.nome}
              className="relative flex flex-1 items-center justify-center"
              style={{ marginBottom: RAIO * 2 + 2 }}
            >
              <svg
                aria-hidden="true"
                className="absolute inset-0 h-full w-full overflow-visible"
                viewBox="0 0 100 100"
                preserveAspectRatio="none"
              >
                <defs>
                  <linearGradient id={grad} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0" stopColor={tom(i / total)} />
                    <stop offset="1" stopColor={tom((i + 1) / total)} />
                  </linearGradient>
                </defs>
                <polygon
                  points={`${topoEsq},0 ${100 - topoEsq},0 ${100 - baseEsq},100 ${baseEsq},100`}
                  fill={`url(#${grad})`}
                  stroke={`url(#${grad})`}
                  strokeWidth={RAIO * 2}
                  strokeLinejoin="round"
                  vectorEffect="non-scaling-stroke"
                />
              </svg>
              <div className="relative px-4 text-center leading-tight">
                <div className="text-[11px] font-bold tracking-[0.14em] text-ink/70 uppercase">
                  {e.nome}
                </div>
                <div className="numero text-lg font-extrabold text-ink">{e.valor}</div>
              </div>
            </div>
            )
          })}
        </div>

        {/* custos */}
        <div className="flex flex-col">
          <div className="flex-[0.5]" />
          {juntas.map((j, i) => (
            <div key={i} className="flex flex-1 flex-col justify-center">
              <span className="rotulo text-[11px]">{j.custo.rotulo}</span>
              <span className="numero text-base font-semibold text-ink">{j.custo.valor}</span>
            </div>
          ))}
          <div className="flex-[0.5]" />
        </div>
      </div>
    </Panel>
  )
}
