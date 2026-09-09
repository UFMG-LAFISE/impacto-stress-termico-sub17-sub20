# Impacto do estresse térmico no desempenho — Sub-17 vs Sub-20

Modelos mistos comparando desempenho físico e carga interna entre categorias
de base do futebol, em função do IBUTG (WBGT).

## Estrutura
- `modelo-comparacao-categoria/`   — análise inicial (U14/U17/U20 e U17/U20)
- `modelo-comparacao-sub17-sub20/` — análise final (U17 vs U20)
  - modelos por desfecho: distância/min, velocidade máx, sprint, DAI, AAI, PSE_UA
  - pressupostos via DHARMa
  - contagens (AAI, sprint) em binomial negativa com offset log(duração)
  - `*_naolinear.R` — testes de forma (linear vs quadrática) do efeito de IBUTG

## Requisitos R
lme4, lmerTest, glmmTMB, DHARMa, performance, sjPlot, dplyr, car, see, mgcv
