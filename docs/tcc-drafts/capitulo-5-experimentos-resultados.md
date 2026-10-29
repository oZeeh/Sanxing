# 5. Experimentos e resultados

Este capítulo apresenta a avaliação experimental do Sanxing. O objetivo não consiste apenas em
verificar se o programa termina uma execução, mas em examinar separadamente quatro propriedades da
engine: o custo computacional dos *solvers* gravitacionais, o erro introduzido pela aproximação de
Barnes-Hut, o comportamento do integrador numérico e a sensibilidade de uma configuração de três
corpos. Essa separação é necessária porque uma simulação pode ser rápida e pouco precisa, ou pode
calcular corretamente as forças instantâneas e ainda acumular erro durante a evolução temporal.

Os experimentos foram organizados para responder às seguintes perguntas:

1. em que escala o método de Barnes-Hut se torna mais rápido que o cálculo direto por força bruta;
2. quanto erro de aceleração é introduzido quando Barnes-Hut aproxima grupos de corpos;
3. se a redução do passo de tempo melhora o resultado produzido pelo método de Euler
   semi-implícito; e
4. como uma pequena alteração nas condições iniciais evolui em uma configuração de três corpos e
   quanto essa observação depende do passo de tempo adotado.

Não se utiliza a divergência entre duas trajetórias como medida direta do erro de Barnes-Hut. O erro
do *solver* é avaliado antes da integração, por meio da comparação das acelerações calculadas sobre o
mesmo estado. A integração temporal e a sensibilidade das trajetórias são avaliadas em experimentos
próprios.

## 5.1. Conceitos necessários à interpretação

### 5.1.1. O problema de N corpos

No problema gravitacional de N corpos, deseja-se determinar como um conjunto de corpos se movimenta
devido à atração gravitacional mútua. Cada corpo possui massa, posição e velocidade. A cada instante,
a posição dos demais corpos determina a aceleração que atua sobre ele. Essa aceleração modifica sua
velocidade, e a velocidade, por sua vez, modifica sua posição.

Para dois corpos, algumas condições particulares admitem soluções analíticas conhecidas, como a
órbita circular utilizada neste trabalho. Entretanto, à medida que mais corpos são introduzidos, a
evolução geral do sistema deixa de possuir uma expressão fechada simples. A solução passa a ser
obtida numericamente: o tempo é dividido em pequenos intervalos e o estado do sistema é atualizado
repetidamente.

No Sanxing, o modelo é bidimensional e utiliza gravidade suavizada. A suavização substitui a
singularidade que ocorreria quando a distância entre dois corpos tende a zero por uma interação
finita. Esse recurso não representa colisões ou fusões; ele apenas torna o cálculo gravitacional
definido durante aproximações muito pequenas. Todas as comparações de uma mesma série experimental
mantêm o modelo e seus parâmetros constantes.

### 5.1.2. Força bruta

O *solver* de força bruta calcula, para cada corpo, a contribuição gravitacional de todos os outros.
Com `N` corpos, são avaliados `N(N-1)` pares direcionados em cada passo. Isso significa que o trabalho
cresce aproximadamente com o quadrado da quantidade de corpos, comportamento representado por
`O(N²)`.

Esse método é direto: nenhuma região do espaço é resumida e nenhuma interação é descartada por
aproximação. Por esse motivo, ele foi utilizado como referência para avaliar as acelerações
produzidas por Barnes-Hut. O termo *referência* não significa que toda trajetória integrada seja uma
solução matemática exata; significa apenas que, para um estado fornecido, o *solver* soma diretamente
as contribuições definidas pelo modelo implementado.

### 5.1.3. Barnes-Hut, quadtree e o parâmetro theta

Barnes-Hut reduz o número de interações ao observar que um grupo de corpos suficientemente distante
pode ser aproximado por sua massa total posicionada no centro de massa. Em duas dimensões, o espaço
é organizado em uma *quadtree*. A região inicial é dividida em quatro quadrantes, e os quadrantes que
contêm mais corpos podem ser subdivididos novamente. Cada nó da árvore armazena informações
agregadas sobre a região que representa.

