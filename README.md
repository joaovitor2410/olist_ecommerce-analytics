# Olist | Análise de e-commerce

**Da descoberta dos dados ao dashboard: vendas, entregas e satisfação dos clientes com Python, PostgreSQL e Power BI.**

Projeto de portfólio desenvolvido por **João Victor Azevedo Porto**, com o objetivo de transformar dados transacionais de e-commerce em indicadores consistentes e análises de negócio. O trabalho contempla descoberta, limpeza, análise exploratória, estruturação em banco de dados e visualização interativa.

## Objetivo e perguntas de negócio

Analisar o desempenho comercial e a experiência de compra, respondendo:

- Como o valor de mercadorias e o volume de pedidos evoluem ao longo do tempo?
- Quais estados concentram o maior valor de mercadorias?
- Quanto tempo os pedidos levam para chegar e qual parcela apresenta atraso?
- Como a frequência de atrasos varia entre estados?
- Como as avaliações se distribuem e como se relacionam com a pontualidade das entregas?

## Resultados comerciais

No recorte de vendas entregues elegíveis, sem filtros adicionais de período ou estado:

| Indicador | Resultado |
|---|---:|
| Pedidos de vendas entregues elegíveis | 96.478 |
| Consumidores distintos identificados | 93.358 |
| Valor de mercadorias, sem frete | R$ 13.221.498,11 |
| Ticket médio por pedido, sem frete | R$ 137,04 |

O gráfico por estado mostra São Paulo na liderança do valor de mercadorias. A evolução mensal evidencia variações relevantes ao longo do período, que devem ser interpretadas considerando a cobertura dos dados e a conclusão das entregas.

O valor de mercadorias representa os produtos dos pedidos elegíveis. **Não equivale a lucro, receita líquida ou total pago com frete.** O ticket médio utiliza pedidos como denominador, e não consumidores.

## Dashboard

O relatório possui três páginas, com segmentações por período da compra e estado do cliente, além de botão para limpar as segmentações da página.

### Visão Geral

Apresenta valor de mercadorias, pedidos, consumidores, ticket médio, evolução mensal e distribuição geográfica das vendas.

![Dashboard Olist — Visão Geral](images/Power%20BI/visao_geral.png)

### Entregas

Apresenta pedidos elegíveis para análise logística, taxa de atraso, tempo mediano e percentil 90 do tempo de entrega. Os gráficos permitem acompanhar atrasos por mês da compra e comparar estados.

Na comparação por estado, o mínimo de 100 pedidos analisados no contexto selecionado reduz a exposição de taxas baseadas em volumes muito pequenos. Esse corte é um critério de apresentação, não uma garantia de significância estatística.

![Dashboard Olist — Entregas](images/Power%20BI/entregas.png)

### Satisfação

Apresenta pedidos avaliados elegíveis, nota média, percentual de avaliações baixas e positivas, distribuição das notas e comparação entre entregas pontuais e atrasadas.

A comparação utiliza a proporção de notas baixas dentro de cada grupo, permitindo avaliar grupos com quantidades diferentes de pedidos.

![Dashboard Olist — Satisfação](images/Power%20BI/satisfacao.png)

O arquivo editável está em [powerbi/Olist_Ecommerce_Analytics.pbix](powerbi/Olist_Ecommerce_Analytics.pbix).

## Dados e ferramentas

**Fonte:** Brazilian E-Commerce Public Dataset by Olist, disponível no Kaggle sob o identificador `olistbr/brazilian-ecommerce`.

O conjunto reúne nove tabelas com pedidos, itens, clientes, vendedores, produtos, pagamentos, avaliações, geolocalização e tradução de categorias. A base original possui 99.441 pedidos, com compras entre setembro de 2016 e outubro de 2018. O intervalo disponível para cada indicador depende dos critérios de elegibilidade.

| Ferramenta | Aplicação |
|---|---|
| Python e Google Colab | Descoberta, limpeza e análise exploratória |
| Pandas e NumPy | Transformações, agregações e validações |
| Matplotlib e Seaborn | Visualizações exploratórias |
| Parquet | Armazenamento dos dados processados com preservação de tipos |
| PostgreSQL e SQL | Estruturação das tabelas, views e consultas analíticas |
| Power BI, Power Query e DAX | Modelo analítico, indicadores e dashboard |
| Git e GitHub | Versionamento e documentação |

## Desenvolvimento

### 1. Data Discovery

Levantamento do tamanho e da granularidade das tabelas, tipos de dados, chaves, relacionamentos, valores ausentes, duplicidades e inconsistências temporais.

Foram identificados problemas como datas armazenadas como texto, contagens representadas como números decimais, dados geográficos duplicados e ausência de informações em produtos e avaliações. Também foi verificado que identificadores de avaliações não poderiam ser tratados indiscriminadamente como chaves únicas.

### 2. Data Cleaning

As transformações foram orientadas pelo diagnóstico e registradas para permitir auditoria:

- Conversão e validação de datas, com sinalização de sequências temporais inconsistentes.
- Uso de inteiros anuláveis para contagens que admitem valores ausentes.
- Preservação de identificadores e prefixos de CEP como texto.
- Representação monetária em centavos inteiros.
- Tratamento de duplicatas exatas na geolocalização e sinalização de coordenadas suspeitas.
- Preservação de ausências que não podem ser interpretadas como zero.
- Definição de critérios específicos de elegibilidade para vendas, entregas e avaliações.

Pedidos não foram descartados indiscriminadamente por status. As regras de inclusão são aplicadas conforme a pergunta analítica.

### 3. Análise exploratória

Exploração do desempenho comercial, distribuição geográfica, tempos de entrega, atrasos e avaliações. As análises utilizam denominadores explícitos e consideram a disponibilidade dos campos necessários.

