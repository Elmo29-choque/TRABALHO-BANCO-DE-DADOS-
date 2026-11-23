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

-- =====================================================================
-- 02_dados.sql : dados de teste (rode depois do 01_criacao.sql)
-- Casos-limite: leitor sem empréstimos, livro nunca emprestado, NULLs,
-- empréstimos em aberto/atrasados, acentos e ç (utf8mb4).
-- =====================================================================

INSERT INTO cidade (nome, estado) VALUES
  ('Rio de Janeiro', 'RJ'),
  ('Niterói', 'RJ'),
  ('Nova Iguaçu', 'RJ'),
  ('São Gonçalo', 'RJ'),
  ('Duque de Caxias', 'RJ'),
  ('São Paulo', 'SP'),
  ('Belo Horizonte', 'MG'),
  ('Vitória', 'ES');

INSERT INTO editora (nome) VALUES
  ('Companhia das Letras'),
  ('Rocco'),
  ('Intrínseca'),
  ('Record'),
  ('Editora Globo'),
  ('Aleph');

INSERT INTO autor (nome) VALUES
  ('Machado de Assis'),
  ('Clarice Lispector'),
  ('Graciliano Ramos'),
  ('Jorge Amado'),
  ('Cecília Meireles'),
  ('Carlos Drummond de Andrade'),
  ('Rachel de Queiroz'),
  ('Lygia Fagundes Telles'),
  ('Conceição Evaristo'),
  ('Paulo Coelho'),
  ('Ariano Suassuna'),
  ('Mário de Andrade');

INSERT INTO livro (titulo, isbn, ano_publicacao, id_editora) VALUES
  ('Dom Casmurro', '9788500000001', 1899, 1),
  ('Memórias Póstumas de Brás Cubas', '9788500000002', 1881, 1),
  ('A Hora da Estrela', '9788500000003', 1977, 2),
  ('Laços de Família', '9788500000004', 1960, 2),
  ('Vidas Secas', '9788500000005', 1938, 3),
  ('São Bernardo', '9788500000006', 1934, 3),
  ('Capitães da Areia', '9788500000007', 1937, 4),
  ('Gabriela, Cravo e Canela', '9788500000008', 1958, 4),
  ('O Quinze', '9788500000009', 1930, 5),
  ('Ponciá Vicêncio', '9788500000010', 2003, 6),
  ('O Alquimista', '9788500000011', 1988, 2),
  ('Auto da Compadecida', '9788500000012', 1955, 5),
  ('Macunaíma', '9788500000013', 1928, 1),
  ('Antologia Poética', '9788500000014', 1962, 4),
  ('As Meninas', '9788500000015', 1973, 6),
  ('Poesia Reunida', '9788500000016', 1999, 3);

INSERT INTO livro_autor (id_livro, id_autor) VALUES
  (1, 1),
  (2, 1),
  (3, 2),
  (4, 2),
  (5, 3),
  (6, 3),
  (7, 4),
  (8, 4),
  (9, 7),
  (10, 9),
  (11, 10),
  (12, 11),
  (13, 12),
  (14, 6),
  (14, 5),
  (15, 8),
  (16, 5);

INSERT INTO exemplar (codigo_tombo, id_livro, status) VALUES
  ('TB00001', 1, 'disponivel'),
  ('TB00002', 1, 'disponivel'),
  ('TB00003', 2, 'disponivel'),
  ('TB00004', 2, 'emprestado'),
  ('TB00005', 3, 'disponivel'),
  ('TB00006', 3, 'disponivel'),
  ('TB00007', 4, 'disponivel'),
  ('TB00008', 4, 'disponivel'),
  ('TB00009', 5, 'disponivel'),
  ('TB00010', 5, 'disponivel'),
  ('TB00011', 6, 'emprestado'),
  ('TB00012', 6, 'disponivel'),
  ('TB00013', 7, 'emprestado'),
  ('TB00014', 7, 'disponivel'),
  ('TB00015', 8, 'disponivel'),
  ('TB00016', 8, 'disponivel'),
  ('TB00017', 9, 'disponivel'),
  ('TB00018', 10, 'disponivel'),
  ('TB00019', 11, 'disponivel'),
  ('TB00020', 12, 'emprestado'),
  ('TB00021', 13, 'manutencao'),
  ('TB00022', 14, 'disponivel'),
  ('TB00023', 15, 'disponivel'),
  ('TB00024', 16, 'disponivel');

