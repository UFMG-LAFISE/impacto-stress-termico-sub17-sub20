---
editor_options: 
  markdown: 
    wrap: 72
---

#Autor da metodologia de analise: Letícia Gontijo

# Metodologia estatística

Análise da associação entre estresse térmico ambiental e indicadores de
desempenho externo e de carga interna em atletas de futebol das
categorias Sub-17 (U17) e Sub-20 (U20).

------------------------------------------------------------------------

## 1. Delineamento e amostra

Trata-se de um estudo observacional com **medidas repetidas**, em que
cada unidade de observação corresponde a um atleta monitorado em uma
partida oficial. A amostra analisada compreende 598 observações
provenientes de 53 atletas distintos (24 com participações pela U17 e 30
pela U20; um atleta atuou nas duas categorias), distribuídos em 33
partidas (U17: 7; U20: 26) disputadas entre março e novembro de 2025 em
quatro competições. Foram analisadas apenas as observações com tempo de
participação compatível com a titularidade (aproximadamente ≥ 60 min na
U20 e ≥ 40 min na U17). A estrutura dos dados é, portanto, hierárquica,
com observações aninhadas em atletas e cruzadas com
partidas.

## 2. Variável de exposição ambiental

A exposição ao estresse térmico foi avaliada pelo **Índice de
Bulbo Úmido e Termômetro de Globo (IBUTG; *Wet-Bulb Globe Temperature*,
WBGT)** médio da partida (`IBUTG_med`), obtido a partir das temperaturas
de bulbo seco, bulbo úmido natural e de globo. O IBUTG é uma variável de
**nível-partida**: assume o mesmo valor para todos os atletas de um
mesmo jogo. Na amostra, o IBUTG variou de 15,5 a 31,0 °C (mediana 23,0
°C).

Para a modelagem, o IBUTG foi **centrado na média amostral**
(`IBUTG_med_c = IBUTG_med − média`), de modo que o intercepto e os
efeitos das demais covariáveis passam a ser interpretados na condição
térmica média e a colinearidade entre o termo linear e os termos de
interação é reduzida.

## 3. Variáveis-desfecho(DEPENDENTES)

Seis variaveis deéndentes foram modeladas separadamente, agrupados segundo sua
natureza estatística:

| Desfecho | Definição | Natureza |
|------------------------|------------------------|------------------------|
| Distância relativa | distância total ÷ tempo de jogo (m·min⁻¹) | contínua, aproximadamente simétrica |
| Velocidade máxima | pico de velocidade instantânea na partida (km·h⁻¹) | contínua; máximo por bloco |
| Nº de sprints | número de esforços acima de 25 km·h⁻¹ | contagem |
| DAI | distância percorrida acima de 19,8 km·h⁻¹ (m) | contínua positiva, assimétrica à direita |
| AAI | número de acelerações + desacelerações acima de 3 m·s⁻² | contagem (soma de duas contagens) |
| PSE_UA | percepção subjetiva de esforço (escala de Borg CR-10) × duração da sessão (u.a.) | escore composto, discreto |

## 4. Preparação dos dados

As variáveis categóricas `categoria` e `posicao` foram convertidas em
fatores, com níveis de referência definidos *a priori* (categoria: U20;
posição: zagueiro). Para a variável **velocidade máxima**, três
registros com valores fisiologicamente impossíveis para atletas de campo
(77,8; 84,2 e 94,5 km·h⁻¹; o quarto maior valor observado foi ≈ 35
km·h⁻¹) foram identificados como erros de medida e excluídos das
análises desse desfecho.

## 5. Especificação dos modelos

### 5.1 Estrutura geral

Cada desfecho foi analisado por meio de um **modelo misto** (linear —
LMM — ou linear generalizado — GLMM) com a seguinte estrutura de efeitos
fixos:

```         
variavel-dependente ~ IBUTG_med_c + categoria + IBUTG_med_c × categoria + posicao
```

e um **intercepto aleatório por atleta**, `(1 | atleta)`, que acomoda a
correlação entre observações do mesmo indivíduo. O termo de interação
`IBUTG_med_c × categoria` representa a hipótese central do estudo (
diferença entre U17 e U20 na resposta ao calor). A posição em campo foi
incluída como covariável de ajuste.

### 5.2 Distribuições e funções de ligação

A família de distribuição de cada modelo foi escolhida segundo a
natureza do desfecho:

