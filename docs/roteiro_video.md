# Roteiro — Cloud Architecture Security Analyzer (Vídeo YouTube)

> **Formato:** Gravação de tela + narração lida em voz alta.
> Cada seção indica **o que mostrar na tela** e **o que falar**.

---

## CENA 1 — Abertura (≈ 30 s)

**Tela:** Slide de abertura ou tela inicial do projeto (README no VS Code).

**Fala:**

> Fala pessoal! Neste vídeo vou apresentar o nosso MVP do módulo de Cloud, Arquitetura e Segurança da FIAP: o **Cloud Architecture Security Analyzer**.
>
> A ideia é simples e poderosa: você faz upload de um diagrama de arquitetura cloud — pode ser AWS, Azure ou GCP — e a aplicação detecta automaticamente cada componente usando visão computacional, e em seguida aplica a metodologia **STRIDE** para identificar ameaças e sugerir mitigações.
>
> Tudo isso rodando 100% local, sem depender de API externa, sem custo por requisição.

---

## CENA 2 — O Problema e a Motivação (≈ 45 s)

**Tela:** Diagrama de arquitetura de exemplo (uma imagem com vários componentes AWS).

**Fala:**

> Quando a gente desenha uma arquitetura cloud, normalmente a análise de segurança é feita manualmente — um especialista olha componente por componente, identifica possíveis ameaças e propõe controles. Isso é demorado, caro e depende de experiência.
>
> Existem soluções baseadas em LLMs, chamando GPT ou Claude via API pra analisar diagramas, mas isso tem um custo operacional contínuo — cada análise consome tokens, e em ambiente corporativo isso escala rápido.
>
> A nossa proposta elimina esse custo: usamos um modelo YOLO treinado localmente para a detecção, e uma base de conhecimento STRIDE embutida no código para a análise de ameaças. O custo operacional é praticamente zero depois do deploy.

---

## CENA 3 — O Dataset e a Preparação (≈ 1 min)

**Tela:** Abrir o arquivo `script/prepare_dataset.py` no VS Code. Mostrar a pasta `data/`.

**Fala:**

> Tudo começa pelo dataset. Nós utilizamos um dataset do Kaggle com diagramas de arquitetura cloud anotados em formato Pascal VOC — ou seja, XMLs com bounding boxes.
>
> Só que o dataset bruto não estava pronto pra treinar. Então criamos o script `prepare_dataset.py`, que faz o seguinte pipeline:
>
> Primeiro, extrai o dataset do Kaggle a partir de um ZIP.
> Segundo, converte as anotações de LabelMe JSON para Pascal VOC XML.
> Terceiro, mescla as nossas anotações customizadas — nós anotamos diagramas nossos manualmente com o LabelMe para complementar.
> Por fim, empacota tudo num ZIP pronto pra upload no Google Drive.
>
> Além disso, temos o `analyze_dataset.py`, que gera estatísticas: quantas anotações por classe, qual o desbalanceamento, quais classes têm poucas amostras. Isso foi essencial pra entender que o dataset original tinha mais de 60 classes granulares — como `aws_amazon_ec2`, `azure_virtual_machines` — e precisávamos simplificar.

**Tela:** Abrir `script/analyze_dataset.py` e mostrar as funções `count_classes_in_labels` e o trecho de top 20 classes.

---

## CENA 4 — O Treinamento no Google Colab (≈ 1 min 30 s)

**Tela:** Abrir `notebooks/train_colab.ipynb` no VS Code.

**Fala:**

> O treinamento foi feito no Google Colab, e aqui tivemos um dos maiores desafios do projeto: o **free tier**.
>
> No plano gratuito, o Colab te dá uma GPU T4 com limitação de tempo — geralmente 4 a 6 horas por sessão, e depois pode desconectar a qualquer momento. Se o treinamento cai no meio, você perde tudo.
>
> Para superar isso, implementamos um sistema de **checkpoints no Google Drive**. A cada 5 épocas, o modelo salva automaticamente o `last.pt` e o `best.pt` no Drive. Quando reconecta, o notebook detecta o checkpoint e **retoma** o treinamento de onde parou, com a flag `resume=True` do YOLO.
>
> Outro ponto importante: a decisão do modelo. Inicialmente consideramos o YOLOv11, e depois migramos para o YOLOv8n — a versão nano. Essa escolha foi estratégica: o modelo nano é leve o suficiente pra treinar no free tier dentro do tempo limite, e ainda assim entrega boa acurácia pra detecção de ícones em diagramas.

**Tela:** Scroll pelo notebook mostrando: montagem do Drive, checkpoint, e parâmetros do `model.train()`.

**Fala:**

> Aqui vocês podem ver os hiperparâmetros: 150 épocas, batch 16, imagem 640, optimizer AdamW, com augmentação moderada — mosaico, flip, mistura. Também usamos cosine learning rate e warmup de 3 épocas.
>
> Uma etapa essencial foi o **mapeamento de categorias**. O dataset tinha mais de 60 classes do Kaggle, e nós mapeamos tudo para 15 categorias alinhadas ao STRIDE: compute, database, storage, network, security, api_gateway, messaging, monitoring, identity, ml_ai, devops, serverless, analytics, groups e other. Isso simplifica a saída do modelo e permite que a engine STRIDE trabalhe com categorias bem definidas.