Essa organização ajuda a compreender a expressão $O(N\log N)$, frequentemente associada ao custo
esperado de Barnes-Hut. O termo $\log N$ representa um crescimento lento relacionado à quantidade de
níveis necessária para organizar e percorrer uma árvore. Em uma árvore equilibrada, cada subdivisão
reduz a parte do problema que precisa ser examinada em detalhe. Se a quantidade de elementos dobra,
a profundidade não dobra: normalmente é necessário acrescentar apenas um pequeno número de níveis.
Como exemplo intuitivo, enquanto `N` cresce de 1.000 para 10.000, isto é, dez vezes, $\log_2 N$ cresce
de aproximadamente 10 para 13,3.

O fator `N` aparece porque a aceleração precisa ser calculada para cada um dos `N` corpos. O fator
$\log N$ representa, de maneira aproximada, o trabalho de percorrer a hierarquia espacial para cada
corpo. Assim, $O(N\log N)$ cresce mais lentamente que $O(N^2)$: ao multiplicar `N` por dez, um custo
quadrático tende a crescer cerca de cem vezes, enquanto um custo do tipo $N\log N$ cresce pouco mais
de dez vezes. Essa notação descreve a tendência de crescimento, e não o tempo exato em segundos.

O comportamento $O(N\log N)$ depende da distribuição espacial e do equilíbrio da árvore. Uma
distribuição desfavorável ou um critério de abertura muito rigoroso pode exigir mais visitas e mais
interações diretas, aproximando o custo do caso quadrático. Por isso, o presente trabalho não utiliza
apenas a complexidade teórica: também registra o tempo, as visitas aos nós e as interações realmente
executadas em cada configuração.

Ao calcular a aceleração de um corpo, a árvore é percorrida. Regiões próximas são abertas para que
seus conteúdos sejam examinados com maior detalhe. Regiões distantes podem ser tratadas como uma
única fonte agregada. A decisão é controlada pelo critério de abertura:

$$
\frac{s}{d} < \theta,
$$

em que `s` representa o tamanho da região, `d` é sua distância ao corpo analisado e $\theta$ (*theta*)
é o parâmetro de abertura. Um valor pequeno de $\theta$ torna o critério mais rigoroso: a região
precisa parecer menor em relação à distância para ser aceita como uma aproximação. Consequentemente,
mais nós são abertos e mais interações diretas são realizadas. Um valor maior aceita regiões mais
amplas, reduzindo o trabalho ao custo de uma aproximação menos precisa.

Neste estudo foram avaliados os valores 0,25, 0,5 e 1,0. De maneira intuitiva:

- $\theta = 0{,}25$ representa uma configuração conservadora, com maior detalhamento;
- $\theta = 0{,}5$ representa uma configuração intermediária; e
- $\theta = 1{,}0$ representa uma configuração mais agressiva, que agrega mais interações.

Também foi executado $\theta = 0$ no ensaio de exatidão. Nesse caso de controle, o critério não
aceita aproximações e o resultado deve coincidir com o cálculo direto, salvo diferenças de
arredondamento de ponto flutuante. Theta, portanto, não é uma medida de tempo nem uma porcentagem de
erro. Ele é um parâmetro geométrico que controla a decisão de abrir ou agregar nós da árvore; o erro
resultante precisa ser medido experimentalmente.

### 5.1.4. Integração numérica e passo de tempo

O *solver* calcula a aceleração correspondente a um estado, mas isso ainda não produz uma trajetória.
Para avançar a simulação, é necessário integrar numericamente as equações do movimento. A integração
divide o tempo contínuo em intervalos discretos de duração $\Delta t$. Em cada passo, as acelerações
são utilizadas para atualizar velocidades e posições.

