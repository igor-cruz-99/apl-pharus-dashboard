import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  LabelList,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { Panel } from '../ui/Panel'
import { Sanfona } from '../ui/Sanfona'
import { RendaDonut } from '../origem/RendaDonut'
import { BarrasRespostas, type Resposta } from './BarrasRespostas'
import { formatInt } from '../../utils/format'
import { tooltipProps } from '../../utils/chartTheme'
import { curtoFaixa, ordemFaixa } from '../../utils/faixa'
import type { PerfilLinha, RendaLinha } from '../../types'

/**
 * Perfil do lead — as respostas do formulário do APL (sql/apl/03_perfil.sql),
 * em blocos recolhíveis para a página não ficar interminável.
 *
 * O gráfico segue o TIPO de resposta, não o gosto:
 *   • dia da semana / hora → barras na ordem natural (domingo→sábado, 0h→23h):
 *     reordenar por volume destruiria a sequência que dá sentido à leitura.
 *   • faixas de valor (renda, capital, aporte) → rosca ordinal: a cor escurece
 *     conforme a faixa sobe, então a fatia se identifica pela cor.
 *   • opções em frase (profissão, situação, …) → barras horizontais com o texto
 *     inteiro por cima, ordenadas por volume. Categoria sem ordem própria não
 *     vai em rosca: a cor teria de distinguir 5+ fatias sem significado.
 */

const DIAS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado']

const TOPO = [0xd9, 0x57, 0x0a]
const BASE = [0xfb, 0xc9, 0x9f]

/** Barra mais forte quanto maior o valor — o pico salta sem precisar de legenda. */
function tom(v: number, max: number): string {
  const t = max > 0 ? 1 - Math.min(v / max, 1) : 0.5
  const c = TOPO.map((x, i) => Math.round(x + (BASE[i] - x) * t))
  return `rgb(${c[0]},${c[1]},${c[2]})`
}

const eixoTick = { fill: 'var(--color-muted)', fontSize: 11 }

/** Respostas de uma pergunta + a base (quem respondeu). */
function daPergunta(linhas: PerfilLinha[], pergunta: string): { itens: Resposta[]; base: number } {
  const doTipo = linhas.filter((l) => l.pergunta === pergunta)
  return {
    itens: doTipo.map((l) => ({ resposta: l.resposta, leads: Number(l.leads) })),
    base: Number(doTipo[0]?.respondentes ?? 0),
  }
}

/** Faixas de valor → fatias da rosca, na ordem da escala e com rótulo curto. */
function faixas(linhas: PerfilLinha[], pergunta: string): RendaLinha[] {
  const { itens, base } = daPergunta(linhas, pergunta)
  return itens
    .map((i) => ({
      faixa: curtoFaixa(i.resposta),
      ordem: ordemFaixa(i.resposta),
      leads: i.leads,
      pct: base > 0 ? (100 * i.leads) / base : null,
    }))
    .sort((a, b) => a.ordem - b.ordem)
}

