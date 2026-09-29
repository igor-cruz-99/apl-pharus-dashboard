-- ============================================================================
-- APL · Pharus — 08c. Filtro de origem: ciclo, matriz e perfil
--
-- ⚠️ RODAR NO BUSINESS DATA, depois do 08b.
-- ============================================================================

create or replace function mkt_apl.fn_ciclo_vendas(p_ini date, p_fim date, p_origens text[] default null)
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
  and (p_origens is null or v.origem = any(p_origens))
order by v.data desc;
$$;


create or replace function mkt_apl.fn_macro(p_ano integer default null, p_origens text[] default null)
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
  d::date, (d + interval '1 month' - interval '1 day')::date, p_origens
) k
order by 1;
$$;


create or replace function mkt_apl.fn_perfil(p_ini date, p_fim date, p_origens text[] default null)
returns table (pergunta text, resposta text, leads bigint, respondentes bigint)
language sql
stable
as $$
with base as (
  select * from mkt_apl.cadastrados
  where data between p_ini and p_fim
    and (p_origens is null or mkt_apl.origem_lead(origem) = any(p_origens))
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
