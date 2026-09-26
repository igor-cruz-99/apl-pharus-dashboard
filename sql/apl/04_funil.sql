-- ============================================================================
-- APL · Pharus — 04. Funil completo: leads → agendamentos → vendas
--
-- ⚠️ RODAR NO BUSINESS DATA, depois do 01, 02 e 03. Sem senha, cola direto.
--    Pode rodar de novo (tudo é create or replace).
--
-- DE ONDE VEM CADA ETAPA
--   tráfego       mkt_apl.ads          (espelho do Anchor, campanhas ls-APL-CAPTACAO)
--   leads         mkt_apl.cadastrados  (espelho do Anchor, formulário do APL)
--   agendamentos  mkt_se.crm_meetings  (espelho do Backup QV que o SE já mantém)
--   vendas        mkt_se.contratos     (espelho de contratos_pharus, idem)
--
--   O CRM e os contratos são os mesmos do SE — não há funil próprio do APL
--   no CRM. O que separa é o CRUZAMENTO com os cadastros do APL:
--
--     cadastro APL ──email ou telefone──► crm_leads ──lead_id──► crm_meetings
--     cadastro APL ──email ou telefone──► contratos_pharus
--
--   • E-mail: minúsculo e sem espaço.
--   • Telefone: só os 8 ÚLTIMOS dígitos. O cadastro guarda "5561984848484" e
--     o CRM às vezes "51985315784" (sem o 55) — os 8 finais batem nos dois.
--   • Só conta o que aconteceu NO DIA do cadastro ou DEPOIS. Quem já era lead
--     do SE e agendou antes de se cadastrar no APL não vira agendamento do APL.
--   • Se a pessoa se cadastrou mais de uma vez, vale o PRIMEIRO cadastro.
--
-- ⚠️ DEPENDE DO SE: usa mkt_se.crm_leads, crm_meetings e contratos (espelhos
--    que o SE atualiza a cada 15 min) e mkt_se.norm_chave. Se o SE for
--    desligado, esses espelhos precisam continuar existindo.
--
-- ⚠️ DUAS DEFINIÇÕES PROVISÓRIAS (confirmar com o gestor — mudam num lugar só):
--    • MQL = renda declarada a partir de R$ 20 mil  → mkt_apl.eh_mql()
--    • Valor da venda = valor à vista; se vazio, o parcelado → mkt_apl.vw_vendas
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Auxiliares
-- ----------------------------------------------------------------------------

-- 8 últimos dígitos do telefone; null se tiver menos de 8.
create or replace function mkt_apl.tel8(p text)
returns text
language sql
immutable
as $$
  select case when length(d) >= 8 then right(d, 8) end
  from (select regexp_replace(coalesce(p, ''), '\D', '', 'g') as d) t;
$$;

-- Piso da faixa, em MIL reais: "Entre R$ 50 mil e R$ 100 mil" → 50,
-- "Acima de R$ 1 milhão" → 1000, "Até R$ 20 mil" → 0.
create or replace function mkt_apl.piso_mil(p text)
returns numeric
language sql
immutable
as $$
  select case
    when p is null or trim(p) = '' then null
    when p ~* '^\s*(at[eé]|menos de)' then 0
    else (
      select replace(r[1], '.', '')::numeric
             * case when r[2] ~* '^milh' then 1000
                    when r[2] ~* '^mil'  then 1
                    else 0.001 end
      from regexp_match(p, 'R\$\s*([\d.]+)\s*(milh\S*|mil)?', 'i') as t(r)
    )
  end;
$$;

-- ⚠️ PROVISÓRIO: mesmo corte do SE (renda >= 20 mil).
create or replace function mkt_apl.eh_mql(p_renda text)
returns boolean
language sql
immutable
as $$ select coalesce(mkt_apl.piso_mil(p_renda) >= 20, false); $$;


-- ----------------------------------------------------------------------------
-- 2. Views
-- ----------------------------------------------------------------------------

create or replace view mkt_apl.vw_ads as
select
  a.data, a.campanha, a.conjunto, a.anuncio,
  a.gasto, a.impressoes, a.cliques,
  a.video_3s, a."video_25%" as video_25, a."video_50%" as video_50
