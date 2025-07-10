
-- ============================================
-- SQL Script: Análise de Margem - Revisão IC
-- Origem: Conversa com assistente (Chat Copilot)
-- Finalidade: Armazenamento e documentação no GitHub
-- ============================================

-- Medidas DAX convertidas para SQL
-- --------------------------------

-- cash margem companhia
-- SUM(venda_bruta_total - custo_total)

-- cash margem (revisao ic)
-- SUM(CASE WHEN origem = 'revisao ic' THEN venda_bruta_total - custo_total ELSE 0 END)

-- margem simulada (revisao ic)
-- SUM(CASE WHEN origem = 'revisao ic' THEN preco_regular_anterior_pond_total - custo_total ELSE 0 END)

-- margem incremental (revisao ic)
-- cash margem (revisao ic) - margem simulada (revisao ic)

-- % ganho margem (revisao ic)
-- margem incremental / margem simulada

-- ============================================
-- Query SQL completa com filtros e ajustes
-- ============================================

WITH vendas_agregadas AS (
    SELECT
        v.uf,
        DATE_TRUNC('week', v.data_movimento) AS data_inicio_semana,
        'S' || LPAD(CAST(WEEK(v.data_movimento) AS VARCHAR), 2, '0') AS semana_ano,
        v.codigo_produto,
        m.nome_categoria_n2,
        m.nome_categoria_n3,
        m.nome_categoria_n4,
        v.venda_ecommerce,
        SUM(v.cc_venda_bruta) AS venda_bruta_total,
        SUM(v.cc_custo_medio_contabil_ponderado_com_icms) AS custo_total,
        SUM(v.cc_quantidade) AS quantidade_total
    FROM master_data.cta_vendas_multiempresa_datalake v
    JOIN master_data.cta_dim_produto_mestre m ON v.codigo_produto = m.codigo_produto
    WHERE v.data_movimento BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
      AND m.nome_categoria_n2 != 'RX'
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),

precos_semanais_corrigido AS (
    SELECT
        p.uf_filial AS uf,
        DATE_TRUNC('week', p.data_movimento) AS data_inicio_semana,
        p.codigo_produto,
        AVG(p.preco_regular_ff) AS preco_regular
    FROM precos.vw_historico_preco_regular_ff p
    WHERE p.data_movimento BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
      AND p.preco_regular_ff > 0
    GROUP BY 1, 2, 3
),

precos_com_anterior AS (
    SELECT *,
           LAG(preco_regular) OVER (
               PARTITION BY uf, codigo_produto 
               ORDER BY data_inicio_semana
           ) AS preco_anterior
    FROM precos_semanais_corrigido
),

origens_base AS (
    SELECT
        CAST(produto AS DOUBLE) AS codigo_produto,
        uf,
        CAST("data efetividade" AS DATE) AS data_efetividade,
        COALESCE(origem, 'não identificado') AS origem
    FROM precos.execucoes_preco_regular
),

precos_agregados AS (
    SELECT 
        uf, 
        data_inicio_semana, 
        codigo_produto,
        AVG(preco_regular) AS preco_regular,
        AVG(preco_anterior) AS preco_anterior
    FROM precos_com_anterior
    GROUP BY 1, 2, 3
),

origens_proximas AS (
    SELECT
        va.uf,
        va.data_inicio_semana,
        va.codigo_produto,
        ob.origem,
        ROW_NUMBER() OVER (
            PARTITION BY va.uf, va.data_inicio_semana, va.codigo_produto
            ORDER BY 
                ABS(date_diff('day', ob.data_efetividade, va.data_inicio_semana)) ASC,
                ob.data_efetividade DESC
        ) AS rn
    FROM vendas_agregadas va
    LEFT JOIN origens_base ob 
        ON va.codigo_produto = ob.codigo_produto
        AND va.uf = ob.uf
        AND ob.data_efetividade 
            BETWEEN va.data_inicio_semana - INTERVAL '15' DAY
                AND va.data_inicio_semana + INTERVAL '15' DAY
),

dados_venda AS (
    SELECT
        v.uf,
        v.semana_ano,
        v.data_inicio_semana,
        v.codigo_produto,
        v.nome_categoria_n2,
        v.nome_categoria_n3,
        v.nome_categoria_n4,
        v.venda_ecommerce,
        v.venda_bruta_total,
        v.custo_total,
        v.quantidade_total,
        CASE WHEN v.quantidade_total > 0 
             THEN v.venda_bruta_total / v.quantidade_total 
             ELSE NULL END AS preco_medio_venda,
        pa.preco_regular * v.quantidade_total AS preco_regular_pond_total,
        COALESCE(pa.preco_anterior, pa.preco_regular) * v.quantidade_total AS preco_regular_anterior_pond_total,
        COALESCE(op.origem, 'não identificado') AS origem
    FROM vendas_agregadas v
    LEFT JOIN precos_agregados pa 
        ON v.uf = pa.uf 
        AND v.data_inicio_semana = pa.data_inicio_semana 
        AND v.codigo_produto = pa.codigo_produto
    LEFT JOIN origens_proximas op 
        ON v.uf = op.uf 
        AND v.data_inicio_semana = op.data_inicio_semana 
        AND v.codigo_produto = op.codigo_produto
        AND op.rn = 1
    WHERE v.venda_ecommerce = 'N' OR v.venda_ecommerce IS NULL
)

SELECT
    SUM(venda_bruta_total - custo_total) AS cash_margem_companhia,
    SUM(CASE WHEN origem = 'revisao ic' THEN venda_bruta_total - custo_total ELSE 0 END) AS cash_margem_revisao_ic,
    SUM(CASE WHEN origem = 'revisao ic' THEN preco_regular_anterior_pond_total - custo_total ELSE 0 END) AS margem_simulada_revisao_ic,
    SUM(CASE WHEN origem = 'revisao ic' THEN venda_bruta_total - preco_regular_anterior_pond_total ELSE 0 END) AS margem_incremental_revisao_ic,
    CASE 
        WHEN SUM(CASE WHEN origem = 'revisao ic' THEN preco_regular_anterior_pond_total - custo_total ELSE 0 END) != 0
        THEN 
            SUM(CASE WHEN origem = 'revisao ic' THEN venda_bruta_total - preco_regular_anterior_pond_total ELSE 0 END) 
            / 
            SUM(CASE WHEN origem = 'revisao ic' THEN preco_regular_anterior_pond_total - custo_total ELSE 0 END)
        ELSE NULL
    END AS percentual_ganho_margem_revisao_ic
FROM dados_venda;
