-- ============================================================================
-- APL · Pharus — 00. Libera a leitura do schema apl_pharus
--
-- ⚠️ RODAR NO ANCHOR (sfxbzfaxbbdjzuhzzrjc). Sem senha, cola direto.
--
-- Reaproveita a role `fdw_se`, criada para o SE EMP (sql/00_roles_remotos.sql).
-- É ela que o Business Data usa para ler o Anchor pelo servidor `srv_anchor`;
-- criar outra role exigiria outro servidor + user mapping com senha, sem ganho.
-- A role continua só de LEITURA e só no que for liberado aqui.
-- ============================================================================

grant usage  on schema apl_pharus                 to fdw_se;
grant select on apl_pharus.apl_cadastrados        to fdw_se;

-- Conferir o privilégio:
select has_table_privilege('fdw_se', 'apl_pharus.apl_cadastrados', 'select') as pode_ler;

-- ⚠️ RLS — a tabela TEM RLS ligada (conferido em 26/09/2026). Sem esta
--    política a fdw_se não recebe erro: recebe ZERO LINHAS, e o espelho
--    sincroniza "com sucesso" vazio. Foi exatamente o que aconteceu na primeira
--    carga. A política libera só LEITURA e só para a fdw_se.
create policy fdw_se_leitura on apl_pharus.apl_cadastrados
  for select to fdw_se using (true);

-- Tamanho da tabela — define se o espelho copia tudo ou precisa de corte:
select count(*) as linhas, min(data) as primeiro_dia, max(data) as ultimo_dia
from apl_pharus.apl_cadastrados;

-- Teste: NÃO dá para testar aqui com `set role fdw_se` — no Supabase o usuário
-- do SQL Editor não tem permissão para assumir a role (erro 42501). O teste
-- de verdade é no Business Data, depois do 01:
--   select count(*) from ext_anchor.apl_cadastrados;   -- tem de bater com `linhas`