**Tela:** Mostrar o dicionário `CATEGORY_MAPPING` no notebook, com os nomes AWS/Azure/GCP.

> Ao final do treinamento, o notebook roda uma validação automática: calcula mAP50, precisão e recall por categoria, e testa visualmente em imagens do test set com bounding boxes. O modelo final — o `best.pt` — é salvo no Drive e depois copiado pra pasta `models/` do projeto local.

---

## CENA 5 — Arquitetura do Projeto (≈ 1 min 30 s)

**Tela:** Mostrar a árvore de pastas no VS Code (Explorer), abrindo cada pasta.

**Fala:**

> Agora vamos falar da arquitetura do projeto em si. Uma das coisas que mais investimos foi na organização e nas boas práticas de engenharia de software.
>
> O projeto segue uma estrutura modular bem definida. Vou percorrer cada pasta:
>
> **`config/`** — Configurações centralizadas. O `settings.py` usa **dataclasses frozen** pra garantir imutabilidade: `ModelConfig`, `TrainingConfig`, `DatabaseConfig` e `AppConfig`. Todas as credenciais do banco leem de variáveis de ambiente via **dotenv**, nunca ficam hardcoded no código.

**Tela:** Abrir `config/settings.py`.

> **`src/detection/`** — O módulo de detecção. O `detector.py` encapsula o YOLO com lazy loading — o modelo só carrega quando a primeira detecção é requisitada. Usa dataclasses `Detection` e `DetectionResult` com tipagem forte. Depois da detecção, gera automaticamente a imagem anotada com bounding boxes usando o `result.plot()` do Ultralytics.

**Tela:** Abrir `src/detection/detector.py`.

> **`src/stride/`** — O coração da análise. São três arquivos:
>
> - `categories.py` — Um enum `ComponentCategory` com 15 categorias e um dicionário de mais de 100 componentes mapeados. O `CategoryClassifier` faz match exato ou parcial, case-insensitive.
> - `knowledge_base.py` — A base de ameaças. Cada categoria tem uma lista de `ThreatRisk` com tipo STRIDE, detalhamento e mitigação. São dataclasses frozen, imutáveis.
> - `engine.py` — O motor que orquestra tudo. Recebe uma lista de componentes, classifica cada um, busca as ameaças na knowledge base, calcula score de risco de 0 a 100, e retorna um relatório completo.

**Tela:** Abrir `src/stride/engine.py` e `src/stride/knowledge_base.py` brevemente.

> **`src/database.py`** — Camada de persistência com PostgreSQL. O `AnalysisRepository` usa context managers pra gerenciamento seguro de conexão, com commit automático e rollback em caso de erro. Salva análises, recupera histórico, e tem até delete de registros.

**Tela:** Abrir `src/database.py`.

> **`src/app.py`** — A interface web, construída com Streamlit. Upload de imagem, slider de confiança, exibição da imagem com bounding boxes, análise STRIDE expandível por componente, export JSON, e histórico com opção de deletar na sidebar.

**Tela:** Abrir `src/app.py`.

---

## CENA 6 — Infraestrutura e DevOps (≈ 1 min)

**Tela:** Abrir `docker-compose.yml`, depois `Makefile`, depois `pyproject.toml`.

**Fala:**

> A infraestrutura é toda containerizada. O `docker-compose.yml` sobe um PostgreSQL 16 Alpine com healthcheck, volume persistente e inicialização automática do schema via `init_db.sql`.
>
> O `Makefile` — que funciona tanto no Linux quanto no Windows — oferece comandos padronizados. O `make dev` instala tudo incluindo ferramentas de desenvolvimento. O `make test` roda os testes. O `make lint` roda o Ruff pra linting e formatação. O `make run` sobe o Streamlit com um comando. O `make db-up` e `make db-down` controlam o Docker.
>
> O `pyproject.toml` centraliza toda a configuração do projeto: metadados, dependências, configurações do Ruff, MyPy com strict mode, e pytest com coverage automático. Os comandos de clean no Makefile usam Python puro — `shutil` e `pathlib` — pra funcionar em qualquer sistema operacional.

---

## CENA 7 — Testes e Qualidade (≈ 45 s)

**Tela:** Rodar `pytest` no terminal mostrando os 71 testes passando.

**Fala:**

> Qualidade é pilar desse projeto. Temos **71 testes automatizados** divididos em três arquivos:
>
> - `test_detector.py` — Testa a criação de detecções, imutabilidade do frozen dataclass, nomes únicos, contagem e tratamento de modelo ausente.
> - `test_knowledge_base.py` — Testa criação de `ThreatRisk`, imutabilidade, `to_dict`, e faz testes parametrizados de integridade — verifica que todas as 15 listas de ameaças são não-vazias e têm severidades válidas.
> - `test_stride_engine.py` — Testa o classificador de categorias com match exato, parcial, case-insensitive, componentes desconhecidos, e testa o engine completo: análise individual, análise de arquitetura, cálculo de risco, mapeamento de risk level, e garante que todas as categorias do enum têm um profile definido.