O Sanxing utiliza o método de Euler semi-implícito. Para cada corpo, a velocidade é atualizada antes
da posição:

$$
v_{n+1} = v_n + a_n\Delta t,
$$

$$
p_{n+1} = p_n + v_{n+1}\Delta t.
$$

Nessas expressões, $p_n$ e $v_n$ são a posição e a velocidade no passo atual, $a_n$ é a aceleração
calculada pelo *solver* e $p_{n+1}$ e $v_{n+1}$ são os valores do passo seguinte. A denominação
*semi-implícito* decorre do uso da nova velocidade $v_{n+1}$ na atualização da posição.

O passo de tempo influencia a precisão. Um $\Delta t$ menor descreve a evolução com mais atualizações,
mas exige mais processamento. Um passo maior é mais econômico, porém pode não representar
adequadamente mudanças rápidas, sobretudo durante encontros próximos. Reduzir $\Delta t$ e observar
se o erro também diminui é uma forma de avaliar a convergência do integrador.

### 5.1.5. Energia e momento linear

Em um sistema gravitacional isolado ideal, a energia mecânica total e o momento linear total são
conservados. A energia total combina a energia cinética, associada às velocidades, e a energia
potencial gravitacional, associada às posições. O momento linear total corresponde à soma de
$m_i v_i$ para todos os corpos.

Uma integração numérica não reproduz necessariamente essas quantidades com exatidão em cada passo.
Por isso, foram registradas suas variações ao longo da simulação. Uma deriva menor ao reduzir o passo
de tempo constitui evidência de melhoria numérica. Para a energia, é importante observar não apenas
a diferença no último quadro, mas também a maior diferença ocorrida durante toda a execução, pois o
erro pode oscilar e retornar a um valor pequeno no final de uma órbita.

### 5.1.6. O problema de Burrau

O problema de Burrau, também chamado de problema pitagórico de três corpos, utiliza massas
proporcionais a 3, 4 e 5 inicialmente em repouso, posicionadas de maneira relacionada a um triângulo
retângulo. Embora a configuração inicial seja simples, sua evolução inclui interações próximas e
uma dinâmica complexa. Isso a torna útil para observar a sensibilidade das trajetórias e as
dificuldades numéricas de um sistema de três corpos.

Sensibilidade significa que estados iniciais muito próximos podem produzir estados posteriores
muito diferentes. Entretanto, a observação de separação entre trajetórias, por si só, não constitui
o cálculo de um expoente de Lyapunov nem prova que uma trajetória numérica seja exata. Se resultados
obtidos com passos de tempo diferentes divergem muito, parte importante do fenômeno observado pode
estar relacionada à resolução numérica. O experimento de Burrau é, por essa razão, apresentado como
um estudo de sensibilidade e de dependência do passo de tempo.

## 5.2. Procedimento experimental e reprodutibilidade

As medições foram produzidas pela própria infraestrutura experimental do Sanxing. A execução
canônica foi realizada sobre a revisão Git `5053581a83d7d39fc1717933e3a410c163a3e6b2`, com a engine
compilada no modo de otimização voltado à velocidade. O manifesto associado registra a revisão do
código, a versão do compilador Odin, o sistema operacional, o processador, a data, os comandos, as
matrizes experimentais e os resumos criptográficos dos artefatos. O conjunto foi marcado como
`complete` somente depois da validação das matrizes e dos arquivos esperados.

Os resultados foram divididos em dados brutos e resumos. As medições individuais de desempenho e
exatidão foram preservadas em JSONL. As tabelas consolidadas foram exportadas em CSV. As trajetórias
e os diagnósticos também permaneceram disponíveis, permitindo refazer a análise sem executar
novamente a simulação. Os gráficos foram gerados a partir desses arquivos, e não por valores
transcritos manualmente.

