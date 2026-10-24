# 4. Desenvolvimento

O desenvolvimento do Sanxing foi orientado pela construção de um motor de simulação capaz de
representar sistemas gravitacionais de N corpos e de fornecer uma base controlada para a comparação
entre diferentes estratégias de cálculo. Para isso, a solução foi implementada de forma modular,
separando o núcleo responsável pelo modelo físico, pelos métodos numéricos e pela exportação dos
dados da camada destinada à apresentação visual dos resultados. Essa separação permite executar a
simulação sem uma interface gráfica e, posteriormente, reproduzir os estados calculados em um
visualizador independente.

O núcleo da aplicação foi desenvolvido na linguagem de programação Odin, escolhida por apresentar
uma sintaxe direta, oferecer compilação nativa e manter proximidade com conceitos de programação de
sistemas (Odin, 2026a, 2026b). A linguagem também possibilita a organização do código em pacotes com
responsabilidades distintas, característica utilizada para separar os tipos fundamentais, os
solvers gravitacionais, o integrador numérico, a decomposição espacial, a entrada de configurações e
a exportação dos resultados. A escolha da linguagem, entretanto, não é utilizada isoladamente como
evidência de desempenho. O comportamento computacional da solução é avaliado por meio dos
experimentos apresentados no capítulo de resultados.

A versão desenvolvida opera em duas dimensões e recebe as condições iniciais da simulação por meio
de um arquivo JSON. Durante a execução, o usuário pode selecionar o cálculo direto por força bruta ou
o algoritmo de Barnes-Hut. Em ambos os casos, o estado dos corpos é atualizado pelo método de Euler
semi-implícito. Quando a exportação está habilitada, os estados produzidos são registrados em JSON
Lines (JSONL), de modo que cada linha represente um instante completo da simulação (JSON, 2026; JSON
Lines, 2026). O arquivo resultante pode ser analisado por outras ferramentas ou carregado pelo
visualizador local.

## 4.1. Organização do desenvolvimento

A implementação foi conduzida de forma incremental. Inicialmente, foram definidos os tipos que
representam os corpos, os parâmetros da simulação e o estado global do sistema. Em seguida, foi
implementado o cálculo direto das interações gravitacionais, utilizado como referência de
comportamento para as demais etapas. Após a consolidação desse caminho básico, foram acrescentados o
integrador numérico, a leitura de configurações, a exportação dos estados e os testes automatizados.

Na etapa seguinte, foi implementada a decomposição espacial por quadtree e sua utilização pelo
algoritmo de Barnes-Hut. A introdução da abordagem hierárquica exigiu cuidados adicionais com os
limites espaciais da árvore, o cálculo do centro de massa e a preservação de corpos coincidentes ou
muito próximos. Por fim, foram adicionados mecanismos de diagnóstico, geração determinística de
cenários, medição de desempenho, comparação do erro de aceleração e reprodução visual dos arquivos
gerados.

Essa sequência permitiu utilizar o método direto como referência durante o desenvolvimento do
Barnes-Hut. Como ambos os métodos compartilham os mesmos tipos, o mesmo integrador e as mesmas
condições iniciais, diferenças encontradas nos experimentos podem ser relacionadas ao procedimento
de cálculo das acelerações, respeitadas as limitações de cada protocolo experimental.

## 4.2. Arquitetura da solução

A arquitetura do Sanxing foi organizada em dois blocos principais: a engine headless e o
visualizador local. A engine concentra o estado da simulação, a validação dos dados de entrada, o
cálculo das acelerações, a integração temporal, os diagnósticos e a exportação. O visualizador, por
sua vez, limita-se a carregar e apresentar os estados previamente exportados. Assim, nenhuma regra
do modelo físico é reimplementada na camada de interface.

> **Indicação de figura:** inserir uma versão atualizada do diagrama de arquitetura, apresentando a
> entrada JSON, os pacotes da engine, a saída JSONL e o visualizador local como consumidor externo.

