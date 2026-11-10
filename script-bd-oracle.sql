-- DDL e Criação das Tabelas Relacionais
DROP TABLE TB_AUDITORIA_OCORRENCIA CASCADE CONSTRAINTS;
DROP TABLE TB_ORDEM_SERVICO CASCADE CONSTRAINTS;
DROP TABLE TB_OCORRENCIA CASCADE CONSTRAINTS;
DROP TABLE TB_USUARIO CASCADE CONSTRAINTS;

-- 1. Tabela de Usuários
CREATE TABLE TB_USUARIO (
    id_usuario       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome             VARCHAR2(100) NOT NULL,
    email            VARCHAR2(120) UNIQUE NOT NULL,
    cpf              VARCHAR2(14) UNIQUE NOT NULL,
    telefone         VARCHAR2(20),
    perfil           VARCHAR2(20) DEFAULT 'CIDADAO' CHECK (perfil IN ('CIDADAO', 'GESTOR', 'FISCAL')),
    data_cadastro    DATE DEFAULT SYSDATE NOT NULL
);

-- 2. Tabela de Ocorrências Urbanas
CREATE TABLE TB_OCORRENCIA (
    id_ocorrencia    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario       NUMBER NOT NULL,
    categoria        VARCHAR2(40) NOT NULL CHECK (categoria IN ('BURACO_ASFALTO', 'ILUMINACAO_PUBLICA', 'BUEIRO_ENTUPIDO', 'DESCARTE_IRREGULAR')),
    descricao        VARCHAR2(500) NOT NULL,
    bairro           VARCHAR2(80) NOT NULL,
    latitude         NUMBER(9,6) NOT NULL,
    longitude        NUMBER(9,6) NOT NULL,
    status           VARCHAR2(20) DEFAULT 'ABERTO' CHECK (status IN ('ABERTO', 'EM_ANALISE', 'EM_EXECUCAO', 'CONCLUIDO', 'CANCELADO')),
    gravidade        VARCHAR2(20) DEFAULT 'MEDIA' CHECK (gravidade IN ('BAIXA', 'MEDIA', 'ALTA', 'URGENTE')),
    data_abertura    DATE DEFAULT SYSDATE NOT NULL,
    data_conclusao   DATE,
    CONSTRAINT fk_ocorrencia_usuario FOREIGN KEY (id_usuario) REFERENCES TB_USUARIO(id_usuario)
);

-- 3. Tabela de Ordens de Serviço
CREATE TABLE TB_ORDEM_SERVICO (
    id_os            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_ocorrencia    NUMBER NOT NULL,
    equipe           VARCHAR2(80) NOT NULL,
    data_abertura_os DATE DEFAULT SYSDATE NOT NULL,
    data_conclusao_os DATE,
    custo_reparo     NUMBER(10,2) DEFAULT 0,
    CONSTRAINT fk_os_ocorrencia FOREIGN KEY (id_ocorrencia) REFERENCES TB_OCORRENCIA(id_ocorrencia)
);

-- 4. Tabela de Auditoria
CREATE TABLE TB_AUDITORIA_OCORRENCIA (
    id_audit         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_ocorrencia    NUMBER NOT NULL,
    operacao         VARCHAR2(10) NOT NULL,
    usuario_bd       VARCHAR2(50) NOT NULL,
    data_operacao    TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    status_antigo    VARCHAR2(20),
    status_novo      VARCHAR2(20),
    gravidade_antiga VARCHAR2(20),
    gravidade_nova   VARCHAR2(20)
);

-- Triggers
-- Gatilho 1: Trilha de Auditoria Completa
CREATE OR REPLACE TRIGGER TRG_AUDITORIA_OCORRENCIA
AFTER UPDATE ON TB_OCORRENCIA
FOR EACH ROW
BEGIN
    INSERT INTO TB_AUDITORIA_OCORRENCIA (
        id_ocorrencia,
        operacao,
        usuario_bd,
        data_operacao,
        status_antigo,
        status_novo,
        gravidade_antiga,
        gravidade_nova
    ) VALUES (
        :OLD.id_ocorrencia,
        'UPDATE',
        USER,
        SYSTIMESTAMP,
        :OLD.status,
        :NEW.status,
        :OLD.gravidade,
        :NEW.gravidade
    );
