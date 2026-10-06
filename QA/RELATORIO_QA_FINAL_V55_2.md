# QA FINAL — Terapia Visual V55.2 — 05/10/2026

## Resultado da auditoria estática

| Teste | Resultado |
|---|---:|
| Blocos JavaScript analisados | 68 |
| Erros de sintaxe JavaScript | **0** |
| IDs HTML duplicados | **0** |
| Referências locais de imagens/CSS inexistentes | **0** |
| Função final de impressão duplicada | **0** (1 implementação final) |
| `patchPrintWindows` antigo | **removido** |
| Código de reparo de Secretaria duplicado | **removido** (9 cópias antigas) |
| Hotfix de navegação embutido indevidamente em impressão | **removido** |
| Login unificado | **implementado** |
| Seleção Clínica / Secretária / Administrador na mesma tela | **implementado** |
| Sincronização remota da agenda para Anderson/Admin | **implementada no front-end** |
| Calendário mensal estilo Outlook | **preservado** |
| Atividades do dia / resumo completo | **preservado** |
| Próximo atendimento sugerido | **preservado** |
| Pré-data editável antes de enviar à Secretaria | **preservado** |
| Palavra do Dia | **preservada e fixa na Home** |
| Nome de apresentação nas configurações | **preservado** |
| Marca d'água dourada da receita/declaração | **adicionada** |
| Código JS visível nas impressões | **corrigido na estrutura atual** |

## Correções principais desta versão

### 1. Impressão / PDF
O defeito que inseria blocos de HTML/JavaScript no documento impresso foi causado por código de manutenção sendo injetado dentro de template literals de impressão. Foram removidos esses blocos e reconstruída a função final `openPrintWindow()`.

A impressão agora possui um único documento gerado, sem o antigo saneador que removia o script de impressão de forma agressiva.

A marca d'água usa `assets/marca_dagua_clinica.png`, recortada somente do símbolo da clínica.

### 2. Login
A tela de autenticação continua única. Os três perfis agora usam a mesma tela:

- Clínica / Anderson
- Secretária
- Administrador

Os botões de perfil apenas preenchem o usuário e levam o foco para a senha. A página da Secretária não é mais tratada como um segundo login.

### 3. Agenda compartilhada
Foi adicionada uma rotina de sincronização remota para Anderson/Admin que tenta:

1. `anderson_get_agenda`
2. fallback `secretaria_get_agenda`

Ela atualiza a agenda local ao abrir a agenda, voltar ao foco, trocar de tela e periodicamente enquanto a agenda está aberta.

### 4. Fluxo clínico → Secretaria
A lógica existente de pré-data foi mantida: depois da sessão concluída, o sistema calcula uma data sugerida com base no protocolo e na disponibilidade e permite editar a data antes de enviar à Secretaria.

### 5. Palavra do Dia
A função diária continua baseada na data e a Home possui um bloco próprio para ela. O bloco não depende dos cards de agenda.

## Massa de teste

Foi criada uma massa separada em:

`QA/QA_MASSA_TESTE_50.json`

Ela contém 50 pacientes fictícios, incluindo 10 pacientes de baixa adesão com padrão alternado de presença/falta. **O arquivo não é carregado automaticamente e não altera a base do cliente.**

## Limpeza de código

Foram removidos somente blocos comprovadamente duplicados/injetados que estavam quebrando o parser e a impressão.

**Não foi feita uma remoção cega dos 68 blocos de JavaScript históricos.** Há funções de versões anteriores que ainda são chamadas por camadas posteriores. Removê-las sem teste funcional de navegador poderia quebrar ficha, retina, indicadores ou agenda.

Portanto, os blocos históricos devem ser considerados **candidatos a refatoração pós-homologação**, não uma exclusão para esta versão final.

## Ponto que ainda depende do backend

O front-end possui a devolução do próximo atendimento para a Secretaria, mas a documentação do Supabase encontrada no projeto confirma as RPCs administrativas `secretaria_get_agenda`, `secretaria_solicitar_agendamento` e `secretaria_confirmar_solicitacao`; não foi encontrada uma RPC específica documentada para **Anderson → Secretaria / solicitação de próxima sessão**.

Assim, a sincronização da agenda compartilhada está preparada no front-end, mas o fluxo remoto da **solicitação clínica de próxima sessão** precisa ser homologado no Supabase. Não é correto declarar esse ponto como 100% validado sem executar com JWT real contra o projeto.

A documentação anterior também confirma que o banco é único e que a Secretária deve receber apenas os campos administrativos permitidos pelas RPCs. 

## Limitação do teste desta execução

A auditoria local confirmou sintaxe, estrutura, IDs e referências de arquivos. O ambiente de execução desta auditoria não conseguiu acessar o endpoint externo do Supabase nem abrir o HTML em um navegador automatizado devido à restrição do ambiente. Portanto, **não vou declarar que os cliques e RLS foram testados em navegador real**.

## Critério para homologação final

Antes de entregar ao cliente, executar em dois computadores reais:

**Computador 1 — Secretária**
- criar paciente;
- agendar consulta;
- alterar horário;
- registrar falta;
- reagendar;
- solicitar bloqueio.

**Computador 2 — Anderson**
- confirmar que o agendamento aparece;
- abrir paciente;
- lançar sessão;
- salvar ficha;
- receber pré-data;
- enviar retorno para Secretaria;
- bloquear período;
- confirmar urgência de conflitos.

Depois repetir o teste no sentido inverso e conferir Supabase/RLS.