O cenário empregado nos ensaios de escala distribui os corpos deterministicamente segundo um
padrão de ângulo áureo. A utilização de um cenário determinístico garante que os *solvers* recebam o
mesmo estado em execuções equivalentes. Esse cenário serve como carga computacional controlada e não
pretende reproduzir uma galáxia ou outro sistema astronômico específico.

> **Indicação de quadro:** registrar, a partir do `manifest.json`, a versão do Odin, o sistema
> operacional, o processador e a quantidade de processadores lógicos da máquina utilizada.

## 5.3. Experimento de desempenho

### 5.3.1. Configuração

O primeiro experimento comparou força bruta e Barnes-Hut para 100, 500, 1.000, 5.000 e 10.000
corpos. Cada configuração realizou 10 passos de integração. Foram coletadas 10 amostras temporizadas
após duas execuções de aquecimento, utilizadas para reduzir a influência do primeiro uso do código e
das estruturas de dados.

Para Barnes-Hut, foram avaliados $\theta = 0{,}25$, $\theta = 0{,}5$ e $\theta = 1{,}0$. A região
temporizada contém o trabalho normal do *solver* e do integrador. A escrita dos resultados e a geração
dos gráficos não fazem parte do tempo medido. Os contadores de interações e visitas à árvore foram
coletados separadamente para não acrescentar instrumentação às amostras de tempo.

### 5.3.2. Resultados

A Tabela 1 apresenta a média do tempo decorrido para os 10 passos. Tempos menores representam maior
desempenho.

| Corpos | Força bruta (s) | BH $\theta=0{,}25$ (s) | BH $\theta=0{,}5$ (s) | BH $\theta=1{,}0$ (s) |
| ---: | ---: | ---: | ---: | ---: |
| 100 | 0,00033 | 0,00208 | 0,00149 | 0,00105 |
| 500 | 0,00984 | 0,03640 | 0,01684 | 0,00954 |
| 1.000 | 0,03336 | 0,08468 | 0,03991 | 0,02162 |
| 5.000 | 0,82481 | 0,72055 | 0,25645 | 0,12441 |
| 10.000 | 3,36327 | 1,92650 | 0,62904 | 0,27710 |

Em sistemas pequenos, a força bruta apresentou vantagem. Para 100 corpos, até a configuração mais
agressiva de Barnes-Hut foi mais lenta. Isso ocorre porque construir e percorrer a quadtree possui um
custo próprio. Quando existem poucos pares, a simplicidade do laço direto compensa seu crescimento
quadrático.

Com o aumento de `N`, o número de pares da força bruta cresce rapidamente. Barnes-Hut com
$\theta = 1{,}0$ tornou-se ligeiramente mais rápido a partir de 500 corpos, enquanto as configurações
0,25 e 0,5 ultrapassaram a força bruta em 5.000 corpos. Em 10.000 corpos, os ganhos foram de
aproximadamente 1,75 vez para $\theta = 0{,}25$, 5,35 vezes para $\theta = 0{,}5$ e 12,14 vezes para
$\theta = 1{,}0$.

> **Indicação de figura:** inserir `figures/runtime.svg`, que apresenta os tempos médios e as barras
> de desvio-padrão.

> **Indicação de figura:** inserir `figures/speedup.svg`, que apresenta a razão entre o tempo da
> força bruta e o tempo de Barnes-Hut. Valores acima de 1 indicam vantagem de Barnes-Hut.

Os contadores de trabalho ajudam a explicar essa mudança. Para 10.000 corpos e 10 passos, a força
bruta realizou 999.900.000 interações diretas. Barnes-Hut com $\theta = 0{,}5$ realizou cerca de
3,40 milhões de interações diretas e 25,25 milhões de interações aproximadas, além das visitas
necessárias à árvore. Com $\theta = 1{,}0$, o total caiu para aproximadamente 0,76 milhão de
interações diretas e 7,54 milhões de aproximações. A redução do trabalho gravitacional explica o
ganho observado, enquanto a construção e a travessia da árvore explicam por que a vantagem não
aparece imediatamente nos menores sistemas.

