---
name: ciclo
description: Conduzir a linha de base ou o ciclo de uma mudança de performance neste desafio, incluindo contrato, três medições e comparação. Use quando a pessoa pedir para iniciar a linha de base, aplicar e medir uma mudança, ou comparar seus resultados.
---

# Ciclo de medição

Leia `AGENTS.md` e o estado do repositório antes de agir. Explique cada comando relevante antes de executá-lo e examine sua saída com a pessoa. Ajude a desenvolver a hipótese, a previsão e o critério de avaliação; registre-os antes da mudança, sem inventar autoria ou fonte.

## Linha de base

Com a aplicação original e a árvore limpa, suba o Compose, confira `/saude`, grave o contrato uma única vez e commite `contrato/base.json`. Faça pelo menos três medições com o mesmo rótulo, `VUS`, `DURACAO` e `SEMENTE`. Dê pelo menos três minutos de timeout a cada medição. Confira os arquivos gerados e commite as pastas de `resultados/` em separado. Não altere a régua.

## Uma mudança

1. Confira qual hipótese e previsão a pessoa quer testar. Identifique a única alteração e registre a previsão antes de ver o resultado.
2. Faça e commite somente essa alteração. Confira que a árvore, excluindo resultados anteriores já commitados, está limpa.
3. Aplique a mudança conforme `AGENTS.md`: reconstrução para API, Dockerfile ou Compose; recriação do banco para `.sql` novo. Confira que a aplicação e, se houver, o SQL ou parâmetro novo estão ativos.
4. Rode o verificador de contrato. Se houver quebra, corrija ou desfaça antes de medir.
5. Meça pelo menos três vezes com os mesmos parâmetros e rótulo. Evite outras tarefas pesadas durante a carga. Em cada execução, confira `contexto.txt` e `contrato.txt`; não edite os resultados.
6. Compare a mediana das execuções com a linha de base usando os arquivos de `resultados/`. Mostre o resultado geral, a variação entre execuções e o custo de CPU e memória. Não apresente diagnóstico sem salvar sua saída no repositório.
7. Commite somente as pastas novas de `resultados/` num commit separado. Registre o que a medição sustenta, o que permanece incerto e as contribuições reais da pessoa e da IA.

Não imponha uma solução ou conclusão porque ela parece promissora. Se faltarem dados para decidir, diga o que falta e continue a investigação possível.
