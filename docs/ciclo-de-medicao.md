# Ciclo de medição

Use as [regras do repositório](../AGENTS.md) e os [comandos do README](../README.md#como-medir). O [registro de decisões](decisoes.md) indica o que já entrou na `main` e onde encontrar a evidência.

## Preparar a comparação

1. Confira a branch, o commit, os arquivos locais e os PRs que afetam a hipótese. Identifique o ambiente Compose que está rodando. Ao retomar um teste, confira quais mudanças foram aplicadas dentro dos containers.
2. Se o contrato e a linha de base já estiverem registrados, use-os. Na primeira montagem do projeto, grave o contrato da aplicação original e faça pelo menos três rodadas da linha de base conforme o README.
3. Escolha a versão de referência imediata, já medida e com as mesmas mudanças anteriores. Encontre as três pastas correspondentes e confira os commits, parâmetros e limites em `contexto.txt`. A linha de base original mostra o ganho acumulado. Se a referência imediata estiver indisponível ou as condições forem incompatíveis, meça o estado de referência de novo.
4. No registro de [experimentos](../experimentos.md), anote a mudança, a evidência, a hipótese e a previsão antes de alterar o código ou o banco. Indique de quem foi a decisão e o que faria a hipótese ganhar ou perder força. Para um teste ainda futuro, use [próximos testes](../proximos-testes.md).

## Aplicar e medir

1. Parta da `main` atualizada para uma mudança nova. Faça um commit para a hipótese e outro para a alteração que será medida. Confira que a árvore está limpa antes da carga.
2. Ao usar `COMPOSE_PROJECT_NAME`, mantenha o mesmo nome nos comandos da aplicação, no verificador e no `medir.sh`. Se houver um `.sql` novo, ele precisa de um banco inicializado do zero. Para preservar um volume anterior, use um projeto Compose separado. Confira os containers e as portas antes de pausar serviços ou reinicializar um banco de teste.
3. Explique o que o comando vai fazer antes de alterar o ambiente. Confira `/saude`, a mudança ativa no container e `scripts/verificar-contrato.sh comparar`. Prossiga quando o comando terminar em `Contrato mantido`.
4. Rode pelo menos três medições, uma por vez, com o mesmo rótulo e pelo menos três minutos de timeout por execução. Os parâmetros do teste atual são `VUS=20`, `DURACAO=60s`, `AQUECIMENTO=15s` e `SEMENTE=42`. Use os mesmos parâmetros e condições do teste de referência.
5. Registre diferenças relevantes na máquina, como um navegador aberto durante a carga. O `medir.sh` registra os parâmetros da carga. Se uma condição afetar a comparação, repita a série afetada e indique quais rodadas sustentam o resultado.
6. Confira `contexto.txt` e `contrato.txt` de cada rodada. Confirme o commit medido e `arquivos alterados sem commit: 0`. Preserve os arquivos gerados.

## Ler e registrar

- Leia `resumo.txt` e `recursos.txt`. Compare a mediana das três ou mais rodadas para req/s, p50 e p95 gerais, erros, CPU e memória. Para memória, observe também o maior pico amostrado e o limite. Use a rota afetada como evidência adicional e indique quando suas amostras forem poucas.
- Mostre a variação entre rodadas e o custo associado, como o espaço de um índice ou o consumo de um serviço adicional. Com usuários virtuais fixos, mais req/s com CPU parecida significa mais vazão com uso parecido nesse teste. Medir economia de CPU a uma taxa de chegada fixa exige outra comparação.
- Salve o plano e outras saídas de diagnóstico em `diagnostico/` antes de citá-los. O plano mostra o trabalho da consulta no banco. A medição HTTP mostra o efeito na aplicação sob carga.
- Commite as novas pastas de resultados separadamente. Atualize `experimentos.md` com as fontes e a conclusão e `uso-de-ia.md` com as contribuições verificáveis. O PR deve apontar para os resultados. Atualize [decisões](decisoes.md) quando a pessoa autora escolher integrar, adiar ou descartar uma proposta.
- Se um experimento ficar em andamento, deixe no PR ou no registro a branch e o commit, o projeto Compose, a última etapa conferida e o que falta fazer.
