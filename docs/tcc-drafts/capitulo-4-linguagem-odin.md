# Extensão do Capítulo 4 — Linguagem Odin

> **Posição sugerida:** inserir o texto como uma nova subseção após a introdução do Capítulo 4 e
> antes da atual Seção 4.1 — Modelagem. A numeração pode ser definida durante a integração com a
> fonte do TCC.

## Linguagem de programação Odin

O núcleo da simulação foi desenvolvido na linguagem de programação Odin. Trata-se de uma linguagem
de propósito geral voltada à programação de sistemas, com tipagem estática e compilação nativa. Sua
proposta enfatiza simplicidade, controle sobre a representação dos dados e proximidade com os
recursos da máquina, mantendo construções destinadas à organização de aplicações contemporâneas
(Odin, 2026a, 2026b). Essas características foram consideradas compatíveis com o desenvolvimento de
uma engine de simulação, na qual a estrutura dos dados, a realização de operações numéricas e o
controle das alocações possuem relação direta com o comportamento do programa.

A escolha de Odin também esteve relacionada ao caráter experimental do projeto. A implementação de
um motor de N-corpos requer a representação explícita de corpos, vetores, configurações e estruturas
espaciais, além da execução repetida de operações sobre essas informações. Em Odin, esses elementos
podem ser descritos por estruturas e procedimentos sem a necessidade de uma hierarquia de classes.
No Sanxing, por exemplo, cada corpo é representado por uma estrutura que reúne identificador, massa,
posição, velocidade e aceleração. Os vetores bidimensionais são compostos por duas coordenadas de
ponto flutuante de 64 bits, enquanto o estado da simulação associa a coleção de corpos ao passo e ao
tempo atuais.

A linguagem organiza os arquivos em pacotes definidos por diretórios. Esse mecanismo foi utilizado
para dividir a engine segundo as responsabilidades de cada componente. Os tipos compartilhados e a
coordenação dos passos foram mantidos no pacote central; os cálculos gravitacionais foram reunidos
no pacote de *solvers*; a quadtree foi isolada no pacote espacial; e a integração temporal, a entrada
de dados, a exportação e os recursos experimentais foram implementados em pacotes próprios. Essa
organização contribuiu para que o método de força bruta e o Barnes-Hut compartilhassem o mesmo modelo
de dados e o mesmo integrador, sem concentrar toda a implementação em um único módulo.

Outro aspecto utilizado no projeto foi a definição de procedimentos como tipos. A engine estabelece
um contrato para os *solvers*, segundo o qual cada implementação recebe os corpos, a configuração da
simulação e, opcionalmente, uma estrutura de contadores. De forma semelhante, o integrador é
representado por um procedimento responsável por atualizar os corpos a partir da configuração. Com
isso, o ciclo principal pode receber o *solver* e o integrador selecionados sem incorporar diretamente
os detalhes de cada algoritmo. Essa solução favorece a extensibilidade da arquitetura e permite que
novos métodos sejam acrescentados mantendo a separação entre cálculo das acelerações e atualização
do estado.

Odin adota gerenciamento manual de memória e disponibiliza mecanismos de alocação associados ao
contexto de execução (Odin, 2026b). No desenvolvimento da quadtree, os nós são criados conforme a
subdivisão do espaço e liberados após o término do cálculo correspondente. As coleções dinâmicas
utilizadas para armazenar índices de corpos também possuem seu ciclo de vida encerrado
explicitamente. Embora essa abordagem exija atenção do desenvolvedor, ela torna visíveis as etapas
de criação e destruição das estruturas temporárias usadas pelo *solver*. Para reduzir falhas nesse
processo, os testes da engine são executados com os mecanismos de verificação disponibilizados pelo
ambiente de testes da linguagem.

A biblioteca padrão de Odin foi suficiente para o núcleo da aplicação e para a infraestrutura de
experimentos. Foram utilizados recursos dos pacotes oficiais para operações matemáticas, leitura e
escrita de arquivos, processamento de JSON, formatação de texto, medição de tempo e testes
automatizados. Dessa forma, a engine não depende de um framework externo para interpretar as
configurações, executar os algoritmos ou exportar os resultados. A redução do número de dependências
também simplifica a preparação do ambiente empregado nos experimentos, pois a versão do compilador
e os comandos de execução podem ser registrados juntamente com os demais dados de proveniência.

O compilador fornece comandos próprios para verificar, testar, compilar e executar pacotes. Durante
o desenvolvimento, `odin check` foi utilizado para validar a engine sem iniciar uma simulação, e
`odin test` foi empregado sobre os diferentes pacotes de testes. Para as execuções experimentais, o
programa é compilado com o modo de otimização voltado à velocidade. A configuração utilizada em
cada coleta, incluindo a versão do compilador e o modo de otimização, é armazenada no manifesto dos
resultados para permitir a identificação do ambiente em que as medições foram produzidas.

Apesar de Odin apresentar recursos destinados a software de alto desempenho, a escolha da linguagem
não é utilizada como prova de que o Sanxing possui desempenho superior a outras ferramentas. Uma
afirmação desse tipo dependeria de uma comparação que controlasse o algoritmo, as condições iniciais,
o integrador, a precisão numérica, a compilação e o trabalho efetivamente executado. Neste projeto,
o desempenho é avaliado principalmente pela comparação entre força bruta e Barnes-Hut dentro da
própria engine. Essa estratégia mantém constantes a linguagem, o modelo físico, o integrador e os
dados de entrada, permitindo observar com maior controle o efeito da decomposição espacial.

Por fim, a adoção de Odin deve ser compreendida tanto como uma decisão técnica quanto como parte do
processo de investigação do trabalho. A linguagem ofereceu os recursos necessários para implementar
o núcleo numérico, organizar os componentes, construir a estrutura espacial e gerar os arquivos de
reprodução. Ao mesmo tempo, o uso de uma tecnologia menos difundida exige documentar de forma
explícita a versão do compilador, os comandos empregados e as dependências do ambiente. Esses
registros são necessários para que os resultados do Sanxing possam ser repetidos e avaliados
independentemente das expectativas associadas à linguagem escolhida.