INSERT INTO leitor (nome, email, data_nascimento, data_cadastro, id_cidade) VALUES
  ('Mariana Alves', 'mariana.alves@email.com', '1980-01-01', '2025-03-01', 1),
  ('Rafael Costa', 'rafael.costa@email.com', '1982-02-04', '2025-03-26', 2),
  ('Beatriz Nogueira', 'beatriz.nogueira@email.com', '1984-03-07', '2025-04-20', 3),
  ('João Pedro Carvalho', 'joao.carvalho@email.com', '1986-04-10', '2025-05-15', 4),
  ('Luciana Ferreira', 'luciana.ferreira@email.com', '1988-05-13', '2025-06-09', 5),
  ('Thiago Araújo', 'thiago.araujo@email.com', '1990-06-16', '2025-07-04', 6),
  ('Camila Rocha', 'camila.rocha@email.com', '1992-07-19', '2025-07-29', 7),
  ('Gustavo Lima', 'gustavo.lima@email.com', '1994-08-22', '2025-08-23', 8),
  ('Fernanda Moreira', 'fernanda.moreira@email.com', '1996-09-25', '2025-09-17', 1),
  ('Henrique Barbosa', 'henrique.barbosa@email.com', '1998-10-01', '2025-10-12', 2),
  ('Patrícia Gonçalves', 'patricia.goncalves@email.com', NULL, '2025-11-06', 3),
  ('Sem Empréstimos', 'sem.emprestimos@email.com', '2002-12-07', '2025-12-01', NULL);

INSERT INTO telefone_leitor (id_leitor, numero) VALUES
  (1, '(21) 91037-2053'),
  (1, '(21) 3301-4071'),
  (2, '(21) 91074-2106'),
  (3, '(21) 91111-2159'),
  (3, '(21) 3303-4213'),
  (4, '(21) 91148-2212'),
  (5, '(21) 91185-2265'),
  (5, '(21) 3305-4355'),
  (6, '(21) 91222-2318'),
  (7, '(21) 91259-2371'),
  (7, '(21) 3307-4497'),
  (8, '(21) 91296-2424'),
  (9, '(21) 91333-2477'),
  (10, '(21) 91370-2530'),
  (11, '(21) 91407-2583');

INSERT INTO carteirinha (id_leitor, data_emissao, data_validade, ativa) VALUES
  (1, '2025-03-01', '2027-03-01', TRUE),
  (2, '2025-03-26', '2027-03-26', TRUE),
  (3, '2025-04-20', '2027-04-20', TRUE),
  (4, '2025-05-15', '2027-05-15', TRUE),
  (5, '2025-06-09', '2027-06-09', TRUE),
  (6, '2025-07-04', '2027-07-04', TRUE),
  (7, '2025-07-29', '2027-07-29', TRUE),
  (8, '2025-08-23', '2027-08-23', TRUE),
  (9, '2025-09-17', '2027-09-17', TRUE),
  (10, '2025-10-12', '2027-10-12', FALSE);

