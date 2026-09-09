# regressão 4 - acoes em alta intensidade

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

# tratamento de variaveis ------------------------------------------------------
# AAI = CONTAGEM de acoes de aceleracao + desaceleracao (> 3 m/s^2) no jogo.
# Contagem inteira e sobredispersa -> modelo binomial negativo (nbinom2) com
# offset log(duracao_total_min) para modelar a taxa (acoes/min) sem perder a
# natureza discreta. NAO se modela AAI/duracao como resposta gaussiana.
dados$AAI <- dados$aceleracao_3_ms + dados$desaceleracao_3_ms

# Filtrar apenas U20 e U17
dados <- dados %>%
  filter(categoria %in% c("U20", "U17"))

dados$categoria <- droplevels(as.factor(dados$categoria))

dados$categoria <- as.factor(dados$categoria)
dados$posicao <- as.factor(dados$posicao)
dados$resultado <- as.factor(dados$resultado)
dados$IBUTG_med_c <- as.numeric(scale(dados$IBUTG_med, center = TRUE, scale = FALSE))
dados$posicao <- relevel(factor(dados$posicao), ref = "ZAG")
dados$categoria <- relevel(factor(dados$categoria), ref = "U20")

# modelo -----------------------------------------------------------------------
modelo_1 <- glmmTMB(
  AAI ~
    IBUTG_med_c +
    categoria +
    IBUTG_med_c * categoria +
    posicao +
    offset(log(duracao_total_min)) +
    (1 | atleta),
  family = nbinom2,
  data = dados
)

# Esta função cria uma tabela comparativa elegante entre os dois modelos
tab_model(
  modelo_1, 
  show.re.var = TRUE,           # Mostra a variância dos efeitos aleatórios (atleta)
  show.icc = TRUE,              # Coeficiente de Correlação Intraclasse (importante no doutorado)
  show.stat = TRUE,             # Mostra a estatística t
  p.style = "numeric_stars",    # Mostra p-value e estrelas (* p < 0.05)
  dv.labels = c("modelo 1 AAI (NB2, offset log duracao)"),
  string.pred = "Preditores",
  string.est = "IRR (exp Beta)",
  title = "Tabela 1. Modelo binomial negativo para acoes de alta intensidade e variáveis ambientais"
)
##################################################################
### Análise de pressupostos via DHARMa
### Resíduos quantílicos por simulação — abordagem adequada para
### modelos mistos. Avalia normalidade/uniformidade, dispersão,
### outliers e homocedasticidade a partir de resíduos escalonados.

run_model_diagnostics <- function(model_object, model_name) {

  old_par <- par(no.readonly = TRUE)
  on.exit(par(old_par))

  cat(paste0("\n=============================="))
  cat(paste0("\nPressupostos (DHARMa) - ", model_name))
  cat(paste0("\n==============================\n"))

  set.seed(123)
  sim <- simulateResiduals(fittedModel = model_object, n = 1000)

  # Gráfico principal: QQ dos resíduos + resíduos vs preditos (com testes no título)
  plot(sim)

  # ---- Testes formais ----
  cat("\n--- Uniformidade / normalidade dos residuos (KS) ---\n")
  print(testUniformity(sim, plot = FALSE))

  cat("\n--- Dispersao (sobre/subdispersao) ---\n")
  print(testDispersion(sim, plot = FALSE))

  cat("\n--- Outliers (bootstrap) ---\n")
  print(testOutliers(sim, type = "bootstrap", plot = FALSE))

  cat("\n--- Homocedasticidade / forma (quantis vs preditos) ---\n")
  print(testQuantiles(sim, plot = FALSE))

  # ---- Residuos contra cada preditor do modelo ----
  cat("\n--- Residuos vs preditores ---\n")
  dados_mod   <- tryCatch(model.frame(model_object), error = function(e) NULL)
  preditores  <- tryCatch(all.vars(formula(model_object))[-1], error = function(e) character(0))
  preditores  <- setdiff(preditores, "atleta")
  if (!is.null(dados_mod)) {
    for (p in intersect(preditores, names(dados_mod))) {
      plotResiduals(sim, form = dados_mod[[p]],
                    xlab = p, main = paste("Residuos vs", p, "-", model_name))
    }
  }

  invisible(sim)
}

# =========================
# Rodando para o(s) modelo(s)
# =========================

modelos <- list(
  modelo_1 = modelo_1
)

for (nome in names(modelos)) {
  run_model_diagnostics(modelos[[nome]], nome)
}

# =========================
# Teste de colinearidade
# =========================
check_collinearity(modelo_1)