from mkt_apl.ads a;

-- Um cadastro = um lead (mesma regra do SE: conta linha, não pessoa).
-- utm_campaign/medium/content → campanha/conjunto/anúncio (padrão dos links
-- da Meta: {{campaign.name}}, {{adset.name}}, {{ad.name}}).
create or replace view mkt_apl.vw_leads as
select
  c.id,
  c.created_at,
  c.data,
  c.hora,
  nullif(lower(trim(c.email)), '')                          as email,
  mkt_apl.tel8(coalesce(nullif(c.tel_8d, ''), c.telefone))  as tel8,
  c.nome_completo                                           as nome,
  c.utm_campaign                                            as campanha,
  c.utm_medium                                              as conjunto,
  c.utm_content                                             as anuncio,
  c.renda,
  mkt_apl.piso_mil(c.renda)                                 as renda_piso,
  mkt_apl.eh_mql(c.renda)                                   as mql
from mkt_apl.cadastrados c;

-- Leads do CRM que são pessoas que se cadastraram no APL, cada um preso ao
-- PRIMEIRO cadastro que casa por e-mail ou telefone.
create or replace view mkt_apl.vw_crm as
select
  cl.id           as crm_id,
  x.lead_id,
  x.cadastro_data
from mkt_se.crm_leads cl
cross join lateral (
  select l.id as lead_id, l.data as cadastro_data
  from mkt_apl.vw_leads l
  where (l.email is not null and l.email = lower(trim(cl.email)))
     or (l.tel8  is not null and l.tel8  = mkt_apl.tel8(cl.telefone))
  order by l.created_at
  limit 1
) x;

-- Um agendamento por lead do APL: a data é a do PRIMEIRO agendamento criado a
-- partir do dia do cadastro; a situação olha todas as calls desse período
-- (realizou alguma → realizado; senão faltou → no_show; …).
create or replace view mkt_apl.vw_agendamentos as
select
  l.id                                    as lead_id,
  min(m.created_at)::date                 as data,
  case
    when count(*) filter (where m.outcome = 'realizada') > 0 then 'realizado'
    when count(*) filter (where m.outcome = 'no_show')   > 0 then 'no_show'
    when count(*) filter (where m.outcome is null
                             or m.outcome in ('pendente', 'remarcada')) > 0 then 'pendente'
    else 'cancelado'
  end                                     as situacao,
  max(l.nome)                             as nome,
  max(l.campanha)                         as campanha,
  max(l.conjunto)                         as conjunto,
  max(l.anuncio)                          as anuncio
from mkt_apl.vw_crm c
join mkt_se.crm_meetings m on m.lead_id = c.crm_id
                          and m.created_at::date >= c.cadastro_data
join mkt_apl.vw_leads l    on l.id = c.lead_id
group by l.id;

-- Venda = contrato ASSINADO, fora do modo teste, de alguém que se cadastrou
-- no APL até o dia da assinatura.
create or replace view mkt_apl.vw_vendas as
select
  k.id                                    as contrato_id,
  x.lead_id,
  k.signed_at::date                       as data,
  -- ⚠️ PROVISÓRIO: à vista; se vazio, o parcelado.
  coalesce(nullif(k.valor_a_vista, 0), nullif(k.valor_parcelado, 0), 0) as valor,
  x.nome, x.campanha, x.conjunto, x.anuncio, x.cadastro_data
from mkt_se.contratos k
cross join lateral (
  select l.id as lead_id, l.data as cadastro_data, l.nome,
         l.campanha, l.conjunto, l.anuncio
  from mkt_apl.vw_leads l
  where (l.email is not null and l.email = lower(trim(k.email)))
     or (l.tel8  is not null and l.tel8  = mkt_apl.tel8(k.telefone))
  order by l.created_at
  limit 1
) x
where k.signed_at is not null
  and not coalesce(k.modo_teste, false)
  and k.signed_at::date >= x.cadastro_data;