END;
/

-- Gatilho 2: Validação de Regra de Negócio na Inclusão
CREATE OR REPLACE TRIGGER TRG_VALIDA_ABERTURA_OCORRENCIA
BEFORE INSERT ON TB_OCORRENCIA
FOR EACH ROW
BEGIN
    -- Impede inserção com data futura ou preenchimento de conclusão na abertura
    IF :NEW.data_abertura > SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'A data de abertura não pode ser futura.');
    END IF;
    
    IF :NEW.data_conclusao IS NOT NULL THEN
        RAISE_APPLICATION_ERROR(-20002, 'Não é permitido registrar uma ocorrência já concluída.');
    END IF;
END;
/

-- Packages 
-- Pacote 1: PKG_FIXIT_OCORRENCIAS
-- Specification
CREATE OR REPLACE PACKAGE PKG_FIXIT_OCORRENCIAS IS
    FUNCTION FN_CALCULAR_INDICE_RESOLUCAO(p_bairro IN VARCHAR2) RETURN NUMBER;
    PROCEDURE PR_ESCALAR_GRAVIDADE_ATRASADA(p_dias_limite IN NUMBER);
END PKG_FIXIT_OCORRENCIAS;
/

-- Body
-- 1. ESPECIFICAÇÃO DO PACOTE (PACKAGE SPECIFICATION)
CREATE OR REPLACE PACKAGE PKG_FIXIT_OCORRENCIAS IS
    FUNCTION FN_CALCULAR_INDICE_RESOLUCAO(p_bairro IN VARCHAR2) RETURN NUMBER;
    PROCEDURE PR_ESCALAR_GRAVIDADE_ATRASADA(p_dias_limite IN NUMBER);
END PKG_FIXIT_OCORRENCIAS;
/

-- 2. CORPO DO PACOTE (PACKAGE BODY)
CREATE OR REPLACE PACKAGE BODY PKG_FIXIT_OCORRENCIAS IS

    -- Função 1: Retorna a taxa percentual (%) de chamados resolvidos por bairro
    FUNCTION FN_CALCULAR_INDICE_RESOLUCAO(p_bairro IN VARCHAR2) RETURN NUMBER IS
        v_total      NUMBER := 0;
        v_resolvidos NUMBER := 0;
        v_indice     NUMBER := 0;
    BEGIN
        SELECT COUNT(*),
               NVL(SUM(CASE WHEN status = 'CONCLUIDO' THEN 1 ELSE 0 END), 0)
          INTO v_total, v_resolvidos
          FROM TB_OCORRENCIA
         WHERE UPPER(bairro) = UPPER(p_bairro);

        IF v_total > 0 THEN
            v_indice := ROUND((v_resolvidos / v_total) * 100, 2);
        END IF;

        RETURN v_indice;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END FN_CALCULAR_INDICE_RESOLUCAO;

    -- Procedimento 1: Eleva para 'URGENTE' chamados abertos sem conclusão acima de X dias
    PROCEDURE PR_ESCALAR_GRAVIDADE_ATRASADA(p_dias_limite IN NUMBER) IS
    BEGIN
        UPDATE TB_OCORRENCIA
           SET gravidade = 'URGENTE'
         WHERE status NOT IN ('CONCLUIDO', 'CANCELADO')
           AND gravidade <> 'URGENTE'
           AND (SYSDATE - data_abertura) > p_dias_limite;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END PR_ESCALAR_GRAVIDADE_ATRASADA;

END PKG_FIXIT_OCORRENCIAS;
/

-- Pacote 2: PKG_FIXIT_AUDITORIA
-- Specification
CREATE OR REPLACE PACKAGE PKG_FIXIT_AUDITORIA IS
    FUNCTION FN_TEMPO_MEDIO_ATENDIMENTO(p_categoria IN VARCHAR2) RETURN NUMBER;
    PROCEDURE PR_FINALIZAR_OCORRENCIA(p_id_ocorrencia IN NUMBER, p_equipe IN VARCHAR2, p_custo IN NUMBER);
