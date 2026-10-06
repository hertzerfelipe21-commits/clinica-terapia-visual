# V55.31.2 — Agenda compartilhada Secretaria ↔ Anderson

## Regra final
- A **Secretária** cria, consulta, altera status e reagenda pela área administrativa.
- O registro definitivo fica em `public.agenda_compartilhada`.
- O **Anderson** lê a mesma agenda pelo RPC `anderson_get_agenda`.
- A **Secretária** lê a mesma agenda pelo RPC `secretaria_get_agenda`.
- Alterações da Secretária usam `secretaria_atualizar_agendamento`.
- Alterações do Anderson/Admin podem usar `anderson_atualizar_agendamento`.
- Atualização automática ocorre na abertura, foco, retorno à aba e a cada 45 s.
- Encaixes continuam usando `secretaria_solicitar_agendamento` → `anderson_decidir_solicitacao`.

## Segurança
A Secretária não recebe INSERT/UPDATE direto na tabela compartilhada. As alterações administrativas passam pelo RPC `SECURITY DEFINER`, que valida `current_app_role()`. RLS permanece ativo.

## Banco
Execute **uma vez**:
`SUPABASE_V55_31_2_AGENDA_COMPARTILHADA_FIX.sql`

Depois teste:
1. Secretária cria agendamento.
2. Anderson atualiza/recarrega a agenda.
3. Secretária altera status/data/horário.
4. Anderson recarrega e vê a mesma alteração.
5. Teste um encaixe e confirme no Anderson.
6. Teste Secretária sem acesso à ficha clínica.
