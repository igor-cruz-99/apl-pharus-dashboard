-- ============================================================================
-- APL · Pharus — 05. Origem vazia vira Typeform
--
-- ⚠️ RODAR NO ANCHOR (sfxbzfaxbbdjzuhzzrjc) — é lá que a tabela vive.
--    Os cadastros anteriores à coluna `origem` vieram todos do Typeform.
-- ============================================================================

update apl_pharus.apl_cadastrados
   set origem = 'Typeform'
 where origem is null or trim(origem) = '';

-- Conferir: só pode sobrar Typeform e Forms Nativo.
select origem, count(*) from apl_pharus.apl_cadastrados group by 1 order by 1;
