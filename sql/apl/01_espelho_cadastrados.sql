-- ============================================================================
-- APL · Pharus — 01. Espelho dos cadastrados do Anchor
--
-- ⚠️ RODAR NO BUSINESS DATA (rckpuebaiswrxzmywllv), depois do 00 no Anchor.
--    Sem senha: reaproveita o servidor `srv_anchor` e o user mapping que o SE
--    EMP já criou (sql/01_fdw.sql).
--
--   Anchor                                  BUSINESS DATA
--   apl_pharus.apl_cadastrados ──fdw──► ext_anchor.apl_cadastrados (não consultar direto!)
--                                               │ a cada 30 min
--                                               ▼
--                                        mkt_apl.cadastrados (espelho)
--                                        mkt_apl.vw_* / fn_*  (painel)
--
-- Mesmo motivo do SE para espelhar em vez de consultar ao vivo: o Anchor está
-- com a RAM sobrecarregada. Assim ele recebe uma consulta a cada 30 min, não
-- uma por carregamento do painel.
-- ============================================================================


-- 1. Schema próprio do APL — separado do mkt_se para um painel não esbarrar
--    no outro.
create schema if not exists mkt_apl;


-- 2. Tabela estrangeira. LIMIT TO: entra só o que o painel usa.
import foreign schema apl_pharus
  limit to (apl_cadastrados)
  from server srv_anchor into ext_anchor;


-- 3. Espelho local — cópia EXATA da estrutura remota. Nada de coluna derivada
--    aqui (quebraria o INSERT ... SELECT * quando a origem ganhar coluna);
--    derivações vivem nas views.
create table if not exists mkt_apl.cadastrados
  as select * from ext_anchor.apl_cadastrados with no data;


-- 4. Sincronização. Sem WHERE: a tabela inteira é o universo do APL.
--    Se o 00 mostrar que ela é grande, entra um corte por `data` aqui — só com
--    operador nativo (>=), para o filtro rodar NO Anchor e não aqui.
create or replace function mkt_apl.sync_cadastrados()
returns integer
language plpgsql
security definer
set search_path = mkt_apl, ext_anchor, public
as $$
declare
  n integer;
begin
  truncate mkt_apl.cadastrados;
  insert into mkt_apl.cadastrados select * from ext_anchor.apl_cadastrados;
  get diagnostics n = row_count;
  return n;
end;
$$;


-- 5. Primeira carga — o número tem de bater com o `linhas` do 00.
--    Se vier ZERO, é RLS no Anchor (ver 00).
select mkt_apl.sync_cadastrados() as linhas;


-- 6. Índices (depois da carga, para o planner ter estatística)
create index if not exists idx_apl_cad_data  on mkt_apl.cadastrados (data);
create index if not exists idx_apl_cad_email on mkt_apl.cadastrados (lower(trim(email)));
create index if not exists idx_apl_cad_tel   on mkt_apl.cadastrados (tel_8d);
analyze mkt_apl.cadastrados;


-- 7. Agendamento. Minutos 6 e 36: os jobs do SE ocupam :00/:30, :03/:33,
--    :10 e :12 — espaçar evita tudo batendo no Anchor no mesmo instante.
--    Idempotente: rodar de novo não duplica o job.
select cron.unschedule('apl_sync_cadastrados')
 where exists (select 1 from cron.job where jobname = 'apl_sync_cadastrados');
select cron.schedule('apl_sync_cadastrados', '6,36 * * * *',
                     $$select mkt_apl.sync_cadastrados()$$);


-- 8. Trancar: o painel lê pela API com service_role; anon não lê nada.
--    O espelho tem nome, e-mail e telefone — dado pessoal.
revoke all on schema mkt_apl                  from anon, authenticated;
revoke all on all tables in schema mkt_apl    from anon, authenticated;


-- ============================================================================
-- CONFERÊNCIA
-- ============================================================================
-- 1) Espelho x origem (as duas contagens têm de ser iguais):
--   select (select count(*) from mkt_apl.cadastrados)       as espelho,
--          (select count(*) from ext_anchor.apl_cadastrados) as anchor;
--
-- 2) O job existe e está rodando:
--   select jobname, schedule from cron.job where jobname = 'apl_sync_cadastrados';
--   select status, start_time, return_message from cron.job_run_details
--    where jobid = (select jobid from cron.job where jobname = 'apl_sync_cadastrados')
--    order by start_time desc limit 5;
--
-- 3) Retrato dos cadastros (para validar com o time antes de desenhar o painel):
--   select data, count(*) from mkt_apl.cadastrados group by 1 order by 1 desc limit 15;
--   select utm_source, utm_medium, count(*) from mkt_apl.cadastrados group by 1,2 order by 3 desc;
--   select utm_campaign, count(*) from mkt_apl.cadastrados group by 1 order by 2 desc limit 20;
-- ============================================================================