A execução desacoplada foi adotada para que experimentos de desempenho não dependam da abertura de
uma janela, da taxa de atualização gráfica ou do processamento necessário à renderização. Essa
decisão também permite que um mesmo arquivo de saída seja inspecionado mais de uma vez sem repetir
o cálculo físico. Além disso, o contrato de dados em JSONL possibilita que outros visualizadores
sejam desenvolvidos futuramente sem criar uma dependência da engine em relação a uma tecnologia de
interface específica.

A engine foi dividida em pacotes internos com responsabilidades delimitadas. O pacote `core` contém
os tipos compartilhados e coordena cada passo da simulação. O pacote `input` realiza a leitura e a
validação dos arquivos JSON. Os pacotes `solvers` e `spatial` implementam, respectivamente, os
métodos de cálculo gravitacional e a quadtree. O pacote `integration` atualiza velocidades e
posições, enquanto `export` registra os estados e os diagnósticos. Os pacotes `benchmark`,
`accuracy`, `diagnostics` e `scenarios` fornecem a infraestrutura necessária à avaliação
experimental.

Essa divisão reduz o acoplamento entre componentes. O integrador recebe os corpos já associados às
acelerações calculadas pelo solver, sem precisar conhecer a maneira pela qual essas acelerações foram
obtidas. De forma semelhante, o exportador recebe um estado completo da simulação e não participa do
cálculo das forças. A substituição de um solver, portanto, não exige alterações no formato dos
corpos, no integrador ou no visualizador.

### 4.2.1. Fluxo de execução

O fluxo principal começa pela interpretação do comando fornecido ao programa. A interface de linha
de comando disponibiliza operações separadas para simulação, benchmark e análise do erro de
aproximação. No modo de simulação, o arquivo JSON é carregado e validado antes da criação do estado
inicial. Caso a exportação esteja habilitada, esse estado é registrado antes do primeiro passo, de
modo que uma configuração com `N` passos produza `N + 1` quadros: um quadro inicial e um quadro após
cada atualização.

Em cada passo, o núcleo seleciona o solver indicado na configuração e solicita o cálculo das
acelerações. Quando essa etapa é concluída, o integrador atualiza primeiro as velocidades e depois as
posições. Somente após essas operações o contador de passos e o tempo simulado são incrementados. O
novo estado pode então ser enviado ao exportador. Se também tiver sido solicitado um arquivo de
diagnósticos, as grandezas correspondentes ao mesmo instante são calculadas e gravadas em um fluxo
separado.

> **Indicação de figura:** inserir um diagrama de atividade atualizado com a sequência “validar
> entrada → exportar estado inicial → calcular acelerações → integrar → atualizar tempo → exportar
> estado”, incluindo o encerramento após a quantidade configurada de passos.

O programa encerra a execução quando todos os passos são concluídos ou quando ocorre uma falha de
validação, seleção do solver, leitura ou escrita. O visualizador não participa desse ciclo. No fluxo
combinado disponibilizado pelo projeto, a engine conclui a geração do arquivo e somente depois o
visualizador é aberto para reproduzi-lo. Dessa forma, mesmo a operação que reúne os dois programas
preserva a fronteira entre simulação e apresentação.

## 4.3. Modelo de dados e configuração

O estado da simulação é formado por uma coleção de corpos, pelo número do passo atual e pelo tempo
simulado. Cada corpo possui um identificador textual, massa, posição, velocidade e aceleração. As
grandezas vetoriais são representadas por duas componentes de ponto flutuante de 64 bits,
correspondentes aos eixos x e y. O modelo não impõe um sistema específico de unidades; entretanto,
todos os valores fornecidos para uma mesma execução devem pertencer a um sistema internamente
consistente.

