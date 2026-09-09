# regressão 1 - Distancia total/min (U17 vs. U20)

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

# tratamento de bases de dados--------------------------------------------------
# Filtrar apenas U20 e U17
dados <- dados %>%
  filter(categoria %in% c("U20", "U17"))
# Retira categorias que não serão usadas
dados$categoria <- droplevels(as.factor(dados$categoria))
# Tratamento por variavel
dados$categoria <- as.factor(dados$categoria)
dados$posicao <- as.factor(dados$posicao)
dados$IBUTG_med_c <- as.numeric(scale(dados$IBUTG_med, center = TRUE, scale = FALSE))
dados$posicao <- relevel(factor(dados$posicao), ref = "ZAG")
dados$categoria <- relevel(factor(dados$categoria), ref = "U20")

# Tratamento da variavel distancia total em minutos
# Distancia relativa (m/min): variavel continua, aproximadamente normal no
# futebol. O LMM gaussiano passou no DHARMa (KS e dispersao ok; leve desvio
# nos quantis). Mantido como esta; Gamma(log)+offset serve como sensibilidade.
dados$distanciatotalminutos <- dados$distancia_total_min/dados$duracao_total_min

# Modelagem
modelo_1 <- lmer(
  `distanciatotalminutos` ~
    IBUTG_med_c +
    categoria +
    IBUTG_med_c * categoria +
    posicao +
    (1 | atleta), 
  data = dados
)


# Esta função cria uma tabela comparativa elegante entre os dois modelos
tab_model(
  modelo_1, 
  show.re.var = TRUE,           # Mostra a variância dos efeitos aleatórios (atleta)
  show.icc = TRUE,              # Coeficiente de Correlação Intraclasse (importante no doutorado)
  show.stat = TRUE,             # Mostra a estatística t
  p.style = "numeric_stars",    # Mostra p-value e estrelas (* p < 0.05)
  dv.labels = c("modelo 1 Distan.total.min"),
  string.pred = "Preditores",
  string.est = "Estimativa (Beta)",
  title = "Tabela 1. Modelos Mistos para Desempenho Físico e Variáveis Ambientais"
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
