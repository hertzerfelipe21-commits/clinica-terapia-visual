# V55.31.2 — publicação segura

## 1. Antes de publicar

Execute no SQL Editor do Supabase:

`SUPABASE_V55_31_2_CLINICAL_SYNC.sql`

Use uma conta/role com permissão para criar tabela e funções. **Não cole nenhuma service_role key no HTML.**

## 2. Depois do SQL

Abra o sistema pelo servidor HTTP/HTTPS, entre como `admin` ou `cv/tv` e confirme:

- teste de conexão;
- schema clínico;
- sincronização clínica;
- criação/edição de paciente;
- alteração clínica;
- saída e novo login.

## 3. Teste entre dois dispositivos

### A → B

1. No dispositivo A, altere um dado de teste.
2. Aguarde a sincronização.
3. No dispositivo B, entre com o mesmo usuário autorizado.
4. Aguarde a atualização.
5. Confirme que o dado aparece.

### B → A

Repita no sentido contrário.

### Conflito

1. Deixe os dois dispositivos com a mesma revisão.
2. Faça uma alteração diferente em cada um antes de sincronizar.
3. O segundo envio deve gerar conflito, sem sobrescrita silenciosa.
4. Escolha explicitamente `Usar versão da nuvem` ou `Manter este dispositivo`.

## 4. Publicação

Somente depois dos testes acima, publique o conteúdo descompactado do ZIP em hospedagem que respeite `_headers` (por exemplo, Netlify).
