-- ============================================================================
-- APL · Pharus — 02. Espelho do tráfego (core.ads_metrics) do APL
--
-- ⚠️ RODAR NO BUSINESS DATA (rckpuebaiswrxzmywllv). Sem senha, cola direto.
--    Reaproveita a tabela estrangeira `ext_anchor.ads_metrics`, que o SE EMP já
--    importou (sql/01_fdw.sql) — nada muda no Anchor.
--
-- Filtro: o APL roda na mesma conta do SE (ALPES 5). O que separa é o nome da
-- campanha — tudo que contém `ls-APL-CAPTACAO` (definição do gestor).
--
--   ⚠️ Mesma regra de ouro do SE: o WHERE usa só operador NATIVO (ilike, >=),
--   para o postgres_fdw empurrar o filtro para o Anchor. Com função nossa no
--   WHERE, a tabela inteira de ads da Quarta Via atravessaria a rede.
--
--   Se o APL ganhar campanha com outro nome (retargeting, outra fase), é aqui
--   que o filtro se alarga — e roda `select mkt_apl.sync_ads()` para recarregar.
-- ============================================================================


-- 1. Espelho — cópia exata da estrutura remota, igual ao mkt_se.ads.
create table if not exists mkt_apl.ads
  as select * from ext_anchor.ads_metrics with no data;


-- 2. Sincronização
create or replace function mkt_apl.sync_ads()
returns integer
language plpgsql
security definer
set search_path = mkt_apl, ext_anchor, public
as $$
declare
  n integer;
begin
  truncate mkt_apl.ads;
  insert into mkt_apl.ads
  select *
  from ext_anchor.ads_metrics
  where data >= date '2026-01-01'
    and campanha ilike '%ls-APL-CAPTACAO%';
  get diagnostics n = row_count;
  return n;
end;
$$;


-- 3. Primeira carga. Zero aqui não é erro se as campanhas ainda não gastaram —
--    confira na conferência 2 abaixo.
select mkt_apl.sync_ads() as linhas_ads;


-- 4. Índices
create index if not exists idx_apl_ads_data     on mkt_apl.ads (data);
create index if not exists idx_apl_ads_campanha on mkt_apl.ads (campanha);
create index if not exists idx_apl_ads_anuncio  on mkt_apl.ads (anuncio);
analyze mkt_apl.ads;


-- 5. Agendamento — minutos 9 e 39, fora dos horários dos outros jobs
--    (SE: :00/:30, :03/:33, :10, :12 · APL cadastrados: :06/:36).
select cron.unschedule('apl_sync_ads')
 where exists (select 1 from cron.job where jobname = 'apl_sync_ads');
select cron.schedule('apl_sync_ads', '9,39 * * * *', $$select mkt_apl.sync_ads()$$);


-- 6. Trancar
revoke all on all tables in schema mkt_apl from anon, authenticated;


-- ============================================================================
-- CONFERÊNCIA
-- ============================================================================
-- 1) O que entrou — campanha por campanha, com gasto e período:
--   select campanha, min(data), max(data), round(sum(gasto)::numeric, 2) as gasto
--     from mkt_apl.ads group by 1 order by 1;
--
-- 2) O que existe no Anchor com "APL" no nome — para ver se alguma campanha do
--    APL ficou de fora do filtro (roda no Anchor, filtro empurrado pelo fdw):
--   select distinct campanha from ext_anchor.ads_metrics
--    where data >= date '2026-01-01' and campanha ilike '%apl%' order by 1;
--
-- 3) Nenhuma campanha do APL caiu também no espelho do SE:
--   select distinct campanha from mkt_se.ads where campanha ilike '%apl%';
--   -- esperado: nenhuma linha
-- ============================================================================
