-- ============================================================================
-- APL · Pharus — 07. Origem (Typeform × Forms Nativo) nas views
--
-- ⚠️ RODAR NO BUSINESS DATA, depois do 06.
--
--   Lead      → coluna `origem` do cadastro. Vazio conta como Typeform.
--   Tráfego   → nome da campanha: com "FORMS NATIVO" (ex.:
--               ls-APL-CAPTACAO-ig-validacao-FORMS-NATIVO) é Forms Nativo;
--               as demais ls-APL-CAPTACAO são Typeform.
--   Agendamento e venda herdam a origem do lead.
-- ============================================================================

create or replace function mkt_apl.origem_lead(p text)
returns text language sql immutable
as $$ select case when p ~* 'nativo' then 'Forms Nativo' else 'Typeform' end; $$;

create or replace function mkt_apl.origem_campanha(p text)
returns text language sql immutable
as $$ select case when p ~* 'forms[-_ ]*nativo' then 'Forms Nativo' else 'Typeform' end; $$;

create or replace view mkt_apl.vw_ads as
select
  a.data, a.campanha, a.conjunto, a.anuncio,
  a.gasto, a.impressoes, a.cliques,
  a.video_3s, a."video_25%" as video_25, a."video_50%" as video_50,
  mkt_apl.origem_campanha(a.campanha) as origem
from mkt_apl.ads a;

create or replace view mkt_apl.vw_leads as
select
  c.id, c.created_at, c.data, c.hora,
  nullif(lower(trim(c.email)), '')                          as email,
  mkt_apl.tel8(coalesce(nullif(c.tel_8d, ''), c.telefone))  as tel8,
  c.nome_completo                                           as nome,
  c.utm_campaign                                            as campanha,
  c.utm_medium                                              as conjunto,
  c.utm_content                                             as anuncio,
  c.renda,
  mkt_apl.piso_mil(c.renda)                                 as renda_piso,
  mkt_apl.eh_mql(c.renda)                                   as mql,
  mkt_apl.origem_lead(c.origem)                             as origem
from mkt_apl.cadastrados c;

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
  max(l.anuncio)                          as anuncio,
  max(l.origem)                           as origem
from mkt_apl.vw_crm c
join mkt_se.crm_meetings m on m.lead_id = c.crm_id
                          and m.created_at::date >= c.cadastro_data
join mkt_apl.vw_leads l    on l.id = c.lead_id
group by l.id;

create or replace view mkt_apl.vw_vendas as
select
  k.id                                    as contrato_id,
  x.lead_id,
  k.signed_at::date                       as data,
  coalesce(nullif(k.valor_a_vista, 0), nullif(k.valor_parcelado, 0), 0) as valor,
  x.nome, x.campanha, x.conjunto, x.anuncio, x.cadastro_data,
  x.origem
from mkt_se.contratos k
cross join lateral (
  select l.id as lead_id, l.data as cadastro_data, l.nome,
         l.campanha, l.conjunto, l.anuncio, l.origem
  from mkt_apl.vw_leads l
  where (l.email is not null and l.email = lower(trim(k.email)))
     or (l.tel8  is not null and l.tel8  = mkt_apl.tel8(k.telefone))
  order by l.created_at
  limit 1
) x
where k.signed_at is not null
  and not coalesce(k.modo_teste, false)
  and k.signed_at::date >= x.cadastro_data;

-- Conferir:
select origem, count(*) from mkt_apl.vw_leads group by 1;
select origem, count(*), round(sum(gasto)::numeric, 2) from mkt_apl.vw_ads group by 1;
