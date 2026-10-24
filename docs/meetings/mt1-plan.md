# Plano de ação após a reunião 1

Este documento transforma as anotações de `mt1.md` em um plano de escrita e de experimentos. O
objetivo principal é produzir evidências reproduzíveis para o TCC sem ampliar o escopo principal do
Sanxing além do que já está implementado.

## 1. Decisões de escopo antes da escrita

1. Manter como contribuição principal o motor serial em Odin, com força bruta, Barnes-Hut,
   Euler semi-implícito, entrada JSON e visualização local 2D por replay JSONL.
2. Tratar paralelismo como uma prova de conceito opcional e isolada. Ele não deve alterar os
   resultados de referência do motor serial nem ser apresentado como uma funcionalidade concluída.
3. Comparar força bruta e Barnes-Hut dentro do Sanxing como experimento principal, porque essa
   comparação — chamada de “nós contra nós” nas anotações da reunião — controla linguagem,
   integrador, dados de entrada e máquina. Para cada configuração, executar primeiro a força bruta e
   depois o Barnes-Hut sobre o mesmo cenário determinístico.
4. Só comparar com uma ferramenta externa se for possível executar o mesmo problema, com as mesmas
   condições iniciais, número de passos, passo de tempo e política de saída. Caso contrário, usar a
   ferramenta apenas em uma comparação qualitativa de funcionalidades e esforço de uso.
5. Não usar divergência tardia de trajetória como medida direta do erro do Barnes-Hut. O erro da
   aproximação deve ser medido nas acelerações antes da integração.

## 2. Plano de escrita do TCC

### Revisão dos objetivos

Reescrever o objetivo geral para refletir o resultado real: desenvolver e avaliar um motor 2D de
simulação de N corpos, modular e reproduzível, comparando o método direto com Barnes-Hut.

Objetivos específicos sugeridos:

- implementar um modelo gravitacional de N corpos com força bruta como referência;
- implementar Barnes-Hut com quadtree e limiar de abertura configurável;
- separar motor, exportação e visualização;
- avaliar desempenho, trabalho computacional e erro de aproximação;
- avaliar o comportamento do integrador por refinamento do passo de tempo;
- disponibilizar uma interface local 2D para inspeção dos resultados;
- explorar paralelismo apenas como trabalho adicional, se a prova de conceito for concluída.

Remover dos objetivos alcançados as afirmações sobre CSV, edição gráfica, execução distribuída,
visualização 3D, integração ao vivo e aplicação web pronta. Esses itens podem aparecer em trabalhos
futuros.

### Capítulo 4 — Desenvolvimento

Organizar o capítulo em uma sequência que explique decisões, não apenas arquivos:

1. **Linguagem Odin:** motivo da escolha, compilação nativa, modelo simples de dados e adequação a
   software de sistemas. Evitar afirmar que Odin é mais rápido sem evidência experimental.
2. **Arquitetura:** motor headless, pacotes internos, entrada JSON, saída JSONL e independência dos
   visualizadores.
3. **Modelo físico:** estado dos corpos, gravitação com softening e unidades consistentes.
4. **Método direto:** equação, referência de exatidão e custo quadrático.
5. **Quadtree e Barnes-Hut:** construção, centro de massa, critério de abertura, folhas degeneradas e
   custo esperado.
6. **Integração:** Euler semi-implícito, ordem das atualizações e limitações numéricas.
7. **Reprodutibilidade:** cenários determinísticos, testes, manifesto do experimento e separação entre
   medição e exportação.
8. **Visualização:** replay local 2D, controles e inspeção; deixar claro que o visualizador não contém
   física.

### Capítulo 5 — Resultados

Separar os resultados em perguntas de pesquisa:

1. O Barnes-Hut reduz o tempo e o número de interações conforme `N` cresce?
2. Como `theta` altera desempenho, trabalho e erro instantâneo de aceleração?
3. O erro do integrador diminui quando o passo de tempo é refinado?
4. Energia e momento apresentam comportamento compatível com as limitações do método?
5. Pequenas perturbações geram separação observável no problema de três corpos e quanto dessa
   observação depende do passo de tempo?
6. A interface permite reproduzir e inspecionar os resultados exportados?
7. Se executada: qual ganho e qual custo de engenharia aparecem na prova de conceito paralela?
8. Se válida: como o Sanxing se compara a uma implementação externa equivalente?

Para cada subseção, apresentar nesta ordem: pergunta, protocolo, tabela ou figura, observação dos
dados, interpretação e ameaça à validade. Não escrever conclusões numéricas antes da execução do
pacote definitivo.

### Capítulo 6 — Conclusões

Responder diretamente aos objetivos revisados. Sintetizar:

