# regressão 5b - sprint (U17 vs U20)
# Compara a forma do efeito de IBUTG: LINEAR vs QUADRATICO.
# Contexto: no GAM (spline penalizado) com efeito aleatorio de jogo, s(IBUTG) deu
# edf ~2,1 (p = 0,008) -> sinal de curvatura (queda que acelera acima de ~24-25 C).
# Aqui testamos se uma forma QUADRATICA parametrica captura esse sinal:
# se anova(modelo_lin, modelo_quad) nao for significativo, a forma linear basta
# (o spline pode estar vendo um "platô-e-queda" que a parabola nao reproduz).
# Este script NAO substitui spint.R; e a versao para avaliar a nao-linearidade.

# importando bibliotecas--------------------------------------------------------
library(lme4)
library(lmerTest)
library(dplyr)
library(car)
library(sjPlot)
library(performance)
library(see)
library(DHARMa)
library(glmmTMB)

# importando bases de dados-----------------------------------------------------
dados <- read.csv("dados-filtrados-60-40min.csv" , sep = ",")

# tratamento de bases de dados--------------------------------------------------
# Filtrar apenas U20 e U17
dados <- dados %>%
  filter(categoria %in% c("U20", "U17"))
dados$categoria <- droplevels(as.factor(dados$categoria))
dados$categoria <- as.factor(dados$categoria)
dados$posicao   <- as.factor(dados$posicao)
dados$jogo      <- as.factor(dados$numero_jg)          # efeito aleatorio de jogo
dados$IBUTG_med_c  <- as.numeric(scale(dados$IBUTG_med, center = TRUE, scale = FALSE))
dados$logdur    <- log(dados$duracao_total_min)       # offset pre-transformado
dados$posicao   <- relevel(factor(dados$posicao), ref = "ZAG")
dados$categoria <- relevel(factor(dados$categoria), ref = "U20")

# modelos --------------------------------------------------------------------
# sprint_25_kmh e CONTAGEM -> binomial negativa (nbinom2) com offset log(duracao).
# Efeitos aleatorios cruzados: atleta e jogo. IBUTG e variavel de nivel-jogo,
# por isso (1 | jogo) e necessario.

# (a) IBUTG LINEAR
modelo_lin <- glmmTMB(
  sprint_25_kmh ~
    IBUTG_med_c +
    categoria +
    IBUTG_med_c:categoria +
    posicao +
    offset(logdur) +
    (1 | atleta) +
    (1 | jogo),
  family = nbinom2,
  data = dados
)

# (b) IBUTG QUADRATICO  (poly grau 2; raw = TRUE mantem os coeficientes na escala
#     de IBUTG e faz o modelo linear ficar aninhado neste)
modelo_quad <- glmmTMB(
  sprint_25_kmh ~
    poly(IBUTG_med_c, 2, raw = TRUE) +
    categoria +
    poly(IBUTG_med_c, 2, raw = TRUE):categoria +
    posicao +
    offset(logdur) +
    (1 | atleta) +
    (1 | jogo),
  family = nbinom2,
  data = dados
)

# comparacao ----------------------------------------------------------------
# glmmTMB ajusta por ML: AIC(modelo_lin) e AIC(modelo_quad) sao comparaveis.
cat("\nAIC linear    :", AIC(modelo_lin),
    "\nAIC quadratico :", AIC(modelo_quad),
    "\ndAIC (quad - lin):", AIC(modelo_quad) - AIC(modelo_lin),
    "  (negativo => quadratico melhor)\n")

# Teste da razao de verossimilhanca do termo quadratico
cat("\nLinear vs quadratico (LRT):\n")
print(anova(modelo_lin, modelo_quad))

# Tabela lado a lado (para contagem, tab_model mostra IRR = exp(Beta))
tab_model(
  modelo_lin, modelo_quad,
  show.re.var = TRUE,
  show.icc = TRUE,
  show.stat = TRUE,
  p.style = "numeric_stars",
  dv.labels = c("Sprint - IBUTG linear", "Sprint - IBUTG quadrático"),
  string.pred = "Preditores",
  string.est = "IRR (exp Beta)",
  title = "Tabela. Nº de sprints (NB2): forma linear vs quadrática do efeito de IBUTG"
)

# curva do efeito de IBUTG no modelo quadratico
print(
  plot_model(modelo_quad, type = "pred", terms = "IBUTG_med_c [all]", condition = c(logdur = 0),
             title = "Efeito predito de IBUTG (centrado) sobre a taxa de sprints")
)

##################################################################
### Análise de pressupostos via DHARMa

run_model_diagnostics <- function(model_object, model_name) {

  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))

  cat(paste0("\n=============================="))
  cat(paste0("\nPressupostos (DHARMa) - ", model_name))
  cat(paste0("\n==============================\n"))

  set.seed(123)
  sim <- simulateResiduals(fittedModel = model_object, n = 1000)

  plot(sim)

  cat("\n--- Uniformidade / normalidade dos residuos (KS) ---\n")
  print(testUniformity(sim, plot = FALSE))

  cat("\n--- Dispersao (sobre/subdispersao) ---\n")
  print(testDispersion(sim, plot = FALSE))

  cat("\n--- Outliers (bootstrap) ---\n")
  print(testOutliers(sim, type = "bootstrap", plot = FALSE))

  cat("\n--- Homocedasticidade / forma (quantis vs preditos) ---\n")
  print(testQuantiles(sim, plot = FALSE))

  cat("\n--- Residuos vs preditores ---\n")
  dados_mod   <- tryCatch(insight::get_data(model_object), error = function(e) NULL)
  preditores  <- c("IBUTG_med_c", "categoria", "posicao")
  if (!is.null(dados_mod)) {
    for (p in intersect(preditores, names(dados_mod))) {
      plotResiduals(sim, form = dados_mod[[p]],
                    xlab = p, main = paste("Residuos vs", p, "-", model_name))
    }
  }

  invisible(sim)
}

modelos <- list(
  linear     = modelo_lin,
  quadratico = modelo_quad
)

for (nome in names(modelos)) {
  run_model_diagnostics(modelos[[nome]], nome)
}

# =========================
# Teste de colinearidade
# =========================
check_collinearity(modelo_lin)
check_collinearity(modelo_quad)