Foram detectados coeficientes de variação elevados nas medições de 500 corpos para força bruta
(14,3%) e Barnes-Hut com $\theta = 0{,}25$ (16,9%). Essa variação deve ser considerada ao interpretar
diferenças pequenas nessa escala. As conclusões relativas aos maiores sistemas apresentam margens
mais amplas que essas oscilações.

## 5.4. Experimento de exatidão das acelerações

### 5.4.1. Por que comparar acelerações

Uma pequena diferença de aceleração pode se acumular durante milhares de passos, e sistemas
sensíveis podem amplificá-la. Comparar apenas posições finais misturaria três efeitos: a aproximação
do *solver*, o erro do integrador e a sensibilidade da trajetória. Para isolar Barnes-Hut, este
experimento calcula as acelerações sobre estados iniciais idênticos, sem avançar o tempo.

A força bruta fornece o vetor de referência para cada corpo. Em seguida, Barnes-Hut calcula os
vetores correspondentes. A principal medida é o erro L2 normalizado, que compara o tamanho combinado
das diferenças com o tamanho combinado das acelerações de referência. Um valor de 0 representa
concordância completa; um valor de 0,01 corresponde, de forma aproximada, a um erro agregado de 1%
na norma utilizada. Também foram registrados o erro vetorial absoluto médio e o maior erro absoluto.

### 5.4.2. Resultados

A Tabela 2 resume a faixa de erro L2 normalizado observada entre 100 e 10.000 corpos.

| Theta | Menor erro normalizado | Maior erro normalizado | Interpretação aproximada |
| ---: | ---: | ---: | :--- |
| 0 | $4,30 \times 10^{-16}$ | $4,41 \times 10^{-15}$ | concordância numérica com a referência |
| 0,25 | 0,00102 | 0,00357 | cerca de 0,10% a 0,36% |
| 0,5 | 0,00999 | 0,01857 | cerca de 1,00% a 1,86% |
| 1,0 | 0,09824 | 0,11612 | cerca de 9,82% a 11,61% |

O controle com $\theta = 0$ permaneceu abaixo da tolerância de $10^{-12}$ em todas as quantidades de
corpos. O maior valor foi $4,41 \times 10^{-15}$, indicando que, ao desativar a agregação, a travessia
de Barnes-Hut reproduziu a referência dentro das diferenças esperadas de ponto flutuante.

O aumento de theta elevou o erro. Com $\theta = 0{,}25$, o erro permaneceu abaixo de 0,36%. Com
$\theta = 0{,}5$, permaneceu próximo de 1% a 1,86%. Com $\theta = 1{,}0$, aproximou-se de 10% ou mais.
Esse comportamento confirma a troca esperada: aceitar regiões maiores reduz o trabalho, mas perde
detalhes do campo gravitacional.

> **Indicação de figura:** inserir `figures/force-accuracy.svg`, preferencialmente com eixo vertical
> logarítmico para manter visíveis tanto o controle com theta zero quanto as aproximações.

Considerados conjuntamente os dois primeiros experimentos, $\theta = 0{,}5$ apresentou o compromisso
mais equilibrado entre as configurações avaliadas. Em 10.000 corpos, produziu aceleração com erro
normalizado de aproximadamente 1,70% e foi 5,35 vezes mais rápido que a força bruta. Essa observação
não define 0,5 como valor universalmente ótimo: a escolha depende da distribuição espacial, da
precisão requerida e do objetivo da simulação.

## 5.5. Experimento de convergência do integrador

### 5.5.1. Configuração

Para avaliar o integrador, foi escolhida uma órbita circular de dois corpos. Esse cenário é útil
porque, após um período completo, espera-se que o corpo observado retorne para perto de sua posição
inicial. A mesma duração física foi simulada com 100, 200 e 400 passos. Assim, cada refinamento
reduziu $\Delta t$ pela metade.

