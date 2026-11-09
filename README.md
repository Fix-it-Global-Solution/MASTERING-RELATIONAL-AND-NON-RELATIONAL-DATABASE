# Fix-It — Mastering Relational & Non-Relational Database
> Global Solution 2026/2 | Tema: CitizenTech | Turma: 2TDSPF

---

## 1. Integrantes do Grupo
* **Gabriel Sbrana Campos** — RM: 565849
* **Moisés Waidemann Molinillo** — RM: 563719
* **Richard Freitas** — RM: 566127
* **Thiago Rodrigues da Mota** — RM: 563650

---

## 2. Visão Geral da Solução
O **Fix-It** é uma plataforma colaborativa de zeladoria urbana voltada para identificação, registro e priorização de incidentes viários (buracos no asfalto, falhas de iluminação, bueiros obstruídos e lixo irregular). 

A persistência do sistema adota arquitetura poliglota:
* **Oracle Database (Relacional):** Responsável pela consistência transacional ACID, auditoria rígida de alterações de status e execução de rotinas batch/escalonamento via PL/SQL.
* **MongoDB (Orientado a Documentos):** Otimizado para consultas geoespaciais em tempo real (`2dsphere`) e armazenamento desnormalizado dos relatórios com metadados de Inteligência Artificial.

---

## 3. Estrutura do Banco Relacional (Oracle)

O arquivo `script-bd-oracle.sql` implementa:
1. **Tabelas Relacionais:** `TB_USUARIO`, `TB_OCORRENCIA`, `TB_ORDEM_SERVICO` e `TB_AUDITORIA_OCORRENCIA`.
2. **Gatilhos (Triggers):**
   * `TRG_AUDITORIA_OCORRENCIA`: Trilha de auditoria automática gravando valores `:OLD` e `:NEW`, data e usuário do banco a cada alteração de status/gravidade.
   * `TRG_VALIDA_ABERTURA_OCORRENCIA`: Validação de integridade para impedir registros retroativos ou chamados já nascidos como concluídos.
3. **Pacotes PL/SQL:**
   * `PKG_FIXIT_OCORRENCIAS`: Contém a função `FN_CALCULAR_INDICE_RESOLUCAO` e a procedure `PR_ESCALAR_GRAVIDADE_ATRASADA`.
   * `PKG_FIXIT_AUDITORIA`: Contém a função `FN_TEMPO_MEDIO_ATENDIMENTO` e a procedure `PR_FINALIZAR_OCORRENCIA`.
4. **Blocos Anônimos:** Rotinas operacionais com cursores explícitos para triagem de criticidade e testes integrados dos pacotes.

---

## 4. Estrutura do Banco Não-Relacional (MongoDB)

O arquivo `script-mongo-fixit.js` opera sobre a base `zeladoria_fixit`:
* **Collections:** `usuarios_cidadaos` e `ocorrencias_urbanas` (com mais de 10 documentos cadastrados).
* **Índices Criados:** Índice geoespacial `2dsphere` no campo `localizacao` e índice composto em `{ status: 1, categoria: 1 }`.
* **Decisão de Modelagem:**
  * **Embedding (Incorporação):** Metadados da análise de IA e dados de despacho de equipes técnicas foram embutidos diretamente no documento da ocorrência para garantir consultas rápidas em leituras móveis.
  * **Referencing (Referência):** O cidadão solicitante é mantido por referência (`id_usuario_referencia`) evitando replicação desnecessária de dados sensíveis (LGPD).

---

## 5. Mapeamento & Consultas Comparativas

| Conceito | Oracle Database | MongoDB |
| :--- | :--- | :--- |
| **Ponto Geográfico** | Colunas `latitude` e `longitude` | Objeto GeoJSON `localizacao: { type: "Point", coordinates: [lng, lat] }` |
| **Auditoria / Parecer IA** | Tabela normalizada `TB_AUDITORIA_OCORRENCIA` | Subdocumento embutido `ia_analise` |
| **Ordem de Reparo** | Tabela filha `TB_ORDEM_SERVICO` | Subdocumento `ordem_servico` |

### Consultas Equivalentes Executadas

1. **Relatório 1 (Agrupamento por Categoria e Status):**
   * *Oracle:* `SELECT categoria, status, COUNT(*) FROM TB_OCORRENCIA GROUP BY categoria, status;`
   * *MongoDB:* `db.ocorrencias_urbanas.aggregate([{ $group: { _id: { categoria: "$categoria", status: "$status" }, total: { $sum: 1 } } }]);`
2. **Relatório 2 (Ocorrências Críticas Pendentes):**
   * *Oracle:* `SELECT id_ocorrencia, categoria, bairro FROM TB_OCORRENCIA WHERE gravidade IN ('ALTA', 'URGENTE') AND status <> 'CONCLUIDO';`
   * *MongoDB:* `db.ocorrencias_urbanas.find({ gravidade: { $in: ["ALTA", "URGENTE"] }, status: { $ne: "CONCLUIDO" } }, { categoria: 1, bairro: 1, _id: 1 });`
3. **Relatório 3 (Busca Geoespacial por Raio de 1 km):**
   * *Oracle:* Filtro por faixa de latitude e longitude via clausula `BETWEEN`.
   * *MongoDB:* Operador nativo `$near` utilizando o índice `2dsphere` e a geometria `Point` com `$maxDistance: 1000`.

---

## 6. Como Executar

### Oracle Database
1. Conecte-se via Oracle SQL Developer ou SQLcl ao seu schema.
2. Abra e execute o arquivo `script-bd-oracle.sql` como script completo (`F5`).
3. Verifique as saídas no console do `DBMS_OUTPUT`.

### MongoDB
1. Certifique-se de que o serviço do MongoDB está em execução ou conecte ao MongoDB Atlas.
2. No MongoDB Compass (aba mongosh) ou terminal, execute:
   ```bash
   mongosh < script-mongo-fixit.js
   ```
