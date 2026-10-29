# Extensão do Capítulo 4 — Interface de visualização

> **Posição sugerida:** utilizar este texto para atualizar e aprofundar a atual Seção 4.2.1 —
> Visualização. A numeração de figuras deve ser definida durante a integração com a fonte do TCC.

## Interface de visualização

A interface de visualização foi desenvolvida como uma aplicação local independente da engine. Sua
função consiste em carregar os estados exportados pela simulação e apresentá-los de forma gráfica,
permitindo que o usuário acompanhe a movimentação dos corpos e inspecione as informações registradas
em cada instante. Essa separação preserva a arquitetura headless proposta para o núcleo do sistema,
uma vez que o visualizador não participa do cálculo das interações gravitacionais nem da integração
temporal.

Na implementação atual, a engine conclui a simulação antes que a visualização seja iniciada. Os
estados calculados são armazenados em um arquivo JSON Lines (JSONL), no qual cada linha representa
um quadro completo. Em seguida, o visualizador carrega esse arquivo e o utiliza como fonte para a
reprodução. Esse procedimento foi escolhido como primeira forma de integração porque estabelece um
contrato simples entre os dois componentes e permite repetir a inspeção dos resultados sem executar
novamente os cálculos físicos.

O visualizador local foi implementado em Odin com o apoio das bibliotecas Raylib e raygui. A Raylib
é utilizada para a criação da janela, o processamento das entradas e a renderização bidimensional,
enquanto a raygui fornece os elementos empregados nos controles da interface. Embora a engine e o
visualizador tenham sido desenvolvidos na mesma linguagem, eles permanecem como programas
independentes. A dependência ocorre somente por meio do formato exportado, e nenhuma função dos
*solvers*, do integrador ou da quadtree é reproduzida na camada gráfica.

Antes de iniciar a reprodução, o arquivo selecionado é interpretado e validado. Cada quadro deve
conter o número do passo, o tempo e a coleção de corpos. Para cada corpo, são exigidos o
identificador, a massa, a posição, a velocidade e a aceleração. O carregamento também verifica se os
valores numéricos são finitos, se os identificadores são únicos dentro de cada quadro e se a ordem
dos passos e dos tempos é monotônica. Caso o arquivo não satisfaça essas condições, a interface
informa a falha em vez de reproduzir parcialmente dados inconsistentes.

Os quadros válidos são disponibilizados ao restante da aplicação por meio de uma abstração de fonte
de dados. Essa fonte informa a quantidade de quadros existentes e permite consultar um quadro por
seu índice. O replay JSONL constitui a fonte implementada nesta versão e possui tamanho finito e
acesso aos instantes já carregados. A utilização dessa fronteira evita que os controles e o código
de renderização dependam diretamente dos detalhes do parser. Além disso, ela permite investigar
futuramente uma fonte conectada à engine sem modificar a responsabilidade da camada visual.

A tela principal apresenta a área de simulação e os controles necessários à reprodução. O usuário
pode iniciar ou pausar a animação, avançar ou retornar um quadro e percorrer a linha do tempo. Também
é possível alterar a velocidade de reprodução, o que modifica a frequência com que os quadros são
apresentados, mas não altera o tempo simulado ou os estados registrados no arquivo. Dessa forma, a
velocidade da interface é tratada como uma propriedade de apresentação e não como um parâmetro do
modelo numérico.

Para facilitar a observação de sistemas com diferentes escalas, a câmera oferece enquadramento dos
corpos, deslocamento e aproximação. Os limites utilizados no enquadramento são obtidos a partir do
conteúdo do replay, permitindo manter uma referência espacial estável durante a reprodução. O
usuário também pode habilitar rastros para observar o caminho percorrido e rótulos para identificar
os corpos exibidos.

A interface permite selecionar um corpo diretamente na área de visualização. Quando a seleção é
realizada, um painel apresenta seu identificador, massa, posição, velocidade e aceleração no quadro
atual. A associação é mantida pelo identificador do corpo durante a mudança dos quadros, evitando que
a seleção seja transferida apenas pela posição ocupada na coleção. Esse recurso permite relacionar a
representação gráfica aos dados numéricos produzidos pela engine.

> **Indicação de figura:** inserir uma captura da tela principal durante a reprodução, destacando a
> área de simulação, a linha do tempo, os controles de reprodução e as opções de câmera.

> **Indicação de figura:** inserir uma segunda captura com um corpo selecionado e o painel de
> propriedades visível.

Os protótipos iniciais previam a inserção e a alteração de corpos diretamente pela interface. Essas
operações não foram incorporadas à versão desenvolvida. As condições iniciais continuam sendo
definidas em arquivos JSON e validadas pela engine antes da execução. Da mesma forma, a interface não
permite pausar o processamento físico ou continuar uma simulação, pois atua sobre um resultado já
calculado. Os comandos de pausa e avanço pertencem somente à reprodução do arquivo.

A opção por uma visualização bidimensional acompanha o modelo espacial implementado pela engine e
evita introduzir uma representação tridimensional que não corresponda ao cálculo realizado. Um
protótipo anterior para navegador foi preservado como registro do desenvolvimento, mas a aplicação
local constitui o visualizador adotado nesta etapa do trabalho. Uma interface web suportada, a
edição gráfica das condições iniciais e a conexão ao vivo com a engine permanecem como possibilidades
de evolução futura.

Desse modo, a interface implementada atende ao objetivo de apresentar e inspecionar os resultados
sem transferir responsabilidades do núcleo físico para a camada de visualização. O uso de um arquivo
intermediário também contribui para a reprodutibilidade, pois o mesmo conjunto de quadros pode ser
utilizado na análise numérica, na geração de evidências visuais e na repetição da demonstração da
interface.