INSERT INTO emprestimo (id_leitor, id_exemplar, data_emprestimo, data_devolucao_prevista, data_devolucao_real, multa) VALUES
  (1, 1, '2026-01-05', '2026-01-19', '2026-01-16', 0.00),
  (6, 8, '2026-01-14', '2026-01-28', '2026-01-28', 0.00),
  (11, 15, '2026-01-23', '2026-02-06', '2026-02-08', 1.00),
  (5, 22, '2026-02-01', '2026-02-15', '2026-02-20', 2.50),
  (10, 6, '2026-02-10', '2026-02-24', '2026-03-06', 5.00),
  (4, 13, '2026-02-19', '2026-03-05', '2026-03-05', 0.00),
  (9, 20, '2026-02-28', '2026-03-14', '2026-03-15', 0.50),
  (3, 4, '2026-03-09', '2026-03-23', '2026-03-22', 0.00),
  (8, 11, '2026-03-18', '2026-04-01', '2026-03-29', 0.00),
  (2, 18, '2026-03-27', '2026-04-10', '2026-04-10', 0.00),
  (7, 2, '2026-04-05', '2026-04-19', '2026-04-21', 1.00),
  (1, 9, '2026-04-14', '2026-04-28', '2026-05-03', 2.50),
  (6, 16, '2026-04-23', '2026-05-07', '2026-05-17', 5.00),
  (11, 23, '2026-05-02', '2026-05-16', '2026-05-16', 0.00),
  (5, 7, '2026-05-11', '2026-05-25', '2026-05-26', 0.50),
  (10, 14, '2026-05-20', '2026-06-03', '2026-06-02', 0.00),
  (4, 21, '2026-05-29', '2026-06-12', '2026-06-09', 0.00),
  (9, 5, '2026-06-07', '2026-06-21', '2026-06-21', 0.00),
  (3, 12, '2026-06-16', '2026-06-30', '2026-07-02', 1.00),
  (8, 19, '2026-06-25', '2026-07-09', '2026-07-14', 2.50),
  (2, 3, '2026-07-04', '2026-07-18', '2026-07-28', 5.00),
  (7, 10, '2026-07-13', '2026-07-27', '2026-07-27', 0.00),
  (1, 17, '2026-07-22', '2026-08-05', '2026-08-06', 0.50),
  (6, 1, '2026-07-31', '2026-08-14', '2026-08-13', 0.00),
  (11, 8, '2026-08-09', '2026-08-23', '2026-08-20', 0.00),
  (5, 15, '2026-08-18', '2026-09-01', '2026-09-01', 0.00),
  (10, 22, '2026-08-27', '2026-09-10', '2026-09-12', 1.00),
  (4, 6, '2026-09-05', '2026-09-19', '2026-09-24', 2.50),
  (9, 13, '2026-09-14', '2026-09-28', NULL, 0.00),
  (3, 20, '2026-09-23', '2026-10-07', NULL, 0.00),
  (8, 4, '2026-10-02', '2026-10-16', NULL, 0.00),
  (2, 11, '2026-10-11', '2026-10-25', NULL, 0.00);

INSERT INTO reserva (id_leitor, id_livro, data_reserva, status) VALUES
  (1, 1, '2026-02-01', 'atendida'),
  (4, 6, '2026-02-09', 'cancelada'),
  (7, 11, '2026-02-17', 'ativa'),
  (10, 16, '2026-02-25', 'atendida'),
  (1, 5, '2026-03-05', 'cancelada'),
  (4, 10, '2026-03-13', 'ativa'),
  (7, 15, '2026-03-21', 'atendida'),
  (10, 4, '2026-03-29', 'cancelada'),
  (1, 9, '2026-04-06', 'ativa'),
  (4, 14, '2026-04-14', 'atendida'),
  (7, 3, '2026-04-22', 'cancelada'),
  (10, 8, '2026-04-30', 'ativa'),
  (1, 13, '2026-05-08', 'atendida'),
  (4, 2, '2026-05-16', 'cancelada'),
  (7, 7, '2026-05-24', 'ativa'),
  (10, 12, '2026-06-01', 'atendida'),
  (1, 1, '2026-06-09', 'cancelada'),
  (4, 6, '2026-06-17', 'ativa'),
  (7, 11, '2026-06-25', 'atendida'),
  (10, 16, '2026-07-03', 'cancelada'),
  (1, 5, '2026-07-11', 'ativa'),
  (4, 10, '2026-07-19', 'atendida'),
  (7, 15, '2026-07-27', 'cancelada'),
  (10, 4, '2026-08-04', 'ativa'),
  (1, 9, '2026-08-12', 'atendida'),
  (4, 14, '2026-08-20', 'cancelada'),
  (7, 3, '2026-08-28', 'ativa'),
  (10, 8, '2026-09-05', 'atendida'),
  (1, 13, '2026-09-13', 'cancelada'),
  (4, 2, '2026-09-21', 'ativa');

