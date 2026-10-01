import { useEffect, useState, type RefObject } from 'react'
import { createPortal } from 'react-dom'

/**
 * Tira uma imagem da página inteira — do cabeçalho ao fim da matriz — e abre
 * numa janela por cima do painel, onde dá para rolar até o final e baixar.
 *
 * A captura é feita no navegador, com os dados e o filtro que estão na tela
 * naquele momento. Usa html-to-image (SVG foreignObject): quem desenha é o
 * próprio navegador, então as cores do Tailwind 4 (color-mix) saem certas —
 * o html2canvas reimplementa o CSS e erra justamente nelas.
 *
 * O que estiver recolhido (blocos da sanfona) sai recolhido: a imagem é o
 * retrato da tela, não um relatório.
 */
export function BotaoCaptura({ alvo }: { alvo: RefObject<HTMLElement | null> }) {
  const [gerando, setGerando] = useState(false)
  const [imagem, setImagem] = useState<{ url: string; quando: Date } | null>(null)
  const [erro, setErro] = useState<string | null>(null)

  async function capturar() {
    const el = alvo.current
    if (!el) return
    setGerando(true)
    setErro(null)
    try {
      // Import sob demanda: a biblioteca só é baixada quando alguém clica.
      const { toPng } = await import('html-to-image')
      const url = await toPng(el, {
        // Nítida em tela retina sem virar um arquivo gigante.
        pixelRatio: Math.min(window.devicePixelRatio || 1, 2),
        backgroundColor: getComputedStyle(document.body).backgroundColor,
        // A própria barra de botões não precisa sair na foto do botão.
        filter: (n) => !(n instanceof HTMLElement && n.dataset.semCaptura != null),
        cacheBust: true,
      })
      setImagem({ url, quando: new Date() })
    } catch (e) {
      setErro((e as Error).message || 'Não foi possível gerar a imagem.')
    } finally {
      setGerando(false)
    }
  }

  // Esc fecha a janela; a página de trás não rola enquanto ela está aberta.
  useEffect(() => {
    if (!imagem) return
    const fechar = (e: KeyboardEvent) => e.key === 'Escape' && setImagem(null)
    window.addEventListener('keydown', fechar)
    const antes = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      window.removeEventListener('keydown', fechar)
      document.body.style.overflow = antes
    }
  }, [imagem])

  const carimbo = imagem?.quando.toLocaleString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })
  const nomeArquivo = imagem
    ? `apl-pharus-${imagem.quando.toISOString().slice(0, 16).replace(/[:T]/g, '-')}.png`
    : ''

  return (
    <>
      <button
        type="button"
        data-sem-captura
        onClick={capturar}
        disabled={gerando}
        title={erro ?? 'Gera uma imagem da página inteira, como está agora na tela.'}
        className="flex items-center gap-2 rounded-full border border-line bg-card px-4 py-2 text-xs font-semibold tracking-wide text-ink transition hover:border-laranja/60 disabled:opacity-60"
      >
        <svg
          viewBox="0 0 24 24"
          aria-hidden="true"
          className={`h-3.5 w-3.5 ${gerando ? 'animate-pulse' : ''}`}
          fill="none"
          stroke="currentColor"
          strokeWidth={2.2}
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <rect x="3" y="6" width="18" height="14" rx="2" />
          <path d="M8 6l1.5-2h5L16 6" />
          <circle cx="12" cy="13" r="3.5" />
        </svg>
        {gerando ? 'GERANDO…' : erro ? 'FALHOU' : 'IMAGEM'}
      </button>

      {imagem &&
        createPortal(
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Imagem do painel"
            className="fixed inset-0 z-50 flex flex-col bg-ink/85"
            onClick={() => setImagem(null)}
          >
            <div
              className="flex shrink-0 items-center justify-between gap-4 bg-ink px-5 py-3 text-bg"
              onClick={(e) => e.stopPropagation()}
            >
              <span className="text-sm font-semibold">
                Painel APL · Pharus <span className="font-normal text-bg/60">— {carimbo}</span>
              </span>
              <div className="flex items-center gap-2">
                <a
                  href={imagem.url}
                  download={nomeArquivo}
                  className="rounded-full bg-laranja px-4 py-1.5 text-xs font-semibold tracking-wide text-ink transition hover:opacity-90"
                >
                  BAIXAR PNG
                </a>
                <button
                  type="button"
                  onClick={() => setImagem(null)}
                  className="rounded-full border border-bg/30 px-4 py-1.5 text-xs font-semibold tracking-wide text-bg transition hover:border-bg/60"
                >
                  FECHAR
                </button>
              </div>
            </div>
            {/* Só a imagem rola; clique fora dela fecha. */}
            <div className="flex-1 overflow-auto p-4 sm:p-6">
              <img
                src={imagem.url}
                alt="Captura da página inteira do painel"
                className="mx-auto block w-full max-w-[1800px] rounded-lg shadow-2xl"
                onClick={(e) => e.stopPropagation()}
              />
            </div>
          </div>,
          document.body,
        )}
    </>
  )
}
