-- ============================================================================
-- APL · Pharus — 06. A cópia dos cadastros passa a trazer a coluna `origem`
--
-- ⚠️ RODAR NO BUSINESS DATA, depois do 05 no Anchor.
--
-- A tabela estrangeira foi importada ANTES da coluna existir — ela não enxerga
-- colunas novas sozinha. Então: reimporta, acrescenta a coluna no espelho e a
-- sincronização passa a listar as colunas pelo NOME (antes era `select *`,
-- que dependia da ordem das colunas bater nos dois lados).
-- ============================================================================

drop foreign table if exists ext_anchor.apl_cadastrados;

import foreign schema apl_pharus
  limit to (apl_cadastrados)
  from server srv_anchor into ext_anchor;

alter table mkt_apl.cadastrados add column if not exists origem text;

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
  insert into mkt_apl.cadastrados (
    id, created_at, nome_completo, primeiro_nome, sobrenome, telefone, tel_8d,
    email, utm_source, utm_campaign, utm_medium, utm_term, utm_content,
    utm_pagina, data, hora, renda, capital, construir_estrutura, profissao,
    situacao_atual, o_que_busca_pharus, preocupa, aporte, quem_ao_lado,
    urgencia, valeu_a_pena, origem
  )
  select
    id, created_at, nome_completo, primeiro_nome, sobrenome, telefone, tel_8d,
    email, utm_source, utm_campaign, utm_medium, utm_term, utm_content,
    utm_pagina, data, hora, renda, capital, construir_estrutura, profissao,
    situacao_atual, o_que_busca_pharus, preocupa, aporte, quem_ao_lado,
    urgencia, valeu_a_pena, origem
  from ext_anchor.apl_cadastrados;
  get diagnostics n = row_count;
  return n;
end;
$$;

select mkt_apl.sync_cadastrados() as cadastros;

-- Conferir: a origem chegou.
select origem, count(*) from mkt_apl.cadastrados group by 1 order by 1;
