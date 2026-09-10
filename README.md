# Impacto do estresse térmico no desempenho — Sub-17 vs Sub-20

Análise do efeito do **estresse térmico ambiental (IBUTG / WBGT)** sobre o
desempenho físico e a carga interna de atletas de futebol das categorias de
base, comparando **Sub-17 e Sub-20**, por meio de **modelos lineares e
lineares generalizados mistos** (LMM / GLMM).

> Repositório de análise do LAFISE (UFMG). Dados de jogo desidentificados
> (atletas identificados por número). Repositório **privado**.

---

## Objetivo

Estimar como o IBUTG médio da partida se associa a indicadores de desempenho
externo (distância, velocidade, sprints, acelerações) e de carga interna
(PSE), e se essa associação **difere entre U17 e U20** — controlando posição
em campo e as medidas repetidas por atleta.

Pergunta central: *o calor penaliza mais o desempenho de uma categoria do que
da outra?* (termo de interação `IBUTG × categoria`).

---

## Dados

`dados-filtrados-60-40min.csv` — uma linha por atleta × jogo.

| | |
|---|---|
| Período | 11/03/2025 a 26/11/2025 |
| Amostra (U17 + U20) | **598 observações**, **53 atletas**, **33 jogos** |
| U17 | 24 atletas, 7 jogos, 132 obs |
| U20 | 30 atletas, 26 jogos, 466 obs |
| Competições | Brasileiro, Copa do Brasil, Mineiro |
| Filtro | tempo de jogo mínimo (~60 min U20 / ~40 min U17) — daí o nome do arquivo |
| IBUTG médio | 15,5 – 31,0 °C WBGT (mediana 23,0) |
| Duração em campo | 9 – 57 min (mediana 49) |

Variáveis-chave: `categoria`, `posicao`, `atleta`, `numero_jg`,
`duracao_total_min`, `IBUTG_med`, e os desfechos listados abaixo.
GPS/acelerometria por atleta; IBUTG é uma medida **de nível-jogo** (igual para
todos os atletas da mesma partida).

---

## Modelos (categoria final: U17 vs U20)

Um modelo por desfecho. Estrutura comum dos efeitos fixos:
`IBUTG_med_c * categoria + posicao`, com `IBUTG_med_c` = IBUTG **centrado na
média**. Efeito aleatório: `(1 | atleta)`. Referências: categoria = U20,
posição = ZAG.

| # | Desfecho | Variável | Distribuição | Situação |
|---|----------|----------|--------------|----------|
| 1 | Distância total por minuto | `distancia_total_min / duracao_total_min` | Gaussiana (LMM) | adequado |
| 2 | Velocidade máxima | `velocidade_max_kmh` (filtrando > 40 km/h) | Gaussiana (LMM) | adequado; **IBUTG não-linear** (adotar quadrático) |
| 3 | Nº de sprints | `sprint_25_kmh` + `offset(log(duração))` | Binomial negativa (GLMM) | adequado; IBUTG linear |
| 4 | DAI — distância em alta velocidade (> 19,8 km/h) | `soma_3_valoc19.8kmh` + `offset` | Gamma log (GLMM) | teste de dispersão ainda acusa — avaliar Tweedie |
| 5 | AAI — acelerações + desacelerações (> 3 m/s²) | `aceleracao_3_ms + desaceleracao_3_ms` + `offset` | Binomial negativa (GLMM) | adequado |
| 6 | PSE_UA — carga interna | `PSE_UA` (PSE de Borg × duração) | Gaussiana (LMM) | defensável; ideal seria CLMM ordinal |

**Relatório completo de cada regressão** (figuras, tabelas, diagnósticos e
decisões): [`modelo-comparacao-sub17-sub20/relatorios/`](modelo-comparacao-sub17-sub20/relatorios/).

---

## Principais decisões metodológicas

- **Exposição (duração 9–57 min):** contagens (sprint, AAI) e distância (DAI)
  entram como valor **bruto** com `offset(log(duracao_total_min))`, **não**
  divididos pela duração. Dividir e ajustar Gaussiana inflava a variância nos
  jogos curtos (heterocedasticidade) e ignorava a natureza discreta.
- **Escolha da família:** contagem sobredispersa → binomial negativa;
  distância positiva assimétrica → Gamma(log); contínua aproximadamente
  normal → LMM gaussiano.
- **Pressupostos:** avaliados com **DHARMa** (resíduos quantílicos por
  simulação), apropriado para modelos mistos — não com testes de normalidade
  nos resíduos brutos.
- **Limpeza:** `velocidade_max_kmh` tinha 3 registros fisicamente impossíveis
  (77,8 / 84,2 / 94,5 km/h) removidos.
- **Não-linearidade do IBUTG:** testada via spline (GAM) e polinômio. Só
  **velocidade máxima** mostra curvatura real (pico ~23 °C, queda acima de
  25 °C); nas demais a forma linear basta.

### Pendência importante

`IBUTG` é medido **por jogo** (~33 valores), mas há 598 linhas. Sem um efeito
aleatório de jogo `(1 | numero_jg)` a precisão do efeito do IBUTG fica
**superestimada** (pseudorreplicação). A análise exploratória mostrou que
incluir `(1 | numero_jg)` melhora o ajuste em 3 dos 6 modelos e faz o efeito
do IBUTG perder significância em vários. **Ainda não aplicado aos modelos
principais** — decisão em aberto.

---

## Estrutura do repositório

```
modelo-comparacao-categoria/        Análise inicial (U14/U17/U20 e U17/U20)
modelo-comparacao-sub17-sub20/      Análise final (U17 vs U20)
├── distancia-total-min.R  velocidade-max.R  spint.R
├── dai.R  aai.R  PSE-UA.R
├── velocidade-max_naolinear.R      linear vs quadrático (IBUTG)
├── sprint_naolinear.R              linear vs quadrático (IBUTG)
├── gerar_relatorios.R              gera os relatórios .md + figuras
└── relatorios/                     um .md por regressão (renderiza no GitHub)
    ├── README.md                   índice
    ├── 0X_*.md
    └── img/
analises-descritivas/               estatística descritiva
dados-filtrados-60-40min.csv        (uma cópia em cada pasta de modelos)
```

---

## Reproduzir

Requer **R >= 4.3**. Pacotes:

```r
install.packages(c(
  "lme4", "lmerTest", "glmmTMB", "DHARMa", "performance", "parameters",
  "sjPlot", "ggeffects", "ggplot2", "dplyr", "car", "see", "nortest",
  "mgcv", "knitr"
))
```

Rodar (a partir de `modelo-comparacao-sub17-sub20/`):

```bash
Rscript distancia-total-min.R      # cada regressão, isoladamente
Rscript velocidade-max_naolinear.R # comparação de forma do IBUTG
Rscript gerar_relatorios.R         # regenera relatorios/*.md e img/*.png
```

---

## Próximos passos

1. Decidir sobre `(1 | numero_jg)` nos 6 modelos principais.
2. Velocidade máxima: fixar a forma quadrática do IBUTG no script principal.
3. DAI: comparar Gamma vs **Tweedie**.
4. PSE_UA: avaliar *cumulative link mixed model* (`ordinal::clmm`) na PSE bruta.