-- ----------------------------------------------------------------------------
-- 3. KPIs — mesmo retorno do se_kpis, para o painel não mudar
-- ----------------------------------------------------------------------------
create or replace function mkt_apl.fn_kpis(p_ini date, p_fim date)
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
  from mkt_apl.vw_ads where data between p_ini and p_fim
),
lead as (
  select count(*) as leads, count(*) filter (where mql) as mql
  from mkt_apl.vw_leads where data between p_ini and p_fim
),
agen as (
  select count(*)                                          as agendamentos,
         count(*)                                          as agendas,
         count(*) filter (where situacao = 'realizado')    as calls,
         count(*) filter (where situacao = 'no_show')      as no_shows,
         count(*) filter (where situacao = 'pendente')     as pendentes,
         0::bigint                                         as sem_registro
  from mkt_apl.vw_agendamentos where data between p_ini and p_fim
),
vend as (
  select count(*) as vendas, coalesce(sum(valor), 0) as faturamento
  from mkt_apl.vw_vendas where data between p_ini and p_fim
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


-- ----------------------------------------------------------------------------
-- 4. Série diária
-- ----------------------------------------------------------------------------
create or replace function mkt_apl.fn_serie_diaria(p_ini date, p_fim date)
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
  from mkt_apl.vw_ads where data between p_ini and p_fim group by data
) a on a.data = d.dia::date
left join (
  select data, count(*) leads, count(*) filter (where mql) mql
  from mkt_apl.vw_leads where data between p_ini and p_fim group by data
) l on l.data = d.dia::date
left join (
  select data, count(*) agendamentos, count(*) filter (where situacao = 'realizado') calls
  from mkt_apl.vw_agendamentos where data between p_ini and p_fim group by data
) g on g.data = d.dia::date
left join (
  select data, count(*) vendas, sum(valor) faturamento
  from mkt_apl.vw_vendas where data between p_ini and p_fim group by data
) v on v.data = d.dia::date
order by 1;
$$;