A configuração inclui a constante gravitacional, o intervalo de tempo, a quantidade de passos, o
fator de suavização, o solver selecionado, o parâmetro de abertura do Barnes-Hut e a opção de
exportação. O parâmetro de abertura, denominado `theta`, é opcional no arquivo e assume o valor 0,5
quando não é informado. Os demais campos necessários devem estar presentes explicitamente.

A entrada JSON utiliza validação estrita. Campos desconhecidos são rejeitados tanto no objeto
principal quanto nas configurações, nos corpos e nos vetores. A engine também rejeita identificadores
vazios ou repetidos, massas não positivas, valores vetoriais não finitos, passo de tempo não
positivo, quantidade negativa de passos, constante gravitacional negativa, suavização negativa,
`theta` negativo e nomes de solver não reconhecidos. Essa validação ocorre antes do início da
simulação, evitando que um arquivo parcialmente interpretado produza resultados aparentemente
válidos.

Na versão atual, o JSON constitui a forma implementada para a configuração das simulações. A entrada
por CSV e a edição gráfica dos corpos não fazem parte desta etapa do trabalho. Essa delimitação
mantém um único caminho de validação e favorece a repetição dos experimentos a partir dos mesmos
arquivos de entrada.

## 4.4. Modelo gravitacional

O modelo implementado calcula a aceleração de cada corpo a partir da contribuição gravitacional dos
demais corpos. Sejam dois corpos identificados pelos índices `i` e `j`, com posições `p_i` e `p_j` e
massa de origem `m_j`. Define-se inicialmente o vetor de deslocamento:

$$
\Delta p_{ij} = p_j - p_i.
$$

Considerando a constante gravitacional `G` e um fator de suavização `\varepsilon`, a contribuição do
corpo `j` para a aceleração do corpo `i` é calculada por:

$$
a_{ij} = \Delta p_{ij}
\frac{Gm_j}{\left(\lVert\Delta p_{ij}\rVert^2 + \varepsilon^2\right)
\sqrt{\lVert\Delta p_{ij}\rVert^2 + \varepsilon^2}}.
$$

A aceleração resultante de `i` corresponde à soma das contribuições produzidas por todas as fontes
consideradas pelo solver. A massa do próprio corpo-alvo não aparece nessa expressão porque a força
gravitacional foi dividida por sua massa, resultando diretamente em aceleração. O fator de
suavização reduz o crescimento da interação em distâncias muito pequenas e evita a singularidade da
formulação pontual quando dois corpos ocupam posições coincidentes. Como consequência, ele integra o
modelo experimental e deve ser mantido constante nas execuções comparadas.

O sistema não implementa colisão, fusão ou resposta de contato. Corpos que se aproximam podem
atravessar a mesma região e continuam sujeitos à gravidade suavizada. Essa característica precisa
ser considerada na interpretação de cenários com encontros próximos.

## 4.5. Cálculo direto por força bruta

O solver de força bruta calcula explicitamente a influência de cada corpo sobre todos os demais. No
início de cada passo, as acelerações anteriormente armazenadas são zeradas. Em seguida, para cada
corpo-alvo `i`, o algoritmo percorre todos os corpos de origem `j`, ignora o caso em que `i = j` e
acumula as contribuições gravitacionais restantes.

Para um sistema com `N` corpos, são realizadas `N(N-1)` contribuições ordenadas por passo. Portanto,
o custo do cálculo cresce quadraticamente, sendo expresso por `O(N²)`. Apesar dessa limitação, o
método direto possui uma estrutura simples e não introduz aproximações espaciais. Por esse motivo,
ele foi mantido como baseline para os experimentos de desempenho e como referência para a avaliação
do erro das acelerações calculadas pelo Barnes-Hut.

O uso da força bruta como referência não significa que a integração temporal forneça uma trajetória
exata. O método elimina a aproximação hierárquica no cálculo das interações, mas continua sujeito ao
passo de tempo, ao integrador empregado, à suavização e à precisão de ponto flutuante. Essa distinção
é necessária para separar o erro do solver do erro numérico acumulado durante a integração.

