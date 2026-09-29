-- ============================================================================
-- APL · Pharus — 09. Botão "Atualizar" do painel
--
-- ⚠️ RODAR NO BUSINESS DATA. Sem senha, cola direto.
--
-- Refaz na hora as cópias que alimentam o painel, sem esperar o agendamento:
--   cadastros e anúncios (Anchor) · CRM e contratos (Backup QV, os do SE).
--
-- ⚠️ TRAVA DE 2 MINUTOS: o Anchor está com a RAM no limite. Vários cliques
--    seguidos (ou várias pessoas clicando) não podem virar várias cópias
--    inteiras — se a última foi há menos de 2 min, a função só devolve a hora
--    dela e não toca em nada.
-- ============================================================================

create table if not exists mkt_apl.atualizacao (
  id integer primary key default 1 check (id = 1),
  em timestamptz not null
);
alter table mkt_apl.atualizacao enable row level security;

create or replace function mkt_apl.atualizar()
returns table (atualizado_em timestamptz, reprocessou boolean)
language plpgsql
security definer
set search_path = mkt_apl, mkt_se, public
as $$
declare
  ultimo timestamptz;
begin
  -- Trava a linha: dois cliques ao mesmo tempo não rodam duas cópias.
  select em into ultimo from mkt_apl.atualizacao where id = 1 for update;

  if ultimo is not null and ultimo > now() - interval '2 minutes' then
    return query select ultimo, false;
    return;
  end if;

  perform mkt_apl.sync_cadastrados();
  perform mkt_apl.sync_ads();
  perform mkt_se.sync_crm();
  perform mkt_se.sync_qv();

  insert into mkt_apl.atualizacao (id, em) values (1, now())
  on conflict (id) do update set em = excluded.em;

  return query select now(), true;
end;
$$;

create or replace function public.apl_atualizar()
returns table (atualizado_em timestamptz, reprocessou boolean)
language sql
volatile
security definer
set search_path = mkt_apl, mkt_se, public
as $$ select * from mkt_apl.atualizar(); $$;

revoke all on function public.apl_atualizar() from public, anon, authenticated;
grant execute on function public.apl_atualizar() to service_role;
revoke all on all tables in schema mkt_apl from anon, authenticated;

notify pgrst, 'reload schema';

-- Conferir (a 1ª chamada reprocessa; a 2ª, logo em seguida, não):
select * from mkt_apl.atualizar();