END PKG_FIXIT_AUDITORIA;
/

-- Body
CREATE OR REPLACE PACKAGE BODY PKG_FIXIT_AUDITORIA IS

    -- Função 2: Retorna a média de dias úteis para encerramento por categoria
    FUNCTION FN_TEMPO_MEDIO_ATENDIMENTO(p_categoria IN VARCHAR2) RETURN NUMBER IS
        v_dias_medios NUMBER := 0;
    BEGIN
        SELECT NVL(AVG(data_conclusao - data_abertura), 0)
          INTO v_dias_medios
          FROM TB_OCORRENCIA
         WHERE categoria = p_categoria
           AND status = 'CONCLUIDO'
           AND data_conclusao IS NOT NULL;

        RETURN ROUND(v_dias_medios, 2);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END FN_TEMPO_MEDIO_ATENDIMENTO;

    -- Procedimento 2: Conclui a ocorrência e registra o fechamento da OS
    PROCEDURE PR_FINALIZAR_OCORRENCIA(
        p_id_ocorrencia IN NUMBER,
        p_equipe        IN VARCHAR2,
        p_custo         IN NUMBER
    ) IS
    BEGIN
        -- Atualiza a ocorrência
        UPDATE TB_OCORRENCIA
           SET status = 'CONCLUIDO',
               data_conclusao = SYSDATE
         WHERE id_ocorrencia = p_id_ocorrencia;

        -- Insere ou atualiza o registro na tabela de ordens de serviço
        INSERT INTO TB_ORDEM_SERVICO (
            id_ocorrencia,
            equipe,
            data_abertura_os,
            data_conclusao_os,
            custo_reparo
        ) VALUES (
            p_id_ocorrencia,
            p_equipe,
            SYSDATE - 1,
            SYSDATE,
            p_custo
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END PR_FINALIZAR_OCORRENCIA;

END PKG_FIXIT_AUDITORIA;
/

--Dados de Teste
-- Usuários
INSERT INTO TB_USUARIO (nome, email, cpf, telefone, perfil) VALUES ('Carlos Mendes', 'carlos.mendes@email.com', '111.222.333-44', '11988887777', 'CIDADAO');
INSERT INTO TB_USUARIO (nome, email, cpf, telefone, perfil) VALUES ('Mariana Silveira', 'mariana.silva@email.com', '222.333.444-55', '11977776666', 'CIDADAO');
INSERT INTO TB_USUARIO (nome, email, cpf, telefone, perfil) VALUES ('Fiscal Joâo Rocha', 'joao.fiscal@sp.gov.br', '333.444.555-66', '11966665555', 'FISCAL');

-- Ocorrências
INSERT INTO TB_OCORRENCIA (id_usuario, categoria, descricao, bairro, latitude, longitude, status, gravidade, data_abertura)
VALUES (1, 'BURACO_ASFALTO', 'Cratera funda na faixa direita da via', 'Bela Vista', -23.561684, -46.655981, 'ABERTO', 'ALTA', SYSDATE - 15);

INSERT INTO TB_OCORRENCIA (id_usuario, categoria, descricao, bairro, latitude, longitude, status, gravidade, data_abertura)
VALUES (1, 'ILUMINACAO_PUBLICA', 'Poste com lâmpada queimada há duas semanas', 'Bela Vista', -23.562100, -46.654300, 'ABERTO', 'BAIXA', SYSDATE - 35);

INSERT INTO TB_OCORRENCIA (id_usuario, categoria, descricao, bairro, latitude, longitude, status, gravidade, data_abertura)
VALUES (2, 'BUEIRO_ENTUPIDO', 'Bueiro coberto de entulho gerando alagamento', 'Pinheiros', -23.567890, -46.691230, 'EM_EXECUCAO', 'URGENTE', SYSDATE - 5);

INSERT INTO TB_OCORRENCIA (id_usuario, categoria, descricao, bairro, latitude, longitude, status, gravidade, data_abertura)
VALUES (2, 'DESCARTE_IRREGULAR', 'Móveis velhos e entulho na calçada', 'Pinheiros', -23.568100, -46.692000, 'ABERTO', 'MEDIA', SYSDATE - 12);

COMMIT;

--Blocos Anônimos PL/SQL
SET SERVEROUTPUT ON;

-- Bloco Anônimo 1: Cursor explícito com loop e tomada de decisão para relatório
DECLARE
    CURSOR c_ocorrencias_criticas IS
        SELECT o.id_ocorrencia, o.categoria, o.bairro, o.gravidade, u.nome AS municipe
          FROM TB_OCORRENCIA o
          JOIN TB_USUARIO u ON o.id_usuario = u.id_usuario
         WHERE o.status <> 'CONCLUIDO';
    
    v_total_criticas NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- RELATÓRIO DE MONITORAMENTO: FIX-IT ---');
    FOR r IN c_ocorrencias_criticas LOOP
        IF r.gravidade IN ('ALTA', 'URGENTE') THEN
            v_total_criticas := v_total_criticas + 1;
            DBMS_OUTPUT.PUT_LINE('ATENÇÃO: Chamado #' || r.id_ocorrencia || ' | Bairro: ' || r.bairro || 
                                 ' | Tipo: ' || r.categoria || ' | Relator: ' || r.municipe);
        ELSE
            DBMS_OUTPUT.PUT_LINE('ROTINA: Chamado #' || r.id_ocorrencia || ' | Prioridade regular (' || r.gravidade || ')');
        END IF;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Total de ocorrências com severidade crítica: ' || v_total_criticas);
END;
/

-- Bloco Anônimo 2: Execução de rotina de escalonamento e testes de packages
DECLARE
    v_taxa_resolucao NUMBER;
    v_tempo_medio    NUMBER;
BEGIN
    -- Testa procedimento de escalonar chamados parados há mais de 20 dias
    PKG_FIXIT_OCORRENCIAS.PR_ESCALAR_GRAVIDADE_ATRASADA(p_dias_limite => 20);
    
    -- Finaliza um chamado para teste de trigger de auditoria e cálculo
    PKG_FIXIT_AUDITORIA.PR_FINALIZAR_OCORRENCIA(
        p_id_ocorrencia => 1,
        p_equipe        => 'Equipe Pavimentação Centro',
        p_custo         => 1250.00
    );

    -- Testa funções
    v_taxa_resolucao := PKG_FIXIT_OCORRENCIAS.FN_CALCULAR_INDICE_RESOLUCAO('Bela Vista');
    v_tempo_medio    := PKG_FIXIT_AUDITORIA.FN_TEMPO_MEDIO_ATENDIMENTO('BURACO_ASFALTO');

    DBMS_OUTPUT.PUT_LINE('Taxa de Resolução (Bela Vista): ' || v_taxa_resolucao || '%');
    DBMS_OUTPUT.PUT_LINE('Tempo Médio de Reparo (BURACO_ASFALTO): ' || v_tempo_medio || ' dias');
END;
/

--Relatórios:
--Relatório 1: Quantidade de Chamados por Categoria e Status
SELECT categoria,
       status,
       COUNT(*) AS total_chamados
  FROM TB_OCORRENCIA
 GROUP BY categoria, status
 ORDER BY categoria, status;

--Relatório 2: Chamados de Alta Gravidade Pendentes com Projeção Customizada
SELECT id_ocorrencia,
       categoria,
       bairro,
       gravidade,
       TO_CHAR(data_abertura, 'YYYY-MM-DD') AS data_abertura
  FROM TB_OCORRENCIA
 WHERE gravidade IN ('ALTA', 'URGENTE')
   AND status <> 'CONCLUIDO';
   
--Relatório 3: Busca Geoespacial de Incidentes em Raio de 1 km (Proximidade)
-- Busca aproximada por delta de coordenadas em torno da Avenida Paulista (-23.561684, -46.655981)
SELECT id_ocorrencia,
       categoria,
       bairro,
       latitude,
       longitude
  FROM TB_OCORRENCIA
 WHERE latitude BETWEEN -23.570000 AND -23.550000
   AND longitude BETWEEN -46.665000 AND -46.645000;