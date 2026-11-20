# Contadores do teste de paralelismo

Os arquivos reúnem a configuração efetiva do PostgreSQL, a lista de índices, o contrato inicial, as amostras do navegador e os contadores coletados. Consultamos `pg_stat_database` para o banco `loja` e lemos `cpu.stat` e `memory.events` nos dois contêineres antes e depois de cada chamada de `scripts/medir.sh`. Essa janela inclui o aquecimento, a carga e a checagem de contrato.

O contador `temp_bytes` é cumulativo e contabiliza arquivos temporários de consultas do banco inteiro. As diferenças mostram o volume escrito em temporários entre as capturas. A métrica não quantifica escrita física no armazenamento nem atribui bytes a uma rota. [Definição do PostgreSQL 16](https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-DATABASE-VIEW)

| Mediana por rodada | Dois workers | Zero workers |
| --- | ---: | ---: |
| Arquivos temporários | 29 | 324 |
| Bytes em temporários | 245.465.088 | 2.626.828.980 |

Nos três intervalos somados, o PostgreSQL atingiu a cota em 2.377 de 2.441 períodos ativos com dois workers e em 2.302 de 2.503 com zero. A API teve 15 de 2.020 e 17 de 1.994, respectivamente. Contamos zero encerramentos por falta de memória nas duas séries. Os períodos contabilizam quando a cota foi atingida em cada janela do escalonador. [Dois workers](dois-workers.txt) · [Zero workers](zero-workers.txt) · [Resultados HTTP e rodadas](../../experimentos.md#resultado-da-h13)