-- ----------------------------------------------------------------------------
-- 5. Tráfego por campanha / conjunto / anúncio
--    Mesma lógica do fn_trafego do SE (sql/28): chave normalizada com
--    mkt_se.norm_chave, porque o nome da campanha no anúncio e na UTM podem
--    vir com '_' num e espaço no outro.
-- ----------------------------------------------------------------------------
create or replace function mkt_apl.fn_trafego(p_ini date, p_fim date)
returns table (
  nivel text, chave text, campanha_pai text, conjunto_pai text,
  investimento numeric, impressoes bigint, cliques bigint, leads bigint,
  agendamentos bigint, vendas bigint, faturamento numeric, cpl numeric,
  cac numeric, qualif_50k numeric, hook numeric, hold numeric, body numeric
)
language sql
stable
as $$
with
ads_base as (
  select campanha, conjunto, anuncio, gasto, impressoes, cliques, video_3s, video_25, video_50
  from mkt_apl.vw_ads where data between p_ini and p_fim
),
ads as (
  select 'campanha' as nivel,
         'campanha||' || coalesce(mkt_se.norm_chave(campanha), '~') as id,
         max(campanha) nome, null::text pai_c, null::text pai_j,
         sum(gasto) g, sum(impressoes) imp, sum(cliques) cli,
         sum(video_3s) v3, sum(video_25) v25, sum(video_50) v50
  from ads_base group by 1, 2
  union all
  select 'conjunto',
         'conjunto|' || coalesce(mkt_se.norm_chave(campanha), '~')
                     || '|' || coalesce(mkt_se.norm_chave(conjunto), '~'),
         max(conjunto), max(campanha), null,
         sum(gasto), sum(impressoes), sum(cliques), sum(video_3s), sum(video_25), sum(video_50)
  from ads_base group by 1, 2
  union all
  select 'anuncio',
         'anuncio|' || coalesce(mkt_se.norm_chave(campanha), '~')
                    || '|' || coalesce(mkt_se.norm_chave(conjunto), '~')
                    || '|' || coalesce(mkt_se.norm_chave(anuncio), '~'),
         max(anuncio), max(campanha), max(conjunto),
         sum(gasto), sum(impressoes), sum(cliques), sum(video_3s), sum(video_25), sum(video_50)
  from ads_base group by 1, 2
),
leads_base as (
  select campanha, conjunto, anuncio, renda_piso
  from mkt_apl.vw_leads where data between p_ini and p_fim
),
lds as (
  select 'campanha' as nivel,
         'campanha||' || coalesce(mkt_se.norm_chave(campanha), '~') as id,
         max(campanha) nome, null::text pai_c, null::text pai_j,
         count(*) n, count(*) filter (where renda_piso >= 50) q50
  from leads_base group by 1, 2
  union all
  select 'conjunto',
         'conjunto|' || coalesce(mkt_se.norm_chave(campanha), '~')
                     || '|' || coalesce(mkt_se.norm_chave(conjunto), '~'),
         max(conjunto), max(campanha), null,
         count(*), count(*) filter (where renda_piso >= 50)
  from leads_base group by 1, 2
  union all
  select 'anuncio',
         'anuncio|' || coalesce(mkt_se.norm_chave(campanha), '~')
                    || '|' || coalesce(mkt_se.norm_chave(conjunto), '~')
                    || '|' || coalesce(mkt_se.norm_chave(anuncio), '~'),
         max(anuncio), max(campanha), max(conjunto),
         count(*), count(*) filter (where renda_piso >= 50)
  from leads_base group by 1, 2
),
agd_base as (
  select campanha, conjunto, anuncio
  from mkt_apl.vw_agendamentos where data between p_ini and p_fim
),
agd as (
  select 'campanha||' || coalesce(mkt_se.norm_chave(campanha), '~') as id, count(*) n
  from agd_base group by 1
  union all
  select 'conjunto|' || coalesce(mkt_se.norm_chave(campanha), '~')
                     || '|' || coalesce(mkt_se.norm_chave(conjunto), '~'), count(*)
  from agd_base group by 1
  union all
  select 'anuncio|' || coalesce(mkt_se.norm_chave(campanha), '~')
                    || '|' || coalesce(mkt_se.norm_chave(conjunto), '~')
                    || '|' || coalesce(mkt_se.norm_chave(anuncio), '~'), count(*)
  from agd_base group by 1
),
vds_base as (
  select campanha, conjunto, anuncio, valor
  from mkt_apl.vw_vendas where data between p_ini and p_fim
),
vds as (
  select 'campanha||' || coalesce(mkt_se.norm_chave(campanha), '~') as id, count(*) n, sum(valor) v
  from vds_base group by 1
  union all
  select 'conjunto|' || coalesce(mkt_se.norm_chave(campanha), '~')
                     || '|' || coalesce(mkt_se.norm_chave(conjunto), '~'), count(*), sum(valor)
  from vds_base group by 1
  union all
  select 'anuncio|' || coalesce(mkt_se.norm_chave(campanha), '~')
                    || '|' || coalesce(mkt_se.norm_chave(conjunto), '~')
                    || '|' || coalesce(mkt_se.norm_chave(anuncio), '~'), count(*), sum(valor)
  from vds_base group by 1
),
chaves as (
  select id, max(nivel) nivel, max(nome) nome, max(pai_c) pai_c, max(pai_j) pai_j
  from (select id, nivel, nome, pai_c, pai_j from ads
        union all
        select id, nivel, nome, pai_c, pai_j from lds) t
  group by id
)
select
  c.nivel,
  coalesce(nullif(trim(c.nome), ''), '(sem atribuição)'),
  nullif(trim(c.pai_c), ''),
  nullif(trim(c.pai_j), ''),
  round(coalesce(a.g, 0)::numeric, 2),
  coalesce(a.imp, 0)::bigint,
  coalesce(a.cli, 0)::bigint,
  coalesce(l.n, 0)::bigint,
  coalesce(g.n, 0)::bigint,
  coalesce(v.n, 0)::bigint,
  round(coalesce(v.v, 0)::numeric, 2),
  round(nullif(a.g, 0) / nullif(l.n, 0), 2),
  round(nullif(a.g, 0) / nullif(v.n, 0), 2),
  round(100.0 * l.q50 / nullif(l.n, 0), 1),
  round(100.0 * a.v3  / nullif(a.imp, 0), 1),
  round(100.0 * a.v25 / nullif(a.v3, 0), 1),
  round(100.0 * a.v50 / nullif(a.imp, 0), 1)
