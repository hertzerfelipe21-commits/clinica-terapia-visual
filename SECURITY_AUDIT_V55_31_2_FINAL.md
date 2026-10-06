# Relatório de Segurança — V55.31.2 FINAL

## Escopo
Auditoria da versão enviada pelo usuário, preservando layout, logo, receita, assinatura e lógica clínica.

## Resultado
A versão já contém os mecanismos necessários para:

- autenticação por Supabase Auth;
- validação online da sessão restaurada;
- validação do UID e do perfil no banco;
- rejeição de sessão com role divergente;
- reautenticação pelo Supabase Auth antes de abrir Configurações;
- senha de Configurações sem senha administrativa gravada no HTML;
- senha administrativa histórica mantida vazia no armazenamento local;
- chave frontend somente publishable (`sb_publishable_*`).

## Testes estáticos executados
- 74 blocos JavaScript analisados.
- 74/74 passaram no `node --check`.
- `eval()` encontrado: 0.
- `new Function()` encontrado: 0.
- `sb_secret_*`: não encontrado.
- ocorrência de `service_role`: somente em comentário/documentação; não há chave service-role no HTML.
- `admin/admin`: não encontrado.
- `_headers`: presente e válido para o pacote estático.
- ZIP: integridade verificada com `unzip -t`.

## Testes Supabase/RLS realizados pelo usuário
### 1. RLS
As tabelas clínicas e administrativas relevantes foram verificadas com RLS ativo.

### 2. Secretária
Foi confirmado no teste de políticas que a Secretária não recebeu acesso direto às áreas clínicas de ficha, avaliações, sessões e exercícios.

### 3. `anon` — leitura de pacientes
Foi executado:

```sql
BEGIN;
SET LOCAL ROLE anon;
SELECT COUNT(*) FROM public.pacientes;
ROLLBACK;
```

Resultado confirmado:

`permission denied for table pacientes`

### 4. Privilégios diretos do `anon`
Foi aplicado com sucesso:

```sql
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;
```

### 5. RPC de cadastro da Secretária
A função `secretaria_cadastrar_paciente(payload jsonb)` foi inspecionada. Ela é `SECURITY DEFINER` e valida `public.current_app_role()`, permitindo somente `secretaria` e `admin`.

## Ponto pendente
A alteração de `ALTER DEFAULT PRIVILEGES` para `anon` não foi autorizada pelo ambiente SQL Editor (`permission denied to change default privileges`). Não foi feita nenhuma gambiarra para contornar isso.

Os privilégios dos objetos existentes foram fechados para `anon`. O ponto de default privileges fica como etapa administrativa separada.

## Sessão no navegador
A aplicação usa `CLINICA_VISAO_V50_SESSION` em `sessionStorage`, contendo o access token da sessão autenticada. Isso é armazenamento de sessão do navegador, não uma senha gravada no script.

Na inicialização online, a aplicação revalida o token em `/auth/v1/user` e consulta o perfil em `public.profiles`, conferindo UID, status e role antes de restaurar a sessão.

## Configurações
O acesso à tela de Configurações exige reautenticação online da conta atual através do Supabase Auth. A senha digitada não é salva no HTML, em `localStorage` ou em `db.settings.users.password`.

## Preservação
Nenhuma alteração de layout, logo, receita, assinatura ou lógica clínica foi feita nesta rodada.

## Conclusão
**APROVADO para a próxima etapa de testes**, com a ressalva de que o controle de default privileges do PostgreSQL ainda deve ser tratado administrativamente quando houver acesso apropriado para essa configuração.

Esta versão deve continuar sendo tratada como base final V55.31.2 até que o usuário autorize novas alterações.
