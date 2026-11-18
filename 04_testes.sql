-- =====================================================================
-- 04_testes.sql : testes de integridade (cada comando DEVE falhar)
-- Execute um por vez (no Workbench, selecione o comando e use Ctrl+Enter),
-- pois o primeiro erro interrompe a execução do script inteiro.
-- Anote abaixo de cada teste o erro que o SEU MySQL devolveu.
-- =====================================================================
USE biblioteca;

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
