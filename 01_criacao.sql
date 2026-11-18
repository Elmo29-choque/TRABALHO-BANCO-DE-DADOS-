-- =====================================================================
-- 01_criacao.sql : banco, tabelas, índices e views
-- Tema: Biblioteca (livros, autores, exemplares, leitores, empréstimos)
-- SGBD: MySQL 8.0.16+ (CHECK só é aplicado a partir dessa versão)
-- =====================================================================
-- Regras de negócio e onde são garantidas:
--  RN1  O e-mail do leitor não se repete ............ UNIQUE (leitor.email)
--  RN2  O ISBN do livro não se repete ................ UNIQUE (livro.isbn)
--  RN3  Todo exemplar nasce "disponivel" ............. DEFAULT + CHECK (exemplar.status)
--  RN4  Cada leitor tem no máximo uma carteirinha .... FK + UNIQUE (carteirinha.id_leitor)
--  RN5  Prazo de devolução >= data do empréstimo ..... CHECK (emprestimo)
--  RN6  O mesmo livro não é reservado duas vezes pelo
--       mesmo leitor no mesmo dia .................... UNIQUE composto (reserva)
--  RN7  Multa nunca é negativa ....................... CHECK (emprestimo.multa >= 0)
--  RN8  Prazo de 14 dias; atraso gera multa .......... consultas 12 e 14 (03_consultas.sql)
--  RN9  Ao excluir um leitor, seus telefones saem
--       junto ........................................ ON DELETE CASCADE
-- =====================================================================

CREATE DATABASE IF NOT EXISTS biblioteca
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE biblioteca;

-- ---------------------------------------------------------------------
-- Tabelas independentes
-- ---------------------------------------------------------------------
CREATE TABLE cidade (
  id_cidade INT AUTO_INCREMENT PRIMARY KEY,
  nome      VARCHAR(60) NOT NULL,
  estado    CHAR(2)     NOT NULL,
  CONSTRAINT uq_cidade UNIQUE (nome, estado)
);

