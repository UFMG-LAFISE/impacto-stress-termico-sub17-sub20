# Relatórios dos modelos — Sub-17 vs Sub-20

Um arquivo por regressão. Cada um traz especificação, decisões, coeficientes,
figuras (diagnóstico DHARMa e efeito do IBUTG), pressupostos, ajuste e conclusão.

> Descrição metodológica completa (linguagem científica): [METODOLOGIA.md](METODOLOGIA.md)

| # | Regressão | Distribuição | Arquivo |
|---|-----------|--------------|---------|
| 1 | Distância total / min | Gaussiana (LMM) | [01_distancia-total-min.md](01_distancia-total-min.md) |
| 2 | Velocidade máxima | Gaussiana (LMM) | [02_velocidade-max.md](02_velocidade-max.md) |
| 3 | Nº de sprints | Binomial negativa (GLMM) | [03_sprint.md](03_sprint.md) |
| 4 | DAI — distância alta velocidade | Gamma log (GLMM) | [04_dai.md](04_dai.md) |
| 5 | AAI — acel + desacel | Binomial negativa (GLMM) | [05_aai.md](05_aai.md) |
| 6 | PSE_UA — carga interna | Gaussiana (LMM) | [06_PSE-UA.md](06_PSE-UA.md) |

## Decisões transversais

- **Exposição (duração 9–57 min):** contagens (sprint, AAI) e distância (DAI) usam `offset(log(duração))` em vez de dividir pela duração.
- **Contagens** → binomial negativa; **distância positiva assimétrica** → Gamma(log); **contínuas ~normais** → LMM gaussiano.
- **Pressupostos** avaliados com **DHARMa** (resíduos quantílicos por simulação), não com testes nos resíduos brutos.
- **`(1 | numero_jg)` (efeito de jogo)** ainda não incluído nos modelos principais; a análise exploratória mostrou que muda a inferência sobre o IBUTG (que é medido por jogo).
- **Não-linearidade do IBUTG:** real e relevante só em **velocidade máxima**; nas demais, forma linear é suficiente.