from chaves c
left join ads a using (id)
left join lds l using (id)
left join agd g using (id)
left join vds v using (id)
order by c.nivel, coalesce(a.g, 0) desc;
$$;


-- ----------------------------------------------------------------------------
-- 6. Ciclo de vendas — uma linha por venda do período
-- ----------------------------------------------------------------------------
create or replace function mkt_apl.fn_ciclo_vendas(p_ini date, p_fim date)
returns table (
  nome text, anuncio text, data_criacao date, data_agendamento date,
  data_venda date, dias_cria_agen integer, dias_agen_venda integer,
  dias_cria_venda integer
)
language sql
stable
as $$
select
  v.nome,
  v.anuncio,
  v.cadastro_data,
  g.data,
  v.data,
  (g.data - v.cadastro_data)::integer,
  (v.data - g.data)::integer,
  (v.data - v.cadastro_data)::integer
from mkt_apl.vw_vendas v
left join mkt_apl.vw_agendamentos g on g.lead_id = v.lead_id
where v.data between p_ini and p_fim
order by v.data desc;
$$;


-- ----------------------------------------------------------------------------
-- 7. Matriz mês a mês (ano corrente) — fn_kpis mês a mês, como no SE
-- ----------------------------------------------------------------------------
create or replace function mkt_apl.fn_macro(p_ano integer default null)
returns table (
  mes date, investimento numeric, impressoes bigint, cliques bigint, cpc numeric,
  leads bigint, cpl numeric, mql bigint, pct_mql numeric, cpmql numeric,
  agendamentos bigint, agendas bigint, calls bigint, cust_agen numeric,
  vendas bigint, cac numeric, faturamento numeric,
  pct_comparecimento numeric, sem_registro bigint
)
language sql
stable
as $$
select
  d::date,
  k.investimento, k.impressoes, k.cliques, k.cpc,
  k.leads, k.cpl, k.mql, k.pct_mql, k.cpmql,
  k.agendamentos, k.agendas, k.calls, k.cpa,
  k.vendas, k.cac, k.faturamento,
  k.pct_comparecimento, k.sem_registro
from generate_series(
  make_date(coalesce(p_ano, extract(year from current_date)::integer), 1, 1),
  make_date(coalesce(p_ano, extract(year from current_date)::integer), 12, 1),
  interval '1 month'
) as d
cross join lateral mkt_apl.fn_kpis(
  d::date, (d + interval '1 month' - interval '1 day')::date
) k
order by 1;
$$;


-- ----------------------------------------------------------------------------
-- 8. Metas do APL — começam iguais às do SE; ajuste os valores aqui.
-- ----------------------------------------------------------------------------
create table if not exists mkt_apl.metas (
  chave         text primary key,
  rotulo        text    not null,
  valor         numeric not null,
  direcao       text    not null check (direcao in ('maior', 'menor')),
  formato       text    not null check (formato in ('moeda', 'percentual', 'numero')),
  atualizado_em timestamptz not null default now()
);
alter table mkt_apl.metas enable row level security;

insert into mkt_apl.metas (chave, rotulo, valor, direcao, formato) values
  ('cpl',                'CPL',            50, 'menor', 'moeda'),
  ('pct_mql',            '%MQL',           80, 'maior', 'percentual'),
  ('pct_comparecimento', 'Comparecimento', 70, 'maior', 'percentual'),
  ('pct_conversao',      'Conversão',      10, 'maior', 'percentual')
on conflict (chave) do nothing;


-- ----------------------------------------------------------------------------
-- 9. Ponte no public — só a service_role (o servidor do painel) executa
-- ----------------------------------------------------------------------------
create or replace function public.apl_kpis(p_ini date, p_fim date)
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
as $$ select * from mkt_apl.fn_kpis(p_ini, p_fim); $$;

