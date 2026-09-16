# Etapa 04 — PostgreSQL e análise com SQL

**Projeto:** Olist E-commerce Analytics  
**Autor:** João Victor Azevedo Porto

Este guia continua o Data Discovery, a limpeza e a EDA. Você usará o pgAdmin para criar os objetos e executar SQL; um programa Python local importará os Parquet da limpeza. O programa roda no seu Windows, onde está o PostgreSQL. O Colab não acessa automaticamente o `localhost` do seu computador.

## 1. Coloque os arquivos no projeto

Extraia este pacote. Copie os conteúdos de `sql/`, `src/` e `docs/` para as pastas de mesmo nome em `olist-ecommerce-analytics`. Coloque `requirements-sql.txt` e este guia na raiz do projeto. Não é necessário substituir seu README principal.

| Arquivo | Função |
|---|---|
| `sql/01_create_tables.sql` | Cria o schema, as tabelas, restrições e índices |
| `sql/02_analytical_views.sql` | Reconstrói a base por pedido e indicadores no SQL |
| `sql/03_python_sql_validation.sql` | Cria a comparação com o resultado Python |
| `sql/04_quality_checks.sql` | Confere contagens e pendências de qualidade |
| `sql/05_business_queries.sql` | Responde às perguntas da análise exploratória |
| `src/import_olist.py` | Importa os Parquet em uma única transação |
| `src/table_spec.json` | Define explicitamente as colunas importadas |
| `docs/MODELO_E_METRICAS.md` | Explica o modelo, os recortes e os limites |

Use o **ZIP da etapa 02, limpeza**, não o pacote de gráficos da EDA. Ele deve conter `clean/` e `analytical/orders_analysis.parquet`. Você pode usar o ZIP diretamente ou a estrutura já organizada em `data/processed/`.

## 2. Crie o banco no pgAdmin

1. Abra **pgAdmin 4** e expanda **Servers**.
2. Selecione seu servidor e informe a senha definida na instalação.
3. Clique com o botão direito em **Databases → Create → Database**.
4. No campo **Database**, digite `olist_analytics`.
5. Mantenha **Owner** como `postgres`, se esse for o usuário que você configurou. Clique em **Save**.
6. Clique com o botão direito em `olist_analytics` e escolha **Query Tool**.

Se o banco já existe, basta abrir o Query Tool dele. Não crie outro com o mesmo nome.

No editor superior, execute:

```sql
SELECT current_database(), current_user, version();
```

O banco deve ser `olist_analytics`. A grade **Data Output** exibe resultados; **Messages** exibe mensagens e erros. Use o botão de execução da barra de ferramentas. Evite deixar um trecho selecionado quando pretende executar o arquivo inteiro.

## 3. Crie as tabelas e as views

No Query Tool, abra o arquivo SQL pelo botão de abrir arquivo (ou copie todo o seu conteúdo no editor). Execute nesta ordem:

1. `01_create_tables.sql`
2. `02_analytical_views.sql`
3. `03_python_sql_validation.sql`

Os três arquivos podem ser executados **antes da importação**. Nesse momento, resultados vazios são esperados; eles ainda não provam que os dados estão corretos.

Depois de cada arquivo, confira **Messages**. Se ocorrer um erro dentro de uma transação, execute `ROLLBACK;`, corrija o problema e execute novamente o arquivo inteiro.

No painel esquerdo, clique com o botão direito em **Schemas → Refresh**. Expanda **olist → Tables**. Devem existir dez tabelas: nove entidades do conjunto e `reference_orders`, usada para conferir o resultado Python. As consultas salvas aparecem em **olist → Views**.

Um *schema* é um agrupamento de objetos dentro do banco. Uma *view* é uma consulta salva, que calcula os resultados ao ser consultada. Os valores não foram copiados de um relatório pronto: as views agregam as tabelas de itens, pagamentos e avaliações.

## 4. Prepare o Python local

Abra a pasta principal do projeto no Explorador de Arquivos. Na barra de endereço, digite `powershell` e pressione Enter. Isso abre o terminal nessa pasta.

Confira:

```powershell
py --version
```

