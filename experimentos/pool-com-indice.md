# Pool de conexões com o índice de pedidos por cliente

## Hipótese antes da combinação

- **Pedido da pessoa.** Testar juntos a busca em lote, o índice em `pedidos(cliente_id)` e o pool previamente testado com 10 conexões. A pessoa pediu para reconferir a vazão da linha de base original.
- **Hipótese de trabalho.** O índice reduz o trabalho de localizar pedidos. O `pg.Pool` reutiliza conexões e limita a 10 as consultas concorrentes por processo. A combinação pode processar mais requisições ou reduzir o p95 geral em relação à versão com lote e índice. A latência mediana e a memória da API podem subir, como no teste isolado do pool.
- **Como medir.** Manter a implementação do pool de 10 conexões e o banco com o índice já aplicado. Validar o contrato e medir três vezes com 20 usuários virtuais, 60 s, aquecimento de 15 s e semente 42. Usar a H3 (lote e índice) como comparação direta e manter as variantes anteriores para contextualizar os ganhos.