- o que foi implementado e verificado;
- em quais faixas de `N` e `theta` Barnes-Hut foi vantajoso;
- o custo de precisão associado ao ganho, com base no erro de aceleração;
- as limitações de Euler semi-implícito, da execução 2D e da máquina de teste;
- as limitações da comparação externa e do POC paralelo, caso existam;
- trabalhos futuros: outros integradores, paralelismo robusto, distribuição, configuração gráfica,
  visualizador web e 3D.

## 3. Regras gerais de medição

Estas regras devem ser declaradas antes de executar os experimentos:

- usar uma revisão Git limpa e registrar o hash do commit;
- registrar sistema operacional, processador, memória, versão do Odin, modo de otimização e comandos;
- executar todas as configurações principais na mesma máquina, sem outras cargas pesadas;
- usar as mesmas condições iniciais determinísticas em configurações comparadas;
- fazer aquecimentos não medidos antes das amostras;
- medir apenas cálculo do solver e integração no ensaio de desempenho, excluindo exportação e
  instrumentação de contadores;
- coletar 10 amostras independentes por configuração e publicar média, desvio-padrão, mínimo e
  máximo; conservar também os dados brutos;
- não escolher apenas a melhor execução;
- randomizar ou alternar a ordem das configurações em um estudo externo/paralelo para reduzir viés
  térmico e de ordem; documentar a ordem usada;
- validar a correção antes de comparar velocidade;
- tratar resultados da árvore de trabalho atual como piloto, não como resultado final;
- guardar manifesto, JSONL, CSV, figuras e relatório no mesmo pacote de resultados.

O script `tools/run_thesis_experiments.sh` já aplica grande parte dessas regras e deve ser o caminho
canônico para a matriz principal.

## 4. Experimentos principais

### E1 — Desempenho e escalabilidade interna

**Hipótese:** Barnes-Hut passa a superar força bruta a partir de determinado tamanho de problema, e
o ganho depende de `theta`.

Este é o experimento “nós contra nós” solicitado na reunião. Para cada quantidade de corpos, executar
primeiro o solver de força bruta para estabelecer o baseline e depois executar Barnes-Hut para cada
valor de `theta`. Todas as execuções devem partir das mesmas condições iniciais. A execução sequencial
dos solvers define a ordem do protocolo; ela não significa que um solver aproveita o estado final do
outro.

| Fator | Valores |
|---|---|
| Cenário | `scaling_golden_angle_v1` |
| Corpos | 100, 500, 1.000, 5.000, 10.000 |
| Solvers | força bruta; Barnes-Hut |
| Theta de Barnes-Hut | 0,25; 0,5; 1,0 |
| Carga por amostra | 10 passos |
| Repetições | 2 aquecimentos + 10 amostras medidas |
| Compilação | `-o:speed` |

Medir tempo total, tempo médio por passo, desvio-padrão, speedup contra força bruta, contribuições
diretas e aproximadas, visitas a nós e interações por segundo. O resultado principal é a curva de
tempo por `N`; speedup e contadores explicam a curva.

### E2 — Erro da aproximação Barnes-Hut

**Hipótese:** aumentar `theta` reduz trabalho computacional, mas aumenta o erro de aceleração.

Usar os mesmos tamanhos de E1 e `theta = 0; 0,25; 0,5; 1,0`. Comparar as acelerações Barnes-Hut com
força bruta no estado inicial, sem integrar. Medir erro L2 normalizado, erro vetorial absoluto médio e
erro vetorial absoluto máximo. `theta = 0` é o controle exato e deve permanecer abaixo de `1e-12` no
erro L2 normalizado.

Cruzar E1 e E2 em uma tabela de compromisso: para cada `N` e `theta`, mostrar speedup e erro. Não
selecionar um “melhor theta” universal; indicar a faixa observada e o critério adotado.

### E3 — Validade numérica do integrador

**Hipótese:** os erros de posição e energia diminuem com o refinamento do passo.

Executar a órbita circular de dois corpos por um período com 100, 200 e 400 passos. Comparar posição
final com a posição inicial e medir deriva relativa de energia e deriva do momento linear. Relatar a
razão de redução de erro ao dobrar o número de passos, sem prometer uma ordem de convergência que os
dados não sustentem.

### E4 — Sensibilidade de trajetória

Executar o cenário de Burrau suavizado com massas 3, 4 e 5 até o tempo simulado 20, comparando o
estado-base com uma perturbação de `1e-10` na coordenada x do corpo de massa 3. Repetir com passos
`0,001` e `0,0005`.

Apresentar a separação entre trajetórias ao longo do tempo e comparar as duas discretizações. Tratar
o resultado como sensibilidade observada; não como solução exata, sistema sem softening ou cálculo
de expoente de Lyapunov.

### E5 — Interface de visualização

Este é um resultado funcional, não um benchmark de renderização. Demonstrar com capturas da mesma
execução:

- visão completa da trajetória;
- seleção de um corpo e painel de estado;
- linha do tempo em dois instantes;
- controles de reprodução, velocidade, trilhas e rótulos.

Associar cada captura a um arquivo JSONL reproduzível. Relatar que a interface consome dados
exportados e não recalcula a simulação.