## 4.6. Decomposição espacial por quadtree

Para reduzir a quantidade de interações avaliadas individualmente, foi implementada uma quadtree. A
estrutura divide recursivamente uma região quadrada em quatro quadrantes. Cada nó armazena seus
limites, a quantidade total de corpos, a massa acumulada e o centro de massa. Nós internos mantêm
quatro filhos, enquanto folhas preservam os índices dos corpos contidos na região.

Antes da construção da árvore, a engine identifica os valores mínimos e máximos das posições em
ambos os eixos. A maior dimensão encontrada é utilizada para formar uma região quadrada que engloba
todos os corpos. Uma pequena margem é acrescentada aos limites para reduzir ambiguidades numéricas
nas bordas. Quando a extensão do sistema é muito pequena, utiliza-se um tamanho mínimo para a raiz.

Durante a inserção, uma folha vazia recebe diretamente o índice do corpo. Quando uma folha ocupada
recebe outro corpo, ela é subdividida e os índices são encaminhados aos quadrantes correspondentes.
O quadrante é determinado comparando cada coordenada com o centro da região. Esse processo continua
até que os corpos sejam separados espacialmente ou que um limite de subdivisão seja atingido.

Corpos coincidentes apresentam um caso importante, pois suas coordenadas podem conduzi-los sempre ao
mesmo quadrante. Para impedir subdivisões indefinidas e preservar todos os corpos, a implementação
limita a árvore a 32 níveis e interrompe a subdivisão quando a meia largura ou a meia altura da
região atinge `10⁻¹²`. Nessas situações, a folha mantém múltiplos índices e suas interações internas
são avaliadas diretamente. Essa estratégia também evita que um corpo seja descartado devido à
degeneração espacial da árvore.

O centro de massa é atualizado durante cada inserção. Considerando a massa já armazenada em um nó e
a massa do novo corpo, as coordenadas são combinadas por média ponderada. Assim, ao final da
construção, cada nó representa tanto a distribuição de seus descendentes quanto uma fonte agregada
que pode ser utilizada pelo Barnes-Hut.

> **Indicação de figura:** apresentar uma quadtree produzida a partir de um cenário pequeno,
> identificando limites, folhas, massas acumuladas e centros de massa.

## 4.7. Solver de Barnes-Hut

O algoritmo de Barnes-Hut utiliza a hierarquia espacial para substituir grupos suficientemente
distantes por uma única fonte equivalente (BARNES; HUT, 1986; Princeton University, 2026). Para cada
corpo-alvo, a árvore é percorrida a partir da raiz. Folhas são processadas diretamente, respeitando a
exclusão da autointeração. Em nós internos, o algoritmo decide entre aceitar a aproximação pelo
centro de massa ou continuar a visita aos quatro filhos.

Na implementação desenvolvida, um nó que não contém o corpo-alvo pode ser aproximado quando:

$$
\frac{s}{d} < \theta,
$$

em que `s` representa a largura da região do nó, `d` corresponde à distância suavizada entre o
corpo-alvo e o centro de massa, e `theta` é o limiar configurado. Quando a condição é satisfeita, a
massa total e o centro de massa do nó são tratados como uma única fonte. Caso contrário, a travessia
prossegue recursivamente.

Nós que contêm o corpo-alvo não são aceitos como uma fonte agregada. Essa regra impede que a massa
do próprio corpo participe indiretamente do cálculo por meio do centro de massa do nó. Nas folhas,
os índices são percorridos individualmente, o que preserva a exclusão explícita da autointeração
mesmo quando uma folha contém múltiplos corpos.

Valores menores de `theta` tornam o critério mais restritivo e levam a um número maior de visitas e
interações diretas. Valores maiores permitem aceitar agrupamentos mais próximos, reduzindo o
trabalho ao custo de uma aproximação potencialmente maior. Quando `theta` é igual a zero, nenhum nó
interno satisfaz o critério de aceitação, e a árvore percorre as fontes individualmente. Esse caso é
utilizado como controle para verificar a concordância com o solver direto dentro da tolerância
numérica definida.