Todas as execuções utilizaram força bruta para evitar a introdução do erro de aproximação de
Barnes-Hut. Foram medidos o erro de posição ao final do período, a maior deriva relativa de energia e
a deriva do momento linear.

### 5.5.2. Resultados

| Passos por período | Erro final de posição | Maior deriva relativa de energia | Maior deriva de momento |
| ---: | ---: | ---: | ---: |
| 100 | 0,008787 | 0,003952 | 0 |
| 200 | 0,002196 | 0,000987 | 0 |
| 400 | 0,000549 | 0,000247 | 0 |

Ao dobrar a quantidade de passos, o erro de posição foi reduzido por um fator próximo de quatro. A
maior deriva relativa de energia apresentou a mesma tendência. Portanto, a solução se aproximou da
órbita esperada à medida que o passo de tempo foi refinado. Esse comportamento fornece evidência
empírica de convergência para o cenário avaliado.

A deriva de momento registrada foi zero na precisão numérica exportada. Isso é compatível com a
simetria das forças internas calculadas entre o par. A energia, por outro lado, variou durante a
órbita. No caso de 100 passos, por exemplo, a deriva relativa final foi aproximadamente
$1,29 \times 10^{-7}$, muito menor que a deriva máxima de 0,003952. Avaliar apenas o último quadro
ocultaria a oscilação ocorrida durante o período; por isso, a maior deriva foi adotada como medida
principal.

> **Indicação de figuras:** inserir `figures/orbit-position-error.svg`,
> `figures/orbit-energy-drift.svg` e `figures/orbit-momentum-drift.svg`.

O experimento não afirma que Euler semi-implícito é o integrador mais preciso disponível. Ele mostra
que a implementação utilizada melhora de forma consistente sob refinamento no teste regular de dois
corpos. Métodos de ordem superior ou integradores simpléticos mais avançados podem ser investigados
em trabalhos futuros.

## 5.6. Experimento de sensibilidade de Burrau

### 5.6.1. Configuração

Foram preparadas duas versões da configuração de Burrau com massas 3, 4 e 5, velocidades iniciais
nulas, constante gravitacional igual a 1 e suavização igual a 0,001. A única diferença entre as
versões foi uma perturbação de $10^{-10}$ na coordenada `x` do corpo de massa 3. A força bruta foi
utilizada em todas as execuções.

Cada par, formado pela configuração base e pela perturbada, foi simulado até o tempo 20. O primeiro
par utilizou $\Delta t = 0{,}001$, totalizando 20.000 passos. O segundo utilizou
$\Delta t = 0{,}0005$, totalizando 40.000 passos. Em cada instante, corpos com o mesmo identificador
foram comparados. Registraram-se a distância média entre os três pares e a maior distância individual.

### 5.6.2. Resultados e interpretação

No estado inicial, a maior separação era aproximadamente $10^{-10}$, conforme a perturbação
introduzida. Ao final da execução com $\Delta t = 0{,}001$, a maior separação chegou a aproximadamente
0,0211. Isso mostra que uma diferença inicialmente muito pequena tornou-se visível na trajetória
calculada.

Entretanto, a execução com $\Delta t = 0{,}0005$ apresentou separação final de aproximadamente
1.580,94. A diferença de várias ordens de grandeza entre os dois passos de tempo impede que esse
valor seja tratado como uma estimativa estável da separação física no instante 20. Encontros próximos
podem amplificar tanto diferenças iniciais quanto erros de discretização, e o método de Euler
semi-implícito pode exigir uma resolução muito mais fina ou um mecanismo adaptativo para representar
adequadamente essa fase.

> **Indicação de figura:** inserir `figures/trajectory-separation.svg`, identificando claramente as
> curvas correspondentes aos dois passos de tempo.