## 5. Comparação com outra ferramenta ou implementação

Fazer esta etapa somente depois de E1–E4. Primeiro escolher uma implementação que permita controlar
o algoritmo e os parâmetros. A ordem de preferência é:

1. outra implementação aberta do mesmo método direto ou Barnes-Hut;
2. biblioteca de N corpos configurável com o mesmo integrador e softening;
3. ferramenta com modelo diferente, usada apenas para comparação qualitativa.

Antes de medir, preencher uma ficha de equivalência:

| Item | Sanxing | Comparador | Equivalente? |
|---|---|---|---|
| Dimensão | 2D | | |
| Condições iniciais | mesmo arquivo/cenário | | |
| Solver | direto ou Barnes-Hut | | |
| Critério de abertura | | | |
| Integrador | Euler semi-implícito | | |
| Passo e número de passos | | | |
| Constante gravitacional e softening | | | |
| Precisão numérica | `f64` | | |
| Exportação dentro da medição | não | | |
| Paralelismo | desativado no baseline | | |

Se algum item essencial não for equivalente, não calcular um speedup como se as ferramentas
executassem o mesmo trabalho. Nesse caso, comparar arquitetura, facilidade de configuração,
formatos, recursos e limitações.

### Medida de esforço

“Esforço” precisa de uma definição observável. Para o desenvolvimento já realizado, usar métricas
reprodutíveis e reconhecer suas limitações:

- linhas de código por componente, excluindo arquivos gerados e dados;
- número de módulos e testes;
- dependências externas;
- quantidade de passos e comandos para configurar e repetir um experimento;
- tamanho e complexidade da adaptação necessária para importar o mesmo cenário.

Horas retroativas e quantidade de commits não devem ser usadas como medida principal: não são uma
medida confiável de complexidade. Para trabalho novo, registrar prospectivamente data, tarefa,
tempo aproximado, bloqueios e resultado em um diário simples.

## 6. POC de paralelismo

Esta etapa exige confirmação do orientador porque o protocolo canônico atual é serial. Se aprovada,
manter o código atrás de uma opção experimental e começar pela força bruta, cuja decomposição por
corpo-alvo é simples e não muda a equação física.

Plano mínimo:

1. dividir os corpos-alvo em faixas independentes; cada trabalhador escreve apenas nas acelerações
   de sua própria faixa;
2. manter um caminho serial de referência e comparar as acelerações antes de medir tempo;
3. testar 1, 2, 4 e, se houver suporte físico, 8 trabalhadores;
4. usar os mesmos `N`, passos, warmups e repetições de E1;
5. registrar speedup `T1/Tp`, eficiência `speedup/p` e variabilidade;
6. discutir overhead, largura de memória, número de núcleos físicos e ponto de saturação;
7. não misturar o ganho do paralelismo com o ganho algorítmico de Barnes-Hut na primeira POC.

O POC de paralelismo é complementar ao experimento “nós contra nós”. Primeiro deve ser produzida a
comparação serial entre força bruta e Barnes-Hut. Se o POC for executado, seus resultados devem ficar
em uma subseção separada, evitando atribuir ao algoritmo um ganho causado pelo paralelismo.

## 7. Ordem de execução

1. Confirmar com o orientador o escopo do POC paralelo e qual implementação externa será comparada;
   a comparação “nós contra nós” já está definida como força bruta seguida de Barnes-Hut.
2. Atualizar objetivos, hipótese e metodologia para o escopo aceito.
3. Executar todos os testes e um pacote piloto pequeno; corrigir anomalias sem alterar o protocolo
   depois de observar resultados convenientes.
4. Criar um commit limpo e executar o pacote canônico E1–E4.
5. Revisar dados brutos, alertas, tabelas e gráficos antes de redigir interpretações.
6. Produzir as capturas reproduzíveis de E5.
7. Executar a comparação externa somente após validar a ficha de equivalência.
8. Implementar e medir o POC paralelo somente se ele tiver sido mantido no escopo.
9. Escrever o capítulo 5 a partir das evidências e então fechar o capítulo 6.
10. Fazer uma revisão final procurando afirmações não sustentadas e itens antigos de escopo.

## 8. Critério de conclusão

O trabalho experimental está pronto para entrar no TCC quando:

- o pacote principal possui manifesto completo e status `complete`;
- todas as configurações esperadas aparecem uma única vez nos resumos;
- dados brutos, tabelas e figuras podem ser ligados ao mesmo `run_id` e commit;
- o controle `theta = 0` passa pelo limite definido;
- nenhuma falha ou anomalia foi omitida;
- conclusões distinguem desempenho, erro do solver, erro do integrador e sensibilidade;
- comparações externas deixam explícitas todas as diferenças de configuração;
- capturas da interface são ligadas a um replay reproduzível;
- objetivos, resultados e conclusão descrevem o mesmo escopo implementado.
