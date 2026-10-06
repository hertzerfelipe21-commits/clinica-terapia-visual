# Relatório de Segurança — V55.30 (candidato de testes online)

Data: 05/10/2026
Base: V55.29 final do projeto

## Resultado executivo

A auditoria está dividida em duas partes:

- **Auditoria estática/local:** executada nesta versão.
- **Auditoria remota Supabase/RLS:** não pôde ser concluída neste ambiente porque a instância Supabase não está acessível pela rede desta execução.

Portanto, a versão está **preparada para testes online**, mas **não deve ser considerada aprovada para produção até a rodada autenticada de RLS**.

## Testes executados

| Teste | Resultado |
|---|---|
| 73 blocos JavaScript extraídos | PASS |
| Sintaxe dos 73 blocos com Node.js | PASS — 0 erros |
| IDs HTML duplicados | PASS — 0 duplicados |
| Chave `sb_secret_*` no cliente | PASS — não encontrada |
| `service_role` real no cliente | PASS — não encontrado; apenas comentário/documentação |
| URI PostgreSQL no HTML | PASS — não encontrada |
| `eval()` / `new Function()` | PASS — não encontrados |
| Scripts externos | PASS — não há `<script src>` externo |
| Chave Supabase | PASS — é `sb_publishable_*`, apropriada para frontend quando RLS está correto |
| Credencial `admin/admin` pré-preenchida | CORRIGIDO |
| Busca global com interpolação HTML não escapada | CORRIGIDO |
| Tabela administrativa com dados não escapados | CORRIGIDO |
| Sessão restaurada apenas pelo `sessionStorage` | CORRIGIDO para revalidação online |
| Headers de segurança para hospedagem | ADICIONADOS em `_headers` |

## Correções feitas sem alterar layout

### 1. Credencial administrativa legada
Foi removido o valor padrão `admin/admin` do código e do campo de senha administrativa.

A autenticação principal continua sendo feita pelo Supabase Auth.

### 2. Revalidação da sessão
Ao recarregar a página com uma sessão existente, estando online o sistema agora consulta:

- `/auth/v1/user`
- `/rest/v1/profiles`

O `uid` e o `role` são comparados com a sessão armazenada. Se a sessão for inválida, expirada, bloqueada ou adulterada, o sistema volta para o login.

Quando o dispositivo está offline, a operação local permanece disponível para preservar o comportamento offline-first.

### 3. XSS em duas áreas legadas
Foram escapados dados de pacientes em:

- busca global;
- tabela administrativa de pacientes.

A estrutura visual não foi alterada.

### 4. Headers de segurança
Foi adicionado `_headers` para a publicação em Cloudflare Pages com:

- HSTS;
- `X-Content-Type-Options: nosniff`;
- `Referrer-Policy`;
- `X-Frame-Options: DENY`;
- `Permissions-Policy`;
- CSP com `frame-ancestors`, `object-src`, `base-uri` e `connect-src` limitado ao Supabase.

## Pontos que ainda precisam de validação remota

### RLS — CRÍTICO antes de produção
Não foi possível executar chamadas autenticadas contra o projeto Supabase nesta execução.

Precisamos testar, com contas reais:

1. `anon` sem sessão → não pode ler pacientes nem dados clínicos.
2. Secretária → acesso administrativo e agenda, sem ficha/dados clínicos.
3. Anderson → acesso clínico + agenda.
4. Admin → acesso completo.
5. Secretária tentando inserir diretamente em tabela clínica → negar.
6. Secretária solicitando/agendando pelo RPC → permitir conforme regra definida.
7. Anderson aprovando solicitação → permitir.
8. Usuário com role adulterado no navegador → servidor continua negando acesso indevido.

O SQL existente já mantém RLS ativo na agenda compartilhada e nas solicitações e usa funções `SECURITY DEFINER` com `search_path` definido. Isso é positivo, mas a aplicação precisa ser testada contra a instância real.

## Pontos de atenção que NÃO alterei

### A. Dados clínicos no armazenamento local
O sistema é offline-first e mantém dados no armazenamento local do navegador. Isso é uma decisão arquitetural e de privacidade, não algo que deve ser alterado sem aprovação.

**Recomendação:** avaliar criptografia local, política de limpeza em dispositivos compartilhados e minimização de dados.

### B. Senha administrativa legada nas Configurações
Existe ainda a estrutura visual/configurável de “senha administrativa” histórica. O valor padrão foi removido, mas a remoção completa dessa funcionalidade exige decisão porque pode alterar o comportamento de Configurações.

### C. Muitos módulos históricos no HTML
Existem 73 blocos JavaScript no arquivo. A sintaxe está íntegra, mas há código legado acumulado. Uma limpeza/refatoração ampla não deve ser feita antes de congelar uma cópia de segurança e autorizar essa mudança.

## Supabase — situação conhecida

A chave publicável no frontend **não é, por si só, um vazamento de segredo**. O Supabase documenta que publishable keys podem ficar no navegador; a proteção real é RLS + grants + autorização baseada no JWT. Secret/service-role keys nunca devem ir para o frontend.

## Conclusão

**V55.30 = candidata para ambiente de testes online endurecido.**

Não houve alteração de layout ou estrutura visual do sistema.

A etapa que falta para declarar segurança operacional é a **rodada remota autenticada do Supabase/RLS**.

### Autorização necessária para próximos ajustes

Eu **não recomendo alterar agora**:

- armazenamento local/criptografia;
- arquitetura de autenticação além da revalidação feita;
- limpeza dos módulos históricos;
- estrutura de banco/RLS.

Esses pontos podem alterar comportamento/arquitetura e devem ser autorizados antes.