O resultado permite afirmar que foi observada sensibilidade às condições iniciais, acompanhada de
forte dependência da resolução temporal. Não permite afirmar que o Sanxing calculou um expoente de
Lyapunov, que a separação final de uma das execuções constitui uma referência exata ou que a
divergência foi causada por Barnes-Hut, pois esse *solver* não foi utilizado no ensaio. A discrepância
entre os passos é também um resultado experimental: ela delimita a confiança que pode ser atribuída
à trajetória de Burrau produzida pela configuração numérica atual.

## 5.7. Discussão conjunta

Os experimentos mostram que desempenho e precisão não podem ser analisados por uma única medida. A
força bruta apresentou menor custo nos sistemas pequenos e forneceu uma referência direta para as
acelerações. Barnes-Hut passou a oferecer vantagem conforme o número de corpos aumentou, chegando a
ganhos expressivos em 10.000 corpos. Essa vantagem foi acompanhada por um erro controlado pelo
parâmetro theta.

Entre os valores avaliados, $\theta = 0{,}5$ apresentou uma relação favorável entre custo e erro no
cenário de escala: o *solver* tornou-se 5,35 vezes mais rápido em 10.000 corpos, com erro normalizado de
aceleração próximo de 1,70%. Caso a prioridade seja maior fidelidade instantânea, 0,25 reduz o erro,
mas também reduz o ganho. Caso a prioridade seja velocidade, 1,0 aumenta o ganho, mas produziu erros
normalizados próximos de 10%.

O teste orbital mostrou que o integrador responde ao refinamento do passo de tempo: os erros de
posição e energia diminuíram de forma consistente. Contudo, o ensaio de Burrau mostrou que esse
resultado não deve ser generalizado sem cautela para trajetórias com encontros próximos e forte
sensibilidade. Uma configuração pode apresentar bom comportamento em uma órbita regular e ainda
exigir métodos ou passos diferentes em uma dinâmica mais difícil.

Assim, a avaliação sustenta três conclusões principais. Primeiro, a decomposição espacial implementada
é capaz de reduzir substancialmente o custo de sistemas maiores. Segundo, essa redução possui uma
troca mensurável entre desempenho e exatidão. Terceiro, a qualidade de uma trajetória depende não
apenas do *solver* gravitacional, mas também do integrador e do passo de tempo.

## 5.8. Ameaças à validade e limitações

Os tempos apresentados pertencem à máquina e ao ambiente registrados no manifesto. Outras
arquiteturas, versões do compilador e condições de carga podem alterar os valores absolutos e o ponto
de cruzamento entre os *solvers*. Por essa razão, os tempos devem ser acompanhados pelas informações
de proveniência, e não tratados como uma propriedade universal da linguagem ou do algoritmo.

O cenário de escala é sintético e determinístico. Ele favorece comparações controladas, mas não
representa todas as distribuições possíveis. A forma da distribuição espacial afeta a quadtree e,
consequentemente, o trabalho de Barnes-Hut. Novos estudos podem acrescentar distribuições agrupadas,
uniformes e provenientes de aplicações específicas.

As execuções foram seriais. Os resultados não medem paralelismo, aceleração por GPU ou execução
distribuída. Também não comparam Sanxing com outras engines, pois uma comparação externa exigiria
controlar o modelo físico, a precisão, o integrador, as otimizações e o trabalho realizado.

O experimento orbital cobre uma configuração regular de dois corpos e não valida isoladamente todas
as trajetórias possíveis. O experimento de Burrau, por sua vez, evidencia que os resultados tardios
são fortemente dependentes do passo de tempo. Integradores adicionais, controle adaptativo de passo
e critérios específicos para encontros próximos constituem extensões relevantes.

Por fim, os dados de trajetória não devem substituir a comparação direta das acelerações na análise
de Barnes-Hut. Uma diferença tardia de posição pode resultar de aproximação do *solver*, erro acumulado
de integração ou sensibilidade do sistema. A metodologia adotada mantém essas questões separadas
para que cada conclusão permaneça associada à evidência que efetivamente a sustenta.

