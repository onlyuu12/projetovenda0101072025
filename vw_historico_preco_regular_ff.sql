-- View: precos.vw_historico_preco_regular_ff
-- Objetivo: Preencher o histórico de preços regulares por produto e UF, aplicando preenchimento top-down
-- Metodologia:
--   1. Limpeza de dados e conversão de tipos
--   2. Preenchimento bottom-up com LAST_VALUE (ASC)
--   3. Preenchimento top-down com LAST_VALUE (DESC) sobre preco_regular_ff
--   4. Geração de datas futuras com último preço conhecido
--   5. Estrutura final mantém as mesmas colunas da versão original

CREATE VIEW precos.vw_historico_preco_regular_ff AS
WITH
  dados_base AS (
    SELECT
      data_movimento,
      uf_filial,
      codigo_produto,
      anomes,
      CASE
        WHEN preco_regular = 'nan' THEN NULL
        ELSE TRY_CAST(preco_regular AS DOUBLE)
      END AS preco_regular_numerico,
      DATE(PARSE_DATETIME(data_movimento, 'yyyy-MM-dd HH:mm:ss')) AS data_formatada
    FROM precos.historico_preco_regular
    WHERE partition_0 = 'PRECO_REGULAR_HISTORICO_BOLETIM'
  ),

  -- Preenchimento bottom-up
  dados_com_ff AS (
    SELECT
      *,
      LAST_VALUE(preco_regular_numerico) IGNORE NULLS OVER (
        PARTITION BY codigo_produto, uf_filial
        ORDER BY data_formatada ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS preco_regular_ff
    FROM dados_base
  ),

  -- Preenchimento top-down com base no preco_regular_ff
  dados_com_ff2 AS (
    SELECT
      *,
      LAST_VALUE(preco_regular_ff) IGNORE NULLS OVER (
        PARTITION BY codigo_produto, uf_filial
        ORDER BY data_formatada DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
      ) AS preco_regular_ff2
    FROM dados_com_ff
  ),

  ultima_data_conhecida AS (
    SELECT
      codigo_produto,
      uf_filial,
      MAX(data_formatada) AS ultima_data
    FROM dados_com_ff2
    WHERE preco_regular_ff2 IS NOT NULL
    GROUP BY codigo_produto, uf_filial
  ),

  datas_para_preencher AS (
    SELECT date_column AS data_preenchimento
    FROM (
      SELECT SEQUENCE(
        (SELECT MIN(data_formatada) FROM dados_base),
        CURRENT_DATE,
        INTERVAL '1' DAY
      ) AS date_array
    )
    CROSS JOIN UNNEST(date_array) t (date_column)
  ),

  dados_originais AS (
    SELECT
      data_formatada AS data_movimento,
      uf_filial,
      TRY_CAST(codigo_produto AS INTEGER) AS codigo_produto,
      anomes,
      CAST(preco_regular_ff2 AS DOUBLE) AS preco_regular_ff
    FROM dados_com_ff2
  ),

  dados_populados AS (
    SELECT
      d.data_preenchimento AS data_movimento,
      u.uf_filial,
      TRY_CAST(u.codigo_produto AS INTEGER) AS codigo_produto,
      FORMAT_DATETIME(d.data_preenchimento, 'yyyyMM') AS anomes,
      CAST(f.preco_regular_ff2 AS DOUBLE) AS preco_regular_ff
    FROM ultima_data_conhecida u
    INNER JOIN dados_com_ff2 f
      ON u.codigo_produto = f.codigo_produto
     AND u.uf_filial = f.uf_filial
     AND u.ultima_data = f.data_formatada
    INNER JOIN datas_para_preencher d
      ON d.data_preenchimento > u.ultima_data
  )

SELECT
  CAST(data_movimento AS DATE) AS data_movimento,
  CAST(uf_filial AS VARCHAR) AS uf_filial,
  codigo_produto,
  CAST(anomes AS VARCHAR) AS anomes,
  preco_regular_ff
FROM (
  SELECT * FROM dados_originais
  UNION ALL
  SELECT * FROM dados_populados
)
ORDER BY uf_filial ASC, codigo_produto ASC, data_movimento ASC;
