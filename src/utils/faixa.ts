/**
 * Faixas de valor do formulário do APL ("Entre R$ 50 mil e R$ 100 mil").
 *
 * As opções são frases inteiras: não cabem em volta de uma rosca e, pior, em
 * ordem alfabética "Acima de R$ 1 milhão" viria antes de "Até R$ 10 mil".
 * Daqui saem o rótulo curto e a posição na escala.
 *
 * É por regex, não por tabela fixa: se o formulário ganhar uma faixa nova ela
 * encurta e se ordena sozinha. O que não casar fica com o texto original e vai
 * para o fim — aparece, em vez de sumir.
 */

/** Valores da frase, em MIL reais: "R$ 1 milhão" → 1000, "R$ 50 mil" → 50. */
function valores(r: string): number[] {
  const out: number[] = []
  const re = /R\$\s*([\d.,]+)\s*(mil(?!h)|milh[aã]o|milh[oõ]es)?/gi
  for (const m of r.matchAll(re)) {
    const n = Number(m[1].replace(/\./g, '').replace(',', '.'))
    if (!Number.isFinite(n)) continue
    const unidade = (m[2] ?? '').toLowerCase()
    out.push(unidade.startsWith('milh') ? n * 1000 : unidade === 'mil' ? n : n / 1000)
  }
  return out
}

function curto(milhares: number): string {
  if (milhares >= 1000) return `${(milhares / 1000).toLocaleString('pt-BR')} mi`
  return `${milhares.toLocaleString('pt-BR')} mil`
}

/** "Entre R$ 50 mil e R$ 100 mil" → "50–100 mil" · "Até R$ 10 mil" → "Até 10 mil" */
export function curtoFaixa(r: string): string {
  const v = valores(r)
  if (v.length >= 2) {
    const [a, b] = [curto(v[0]), curto(v[1])]
    // Mesma unidade dos dois lados: só a do fim ("50–100 mil").
    const ua = a.split(' ')[1]
    const ub = b.split(' ')[1]
    return ua === ub ? `${a.split(' ')[0]}–${b}` : `${a}–${b}`
  }
  if (v.length === 1) {
    if (/acima|mais de|a partir/i.test(r)) return `${curto(v[0])}+`
    if (/at[eé]|menos de/i.test(r)) return `Até ${curto(v[0])}`
  }
  return r
}

/** Posição na escala. "Até X" vem antes de "Entre X e Y"; "Acima de X", depois. */
export function ordemFaixa(r: string): number {
  const v = valores(r)
  if (v.length === 0) return Number.MAX_SAFE_INTEGER
  if (/at[eé]|menos de/i.test(r) && v.length === 1) return v[0] - 0.5
  if (/acima|mais de|a partir/i.test(r) && v.length === 1) return v[0] + 0.5
  return v[0]
}
