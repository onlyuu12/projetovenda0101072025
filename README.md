# 📊 Projeto: Análise de Margem e Histórico de Preços

Este repositório contém scripts SQL desenvolvidos para análise de margem de lucro e construção de uma visão confiável do histórico de preços regulares por produto e UF.

---

## 🧠 Objetivo Geral

Avaliar o impacto de revisões de preço (origem: "revisão ic") na margem de lucro da companhia, comparando o desempenho real com o desempenho simulado com base em preços anteriores.

---

## 📁 Estrutura do Projeto

### 1. `analise_margem.sql`

Script principal que realiza:

- Agregação de vendas semanais por produto e UF
- Cálculo de métricas de margem:
  - **Cash Margem Companhia**
  - **Cash Margem Revisão IC**
  - **Margem Simulada Revisão IC**
  - **Margem Incremental**
  - **% de Ganho de Margem**
- Cruzamento com histórico de preços e origem da revisão
- Filtros por categoria e período (ano de 2025)

### 2. `vw_historico_preco_regular_ff.sql`

Criação da view `precos.vw_historico_preco_regular_ff`, que:

- Limpa e converte dados de preços
- Preenche valores ausentes com `LAST_VALUE` (bottom-up e top-down)
- Gera datas futuras com o último preço conhecido
- Unifica dados originais e preenchidos para fornecer histórico contínuo

---

## 🔗 Relação entre os scripts

A view `vw_historico_preco_regular_ff` é utilizada no script de análise de margem para obter os preços regulares e anteriores por semana, permitindo simular margens e avaliar o impacto das revisões de preço.

---

## 🛠️ Tecnologias Utilizadas

- SQL ANSI
- Funções analíticas (`LAST_VALUE`, `LAG`, `ROW_NUMBER`)
- CTEs (Common Table Expressions)
- BigQuery (sintaxe compatível)

---

## 📅 Período de Análise

- Ano de 2025
- Dados agregados por semana (`DATE_TRUNC('week', data_movimento)`)

---

## 📌 Observações

- Produtos da categoria `RX` são excluídos da análise
- Apenas vendas físicas são consideradas (`venda_ecommerce = 'N'`)
- Origem da revisão é identificada com base na proximidade da data de efetividade

---

## ✍️ Autor

Este projeto foi desenvolvido com apoio do assistente Copilot para fins de documentação e análise de dados comerciais.

