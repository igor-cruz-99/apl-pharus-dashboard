/**
 * Aparência compartilhada dos tooltips do Recharts.
 *
 * ⚠️ POR QUE ISTO EXISTE NUM ARQUIVO SÓ
 *   O Recharts pinta o texto do item com um cinza escuro fixo (`#666`) quando
 *   `itemStyle` não é informado. Sobre o fundo preto do tooltip isso fica
 *   praticamente ilegível — e o defeito era o MESMO nos seis gráficos, porque
 *   o estilo tinha sido copiado de um para o outro já sem o `itemStyle`.
 *
 *   Cada cópia nova herdava o problema em silêncio. Com um objeto só, acertar
 *   aqui acerta em todos, e o próximo gráfico nasce legível.
 */
export const tooltipEstilo = {
  // Tooltip preto sobre o painel creme — um dos detalhes pretos do tema.
  background: 'var(--color-ink)',
  border: '1px solid var(--color-ink)',
  borderRadius: 10,
  fontSize: 12,
} as const

/** O rótulo (a data, a categoria) é secundário: fica no tom apagado. */
export const tooltipRotulo = { color: 'var(--color-laranja-claro)' } as const

/** O valor é o que a pessoa foi ali ler: tom cheio e peso. */
export const tooltipItem = { color: 'var(--color-card)', fontWeight: 600 } as const

/** Espalhe nos `<Tooltip />` — `{...tooltipProps}` cobre os três de uma vez. */
export const tooltipProps = {
  contentStyle: tooltipEstilo,
  labelStyle: tooltipRotulo,
  itemStyle: tooltipItem,
} as const
