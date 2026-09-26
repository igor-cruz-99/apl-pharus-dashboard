-- ============================================================================
-- APL · Pharus — 03. Perfil do lead (respostas do formulário)
--
-- ⚠️ RODAR NO BUSINESS DATA. Sem senha, cola direto. Pode rodar de novo.
--
-- Uma linha por (pergunta, resposta) com a contagem de leads do período.
-- O painel decide o gráfico de cada pergunta; aqui é só contar.
--
--   pergunta      → nome da coluna do formulário (renda, capital, …) mais
--                   'dia_semana' (0 = domingo … 6 = sábado) e 'hora' (0 … 23)
--   resposta      → o texto da opção, como veio do formulário
--   leads         → quantos leads marcaram essa opção
--   respondentes  → quantos leads responderam a pergunta — é a BASE do %.
--                   Não é o total de leads: quem deixou em branco não entra,
--                   senão as fatias somariam menos de 100% e pareceriam erro.
--
-- ⚠️ `o_que_busca_pharus` é a única de MÚLTIPLA marcação: chega como
--   "Opção A., Opção B." (as opções terminam em ponto e são unidas por ", ").
--   O corte é em ", " só quando vem logo depois de um ponto — vírgula no meio
--   de uma opção não quebra nada. Cada lead pode contar em várias opções,
--   então ali os % somam MAIS de 100%, e a base é quem respondeu.
-- ============================================================================

create or replace function mkt_apl.fn_perfil(p_ini date, p_fim date)
returns table (pergunta text, resposta text, leads bigint, respondentes bigint)
language sql
stable
as $$
with base as (
  select * from mkt_apl.cadastrados
  where data between p_ini and p_fim
),
respostas as (
            select 'dia_semana' as pergunta, extract(dow from data)::int::text as resposta from base where data is not null
  union all select 'hora',                extract(hour from hora)::int::text             from base where hora is not null
  union all select 'renda',               nullif(trim(renda), '')               from base
  union all select 'capital',             nullif(trim(capital), '')             from base
  union all select 'aporte',              nullif(trim(aporte), '')              from base
  union all select 'profissao',           nullif(trim(profissao), '')           from base
  union all select 'situacao_atual',      nullif(trim(situacao_atual), '')      from base
  union all select 'quem_ao_lado',        nullif(trim(quem_ao_lado), '')        from base
  union all select 'construir_estrutura', nullif(trim(construir_estrutura), '') from base
  union all select 'preocupa',            nullif(trim(preocupa), '')            from base
  union all select 'urgencia',            nullif(trim(urgencia), '')            from base
  union all
  select 'o_que_busca', nullif(trim(opcao), '')
  from base, regexp_split_to_table(o_que_busca_pharus, '(?<=\.),\s*') as opcao
),
contagem as (
  select pergunta, resposta, count(*) as leads
  from respostas
  where resposta is not null
  group by 1, 2
),
-- Na múltipla, a base é quem respondeu (linhas), não a soma das marcações.
base_multipla as (
  select count(*) as n from base where nullif(trim(o_que_busca_pharus), '') is not null
)
select
  c.pergunta,
  c.resposta,
  c.leads,
  case when c.pergunta = 'o_que_busca' then (select n from base_multipla)
       else sum(c.leads) over (partition by c.pergunta)
  end::bigint as respondentes
from contagem c;
$$;


-- Ponte no public (mesmo motivo do sql/08 do SE: o PostgREST só enxerga o
-- public). Só a service_role — que só o servidor do painel tem — executa.
create or replace function public.apl_perfil(p_ini date, p_fim date)
returns table (pergunta text, resposta text, leads bigint, respondentes bigint)
language sql
stable
security definer
set search_path = mkt_apl, public
as $$ select * from mkt_apl.fn_perfil(p_ini, p_fim); $$;

revoke all on function public.apl_perfil(date, date) from public, anon, authenticated;
grant execute on function public.apl_perfil(date, date) to service_role;

notify pgrst, 'reload schema';


-- ============================================================================
-- CONFERÊNCIA
-- ============================================================================
-- 1) Cada pergunta com seu total (dia_semana tem de bater com o nº de cadastros):
--   select pergunta, sum(leads), max(respondentes)
--     from mkt_apl.fn_perfil('2026-01-01', current_date) group by 1 order by 1;
--   select count(*) from mkt_apl.cadastrados;
--
-- 2) A múltipla quebrou nas opções certas (nenhuma resposta com ".," no meio):
--   select resposta, leads from mkt_apl.fn_perfil('2026-01-01', current_date)
--    where pergunta = 'o_que_busca' order by 2 desc;
-- ============================================================================
