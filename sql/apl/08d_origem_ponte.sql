-- ============================================================================
-- APL · Pharus — 08d. Filtro de origem: ponte no public
--
-- ⚠️ RODAR NO BUSINESS DATA, por último. Depois dele o painel volta.
-- ============================================================================

create or replace function public.apl_perfil(p_ini date, p_fim date, p_origens text[] default null)
returns table (pergunta text, resposta text, leads bigint, respondentes bigint)
language sql
stable
security definer
set search_path = mkt_apl, public
as $$ select * from mkt_apl.fn_perfil(p_ini, p_fim, p_origens); $$;

revoke all on function public.apl_perfil(date, date, text[]) from public, anon, authenticated;
grant execute on function public.apl_perfil(date, date, text[]) to service_role;


create or replace function public.apl_kpis(p_ini date, p_fim date, p_origens text[] default null)
returns table (
  dias integer, investimento numeric, impressoes bigint, cliques bigint,
  leads bigint, mql bigint, agendamentos bigint, agendas bigint, calls bigint,
  no_shows bigint, pendentes bigint, sem_registro bigint, vendas bigint,
  faturamento numeric, ctr numeric, pct_leads numeric, pct_mql numeric,
  pct_agend numeric, pct_comparecimento numeric, pct_no_show numeric,
  pct_conversao numeric, cpm numeric, cpc numeric, cpl numeric, cpmql numeric,
  cpa numeric, ccall numeric, cac numeric, roas numeric
)
language sql stable security definer set search_path = mkt_apl, mkt_se, public
as $$ select * from mkt_apl.fn_kpis(p_ini, p_fim, p_origens); $$;

create or replace function public.apl_serie_diaria(p_ini date, p_fim date, p_origens text[] default null)
returns table (
  data date, investimento numeric, impressoes bigint, cliques bigint,
  leads bigint, mql bigint, agendamentos bigint, calls bigint,
  vendas bigint, faturamento numeric
)
language sql stable security definer set search_path = mkt_apl, mkt_se, public
as $$ select * from mkt_apl.fn_serie_diaria(p_ini, p_fim, p_origens); $$;

create or replace function public.apl_trafego(p_ini date, p_fim date, p_origens text[] default null)
returns table (
  nivel text, chave text, campanha_pai text, conjunto_pai text,
  investimento numeric, impressoes bigint, cliques bigint, leads bigint,
  agendamentos bigint, vendas bigint, faturamento numeric, cpl numeric,
  cac numeric, qualif_50k numeric, hook numeric, hold numeric, body numeric
)
language sql stable security definer set search_path = mkt_apl, mkt_se, public
as $$ select * from mkt_apl.fn_trafego(p_ini, p_fim, p_origens); $$;

create or replace function public.apl_ciclo_vendas(p_ini date, p_fim date, p_origens text[] default null)
returns table (
  nome text, anuncio text, data_criacao date, data_agendamento date,
  data_venda date, dias_cria_agen integer, dias_agen_venda integer,
  dias_cria_venda integer
)
language sql stable security definer set search_path = mkt_apl, mkt_se, public
as $$ select * from mkt_apl.fn_ciclo_vendas(p_ini, p_fim, p_origens); $$;

create or replace function public.apl_macro(p_ano integer default null, p_origens text[] default null)
returns table (
  mes date, investimento numeric, impressoes bigint, cliques bigint, cpc numeric,
  leads bigint, cpl numeric, mql bigint, pct_mql numeric, cpmql numeric,
  agendamentos bigint, agendas bigint, calls bigint, cust_agen numeric,
  vendas bigint, cac numeric, faturamento numeric,
  pct_comparecimento numeric, sem_registro bigint
)
language sql stable security definer set search_path = mkt_apl, mkt_se, public
as $$ select * from mkt_apl.fn_macro(p_ano, p_origens); $$;

create or replace function public.apl_metas()
returns table (chave text, rotulo text, valor numeric, direcao text, formato text)
language sql stable security definer set search_path = mkt_apl, public
as $$ select chave, rotulo, valor, direcao, formato from mkt_apl.metas order by chave; $$;

revoke all on function public.apl_kpis(date, date, text[])          from public, anon, authenticated;
revoke all on function public.apl_serie_diaria(date, date, text[])  from public, anon, authenticated;
revoke all on function public.apl_trafego(date, date, text[])       from public, anon, authenticated;
revoke all on function public.apl_ciclo_vendas(date, date, text[])  from public, anon, authenticated;
revoke all on function public.apl_macro(integer, text[])            from public, anon, authenticated;
revoke all on function public.apl_metas()                   from public, anon, authenticated;
grant execute on function public.apl_kpis(date, date, text[])         to service_role;
grant execute on function public.apl_serie_diaria(date, date, text[]) to service_role;
grant execute on function public.apl_trafego(date, date, text[])      to service_role;
grant execute on function public.apl_ciclo_vendas(date, date, text[]) to service_role;
grant execute on function public.apl_macro(integer, text[])           to service_role;
grant execute on function public.apl_metas()                  to service_role;

revoke all on all tables in schema mkt_apl from anon, authenticated;

notify pgrst, 'reload schema';