-- =====================================================================
-- 03_consultas.sql : consultas de validação (15 consultas)
-- =====================================================================

-- Consulta 01
-- Pergunta de negócio: quais livros foram publicados entre 1930 e 1960?
-- Conceitos: WHERE + BETWEEN + ORDER BY
SELECT titulo, ano_publicacao
FROM livro
WHERE ano_publicacao BETWEEN 1930 AND 1960
ORDER BY ano_publicacao;

-- Consulta 02
-- Pergunta de negócio: quais reservas ativas ou atendidas foram feitas para os livros 1, 3 e 5?
-- Conceitos: WHERE + AND + IN
SELECT id_reserva, id_leitor, id_livro, data_reserva, status
FROM reserva
WHERE id_livro IN (1, 3, 5)
  AND status IN ('ativa', 'atendida')
ORDER BY data_reserva;

-- Consulta 03
-- Pergunta de negócio: quais livros têm "Hora" ou "Cravo" no título? (busca por parte do nome)
-- Conceitos: LIKE + OR
SELECT titulo
FROM livro
WHERE titulo LIKE '%Hora%' OR titulo LIKE '%Cravo%';

-- Consulta 04
-- Pergunta de negócio: quais leitores não informaram data de nascimento ou cidade?
-- Conceitos: IS NULL + OR
SELECT nome, data_nascimento, id_cidade
FROM leitor
WHERE data_nascimento IS NULL OR id_cidade IS NULL;

-- Consulta 05
-- Pergunta de negócio: quais são os 5 leitores que mais pegaram livros emprestados?
-- Conceitos: COUNT + GROUP BY + ORDER BY + LIMIT (ranking)
SELECT le.nome, COUNT(*) AS total_emprestimos
FROM emprestimo em
INNER JOIN leitor le ON le.id_leitor = em.id_leitor
GROUP BY le.id_leitor, le.nome
ORDER BY total_emprestimos DESC, le.nome
LIMIT 5;

-- Consulta 06
-- Pergunta de negócio: quantos exemplares cada livro tem?
-- Conceitos: COUNT + GROUP BY + LEFT JOIN (livros sem exemplar apareceriam com 0)
SELECT li.titulo, COUNT(ex.id_exemplar) AS exemplares
FROM livro li
LEFT JOIN exemplar ex ON ex.id_livro = li.id_livro
GROUP BY li.id_livro, li.titulo
ORDER BY exemplares DESC, li.titulo;

-- Consulta 07
-- Pergunta de negócio: qual o total de multas, a maior multa e a multa média por mês de empréstimo?
-- Conceitos: SUM, MAX, AVG + GROUP BY + função de data
SELECT MONTH(data_emprestimo) AS mes,
       SUM(multa)           AS total_multas,
       MAX(multa)           AS maior_multa,
       ROUND(AVG(multa), 2) AS multa_media
FROM emprestimo
GROUP BY MONTH(data_emprestimo)
ORDER BY mes;

-- Consulta 08
-- Pergunta de negócio: quais livros foram emprestados mais de 2 vezes?
-- Conceitos: JOIN + GROUP BY + HAVING
SELECT li.titulo, COUNT(*) AS vezes_emprestado
FROM emprestimo em
INNER JOIN exemplar ex ON ex.id_exemplar = em.id_exemplar
INNER JOIN livro li    ON li.id_livro    = ex.id_livro
GROUP BY li.id_livro, li.titulo
HAVING COUNT(*) > 2
ORDER BY vezes_emprestado DESC;