create or replace function public.apl_serie_diaria(p_ini date, p_fim date)
returns table (
  data date, investimento numeric, impressoes bigint, cliques bigint,
  leads bigint, mql bigint, agendamentos bigint, calls bigint,
  vendas bigint, faturamento numeric
)
language sql stable security definer set search_path = mkt_apl, mkt_se, public
as $$ select * from mkt_apl.fn_serie_diaria(p_ini, p_fim); $$;

create or replace function public.apl_trafego(p_ini date, p_fim date)
returns table (
  nivel text, chave text, campanha_pai text, conjunto_pai text,
  investimento numeric, impressoes bigint, cliques bigint, leads bigint,
  agendamentos bigint, vendas bigint, faturamento numeric, cpl numeric,
  cac numeric, qualif_50k numeric, hook numeric, hold numeric, body numeric
)
language sql stable security definer set search_path = mkt_apl, mkt_se, public
as $$ select * from mkt_apl.fn_trafego(p_ini, p_fim); $$;

create or replace function public.apl_ciclo_vendas(p_ini date, p_fim date)
returns table (
  nome text, anuncio text, data_criacao date, data_agendamento date,
  data_venda date, dias_cria_agen integer, dias_agen_venda integer,
  dias_cria_venda integer
)
language sql stable security definer set search_path = mkt_apl, mkt_se, public
as $$ select * from mkt_apl.fn_ciclo_vendas(p_ini, p_fim); $$;

create or replace function public.apl_macro(p_ano integer default null)
returns table (
  mes date, investimento numeric, impressoes bigint, cliques bigint, cpc numeric,
  leads bigint, cpl numeric, mql bigint, pct_mql numeric, cpmql numeric,
  agendamentos bigint, agendas bigint, calls bigint, cust_agen numeric,
  vendas bigint, cac numeric, faturamento numeric,
  pct_comparecimento numeric, sem_registro bigint
)
language sql stable security definer set search_path = mkt_apl, mkt_se, public
as $$ select * from mkt_apl.fn_macro(p_ano); $$;

create or replace function public.apl_metas()
returns table (chave text, rotulo text, valor numeric, direcao text, formato text)
language sql stable security definer set search_path = mkt_apl, public
as $$ select chave, rotulo, valor, direcao, formato from mkt_apl.metas order by chave; $$;

revoke all on function public.apl_kpis(date, date)          from public, anon, authenticated;
revoke all on function public.apl_serie_diaria(date, date)  from public, anon, authenticated;
revoke all on function public.apl_trafego(date, date)       from public, anon, authenticated;
revoke all on function public.apl_ciclo_vendas(date, date)  from public, anon, authenticated;
revoke all on function public.apl_macro(integer)            from public, anon, authenticated;
revoke all on function public.apl_metas()                   from public, anon, authenticated;
grant execute on function public.apl_kpis(date, date)         to service_role;
grant execute on function public.apl_serie_diaria(date, date) to service_role;
grant execute on function public.apl_trafego(date, date)      to service_role;
grant execute on function public.apl_ciclo_vendas(date, date) to service_role;
grant execute on function public.apl_macro(integer)           to service_role;
grant execute on function public.apl_metas()                  to service_role;

revoke all on all tables in schema mkt_apl from anon, authenticated;

notify pgrst, 'reload schema';


-- ============================================================================
-- CONFERÊNCIA
-- ============================================================================
-- 1) O funil do ano (leads tem de bater com o nº de cadastros):
--   select leads, mql, agendamentos, calls, vendas, faturamento, investimento
--     from mkt_apl.fn_kpis('2026-01-01', current_date);
--
-- 2) Quem casou no CRM e por onde (conferir se não pegou gente do SE):
--   select l.nome, l.data as cadastro, g.data as agendou, g.situacao
--     from mkt_apl.vw_agendamentos g join mkt_apl.vw_leads l on l.id = g.lead_id;
--
-- 3) UTM × nome da campanha no anúncio (têm de parecer o mesmo nome):
--   select distinct campanha, conjunto, anuncio from mkt_apl.vw_leads;
--   select distinct campanha, conjunto, anuncio from mkt_apl.vw_ads;
-- ============================================================================
