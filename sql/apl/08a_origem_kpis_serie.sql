-- ============================================================================
-- APL · Pharus — 08a. Filtro de origem: KPIs e série diária
--
-- ⚠️ RODAR NO BUSINESS DATA, depois do 07. Depois rode 08b, 08c e 08d.
-- ============================================================================

-- As funções ganham o parâmetro p_origens. Mudar a lista de parâmetros cria
-- uma função NOVA ao lado da antiga (e a chamada fica ambígua), então as
-- antigas saem primeiro. Entre este arquivo e o 08d o painel fica sem dados.
drop function if exists public.apl_kpis(date, date);
drop function if exists public.apl_serie_diaria(date, date);
drop function if exists public.apl_trafego(date, date);
drop function if exists public.apl_ciclo_vendas(date, date);
drop function if exists public.apl_perfil(date, date);
drop function if exists public.apl_macro(integer);
drop function if exists mkt_apl.fn_macro(integer);
drop function if exists mkt_apl.fn_kpis(date, date);
drop function if exists mkt_apl.fn_serie_diaria(date, date);
drop function if exists mkt_apl.fn_trafego(date, date);
drop function if exists mkt_apl.fn_ciclo_vendas(date, date);
drop function if exists mkt_apl.fn_perfil(date, date);

create or replace function mkt_apl.fn_kpis(p_ini date, p_fim date, p_origens text[] default null)
returns table (
  dias integer, investimento numeric, impressoes bigint, cliques bigint,
  leads bigint, mql bigint, agendamentos bigint, agendas bigint, calls bigint,
  no_shows bigint, pendentes bigint, sem_registro bigint, vendas bigint,
  faturamento numeric, ctr numeric, pct_leads numeric, pct_mql numeric,
  pct_agend numeric, pct_comparecimento numeric, pct_no_show numeric,
  pct_conversao numeric, cpm numeric, cpc numeric, cpl numeric, cpmql numeric,
  cpa numeric, ccall numeric, cac numeric, roas numeric
)
language sql
stable
as $$
with ads as (
  select coalesce(sum(gasto), 0) as investimento,
         coalesce(sum(impressoes), 0) as impressoes,
         coalesce(sum(cliques), 0) as cliques
  from mkt_apl.vw_ads where data between p_ini and p_fim and (p_origens is null or origem = any(p_origens))
),
lead as (
  select count(*) as leads, count(*) filter (where mql) as mql
  from mkt_apl.vw_leads where data between p_ini and p_fim and (p_origens is null or origem = any(p_origens))
),
agen as (
  select count(*)                                          as agendamentos,
         count(*)                                          as agendas,
         count(*) filter (where situacao = 'realizado')    as calls,
         count(*) filter (where situacao = 'no_show')      as no_shows,
         count(*) filter (where situacao = 'pendente')     as pendentes,
         0::bigint                                         as sem_registro
  from mkt_apl.vw_agendamentos where data between p_ini and p_fim and (p_origens is null or origem = any(p_origens))
),
vend as (
  select count(*) as vendas, coalesce(sum(valor), 0) as faturamento
  from mkt_apl.vw_vendas where data between p_ini and p_fim and (p_origens is null or origem = any(p_origens))
)
select
  (p_fim - p_ini + 1)::integer,
  round(a.investimento::numeric, 2),
  a.impressoes::bigint, a.cliques::bigint, l.leads, l.mql,
  g.agendamentos, g.agendas, g.calls, g.no_shows, g.pendentes, g.sem_registro,
  v.vendas, round(v.faturamento::numeric, 2),
  round(100.0 * a.cliques      / nullif(a.impressoes, 0),         2),
  round(100.0 * l.leads        / nullif(a.cliques, 0),            2),
  round(100.0 * l.mql          / nullif(l.leads, 0),              2),
  round(100.0 * g.agendamentos / nullif(l.mql, 0),                2),
  round(100.0 * g.calls        / nullif(g.calls + g.no_shows, 0), 2),
  round(100.0 * g.no_shows     / nullif(g.calls + g.no_shows, 0), 2),
  round(100.0 * v.vendas       / nullif(g.agendamentos, 0),       2),
  round(1000 * a.investimento  / nullif(a.impressoes, 0),   2),
  round(a.investimento         / nullif(a.cliques, 0),      2),
  round(a.investimento         / nullif(l.leads, 0),        2),
  round(a.investimento         / nullif(l.mql, 0),          2),
  round(a.investimento         / nullif(g.agendamentos, 0), 2),
  round(a.investimento         / nullif(g.calls, 0),        2),
  round(a.investimento         / nullif(v.vendas, 0),       2),
  round(v.faturamento          / nullif(a.investimento, 0), 2)
from ads a, lead l, agen g, vend v;
$$;


create or replace function mkt_apl.fn_serie_diaria(p_ini date, p_fim date, p_origens text[] default null)
returns table (
  data date, investimento numeric, impressoes bigint, cliques bigint,
  leads bigint, mql bigint, agendamentos bigint, calls bigint,
  vendas bigint, faturamento numeric
)
language sql
stable
as $$
select
  d.dia::date,
  round(coalesce(a.gasto, 0)::numeric, 2),
  coalesce(a.impressoes, 0)::bigint,
  coalesce(a.cliques, 0)::bigint,
  coalesce(l.leads, 0), coalesce(l.mql, 0),
  coalesce(g.agendamentos, 0), coalesce(g.calls, 0),
  coalesce(v.vendas, 0),
  round(coalesce(v.faturamento, 0)::numeric, 2)
from generate_series(p_ini, p_fim, interval '1 day') as d(dia)
left join (
  select data, sum(gasto) gasto, sum(impressoes) impressoes, sum(cliques) cliques
  from mkt_apl.vw_ads where data between p_ini and p_fim and (p_origens is null or origem = any(p_origens)) group by data
) a on a.data = d.dia::date
left join (
  select data, count(*) leads, count(*) filter (where mql) mql
  from mkt_apl.vw_leads where data between p_ini and p_fim and (p_origens is null or origem = any(p_origens)) group by data
) l on l.data = d.dia::date
left join (
  select data, count(*) agendamentos, count(*) filter (where situacao = 'realizado') calls
  from mkt_apl.vw_agendamentos where data between p_ini and p_fim and (p_origens is null or origem = any(p_origens)) group by data
) g on g.data = d.dia::date
left join (
  select data, count(*) vendas, sum(valor) faturamento
  from mkt_apl.vw_vendas where data between p_ini and p_fim and (p_origens is null or origem = any(p_origens)) group by data
) v on v.data = d.dia::date
order by 1;
$$;
