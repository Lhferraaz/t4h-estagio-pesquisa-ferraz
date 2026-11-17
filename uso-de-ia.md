# Registro de uso de IA

Registro de trabalho para apoiar a seção **9. Uso de IA** do artigo. O enunciado pede que essa seção diga, em 2 a 3 linhas, onde a IA foi usada e como suas contribuições foram verificadas. Este arquivo registra as interações enquanto acontecem; não substitui a seção do artigo.

## 17/11/2026 — Configuração do trabalho

- **Pedido:** configurar instruções para os agentes e uma skill para o ciclo de medição; trabalhar em uma branch por mudança, com pull request e merge em `main`.
- **Contribuição da IA:** leu o repositório novo e redigiu a seção de colaboração do `AGENTS.md` e a skill `ciclo` para Codex e Claude Code. O setup foi registrado no commit `0854c59`, enviado após pedido da pessoa.
- **Verificação feita:** as duas skills passaram na validação de formato; o diff foi conferido e o repositório ficou limpo após o push. Nenhuma mudança de performance foi feita nessa etapa.

## 17/11/2026 — Leitura inicial do código

- **Pedido:** explicar o funcionamento da aplicação e começar este registro.
- **Contribuição da IA:** descreveu o caminho da requisição pelo Express, pelas rotas e pela função de consulta ao PostgreSQL. Apontou aspectos do código para investigar, como a criação de uma conexão por consulta em `api/src/db.js`, as consultas dentro de loops em `api/src/rotas.js`, a agregação de vendas no JavaScript e o registro do corpo das respostas em `api/src/server.js`.
- **Verificação feita:** a descrição foi conferida diretamente nos arquivos citados. Essas observações são leitura do código, não diagnóstico medido. O contrato ainda não foi gravado, a linha de base ainda não foi medida e nenhuma hipótese de melhoria foi testada.
