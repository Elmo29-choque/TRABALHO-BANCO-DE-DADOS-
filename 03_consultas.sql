-- =====================================================================
-- 03_consultas.sql : consultas de validação (15 consultas)
-- =====================================================================
USE biblioteca;

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