Além do resultado físico, o solver pode registrar a quantidade de interações diretas, interações
aproximadas e visitas a nós não vazios. Esses contadores são utilizados para explicar o trabalho
realizado em cada configuração. Durante os benchmarks, entretanto, a coleta detalhada é realizada em
uma repetição separada, para que a instrumentação não altere o tempo atribuído ao caminho normal do
solver.

## 4.8. Integração temporal

Após o cálculo das acelerações, o estado é avançado pelo método de Euler semi-implícito. Para cada
corpo, a velocidade é atualizada antes da posição, conforme as expressões:

$$
v_{t+\Delta t} = v_t + a_t\Delta t,
$$

$$
p_{t+\Delta t} = p_t + v_{t+\Delta t}\Delta t.
$$

Essa ordem distingue o método da forma explícita de Euler, na qual a posição seria atualizada com a
velocidade do início do passo. A aplicação utiliza um intervalo temporal constante durante cada
simulação. Depois da atualização de todos os corpos, o contador de passos é incrementado e o tempo
acumulado recebe `\Delta t`.

O Euler semi-implícito foi mantido por sua simplicidade e por permitir que o foco do trabalho
permaneça na comparação entre os métodos de cálculo gravitacional. Ainda assim, a escolha do
integrador afeta a conservação de energia, o erro de fase e a trajetória acumulada. Por essa razão,
sua validade não é inferida apenas pela inspeção visual. O protocolo experimental inclui uma órbita
de dois corpos executada com refinamento do passo temporal, além do acompanhamento da energia e do
momento linear.

## 4.9. Exportação e diagnósticos

Os quadros da simulação são armazenados em JSONL. Cada registro contém o passo, o tempo e a coleção
completa de corpos, incluindo identificador, massa, posição, velocidade e aceleração. O formato com
um objeto JSON independente por linha permite processar o arquivo de maneira incremental e mantém
os limites entre os quadros explicitamente representados (JSON Lines, 2026).

A engine também pode produzir um arquivo separado de diagnósticos. Para cada instante exportado,
são calculadas a energia cinética, a energia potencial gravitacional suavizada, a energia total e o
momento linear. A separação entre quadros e diagnósticos evita ampliar o contrato mínimo utilizado
pelo visualizador e permite analisar grandezas globais sem inserir cálculos físicos na interface.

Os arquivos de benchmark e de acurácia seguem o mesmo princípio de preservação dos dados brutos. As
amostras individuais são registradas em JSONL, enquanto resumos agregados podem ser gravados em CSV.
Os registros incluem identificadores de execução, cenário, quantidade de corpos, solver, valor de
`theta` quando aplicável e rótulos do ambiente de compilação. Dessa forma, tabelas e figuras podem
ser relacionadas às configurações que lhes deram origem.

## 4.10. Visualizador local

O visualizador local foi desenvolvido em Odin com as bibliotecas Raylib e raygui. Sua função é
carregar um arquivo JSONL produzido pela engine e apresentar a evolução bidimensional dos corpos.
Antes da reprodução, o arquivo é validado quanto à presença dos campos necessários, à finitude dos
valores, à unicidade dos identificadores e à ordem monotônica dos quadros.

A interface permite iniciar e pausar a reprodução, avançar ou retornar um quadro, percorrer a linha
do tempo e alterar a velocidade de exibição. Também estão disponíveis operações de ajuste da câmera,
deslocamento, zoom, exibição de rastros e apresentação de rótulos. Ao selecionar um corpo, o usuário
pode inspecionar seu identificador, massa, posição, velocidade e aceleração. A seleção permanece
associada ao identificador durante a mudança dos quadros.

> **Indicação de figura:** inserir uma captura do visualizador com a trajetória completa e outra com
> um corpo selecionado, identificando os controles de reprodução e o painel de propriedades.

