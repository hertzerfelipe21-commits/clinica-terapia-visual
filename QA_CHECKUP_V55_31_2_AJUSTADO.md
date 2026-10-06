# Check-up V55.31.2 — segurança, dados e sincronização clínica

## Status desta revisão

**Código cliente:** preparado para sincronização clínica bidirecional com revisão/controle de conflito.

**Pré-requisito externo:** executar `SUPABASE_V55_31_2_CLINICAL_SYNC.sql` no SQL Editor do projeto Supabase. O cliente não consegue criar funções/tabelas no PostgreSQL sozinho e nenhuma chave privilegiada foi incluída.

## O que foi implementado no cliente

1. Fila IndexedDB continua sendo o buffer offline.
2. Snapshot local é enviado por RPC `push_clinical_snapshot` quando há internet e sessão clínica/admin.
3. O snapshot central é recuperado por `pull_clinical_snapshot`.
4. Cada dispositivo guarda a revisão central conhecida.
5. Alterações locais usam a revisão-base; se outro dispositivo já gravou uma revisão posterior, o servidor retorna **conflito** e não sobrescreve silenciosamente.
6. A interface oferece duas decisões explícitas:
   - **Usar versão da nuvem**;
   - **Manter este dispositivo** (envio forçado da versão local).
7. Sem alteração local pendente, uma revisão remota mais nova pode ser aplicada automaticamente.
8. Secretária continua fora da sincronização clínica.
9. O envio usa apenas a sessão autenticada e a publishable key.
10. Não há `service_role`, `sb_secret_` ou senha administrativa no cliente.

## Segurança

- RLS permanece ativo.
- Não foi utilizado `WITH CHECK (true)`.
- Os RPCs são `SECURITY DEFINER`, validam `auth.uid()` e `current_app_role()`.
- O acesso clínico é restrito a `admin`, `cv` e `tv`.
- O cliente não recebe privilégio para alterar diretamente a tabela de estado central; as alterações passam pelos RPCs.

## O que ainda depende do Supabase

O arquivo `SUPABASE_V55_31_2_CLINICAL_SYNC.sql` precisa ser executado no projeto correto. Depois disso, o teste real deve confirmar:

`Dispositivo A → Supabase → Dispositivo B`

`Dispositivo B → Supabase → Dispositivo A`

bem como o cenário de conflito.

## Validações locais

- ZIP de origem aberto e arquivos extraídos sem erro.
- Bloco `v49SupabaseInfra` modificado passou em `node --check`.
- Demais blocos permanecem conforme a auditoria anterior; o bloco conhecido de impressão dinâmica não deve ser avaliado por um parser ingênuo que trate HTML JavaScript embutido como código JS independente.