| Desfecho | Família | Ligação | Justificativa |
|------------------|------------------|------------------|------------------|
| Distância relativa | Gaussiana | identidade | variável contínua, dispersão aproximadamente constante; resíduos compatíveis com normalidade |
| Velocidade máxima | Gaussiana | identidade | contínua; após a exclusão dos erros de medida, resíduos compatíveis com normalidade |
| Nº de sprints | Binomial negativa (NB2) | log | contagem com sobredispersão (variância ≈ 2 × média); Var(Y) = μ + μ²/θ |
| AAI | Binomial negativa (NB2) | log | contagem sobredispersa (ΔAIC ≈ 120 em favor da NB sobre Poisson) |
| DAI | Gamma | log | variável contínua estritamente positiva com assimetria à direita e variância crescente com a média |
| PSE_UA | Gaussiana | identidade | escore composto aproximadamente simétrico; melhor desempenho diagnóstico entre as alternativas testadas |

Os modelos gaussianos foram estimados por **máxima verossimilhança
restrita (REML)**; os GLMM, por **máxima verossimilhança (ML)** via
aproximação de Laplace.

### 5.3 Tratamento da exposição temporal

O tempo de participação variou entre observações (9–57
min), o que constitui uma **exposição desigual** para os desfechos
acumulados ao longo da partida (nº de sprints, AAI e DAI). Em vez de
dividir esses desfechos pela duração e modelar a razão resultante que descaracteriza a distribuição de contagem e induz
heterocedasticidade, já que Var(Y/t) ≈ Var(Y)/t² —, adotou-se um termo
de **deslocamento (*offset*)** igual ao logaritmo da duração,
`offset(log(duracao_total_min))`. Nessa formulação, o modelo estima
diretamente a **taxa** do evento por unidade de tempo, preservando a
família de distribuição apropriada. A suposição de proporcionalidade do
*offset* (coeficiente fixo igual a 1 na escala log) foi verificada
substituindo-o por um termo livre de `log(duração)`; as estimativas
resultantes não diferiram de 1 de forma relevante (≈ 0,99–1,08).

### 5.4 Avaliação de não-linearidade do efeito do IBUTG

A hipótese de efeito **não linear** do IBUTG foi investigada por duas
vias complementares, mantendo-se a família e a estrutura de efeitos
aleatórios de cada desfecho:

1.  **Modelos aditivos generalizados (GAM)** com *spline* de regressão
    de placa fina penalizado para o IBUTG, `s(IBUTG_med_c)`, e efeitos
    aleatórios especificados como *splines* de penalização
    (`s(atleta, bs = "re")`). A curvatura foi quantificada pelos **graus
    de liberdade efetivos (edf)**: edf próximo de 1 indica efeito
    linear; edf substancialmente superior a 1 indica curvatura.
2.  **Contraste polinomial paramétrico**: comparação, por **teste da
    razão de verossimilhanças (TRV)**, entre o modelo com IBUTG linear e
    o modelo com um polinômio de 2º grau (`poly(IBUTG_med_c, 2)`),
    incluindo a respectiva interação com categoria.

Ambas as análises foram repetidas **com e sem** um intercepto aleatório
por partida, `(1 | numero_jg)`, para distinguir curvatura genuína de
artefato decorrente da pseudorreplicação da exposição.

## 6. Verificação de pressupostos

Os pressupostos dos modelos foram avaliados por meio de **resíduos
quantílicos aleatorizados por simulação** (pacote DHARMa), abordagem
apropriada para modelos mistos e para famílias não gaussianas, uma vez
que os resíduos brutos de GLMM não seguem distribuição conhecida. Para
cada modelo foram geradas 1000 simulações da resposta a partir do modelo
ajustado; sob especificação correta, os resíduos escalonados seguem
distribuição uniforme(0, 1). Foram aplicados:

-   **Uniformidade** dos resíduos escalonados — teste de
    Kolmogorov–Smirnov (equivalente à checagem de normalidade);
-   **Dispersão** — teste não paramétrico comparando a dispersão
    observada à simulada (detecção de sub/sobredispersão);
-   **Valores atípicos** — teste com calibração por *bootstrap*;
-   **Homocedasticidade / forma funcional** — teste de constância dos
    quantis 0,25, 0,50 e 0,75 dos resíduos ao longo dos valores
    previstos, estimados por regressão quantílica aditiva (`qgam`).

Adotou-se α = 0,05 para sinalização de violação; a inspeção gráfica dos
*QQ-plots* e dos resíduos contra valores previstos e contra cada
covariável complementou os testes formais.

