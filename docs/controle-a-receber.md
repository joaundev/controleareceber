# Controle a Receber — Documentação de Arquitetura

**Versão:** 1.0  
**Status:** Especificação inicial aprovada  
**Plataforma inicial:** Android  
**Idioma:** Português brasileiro

## 1. Objetivo

Desenvolver um aplicativo simples para registrar valores a receber de maneira informal, controlar acordos, parcelas, pagamentos e emitir recibos.

O aplicativo deve permitir cadastrar pessoas, registrar acordos de pagamento, acompanhar vencimentos, registrar pagamentos parciais ou totais, anexar comprovantes, gerar recibos em PDF e realizar backup e restauração dos dados.

## 2. Princípios obrigatórios

- O aplicativo deve funcionar 100% offline.
- Não utilizar backend, servidor, Firebase, Supabase ou APIs remotas.
- Todos os dados devem permanecer no dispositivo, exceto quando o usuário decidir exportar ou compartilhar um arquivo.
- Não enviar automaticamente dados financeiros, documentos ou comprovantes para a internet.
- Não exigir conta, cadastro online ou login.
- Não implementar juros ou multas no MVP.
- Priorizar simplicidade, segurança dos dados e facilidade de uso.
- Não implementar funcionalidades fora do escopo sem aprovação.
- Antes de modificar arquivos existentes, explicar a alteração.
- Nunca afirmar que testes foram executados sem realmente executá-los.

## 3. Tecnologias

- Flutter e Dart.
- SQLite para persistência local.
- Drift como camada de acesso ao banco.
- Riverpod para gerenciamento de estado.
- GoRouter para navegação.
- `path_provider` e `path` para caminhos locais.
- `intl` e `flutter_localizations` para datas e valores em português brasileiro.
- `pdf` para gerar recibos.
- `share_plus` para compartilhar arquivos quando solicitado.
- `image_picker` para selecionar ou fotografar comprovantes.
- `file_picker` para selecionar arquivos de backup e comprovantes.
- `archive` para compactar e extrair backups ZIP.
- `crypto` para calcular SHA-256.
- `uuid` para identificadores e chaves de idempotência, se necessário.
- `drift_dev` e `build_runner` para gerar código do banco.
- Testes unitários e de integração conforme a necessidade.

Usar versões compatíveis entre si e com a versão instalada do Flutter. Não adicionar dependências sem necessidade.

## 4. Organização do projeto

Organizar o código por responsabilidade, evitando arquivos excessivamente grandes.

Estrutura sugerida:

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
  core/
    clock/
    errors/
    formatting/
    storage/
  data/
    database/
    repositories/
    backup/
  domain/
    models/
    services/
    validators/
  features/
    dashboard/
    people/
    agreements/
    payments/
    receipts/
    settings/

test/
  core/
  domain/
  data/
  features/

docs/
  controle-a-receber.md
