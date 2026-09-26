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

-- ⚠️ RLS — mesma armadilha do SE: com RLS ligada e sem política, a fdw_se não
--    recebe erro, recebe ZERO LINHAS, e o espelho sincroniza "com sucesso" vazio.
select relname, relrowsecurity as rls_ligada
from pg_class where oid = 'apl_pharus.apl_cadastrados'::regclass;

--    Se rls_ligada = true, rode também:
--
--      create policy fdw_se_leitura on apl_pharus.apl_cadastrados
--        for select to fdw_se using (true);

-- Tamanho da tabela — define se o espelho copia tudo ou precisa de corte:
select count(*) as linhas, min(data) as primeiro_dia, max(data) as ultimo_dia
from apl_pharus.apl_cadastrados;

-- Teste final (tem que devolver o mesmo número acima, não zero):
--   set role fdw_se;
--   select count(*) from apl_pharus.apl_cadastrados;
--   reset role;