## 7. Colinearidade

A multicolinearidade entre os termos de efeito fixo foi avaliada pelo
**fator de inflação da variância (VIF)**, computado para modelos mistos.
Valores de VIF inferiores a 5 foram considerados aceitáveis.

## 8. Comparação e ajuste dos modelos

A comparação entre especificações concorrentes (p. ex. forma linear vs.
quadrática do IBUTG; famílias alternativas) baseou-se no **Critério de
Informação de Akaike (AIC)**, no **Critério de Informação Bayesiano
(BIC)** e, para modelos aninhados, no **teste da razão de
verossimilhanças**. Para comparações que envolveram diferenças na parte
de efeitos fixos, os modelos lineares mistos foram reajustados por
**máxima verossimilhança (ML)**, dado que o AIC calculado sob REML não é
comparável nessas condições.

O ajuste de cada modelo foi descrito pelo **coeficiente de correlação
intraclasse (CCI)** ao nível do atleta e pelo **R² marginal e
condicional** de Nakagawa & Schielzeth (variância explicada pelos
efeitos fixos e pelo modelo completo, respectivamente).

## 9. Apresentação e inferência dos efeitos

A significância dos efeitos fixos foi avaliada por testes de Wald; nos
modelos lineares mistos, os graus de liberdade foram aproximados pelo
método de Satterthwaite. Os coeficientes são apresentados com
**intervalos de confiança de 95%**. Nos modelos gaussianos, as
estimativas estão na escala da resposta; nos modelos com ligação log
(NB2 e Gamma), as estimativas são apresentadas **exponenciadas**,
correspondendo a **razões de taxas de incidência (IRR)** (contagens)
ou a razões multiplicativas, Gamma , isto é, a variação multiplicativa
esperada no desfecho por unidade do preditor.

Os efeitos ajustados do IBUTG foram ilustrados por **predições
marginais** (valores previstos ao longo da faixa observada de IBUTG, com
as demais covariáveis fixadas em seus níveis/valores de referência e o
*offset*, quando presente, fixado em 90 minutos), acompanhadas de bandas
de confiança de 95%.

## 10. Análise de sensibilidade planejada: efeito aleatório de partida

Como o IBUTG é uma variável de nível-partida (33 valores distintos para
598 observações), os modelos com intercepto aleatório apenas por atleta
**subestimam o erro-padrão do efeito do IBUTG** (pseudorreplicação da
exposição). Está prevista uma análise de sensibilidade com a inclusão de
um segundo intercepto aleatório, por partida ->
`(1 | atleta) + (1 | numero_jg)` <-, que faz o erro-padrão do IBUTG
refletir o número efetivo de unidades independentes de exposição.
Análises exploratórias indicaram que essa inclusão melhora o ajuste
(redução de AIC) em parte dos desfechos e atenua a magnitude e a
significância do efeito do IBUTG, além de eliminar a curvatura aparente
em vários deles.

## 11. Software

Todas as análises foram conduzidas em **R** (versão 4.3.3). Os modelos
lineares mistos foram ajustados com `lme4` (1.1) e `lmerTest` (3.1); os
modelos lineares generalizados mistos, com `glmmTMB` (1.1). O
diagnóstico de resíduos utilizou `DHARMa` (0.4.7); os modelos aditivos,
`mgcv` (1.9); o VIF, o CCI e o R², o pacote `performance` (0.16); as
tabelas de coeficientes, `parameters` (0.28); e as predições marginais,
`ggeffects` (2.3). O nível de significância adotado foi de 5%.

------------------------------------------------------------------------

### Referências metodológicas

-   Bates D, Mächler M, Bolker B, Walker S. *Fitting Linear
    Mixed-Effects Models Using lme4*. J Stat Softw. 2015;67(1):1–48.
-   Brooks ME et al. *glmmTMB Balances Speed and Flexibility Among
    Packages for Zero-inflated Generalized Linear Mixed Modeling*. R J.
    2017;9(2):378–400.
-   Hartig F. *DHARMa: Residual Diagnostics for Hierarchical
    (Multi-Level / Mixed) Regression Models*. R package, 2022.
-   Nakagawa S, Schielzeth H. *A general and simple method for obtaining
    R² from generalized linear mixed-effects models*. Methods Ecol Evol.
    2013;4(2):133–142.
-   Wood SN. *Generalized Additive Models: An Introduction with R*. 2nd
    ed. CRC Press; 2017.
