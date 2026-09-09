# regressão 3b - velocidade máxima (U17 vs U20)
# Compara a forma do efeito de IBUTG: LINEAR vs QUADRATICO.
# Motivo: no GAM com efeito aleatorio de jogo, s(IBUTG) tem edf ~3,6 (p = 0,007)
# para velocidade maxima -> ha curvatura real (sobe ate ~23-24 C, cai acima de 25 C).
# Este script NAO substitui velocidade-max.R; e a versao para avaliar a nao-linearidade.

# importando bibliotecas--------------------------------------------------------
library(lme4)
library(lmerTest)
library(dplyr)
library(car)
library(sjPlot)
library(performance)
library(see)
library(DHARMa)

# importando bases de dados-----------------------------------------------------
dados <- read.csv("dados-filtrados-60-40min.csv" , sep = ",")

# tratamento de bases de dados-------------------------------------------------
# Filtrar apenas U20 e U17
dados <- dados %>%
  filter(categoria %in% c("U20", "U17"))

# Limpeza: remove velocidades maximas fisicamente impossiveis (erros de medida).
# 3 registros com > 40 km/h (77,8 / 84,2 / 94,5); o 4o maior valor real e ~35 km/h.
dados <- dados %>%
  filter(velocidade_max_kmh <= 40)

dados$categoria <- droplevels(as.factor(dados$categoria))
dados$categoria <- as.factor(dados$categoria)
dados$posicao   <- as.factor(dados$posicao)
dados$jogo      <- as.factor(dados$numero_jg)          # efeito aleatorio de jogo
dados$IBUTG_med_c  <- as.numeric(scale(dados$IBUTG_med, center = TRUE, scale = FALSE))
dados$posicao   <- relevel(factor(dados$posicao), ref = "ZAG")
dados$categoria <- relevel(factor(dados$categoria), ref = "U20")

# modelos --------------------------------------------------------------------
# Efeitos aleatorios cruzados: atleta e jogo. IBUTG e uma variavel de nivel-jogo,
# por isso (1 | jogo) e necessario para nao superestimar a precisao do efeito.

# (a) IBUTG LINEAR
modelo_lin <- lmer(
  velocidade_max_kmh ~
    IBUTG_med_c +
    categoria +
    IBUTG_med_c:categoria +
    posicao +
    (1 | atleta) +
    (1 | jogo),
  data = dados,
  REML = TRUE
)

# (b) IBUTG QUADRATICO  (poly grau 2; raw = TRUE mantem os coeficientes na escala
#     de IBUTG e faz o modelo linear ficar aninhado neste)
modelo_quad <- lmer(
  velocidade_max_kmh ~
    poly(IBUTG_med_c, 2, raw = TRUE) +
    categoria +
    poly(IBUTG_med_c, 2, raw = TRUE):categoria +
    posicao +
    (1 | atleta) +
    (1 | jogo),
  data = dados,
  REML = TRUE
)

# comparacao ----------------------------------------------------------------
# anova() re-ajusta os dois modelos com ML (necessario porque os efeitos fixos
# diferem; o AIC de REML NAO seria comparavel) e imprime AIC/BIC/logLik + LRT.
# O termo quadratico "vale a pena" se Pr(>Chisq) < 0.05 e o AIC(ML) cair.
cat("\nLinear vs quadratico (refit ML):\n")
print(anova(modelo_lin, modelo_quad))

# Tabela lado a lado
tab_model(
  modelo_lin, modelo_quad,
  show.re.var = TRUE,
  show.icc = TRUE,
  show.stat = TRUE,
  p.style = "numeric_stars",
  dv.labels = c("Vel. máx - IBUTG linear", "Vel. máx - IBUTG quadrático"),
  string.pred = "Preditores",
  string.est = "Estimativa (Beta)",
  title = "Tabela. Velocidade máxima: forma linear vs quadrática do efeito de IBUTG"
)

# curva do efeito de IBUTG no modelo quadratico
print(
  plot_model(modelo_quad, type = "pred", terms = "IBUTG_med_c [all]",
             title = "Efeito predito de IBUTG (centrado) sobre a velocidade máxima")
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
