# Olist · Síntese da análise exploratória

## Resultados desta execução

A base tem **99.441 pedidos**. O recorte de entregas com nota cobre **95,0%** da base; as conclusões sobre satisfação se referem a esse grupo.
Nos **96.478** pedidos elegíveis de vendas entregues, o valor de mercadorias é 13.221.498,11 reais, com ticket médio de 137,04 reais sem frete.
O maior volume observado no recorte ocorreu em **2017-11**, com **7.289 pedidos**. O gráfico descreve a janela disponível; não demonstra uma tendência sustentável nem uma causa para o pico.
A mediana de entrega foi de **10,3 dias**, e o percentil 90 de **23,2 dias**. **6,8%** dos pedidos elegíveis chegaram após o dia previsto.
Entre as UFs que atendem ao mínimo de volume, **AL** tem a maior taxa observada: **21,1%**, em **393 pedidos**. Esse resultado orienta investigação, não uma conclusão causal sobre a região.
A proporção de notas 1–2 é **62,5% nos atrasados** e **9,3% nos pedidos no prazo**. Nos atrasados ela é maior; diferença absoluta de **53,2 pontos percentuais**. A comparação é descritiva e não isola o efeito do atraso.
A verificação de avaliações após a entrega mantém **89.822 de 94.458 pedidos com nota**. Compare a direção e a magnitude da diferença com a análise principal antes de concluir.

## Limitações

Análise histórica e descritiva. Recortes distintos por indicador; ausência de nota pode ser seletiva.
Bordas mensais e pedidos ainda não entregues podem afetar a evolução. Associação não demonstra causalidade.
Valor de mercadorias não representa lucro ou receita líquida. A comparação por UF não controla todos os fatores.

## Próximas ações

Validar em SQL os indicadores por pedido e montar um dashboard com definições consistentes.
Investigar vendedores e categorias nos grupos sinalizados, sem multiplicar valores nas junções.