CREATE TABLE editora (
  id_editora INT AUTO_INCREMENT PRIMARY KEY,
  nome       VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE autor (
  id_autor      INT AUTO_INCREMENT PRIMARY KEY,
  nome          VARCHAR(100) NOT NULL,
  nacionalidade VARCHAR(40)  NOT NULL DEFAULT 'Brasileira'
);

-- ---------------------------------------------------------------------
-- Tabelas dependentes
-- ---------------------------------------------------------------------
CREATE TABLE livro (
  id_livro       INT AUTO_INCREMENT PRIMARY KEY,
  titulo         VARCHAR(150) NOT NULL,
  isbn           CHAR(13)     NOT NULL UNIQUE,
  ano_publicacao SMALLINT     NOT NULL,
  id_editora     INT          NOT NULL,
  CONSTRAINT ck_livro_ano CHECK (ano_publicacao BETWEEN 1500 AND 2100),
  CONSTRAINT fk_livro_editora FOREIGN KEY (id_editora) REFERENCES editora (id_editora)
);

CREATE TABLE exemplar (
  id_exemplar   INT AUTO_INCREMENT PRIMARY KEY,
  codigo_tombo  VARCHAR(10) NOT NULL UNIQUE,
  id_livro      INT         NOT NULL,
  status        VARCHAR(15) NOT NULL DEFAULT 'disponivel',
  CONSTRAINT ck_exemplar_status CHECK (status IN ('disponivel', 'emprestado', 'manutencao')),
  CONSTRAINT fk_exemplar_livro FOREIGN KEY (id_livro) REFERENCES livro (id_livro)
);

CREATE TABLE leitor (
  id_leitor       INT AUTO_INCREMENT PRIMARY KEY,
  nome            VARCHAR(100) NOT NULL,
  email           VARCHAR(120) NOT NULL UNIQUE,
  data_nascimento DATE,
  data_cadastro   DATE         NOT NULL,
  id_cidade       INT,
  CONSTRAINT fk_leitor_cidade FOREIGN KEY (id_cidade) REFERENCES cidade (id_cidade)
);

-- Atributo multivalorado: vários telefones por leitor
CREATE TABLE telefone_leitor (
  id_telefone INT AUTO_INCREMENT PRIMARY KEY,
  id_leitor   INT         NOT NULL,
  numero      VARCHAR(20) NOT NULL,
  CONSTRAINT fk_tel_leitor FOREIGN KEY (id_leitor) REFERENCES leitor (id_leitor)
    ON DELETE CASCADE
);

-- Relacionamento 1:1: FK com UNIQUE
CREATE TABLE carteirinha (
  id_carteirinha INT AUTO_INCREMENT PRIMARY KEY,
  id_leitor      INT     NOT NULL UNIQUE,
  data_emissao   DATE    NOT NULL,
  data_validade  DATE    NOT NULL,
  ativa          BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT ck_carteirinha_validade CHECK (data_validade > data_emissao),
  CONSTRAINT fk_carteirinha_leitor FOREIGN KEY (id_leitor) REFERENCES leitor (id_leitor)
);

-- ---------------------------------------------------------------------
-- Tabelas associativas e de movimento
-- ---------------------------------------------------------------------
-- N:N livro <-> autor, com chave primária composta
CREATE TABLE livro_autor (
  id_livro INT NOT NULL,
  id_autor INT NOT NULL,
  PRIMARY KEY (id_livro, id_autor),
  CONSTRAINT fk_la_livro FOREIGN KEY (id_livro) REFERENCES livro (id_livro)
    ON DELETE CASCADE,
  CONSTRAINT fk_la_autor FOREIGN KEY (id_autor) REFERENCES autor (id_autor)
);

-- N:N leitor <-> exemplar (cada linha é um empréstimo)
CREATE TABLE emprestimo (
  id_emprestimo           INT AUTO_INCREMENT PRIMARY KEY,
  id_leitor               INT          NOT NULL,
  id_exemplar             INT          NOT NULL,
  data_emprestimo         DATE         NOT NULL,
  data_devolucao_prevista DATE         NOT NULL,
  data_devolucao_real     DATE,                       -- NULL = ainda não devolvido
  multa                   DECIMAL(6,2) NOT NULL DEFAULT 0,
  CONSTRAINT uq_emprestimo UNIQUE (id_exemplar, data_emprestimo),
  CONSTRAINT ck_emp_prazo  CHECK (data_devolucao_prevista >= data_emprestimo),
  CONSTRAINT ck_emp_real   CHECK (data_devolucao_real IS NULL
                                  OR data_devolucao_real >= data_emprestimo),
  CONSTRAINT ck_emp_multa  CHECK (multa >= 0),
  CONSTRAINT fk_emp_leitor   FOREIGN KEY (id_leitor)   REFERENCES leitor (id_leitor),
  CONSTRAINT fk_emp_exemplar FOREIGN KEY (id_exemplar) REFERENCES exemplar (id_exemplar)
);

CREATE TABLE reserva (
  id_reserva   INT AUTO_INCREMENT PRIMARY KEY,
  id_leitor    INT         NOT NULL,
  id_livro     INT         NOT NULL,
  data_reserva DATE        NOT NULL,
  status       VARCHAR(15) NOT NULL DEFAULT 'ativa',
  CONSTRAINT uq_reserva UNIQUE (id_leitor, id_livro, data_reserva),
  CONSTRAINT ck_reserva_status CHECK (status IN ('ativa', 'atendida', 'cancelada')),
  CONSTRAINT fk_reserva_leitor FOREIGN KEY (id_leitor) REFERENCES leitor (id_leitor),
  CONSTRAINT fk_reserva_livro  FOREIGN KEY (id_livro)  REFERENCES livro (id_livro)
);

-- ---------------------------------------------------------------------
-- Índices extras (PK, UNIQUE e FK já têm índice)
-- ---------------------------------------------------------------------
CREATE INDEX idx_livro_titulo      ON livro (titulo);
CREATE INDEX idx_leitor_nome       ON leitor (nome);
CREATE INDEX idx_emp_data          ON emprestimo (data_emprestimo);
CREATE INDEX idx_emp_prevista      ON emprestimo (data_devolucao_prevista);

-- ---------------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------------
-- Livros com a lista de autores em uma única linha
CREATE VIEW vw_livro_autores AS
SELECT l.id_livro, l.titulo, e.nome AS editora,
       GROUP_CONCAT(a.nome ORDER BY a.nome SEPARATOR ', ') AS autores
FROM livro l
INNER JOIN editora e     ON e.id_editora = l.id_editora
INNER JOIN livro_autor la ON la.id_livro = l.id_livro
INNER JOIN autor a       ON a.id_autor   = la.id_autor
GROUP BY l.id_livro, l.titulo, e.nome;

-- Empréstimos com leitor, livro e situação (devolvido / no prazo / atrasado)
CREATE VIEW vw_emprestimo_detalhe AS
SELECT em.id_emprestimo, le.nome AS leitor, li.titulo AS livro, ex.codigo_tombo,
       em.data_emprestimo, em.data_devolucao_prevista, em.data_devolucao_real, em.multa,
       CASE
         WHEN em.data_devolucao_real IS NOT NULL THEN 'devolvido'
         WHEN em.data_devolucao_prevista < CURDATE() THEN 'atrasado'
         ELSE 'no prazo'
       END AS situacao
FROM emprestimo em
INNER JOIN leitor   le ON le.id_leitor   = em.id_leitor
INNER JOIN exemplar ex ON ex.id_exemplar = em.id_exemplar
INNER JOIN livro    li ON li.id_livro    = ex.id_livro;

-- Conferência:
-- SHOW TABLES;
-- DESCRIBE leitor;