```

A estrutura poderá ser ajustada se houver justificativa técnica, sem alterar as regras de negócio.

## 5. Regras monetárias

- Armazenar dinheiro como inteiro em centavos.
- Nunca utilizar `double` para cálculos monetários.
- Exemplo: R$ 123,45 deve ser armazenado como `12345`.
- A formatação visual deve utilizar o padrão brasileiro: `R$ 1.234,56`.
- O total das parcelas deve ser exatamente igual ao valor do acordo.
- A divisão de centavos restantes deve beneficiar as primeiras parcelas.
- Todo cálculo deve ser validado por testes unitários.
- Valores monetários devem ser validados antes de serem persistidos.

## 6. Modelo de dados

### 6.1 Pessoa

Campos principais:

- `id`
- `nome`
- `telefone` opcional
- `email` opcional
- `documento` opcional
- `observacoes` opcional
- `criado_em`
- `arquivado_em` opcional

Pessoas sem histórico financeiro podem ser excluídas permanentemente. Pessoas com histórico devem ser arquivadas para preservar os registros.

### 6.2 Acordo

Todo valor a receber será representado por um acordo, mesmo quando houver apenas uma parcela.

Campos principais:

- `id`
- `pessoa_id`
- `descricao`
- `valor_total_centavos`
- `quantidade_parcelas`
- `data_primeira_parcela`
- `periodicidade`
- `observacoes`
- `criado_em`
- `cancelado_em` opcional
- `motivo_cancelamento` opcional

No MVP, a periodicidade será somente mensal.

### 6.3 Parcela

Campos principais:

- `id`
- `acordo_id`
- `numero`
- `valor_centavos`
- `data_vencimento`

Não persistir o status da parcela como fonte principal. Calcular o status a partir do vencimento, pagamentos válidos e cancelamento do acordo.

### 6.4 Pagamento

Campos principais:

- `id`
- `parcela_id`
- `valor_centavos`
- `data_pagamento`
- `forma_pagamento`
- `observacao`
- `criado_em`
- `estornado_em` opcional
- `motivo_estorno` opcional
- `chave_idempotencia` única

Um pagamento representa um valor recebido para uma parcela. A parcela poderá ter diversos pagamentos parciais.

### 6.5 Comprovante

Campos principais:

- `id`
- `pagamento_id`
- `caminho_relativo`
- `tipo`
- `nome_original`
- `criado_em`
- `tamanho_bytes`
- `sha256`

Os arquivos devem ficar em armazenamento privado do aplicativo. Salvar caminhos relativos, nunca depender de caminhos absolutos fixos.

### 6.6 Recibo

Campos principais:

- `id`
- `pagamento_id`, único
- `numero`, único
- `anulado_em` opcional
- `snapshot_json`
- `emitido_em`

Cada pagamento terá no máximo um recibo. O recibo deve guardar uma cópia imutável dos dados relevantes no momento da emissão, para que alterações posteriores no cadastro da pessoa não modifiquem recibos antigos.

### 6.7 Configuração

Armazenar configurações locais, incluindo:

- Próximo número de recibo.
- Data do último backup.
- Dados opcionais do emissor dos recibos.

## 7. Banco de dados

- Nome sugerido: `controle_a_receber.db`.
- Utilizar SQLite com Drift.
- Ativar e verificar `PRAGMA foreign_keys=ON`.
- Usar transações para operações financeiras que alterem vários registros.
- Utilizar restrições de chave estrangeira com `ON DELETE RESTRICT`, salvo quando uma exclusão em cascata estiver explicitamente autorizada para dados sem histórico.
- Criar índices para consultas frequentes.
- Implementar migrações de esquema.
- Validar a integridade do banco após restaurações.
- Não excluir registros financeiros históricos para simplificar consultas.

## 8. Geração de parcelas

- Permitir de 1 a 120 parcelas.
- O valor total deve permitir pelo menos 1 centavo por parcela.
- Distribuir o valor total em centavos, colocando os centavos restantes nas primeiras parcelas.
- A soma das parcelas deve ser igual ao total do acordo.
- Criar o acordo e todas as suas parcelas em uma única transação.
- Permitir revisar as datas de vencimento antes de salvar.
- A primeira parcela utiliza a data escolhida pelo usuário.
- As parcelas seguintes são mensais.
- Calcular cada vencimento com base na data original, sem acumular erros entre meses.
- Exemplo: uma data no dia 31 deve resultar no último dia de fevereiro e voltar ao dia 31 em março, quando aplicável.
- Tratar corretamente anos bissextos e viradas de ano.

## 9. Status das parcelas

Calcular o saldo com base no valor da parcela menos a soma dos pagamentos não estornados.

Ordem de prioridade:

1. **Cancelada:** o acordo foi cancelado.
2. **Paga:** saldo igual a zero.
3. **Atrasada:** saldo positivo e vencimento anterior à data de hoje.
4. **Parcial:** existe pagamento válido, mas ainda há saldo e não está atrasada.
5. **Pendente:** não há pagamento válido e o vencimento é hoje ou futuro.

Se uma parcela tiver pagamento parcial e estiver vencida, o status será atrasada, mantendo a indicação de pagamento parcial.

O dia do vencimento não deve ser considerado atraso. A data atual deve ser obtida pelo relógio local do dispositivo, por meio de uma abstração injetável para facilitar testes.

## 10. Pagamentos

- O valor de cada pagamento deve ser maior que zero.
- A forma de pagamento é obrigatória.
- A data do pagamento não pode ser futura.
- Não permitir pagamentos superiores ao saldo restante.
- Não permitir novos pagamentos em acordos cancelados ou parcelas quitadas.
- Validar as regras dentro da transação no banco.
- Desabilitar o botão de confirmação durante o salvamento para reduzir envios duplicados.
- Usar chave de idempotência única para impedir duplicação acidental.
- Se um único recebimento precisar ser dividido entre duas parcelas, registrar dois pagamentos, cada um associado à sua parcela e com seu próprio recibo.
- Não implementar crédito excedente nem distribuição automática de valores no MVP.

## 11. Estorno de pagamentos

Pagamentos não podem ser excluídos nem ter seus dados financeiros alterados diretamente.

Para corrigir um lançamento:

- Exigir motivo do estorno.
- Marcar o pagamento como estornado, preservando o histórico.
- Anular o recibo relacionado.
- Permitir registrar um novo pagamento correto.
- Não reutilizar números de recibos.
- Excluir pagamentos somente não é permitido, inclusive para administradores do aplicativo.

O cálculo do saldo deve ignorar pagamentos estornados.

## 12. Cancelamento e edição de acordos

O cancelamento é irreversível no MVP e exige motivo.

Após o cancelamento:

- Não permitir novos pagamentos.
- Preservar os pagamentos já registrados.
- Preservar os recibos e o histórico.
- Não contar os valores restantes como recebíveis ativos.
- Não permitir reativar o acordo.

Edição:

- Sem pagamentos registrados: permitir alterar o total, a quantidade de parcelas e as datas, regenerando as parcelas em uma transação.
- Com pagamentos registrados: permitir alterar somente descrição, observações e vencimentos das parcelas ainda não quitadas.
- Não alterar valores financeiros de parcelas que já tenham pagamentos.
- Para renegociar valores ou quantidade de parcelas após pagamentos, cancelar o acordo antigo e criar um novo.

## 13. Exclusões e histórico

- Pessoa sem histórico: pode ser excluída permanentemente.
- Pessoa com histórico: somente arquivar.
- Acordo sem histórico financeiro: pode ser excluído mediante confirmação, incluindo suas parcelas.
- Acordo com histórico: não pode ser excluído; somente cancelado.
- Parcela: não pode ser excluída individualmente.
- Pagamento: não pode ser excluído; somente estornado.
- Recibo: não pode ser excluído; somente anulado quando necessário.
- Comprovantes: podem ser removidos mediante confirmação.
- Se um arquivo de comprovante não puder ser excluído, implementar limpeza de arquivos órfãos na inicialização e antes de gerar backup.

## 14. Numeração e emissão de recibos

- Cada pagamento gera um recibo.
- O número do recibo é único e nunca é reutilizado.
- Criar o pagamento, o recibo e atualizar o contador na mesma transação.
- Usar restrições `UNIQUE` para impedir números e pagamentos duplicados.
- Uma falha na transação não deve consumir o número do recibo.
- O número inicial pode ser configurado somente antes do primeiro recibo.
- Na inicialização e após a restauração, reconciliar o contador com o maior número já utilizado.
- Gerar PDF a partir do snapshot imutável.
- Regenerar um PDF não cria outro recibo nem altera sua numeração.
- Incluir dados essenciais do pagamento e do emissor, quando configurado.
- Compartilhar o arquivo somente mediante ação explícita do usuário.

## 15. Datas e auditoria

- Datas de vencimento e pagamento devem ser tratadas como datas civis, sem deslocamentos inesperados de fuso horário.
- Formato de referência para datas civis: `yyyy-MM-dd`.
- Timestamps de auditoria devem ser armazenados em UTC.
- Usar um relógio injetável para testar datas e horários.
- Evitar que alterações de fuso horário mudem indevidamente a data de vencimento exibida.

## 16. Comprovantes

- Permitir anexar imagem ou PDF a um pagamento.
- Guardar os arquivos em armazenamento privado do aplicativo.
- Não enviar arquivos automaticamente para serviços externos.
- Armazenar tamanho e SHA-256 para validação.
- Lidar com arquivo ausente sem travar o aplicativo.
- Não tornar o comprovante obrigatório para registrar pagamento.
- O compartilhamento de comprovantes ocorre somente quando solicitado pelo usuário.

## 17. Backup e restauração

O backup manual é obrigatório no MVP.

Nome sugerido:

`controle_a_receber_backup_AAAAMMDD_HHmmss.zip`

Conteúdo:

```text
manifest.json
banco/controle_a_receber.db
comprovantes/<identificador>.<extensao>
```

O manifesto deve conter:

- Versão do formato de backup.
- Versão do esquema do banco.
- Versão do aplicativo.
- Data de criação em UTC.
- Contagens dos registros.
- Relação de arquivos com tamanho e SHA-256.
- Relação de comprovantes referenciados ou ausentes.

### Criar backup

- Criar uma cópia consistente do banco com SQLite `VACUUM INTO` ou outra estratégia comprovadamente consistente.
- Verificar espaço disponível quando possível.
- Copiar os comprovantes existentes e calcular hashes.
- Gerar o ZIP.
- Permitir salvar ou compartilhar o arquivo por ação explícita do usuário.
- Limpar arquivos temporários.
- Atualizar a data do último backup.
- Se algum comprovante estiver ausente, avisar sem impedir necessariamente o backup.

### Restaurar backup

- A restauração é uma substituição completa, não uma mesclagem.
- Validar a estrutura do ZIP e o manifesto.
- Rejeitar formatos incompatíveis ou esquemas mais novos que o aplicativo.
- Validar SHA-256 dos arquivos.
- Executar `PRAGMA integrity_check` e `PRAGMA foreign_key_check`.
- Mostrar um resumo e pedir confirmação explícita.
- Criar um backup de segurança dos dados atuais antes de substituir.
- Fechar o banco antes de substituir os arquivos.
- Manter uma cópia temporária dos dados antigos até confirmar que a restauração funcionou.
- Se qualquer etapa falhar, tentar restaurar os arquivos anteriores.
- Após o sucesso, executar migrações compatíveis e reconciliar o contador de recibos.
- Informar claramente o resultado.

### Segurança do backup

O backup do MVP não será criptografado. Informar ao usuário que o ZIP pode conter dados financeiros e pessoais e deve ser armazenado com segurança.

Exibir um aviso no painel quando o último backup tiver mais de 30 dias ou nunca tiver sido realizado.

## 18. Privacidade e Android

- Desabilitar o backup automático de dados do aplicativo para nuvens do sistema, configurando `allowBackup` e regras de extração adequadas para as versões Android suportadas.
- O backup dos dados financeiros deve ser iniciado manualmente pelo usuário.
- Solicitar somente permissões necessárias.
- Não coletar análises, telemetria ou dados pessoais remotamente no MVP.
- Planejar uma política de privacidade antes da publicação na Google Play.
- Preencher a seção Data Safety da Play Store de acordo com o comportamento real do aplicativo.
- Considerar as responsabilidades da LGPD para dados pessoais armazenados no dispositivo.

## 19. Telas planejadas

1. Painel com resumo dos valores recebidos, pendentes e atrasados.
2. Lista e cadastro de pessoas.
3. Detalhes da pessoa e seu histórico.
4. Lista e cadastro de acordos.
5. Prévia das parcelas antes de salvar um acordo.
6. Detalhes do acordo e parcelas.
7. Registro de pagamento parcial ou total.
8. Histórico de pagamentos e estornos.
9. Visualização e compartilhamento de recibos.
10. Anexos de comprovantes.
11. Configurações, dados do emissor e backup/restauração.

A interface deve ser simples, em português brasileiro, adequada para uso cotidiano e com mensagens de erro claras.

## 20. Estratégia de testes

### Dinheiro e parcelas

- Formatação e leitura de valores brasileiros.
- Distribuição de centavos restantes.
- Soma exata das parcelas.
- Limites de quantidade e valor.
- Rejeição de valores inválidos.

### Datas

- Vencimentos no dia 31.
- Fevereiro em anos comuns e bissextos.
- Virada de ano.
- 120 parcelas.
- Vencimento hoje, ontem e amanhã.

### Status e pagamentos

- Pendente, parcial, atrasada e paga.
- Pagamento parcial com atraso.
- Estorno e recálculo do saldo.
- Cancelamento.
- Rejeição de valor zero, negativo, futuro ou acima do saldo.
- Prevenção de pagamentos duplicados.

### Recibos

- Numeração única.
- Falha e rollback da transação.
- Snapshot imutável.
- Estorno e anulação.
- Regeneração do PDF sem alterar o número.

### Banco e backup

- Integridade das chaves estrangeiras.
- Migrações de esquema.
- ZIP inválido ou corrompido.
- Hash incorreto.
- Backup com comprovante ausente.
- Restauração válida.
- Falha de restauração e rollback.
- Preservação dos dados antigos em caso de erro.

## 21. Ordem de implementação

Implementar em pequenas etapas, testando cada uma antes de avançar:

1. Fundação do projeto, formatação e configuração.
2. Domínio financeiro puro e testes unitários.
3. Banco Drift, tabelas, índices, chaves estrangeiras e migrações.
4. Repositórios e transações.
5. Cadastro e gestão de pessoas.
6. Acordos, geração e edição de parcelas.
7. Pagamentos, estornos e comprovantes.
8. Recibos em PDF.
9. Painel e navegação.
10. Backup e restauração.
11. Configurações e revisão de privacidade.
12. Testes finais, assinatura e publicação na Google Play.

Não avançar para uma etapa seguinte se os testes da etapa atual estiverem falhando.

## 22. Decisões finais do MVP

- Sem juros ou multas.
- Somente periodicidade mensal.
- Sem backend ou sincronização.
- Sem login.
- Sem pagamentos online.
- Sem crédito excedente.
- Cancelamento irreversível.
- Pagamentos corrigidos por estorno, nunca por exclusão.
- Backup manual sem criptografia na primeira versão.
- Regras financeiras testadas antes de criar telas.
- Android como plataforma prioritária.