export function PerfilLead({ linhas }: { linhas: PerfilLinha[] }) {
  const dias = DIAS.map((rotulo, i) => ({
    rotulo,
    leads: Number(linhas.find((l) => l.pergunta === 'dia_semana' && Number(l.resposta) === i)?.leads ?? 0),
  }))

  const horas = Array.from({ length: 24 }, (_, h) => ({
    rotulo: `${String(h).padStart(2, '0')}:00`,
    leads: Number(linhas.find((l) => l.pergunta === 'hora' && Number(l.resposta) === h)?.leads ?? 0),
  }))

  const maxDia = Math.max(1, ...dias.map((d) => d.leads))
  const maxHora = Math.max(1, ...horas.map((h) => h.leads))
  const totalLeads = dias.reduce((s, d) => s + d.leads, 0)

  const profissao = daPergunta(linhas, 'profissao')
  const situacao = daPergunta(linhas, 'situacao_atual')
  const aoLado = daPergunta(linhas, 'quem_ao_lado')
  const estrutura = daPergunta(linhas, 'construir_estrutura')
  const busca = daPergunta(linhas, 'o_que_busca')
  const preocupa = daPergunta(linhas, 'preocupa')
  const urgencia = daPergunta(linhas, 'urgencia')

  return (
    <div className="mt-8">
      <p className="rotulo">Análise</p>
      <h2 className="mt-1 mb-4 text-2xl font-bold tracking-tight text-ink">Perfil do lead</h2>

      <div className="flex flex-col gap-3">
        <Sanfona
          chave="apl-perfil-quando"
          titulo="Quando chegam"
          resumo={`${formatInt(totalLeads)} leads no período`}
          abertaPadrao
        >
          <div className="grid grid-cols-1 gap-5 lg:grid-cols-3">
        {/* ---------- 1/3: dia da semana ---------- */}
          <Panel className="p-5">
            <h3 className="titulo mb-4">Leads por dia da semana</h3>
            <div className="h-72">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart
                  data={dias}
                  layout="vertical"
                  margin={{ top: 4, right: 44, left: 4, bottom: 4 }}
                >
                  <XAxis type="number" hide domain={[0, maxDia]} />
                  <YAxis
                    type="category"
                    dataKey="rotulo"
                    width={68}
                    tick={eixoTick}
                    axisLine={false}
                    tickLine={false}
                  />
                  <Tooltip
                    cursor={{ fill: 'var(--color-card-alt)' }}
                    {...tooltipProps}
                    formatter={(v) => [`${formatInt(Number(v))} leads`, '']}
                  />
                  <Bar dataKey="leads" radius={[0, 4, 4, 0]} isAnimationActive={false}>
                    {dias.map((d, i) => (
                      <Cell key={i} fill={tom(d.leads, maxDia)} />
                    ))}
                    <LabelList
                      dataKey="leads"
                      position="right"
                      formatter={(v) => formatInt(Number(v))}
                      style={{ fill: 'var(--color-ink)', fontSize: 11, fontWeight: 600 }}
                    />
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Panel>
  
          {/* ---------- 2/3: horário ---------- */}
          <Panel className="p-5 lg:col-span-2">
            <h3 className="titulo mb-4">Atividade por horário</h3>
            <div className="h-72">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={horas} margin={{ top: 18, right: 8, left: 0, bottom: 4 }}>
                  <CartesianGrid stroke="var(--color-line)" vertical={false} />
                  <XAxis
                    dataKey="rotulo"
                    tick={eixoTick}
                    axisLine={false}
                    tickLine={false}
                    interval={0}
                    angle={-45}
                    textAnchor="end"
                    height={52}
                  />
                  <YAxis tick={eixoTick} axisLine={false} tickLine={false} width={40} />
                  <Tooltip
                    cursor={{ fill: 'var(--color-card-alt)' }}
                    {...tooltipProps}
                    formatter={(v) => [`${formatInt(Number(v))} leads`, '']}
                  />
                  <Bar dataKey="leads" radius={[3, 3, 0, 0]} isAnimationActive={false}>
                    {horas.map((h, i) => (
                      <Cell key={i} fill={tom(h.leads, maxHora)} />
                    ))}
                    <LabelList
                      dataKey="leads"
                      position="top"
                      formatter={(v) => (Number(v) > 0 ? formatInt(Number(v)) : '')}
                      style={{ fill: 'var(--color-muted)', fontSize: 10 }}
                    />
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Panel>
          </div>
        </Sanfona>

        <Sanfona chave="apl-perfil-financeiro" titulo="Financeiro" resumo="renda · capital · aporte">
          <div className="grid grid-cols-1 gap-5 lg:grid-cols-3">
            <RendaDonut linhas={faixas(linhas, 'renda')} titulo="Renda" />
            <RendaDonut linhas={faixas(linhas, 'capital')} titulo="Capital disponível" />
            <RendaDonut linhas={faixas(linhas, 'aporte')} titulo="Aporte mensal" />
          </div>
        </Sanfona>

        <Sanfona chave="apl-perfil-quem" titulo="Quem é" resumo="profissão · momento · decisão">
          <div className="grid grid-cols-1 gap-5 lg:grid-cols-3">
            <BarrasRespostas titulo="Profissão" linhas={profissao.itens} base={profissao.base} />
            <BarrasRespostas titulo="Situação atual" linhas={situacao.itens} base={situacao.base} />
            <BarrasRespostas titulo="Quem está ao lado na decisão" linhas={aoLado.itens} base={aoLado.base} />
          </div>
        </Sanfona>

        <Sanfona chave="apl-perfil-intencao" titulo="Intenção" resumo="o que busca · preocupação · urgência">
          <div className="grid grid-cols-1 gap-5 lg:grid-cols-2">
            <BarrasRespostas
              titulo="Quer construir uma estrutura patrimonial?"
              linhas={estrutura.itens}
              base={estrutura.base}
            />
            <BarrasRespostas titulo="Urgência" linhas={urgencia.itens} base={urgencia.base} />
            <BarrasRespostas
              titulo="O que busca no Pharus"
              linhas={busca.itens}
              base={busca.base}
              multipla
            />
            <BarrasRespostas titulo="O que mais preocupa" linhas={preocupa.itens} base={preocupa.base} />
          </div>
        </Sanfona>
      </div>
    </div>
  )
}