-- Consulta 09
-- Pergunta de negócio: quem pegou o quê e quando (com autor e editora)?
-- Conceitos: INNER JOIN com 5 tabelas
SELECT le.nome AS leitor, li.titulo, a.nome AS autor, ed.nome AS editora, em.data_emprestimo
FROM emprestimo em
INNER JOIN leitor le      ON le.id_leitor   = em.id_leitor
INNER JOIN exemplar ex    ON ex.id_exemplar = em.id_exemplar
INNER JOIN livro li       ON li.id_livro    = ex.id_livro
INNER JOIN editora ed     ON ed.id_editora  = li.id_editora
INNER JOIN livro_autor la ON la.id_livro    = li.id_livro
INNER JOIN autor a        ON a.id_autor     = la.id_autor
WHERE em.data_emprestimo >= '2026-06-01'
ORDER BY em.data_emprestimo;

-- Consulta 10
-- Pergunta de negócio: quantos livros cada autor tem no acervo e quantos empréstimos eles geraram?
-- Conceitos: JOIN com 5 tabelas (um LEFT JOIN) + GROUP BY
SELECT a.nome AS autor, COUNT(DISTINCT li.id_livro) AS livros, COUNT(em.id_emprestimo) AS emprestimos
FROM autor a
INNER JOIN livro_autor la ON la.id_autor = a.id_autor
INNER JOIN livro li       ON li.id_livro = la.id_livro
INNER JOIN exemplar ex    ON ex.id_livro = li.id_livro
LEFT JOIN emprestimo em   ON em.id_exemplar = ex.id_exemplar
GROUP BY a.id_autor, a.nome
ORDER BY emprestimos DESC, a.nome;

-- Consulta 11
-- Pergunta de negócio: quais leitores nunca fizeram um empréstimo?
-- Conceitos: LEFT JOIN + IS NULL
SELECT le.nome
FROM leitor le
LEFT JOIN emprestimo em ON em.id_leitor = le.id_leitor
WHERE em.id_emprestimo IS NULL;

-- Consulta 12
-- Pergunta de negócio: quais empréstimos estão atrasados hoje (RN8: prazo de 14 dias)?
-- Conceitos: WHERE com datas + IS NULL + DATEDIFF
SELECT le.nome AS leitor, li.titulo, em.data_devolucao_prevista,
       DATEDIFF(CURDATE(), em.data_devolucao_prevista) AS dias_atraso
FROM emprestimo em
INNER JOIN leitor le   ON le.id_leitor   = em.id_leitor
INNER JOIN exemplar ex ON ex.id_exemplar = em.id_exemplar
INNER JOIN livro li    ON li.id_livro    = ex.id_livro
WHERE em.data_devolucao_real IS NULL
  AND em.data_devolucao_prevista < CURDATE()
ORDER BY dias_atraso DESC;

-- Consulta 13
-- Pergunta de negócio: quais livros nunca foram emprestados?
-- Conceitos: subconsulta (NOT IN)
SELECT titulo
FROM livro
WHERE id_livro NOT IN (
  SELECT ex.id_livro
  FROM emprestimo em
  INNER JOIN exemplar ex ON ex.id_exemplar = em.id_exemplar
);

-- Consulta 14
-- Pergunta de negócio: quais empréstimos tiveram multa acima da média das multas cobradas?
-- Conceitos: subconsulta escalar
SELECT id_emprestimo, id_leitor, multa
FROM emprestimo
WHERE multa > (SELECT AVG(multa) FROM emprestimo WHERE multa > 0)
ORDER BY multa DESC;

-- Consulta 15
-- Pergunta de negócio: quais empréstimos estão atrasados ou em aberto, segundo a view?
-- Conceitos: consulta sobre VIEW (vw_emprestimo_detalhe)
SELECT leitor, livro, data_devolucao_prevista, situacao
FROM vw_emprestimo_detalhe
WHERE situacao <> 'devolvido'
ORDER BY data_devolucao_prevista;

-- Consulta 16 (extra: view de livros e autores, com GROUP_CONCAT)
-- Pergunta de negócio: quais livros têm mais de um autor?
-- Conceitos: VIEW + LIKE
SELECT titulo, autores
FROM vw_livro_autores
WHERE autores LIKE '%,%';