Embora ofereça controles de reprodução, o visualizador não continua nem modifica a simulação. Os
quadros são tratados como dados imutáveis e acessados por uma abstração de fonte finita e
consultável. Na versão atual, essa fonte corresponde ao replay JSONL. Essa organização permite que
uma fonte ao vivo seja investigada futuramente sem transferir o solver ou o integrador para a camada
gráfica.

Os protótipos iniciais previam menus para criar e editar corpos durante a interação com a interface.
Essas funcionalidades não integram a versão implementada. A configuração permanece sob
responsabilidade da engine por meio do arquivo JSON, e a interface local atua como ferramenta de
reprodução e inspeção dos resultados já calculados.

## 4.11. Verificação e reprodutibilidade

A implementação foi acompanhada por testes automatizados organizados segundo os pacotes da engine.
Os testes abrangem validação de tipos e configurações, leitura estrita de JSON, cálculo direto,
Barnes-Hut, construção da quadtree, atualização pelo integrador, exportação, diagnósticos, cenários e
comandos experimentais. Casos específicos verificam corpos coincidentes, valores inválidos,
exclusão da autointeração e concordância entre força bruta e Barnes-Hut com critério de abertura
nulo. O parser utilizado pelo visualizador também possui testes próprios para arquivos válidos e
entradas incorretas.

Para os experimentos do trabalho, foram definidos cenários determinísticos e um procedimento
canônico de execução. O procedimento registra a revisão do código, a versão do compilador, a data, a
plataforma, o processador, o modo de otimização e a matriz de configurações. Cada conjunto de
resultados mantém os dados brutos, os resumos, as trajetórias, os diagnósticos, as figuras e um
manifesto no mesmo diretório.

O executor destinado aos resultados definitivos exige uma revisão Git limpa e impede a reutilização
de um diretório de saída existente. Ao término, a matriz esperada e os artefatos são validados, e o
manifesto recebe o estado de conclusão juntamente com tamanhos e resumos criptográficos dos
arquivos. Execuções interrompidas ou produzidas a partir de uma árvore de trabalho modificada podem
ser utilizadas como ensaios piloto, mas não são tratadas como evidência definitiva.

Essa infraestrutura também separa os diferentes tipos de erro analisados. O desempenho é medido sem
a exportação dos quadros; o trabalho do solver é perfilado fora da região temporizada; o erro do
Barnes-Hut é calculado sobre vetores de aceleração antes da integração; e o comportamento do
integrador é avaliado pelo refinamento do passo e por grandezas de conservação. Dessa forma, a
divergência acumulada de uma trajetória não é utilizada, isoladamente, como medida do erro da
aproximação espacial.

## 4.12. Limitações da implementação

A versão apresentada corresponde a um motor serial, bidimensional e executado localmente. Não foram
implementadas execução distribuída, visualização tridimensional, entrada CSV, edição gráfica das
condições iniciais ou uma aplicação web de produção. Existe um protótipo anterior de visualização no
navegador, mas ele não constitui a interface suportada nesta etapa do projeto.

O modelo também não contempla colisões, fusões, tamanhos físicos dos corpos ou integradores de ordem
superior. A suavização gravitacional reduz singularidades de curta distância, porém altera o modelo
pontual original e precisa ser considerada na análise. Além disso, a utilização de ponto flutuante e
de um passo discreto impede interpretar as trajetórias produzidas como soluções analíticas exatas.

Uma prova de conceito de paralelismo pode ser acrescentada como experimento complementar. Caso seja
desenvolvida, ela deve permanecer separada da comparação serial principal entre força bruta e
Barnes-Hut, pois o ganho decorrente da execução concorrente não deve ser confundido com o ganho
algorítmico obtido pela decomposição espacial. As extensões de paralelismo, novos integradores,
configuração gráfica, visualização web e representação tridimensional são tratadas como possíveis
continuações do trabalho.

