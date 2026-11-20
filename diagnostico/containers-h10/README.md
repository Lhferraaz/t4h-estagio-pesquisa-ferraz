# Diagnóstico dos contêineres na H10

A coleta usou a `main` no commit `f61f1b2`, um banco novo e o Compose do projeto. A API manteve 128 MiB e o pool de dez conexões. Usamos a carga de 20 usuários virtuais por 60 s com semente 42, após 15 s de aquecimento com cinco usuários e semente 43. O Chrome e o Chromium estavam ausentes nas verificações do início e do fim. As 42 respostas do contrato passaram antes e depois. [Ambiente](ambiente.txt) · [Contrato antes](contrato-antes.txt) · [Contrato depois](contrato-depois.txt)

## Limites e atividade sob carga

| Serviço | Limite de CPU | Limite de memória | Períodos ativos de CPU | Períodos com restrição |
| --- | ---: | ---: | ---: | ---: |
| API | 0,5 CPU | 128 MiB | 527 | 0 |
| PostgreSQL | 1 CPU | 512 MiB | 632 | 627 |

Um período com restrição indica que a cota foi atingida naquele período. Os valores não representam a fração do tempo de parede em espera. Em uma amostra pontual, o PostgreSQL tinha cinco workers paralelos. A API usou cerca de 2,4 segundos de CPU entre as capturas, e o banco, cerca de 62,8 segundos. [Contadores do cgroup](cgroups.txt) · [Amostra de processos](processos-amostra.txt)

O `memory.current` do banco chegou a 536.858.624 bytes, perto dos 512 MiB configurados, e houve 4.682 eventos adicionais de aproximação ao limite máximo. A API chegou a 31.014.912 bytes nas amostras e registrou zero eventos de limite máximo. Nenhum dos dois contêineres registrou encerramentos por falta de memória. O PostgreSQL já tinha swap em uso após o aquecimento. O uso de `/dev/shm` foi de 24% em uma amostra durante a carga. O limite de `/dev/shm` cobre aquele sistema de arquivos, enquanto o cgroup contabiliza outras parcelas, incluindo memória compartilhada e cache de arquivos. [CPU e memória do cgroup](cgroups.txt) · [Amostra de /dev/shm](shm-amostra.txt) · [Contadores de memória do Linux](https://docs.kernel.org/admin-guide/cgroup-v2.html#memory-interface-files)

O PostgreSQL registrou 21 arquivos temporários e 115.425.280 bytes de temporários entre as capturas. Ele está com `shared_buffers` em 128 MiB, `work_mem` em 4 MiB e até dois workers por consulta paralela. O ranking usou temporários nas execuções isoladas com zero e um worker. Os planos foram rodados fora da carga e em sequência. As comparações de tempo estão sujeitas ao cache e à ordem das consultas. [Configuração do PostgreSQL](postgres.txt) · [Contadores antes](estatisticas-antes.tsv) · [Contadores depois](estatisticas-depois.tsv) · [Planos com dois e zero workers](planos.txt) · [Planos com dois e um worker](planos-um-worker.txt) · [Uso de recursos no PostgreSQL 16](https://www.postgresql.org/docs/16/runtime-config-resource.html)

A API enviou 1.640.101 bytes aos logs na janela de diagnóstico. Os dois contêineres usaram `json-file` sem opções de rotação na configuração efetiva inspecionada. [Volume emitido](volume-log-api.txt) · [Configuração efetiva dos logs](ambiente.txt) · [Driver de logs do Docker](https://docs.docker.com/engine/logging/drivers/json-file/)

## Próximos testes

1. Redistribuir o teto de CPU para 1,25 no banco e 0,25 na API, mantendo 1,5 CPU de teto somado. Medir vazão, p50, p95, p99 e restrição de CPU nos dois serviços.
2. Avaliar um worker por consulta separadamente. Os planos mostram menos processos por consulta e temporários no ranking, por isso o efeito precisa ser medido com a mistura completa de rotas.
3. Avaliar rotação de logs para limitar uso de disco. A redução dos campos registrados pela API seria outra mudança.