-- =====================================================================
-- 04_testes.sql : testes de integridade (cada comando DEVE falhar)
-- Execute um por vez (no Workbench, selecione o comando e use Ctrl+Enter),
-- pois o primeiro erro interrompe a execução do script inteiro.
-- Anote abaixo de cada teste o erro que o SEU MySQL devolveu.
-- =====================================================================

-- Teste 01 (entidade): PK duplicada
INSERT INTO autor (id_autor, nome) VALUES (1, 'Autor Repetido');
-- Esperado: ERROR 1062: Duplicate entry '1' for key 'autor.PRIMARY'
-- Obtido:

-- Teste 02 (entidade): UNIQUE repetido (e-mail do leitor)
INSERT INTO leitor (nome, email, data_cadastro)
VALUES ('Outra Mariana', 'mariana.alves@email.com', '2026-10-01');
-- Esperado: ERROR 1062: Duplicate entry 'mariana.alves@email.com' for key 'leitor.email'
-- Obtido:

-- Teste 03 (entidade): PK composta duplicada (livro_autor)
INSERT INTO livro_autor (id_livro, id_autor) VALUES (1, 1);
-- Esperado: ERROR 1062: Duplicate entry '1-1' for key 'livro_autor.PRIMARY'
-- Obtido:

-- Teste 04 (entidade): 1:1 violado, segunda carteirinha para o mesmo leitor
INSERT INTO carteirinha (id_leitor, data_emissao, data_validade)
VALUES (1, '2026-10-01', '2028-10-01');
-- Esperado: ERROR 1062: Duplicate entry '1' for key 'carteirinha.id_leitor'
-- Obtido:

-- Teste 05 (referencial): FK para leitor inexistente
INSERT INTO emprestimo (id_leitor, id_exemplar, data_emprestimo, data_devolucao_prevista)
VALUES (999, 1, '2026-10-20', '2026-11-03');
-- Esperado: ERROR 1452: Cannot add or update a child row: a foreign key constraint fails
-- Obtido:

-- Teste 06 (referencial): apagar "pai" que possui filhos
DELETE FROM livro WHERE id_livro = 1;
-- Esperado: ERROR 1451: Cannot delete or update a parent row: a foreign key constraint fails
-- Obtido:

-- Teste 07 (domínio): NOT NULL
INSERT INTO leitor (nome, email, data_cadastro)
VALUES (NULL, 'x@email.com', '2026-10-01');
-- Esperado: ERROR 1048: Column 'nome' cannot be null
-- Obtido:

-- Teste 08 (domínio): CHECK do status do exemplar
UPDATE exemplar SET status = 'perdido' WHERE id_exemplar = 1;
-- Esperado: ERROR 3819: Check constraint 'ck_exemplar_status' is violated.
-- Obtido:

-- Teste 09 (domínio): CHECK de multa negativa
UPDATE emprestimo SET multa = -5 WHERE id_emprestimo = 1;
-- Esperado: ERROR 3819: Check constraint 'ck_emp_multa' is violated.
-- Obtido:

-- Teste 10 (domínio): CHECK de datas (devolução prevista antes do empréstimo)
INSERT INTO emprestimo (id_leitor, id_exemplar, data_emprestimo, data_devolucao_prevista)
VALUES (1, 1, '2026-10-20', '2026-10-10');
-- Esperado: ERROR 3819: Check constraint 'ck_emp_prazo' is violated.
-- Obtido:

-- ---------------------------------------------------------------------
-- Contraprova: o CASCADE funciona (este comando NÃO falha).
-- Use transação para desfazer e não perder os dados de teste.
-- ---------------------------------------------------------------------
START TRANSACTION;
INSERT INTO telefone_leitor (id_leitor, numero) VALUES (12, '(21) 90000-0000');
DELETE FROM leitor WHERE id_leitor = 12;      -- leitor sem empréstimos nem carteirinha
SELECT COUNT(*) AS telefones_do_leitor_12 FROM telefone_leitor WHERE id_leitor = 12;  -- esperado: 0
ROLLBACK;