Se o comando não existir, instale o Python pelo [site oficial para Windows](https://www.python.org/downloads/windows/), feche o terminal e abra novamente. Se você já usa `python` em vez de `py`, substitua o comando inicial por `python`.

Crie um ambiente separado para as dependências:

```powershell
py -m venv .venv
```

Instale as bibliotecas usando o Python desse ambiente:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements-sql.txt
```

Não é necessário ativar o ambiente nem alterar a política de execução do PowerShell. `pandas` e `pyarrow` leem os Parquet; `psycopg` se comunica com PostgreSQL. Os comandos desta seção são do **PowerShell**, não do Query Tool.

## 5. Confira e importe os arquivos

Se você organizou as pastas conforme nossa etapa anterior, teste:

```powershell
.\.venv\Scripts\python.exe src/import_olist.py --input data/processed --check-only
```

Isso procura `data/processed/clean/*.parquet` e `data/processed/analytical/orders_analysis.parquet`. Mostra as contagens e confere as colunas e tipos sem se conectar ao banco.

Se preferir o ZIP, substitua `data/processed` pelo caminho entre aspas:

```powershell
.\.venv\Scripts\python.exe src/import_olist.py --input "C:\caminho\olist_cleaning_output.zip" --check-only
```

Após a pré-verificação, importe removendo `--check-only`:

```powershell
.\.venv\Scripts\python.exe src/import_olist.py --input data/processed
```

Digite a senha do usuário `postgres` quando for solicitada. Ela não aparece na tela. Não coloque a senha nos scripts.

Os padrões são `localhost`, porta `5432`, banco `olist_analytics`, usuário `postgres`. Se você escolheu outros valores na instalação, informe-os:

```powershell
.\.venv\Scripts\python.exe src/import_olist.py --input data/processed --port 5433 --user seu_usuario
```

A importação preserva textos, comentários, ausentes, datas, CEPs e centavos. A geolocalização tem muitas linhas; aguarde o terminal terminar. As mensagens de cada tabela ainda se referem à transação em andamento. A confirmação definitiva é:

```text
IMPORTAÇÃO CONFIRMADA. Contagens e referência Python/SQL conferidas.
```

Se uma restrição ou a comparação Python/SQL falhar, a transação é desfeita. Se as tabelas já contiverem dados, o programa recusa uma nova carga em vez de duplicar ou apagar registros. Nenhum script contém `DROP TABLE` ou `TRUNCATE`.

## 6. Veja os dados no pgAdmin

Volte ao Query Tool de `olist_analytics` e execute:

```sql
SELECT *
FROM olist.v_orders_analysis
ORDER BY order_id
LIMIT 10;
```

Execute também:

```sql
SELECT
    (SELECT count(*) FROM olist.orders) AS pedidos_tabela,
    (SELECT count(*) FROM olist.v_orders_analysis) AS pedidos_view,
    (SELECT count(*) FROM olist.reference_orders) AS pedidos_python,
    (SELECT count(*) FROM olist.v_reconciliation_detail) AS campos_divergentes;
```

As três contagens de pedidos precisam ser iguais e maiores que zero; `campos_divergentes` deve ser zero. Os números definitivos vêm da sua execução, não de um valor fixo gravado no script.

Abra `04_quality_checks.sql` e execute uma consulta de cada vez, selecionando do `SELECT` até o ponto e vírgula. Você verá também pendências que foram preservadas na limpeza, como prazos extremos e dados ausentes.

## 7. Faça as análises de negócio

Abra `05_business_queries.sql`. Cada bloco tem uma pergunta e comentários sobre o denominador. Execute um bloco de cada vez.

A primeira análise financeira usa somente pedidos elegíveis de vendas entregues. Compare-a com a tabela do notebook de EDA. Confira valor de mercadorias, quantidade de pedidos, consumidores e ticket. Valores em centavos são convertidos para reais somente na apresentação.

Em seguida, examine a evolução mensal, os atrasos por estado e as notas por situação de entrega. Os filtros de 100 pedidos por UF e 20 por grupo na comparação dentro da UF são os mesmos da EDA original. Se você os alterou no notebook, ajuste também o SQL e documente a mudança.

Use a opção de salvar os resultados em CSV no painel **Data Output**. Guarde os resultados agregados em `reports/sql/`, com nomes como `vendas_mensais.csv` e `atraso_avaliacoes.csv`.

## 8. O que publicar e quando encerrar a etapa

Publique os cinco SQLs, o importador, seu contrato JSON, as dependências e a documentação. Acrescente ao README geral um link para este guia e informe que esta etapa está concluída somente após a execução real e a reconciliação.

O relatório `reports/sql/importacao_*.json` registra contagens, hashes e versões sem senha. Ele pode acompanhar o portfólio. Dados individuais e os arquivos do servidor PostgreSQL não precisam entrar no Git.

Critérios para seguir ao dashboard:

- Importação confirmada sem erros.
- Uma linha por pedido na view.
- Zero divergências nos campos comparados com a base Python.
- Consultas de negócio executadas e resultados conferidos com a EDA.
- Limitações e pendências documentadas.

As views de indicadores servirão como fonte para o Power BI. A tabela de referência Python é um controle de qualidade, não a fonte do dashboard.

## Problemas comuns

| Mensagem / situação | Como agir |
|---|---|
| `relation ... does not exist` | Confira o banco e execute os arquivos 01, 02 e 03 na ordem |
| `password authentication failed` | Use a senha do usuário PostgreSQL, não a senha de desbloqueio do pgAdmin |
| `connection refused` | Confira servidor em execução, host e porta usados no pgAdmin |
| `py` não reconhecido | Instale o Python ou use `python` se esse for seu comando disponível |
| Arquivo Parquet ausente | Use o ZIP da limpeza, não o ZIP da EDA, ou corrija `--input` |
| Tabela já contém dados | Se a primeira carga foi concluída, siga para as consultas; não repita a importação |
| Divergência Python/SQL | Garanta que todos os arquivos pertencem à mesma execução da limpeza; não force a carga |
| Nenhuma pasta `olist` no painel | Atualize **Schemas** com **Refresh** |

## Referências técnicas

- [Criar bancos no pgAdmin](https://www.pgadmin.org/docs/pgadmin4/latest/database_dialog.html)
- [Query Tool e exportação dos resultados](https://www.pgadmin.org/docs/pgadmin4/latest/query_tool.html)
- [Instalação do Psycopg](https://www.psycopg.org/psycopg3/docs/basic/install.html)
- [COPY pelo cliente Python](https://www.psycopg.org/psycopg3/docs/basic/copy.html)
