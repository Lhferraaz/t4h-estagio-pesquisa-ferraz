# Redistribuição da cota de CPU

A referência usou 1 CPU no banco e 0,5 CPU na API. A variante usou 1,25 CPU no banco e 0,25 CPU na API. As duas séries usaram 128 MiB na API, 512 MiB no banco e o pool de dez conexões. Os bancos foram criados em volumes novos. [Resultados e rodadas](../../experimentos.md#resultado-da-h12) · [Ambiente](ambiente.txt)

Os arquivos de cgroup incluem `cpu.max`, `cpu.stat`, o limite de memória, os eventos de memória e o estado dos contêineres. As leituras de cada rodada foram imediatamente antes e depois de `scripts/medir.sh`. A janela inclui aquecimento, carga e verificação do contrato. Um período com restrição indica que a cota foi atingida naquela janela do escalonador. O contador de períodos não mede proporção do tempo de parede em espera. [Contadores da H10](14-h10-referencia-cpu-cgroup.txt) · [Contadores da H12](15-redistribuir-cpu-cgroup.txt) · [Diferenças por rodada](deltas.txt) · [Controle de recursos do Linux](https://docs.kernel.org/admin-guide/cgroup-v2.html)

## Repetir a coleta

Suba a versão a medir, confira o contrato e salve a saída de `docker compose exec -T banco cat /sys/fs/cgroup/cpu.stat`. Repita para `api`. Execute o script de medição com 20 usuários virtuais, 60 s de carga, 15 s de aquecimento e semente 42. Repita as leituras ao final e confira `cpu.max` para confirmar as cotas. Subtraia os contadores iniciais dos finais de cada contêiner.