### 4. PostgreSQL e validação

Importação dos dados tratados, criação de views e consultas de qualidade e negócio. As validações entre Python e SQL foram executadas durante o desenvolvimento para conferir a consistência da base analítica.

A view `olist.v_orders_analysis`, importada no Power BI como `FatoPedidos`, possui **uma linha por pedido**. Itens e pagamentos são agregados antes da junção para evitar multiplicação de linhas e inflação dos totais. Quando há mais de uma avaliação, uma regra determinística seleciona uma por pedido.

### 5. Power BI

Criação da tabela calendário, relacionamento pela data da compra, medidas DAX e páginas de vendas, entregas e satisfação. As medidas aplicam os critérios de elegibilidade correspondentes a cada análise.

## Definições dos indicadores

| Indicador | Definição |
|---|---|
| Vendas elegíveis | Pedidos entregues, com data de compra, itens e total de mercadorias válido |
| Valor de mercadorias | Soma de `merchandise_cents` das vendas elegíveis, dividida por 100 |
| Ticket médio | Valor de mercadorias dividido pela quantidade de pedidos de vendas elegíveis |
| Consumidores | Contagem distinta de `customer_unique_id` não vazio nas vendas elegíveis |
| Entregas elegíveis | Pedidos entregues com datas necessárias válidas e sem inconsistências de sequência temporal |
| Taxa de atraso | Pedidos atrasados divididos pelos pedidos elegíveis para análise de entrega |
| Atraso | Data efetiva de entrega posterior à data prevista, comparadas em dias de calendário |
| Tempo de entrega | Tempo decorrido entre compra e entrega, em dias, incluindo frações |
| Mediana | Valor central da distribuição dos tempos de entrega elegíveis |
| P90 | Percentil 90 dos tempos de entrega; estima o tempo em que aproximadamente 90% dos pedidos foram entregues |
| Avaliações elegíveis | Pedidos elegíveis para análise de entrega com nota válida |
| Avaliações baixas | Notas 1 e 2, divididas pelo total de pedidos avaliados elegíveis |
| Avaliações positivas | Notas 4 e 5, divididas pelo total de pedidos avaliados elegíveis |

A nota 3 integra o total de avaliações, mas não os grupos de notas baixas ou positivas. Avaliações ausentes não são convertidas em zero. Na análise de satisfação, o recorte exige informações logísticas válidas; portanto, não representa todas as avaliações da base original.

## Organização do repositório

| Caminho | Conteúdo |
|---|---|
| `notebooks/` | Notebooks de descoberta, limpeza e análise exploratória |
| `sql/` | Criação das tabelas, views, validações e consultas de negócio |
| `src/` | Script de importação e especificação das tabelas |
| `data/raw/` | Dados originais, gerados ou obtidos localmente |
| `data/processed/` | Dados tratados para análise e importação |
| `reports/` | Relatórios gerados de validação e importação |
| `docs/` | Documentação do modelo, métricas e validações |
| `powerbi/` | Relatório editável do Power BI |
| `images/Power BI/` | Capturas das três páginas do dashboard |
| `requirements-sql.txt` | Dependências Python da etapa PostgreSQL |

## Como reproduzir

1. Clone o repositório e abra a pasta do projeto.
2. Execute os notebooks de descoberta, limpeza e análise exploratória, nessa ordem, seguindo as instruções de cada notebook. Eles foram preparados para uso no Google Colab.
3. Disponibilize os arquivos tratados da limpeza em `data/processed/`. A análise exploratória utiliza a base tratada, evitando uma segunda implementação das regras de limpeza.
4. Instale o PostgreSQL, crie o banco `olist_analytics` e siga o guia da etapa SQL para executar os scripts e a importação na ordem indicada.

No PowerShell, a partir da raiz do projeto, prepare o ambiente de importação:

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-sql.txt
.\.venv\Scripts\python.exe src/import_olist.py --input data/processed --check-only
```

Após preparar o banco conforme o guia e concluir a checagem dos arquivos:

```powershell
.\.venv\Scripts\python.exe src/import_olist.py --input data/processed
```

5. Execute as consultas de validação e confira as divergências antes de prosseguir.
6. Abra `powerbi/Olist_Ecommerce_Analytics.pbix` no Power BI Desktop. Ajuste servidor, banco e credenciais da fonte PostgreSQL para seu ambiente e atualize os dados.

As dependências acima correspondem à etapa SQL; as bibliotecas dos notebooks são configuradas conforme suas próprias instruções. Os dados brutos, processados e as credenciais locais não precisam integrar o versionamento: podem ser obtidos ou gerados pelo fluxo do projeto.

## Limitações e cuidados de interpretação

- Os dados são históricos e não descrevem a operação atual da Olist.
- O recorte de pedidos entregues pode sub-representar compras recentes ainda não concluídas. Meses incompletos exigem cuidado em comparações e não devem sustentar conclusões automáticas de crescimento ou queda.
- Os filtros de período usam a data da compra, inclusive nas páginas de entregas e satisfação.
- Cada área utiliza sua própria elegibilidade; diferenças entre os totais de vendas, entregas e avaliações são esperadas.
- Notas refletem os pedidos avaliados elegíveis e podem apresentar viés de resposta.
- Associação entre atraso e avaliação não demonstra causalidade.
- Não há cálculo de lucro, margem, receita líquida ou NPS. A escala de avaliação de 1 a 5 não é uma pesquisa de NPS.

## Autor

**João Victor Azevedo Porto**  
Estudante de Ciência da Computação na Uniesp Centro Universitário, com foco em Análise de Dados.

[GitHub](https://github.com/joaovitor2410)