**Tela:** Mostrar o output do pytest com todas as barras verdes e a cobertura: `categories.py` 100%, `knowledge_base.py` 100%, `engine.py` 92%.

> A cobertura dos módulos críticos é alta: `categories.py` e `knowledge_base.py` com 100%, `engine.py` com 92%. Os módulos com 0% são o `app.py` e o `database.py`, que dependem de runtime do Streamlit e do banco — eles seriam cobertos por testes de integração.

---

## CENA 8 — Demonstração ao Vivo (≈ 1 min 30 s)

**Tela:** Terminal rodando `make db-up`, depois `make run`. Streamlit abre no navegador.

**Fala:**

> Agora vamos ver funcionando na prática. Primeiro, subo o banco de dados com `make db-up` — ele sobe o container PostgreSQL. Depois, `make run` — que executa `streamlit run src/app.py`.

**Tela:** Navegador com a interface do Streamlit.

> Aqui na interface, temos a sidebar com o slider de confiança mínima, o histórico de análises anteriores — onde podemos deletar individualmente — e as informações sobre o modelo.
>
> Vou fazer upload de um diagrama de arquitetura AWS...

**Tela:** Arrastar uma imagem de diagrama para o uploader.

> O diagrama original aparece à esquerda. Agora clico em "Analisar Arquitetura"...

**Tela:** Clicar no botão e esperar o resultado.

> Pronto! À esquerda agora temos a imagem com os **bounding boxes** — cada componente detectado pelo YOLO está marcado com a categoria e a confiança. À direita, o resultado da análise STRIDE.
>
> Vejam as métricas no topo: total de componentes, score de risco e nível de risco. Abaixo, cada componente tem sua análise expandível — mostrando as categorias STRIDE aplicáveis, o tipo de elemento no diagrama de ameaças, e cada risco com severidade, detalhamento e mitigação sugerida.
>
> Aqui embaixo temos a tabela de detecções do modelo com confiança e coordenadas. E também o JSON exportável com toda a análise, que pode ser integrado em pipelines de CI/CD ou relatórios.
>
> A análise já foi salva automaticamente no banco — vejam o toast de confirmação. E ela aparece no histórico da sidebar, onde eu posso deletar se quiser.

---

## CENA 9 — Vantagens e Diferenciais (≈ 1 min)

**Tela:** Slide ou README aberto com bullet points.

**Fala:**

> Pra fechar, quero destacar os principais diferenciais e vantagens desse projeto:
>
> **Custo operacional zero.** Depois do deploy, não há chamada de API, não há consumo de tokens. Não usamos LLM externa. Toda a inteligência está no modelo YOLO treinado e na base de conhecimento STRIDE local. Numa empresa, isso significa poder rodar milhares de análises por dia sem custo adicional.
>
> **Privacidade total.** Nenhum diagrama sai da sua máquina. Pra empresas que trabalham com arquiteturas sensíveis, isso é crítico — não há exposição de propriedade intelectual pra servidores de terceiros.
>
> **Portabilidade.** Roda em Windows e Linux. O Makefile é cross-platform, o Docker cuida do banco, e o Python cuida do resto.
>
> **Modularidade profissional.** Cada preocupação está no seu arquivo: configuração, detecção, categorização, base de ameaças, engine de análise, persistência, interface. Isso facilita manutenção, extensão e onboarding de novos desenvolvedores.
>
> **Qualidade garantida.** 71 testes unitários, cobertura nos módulos críticos, linting com Ruff, type-checking com MyPy em modo strict, e pyproject.toml moderno.
>
> **Multi-cloud.** O mapeamento de componentes suporta mais de 100 serviços de AWS, Azure e GCP. O modelo foi treinado com diagramas dos três provedores.
>
> **Extensível.** Pra adicionar novas categorias ou ameaças, basta editar a knowledge base. Pra retreinar o modelo com novos componentes, basta o notebook do Colab. Não precisa mexer em nenhuma lógica de negócio.

---

## CENA 10 — Encerramento (≈ 20 s)

**Tela:** README do projeto ou tela do GitHub.

**Fala:**

> É isso, pessoal. Esse foi o nosso Cloud Architecture Security Analyzer — detecção com YOLO, análise com STRIDE, tudo local, profissional e open-source.
>
> Se curtiram, deixa o like, se inscreve no canal, e qualquer dúvida deixa nos comentários.
>
> Valeu!

---

## Resumo de Tempos

| Cena | Conteúdo | Duração |
|------|----------|---------|
| 1 | Abertura | 30 s |
| 2 | Problema e motivação | 45 s |
| 3 | Dataset e preparação | 1 min |
| 4 | Treinamento no Colab | 1 min 30 s |
| 5 | Arquitetura do projeto | 1 min 30 s |
| 6 | Infraestrutura e DevOps | 1 min |
| 7 | Testes e qualidade | 45 s |
| 8 | Demonstração ao vivo | 1 min 30 s |
| 9 | Vantagens e diferenciais | 1 min |
| 10 | Encerramento | 20 s |
| **Total** | | **≈ 9 min 50 s** |
