# regressão 1 - Distancia total/min (U14, U17, U20 vs U17, U20)

# importando bibliotecas--------------------------------------------------------
library(lme4)
library(lmerTest)
library(dplyr)
library(car)
library(sjPlot)
library(performance)
#library(see)
library(nortest)
library(lmtest)
# importando bases de dados-----------------------------------------------------
dados <- read.csv("../data/dados-filtrados-60-40min.csv" , sep = ",")

# tratamento de bases de dados-------------------------------------------------- 
dados$categoria <- as.factor(dados$categoria)
dados$posicao <- as.factor(dados$posicao)
dados$resultado <- as.factor(dados$resultado)
dados$IBUTG_med_c <- as.numeric(scale(dados$IBUTG_med, center = TRUE, scale = FALSE))
dados$posicao <- relevel(factor(dados$posicao), ref = "ZAG")
dados$resultado <- relevel(factor(dados$resultado), ref = "DER")
dados$categoria <- relevel(factor(dados$categoria), ref = "U20")



# modelos-----------------------------------------------------------------------
modelo_1 <- lmer(
  `PSE_UA` ~ 
    IBUTG_med_c +
    categoria +
    IBUTG_med_c * categoria +
    posicao +
    (1 | atleta), 
  data = dados
)


# Filtrar apenas U20 e U17
dados <- dados %>%
  filter(categoria %in% c("U20", "U17"))

dados$categoria <- droplevels(dados$categoria)

# referência
dados$categoria <- relevel(dados$categoria, ref = "U20")


modelo_2 <- lmer(
  `PSE_UA` ~
    IBUTG_med_c +
    categoria +
    IBUTG_med_c * categoria +
    posicao +
    (1 | atleta), 
  data = dados
)

# Esta função cria uma tabela comparativa elegante entre os dois modelos
tab_model(
  modelo_2,  
  show.re.var = TRUE,           # Mostra a variância dos efeitos aleatórios (atleta)
  show.icc = TRUE,              # Coeficiente de Correlação Intraclasse (importante no doutorado)
  show.stat = TRUE,             # Mostra a estatística t
  p.style = "numeric_stars",    # Mostra p-value e estrelas (* p < 0.05)
  dv.labels = c("modelo 1 PSE_UA"),
  string.pred = "Preditores",
  string.est = "Estimativa (Beta)",
  title = "Tabela 1. Modelos Mistos para Desempenho Físico e Variáveis Ambientais"
)



##################################################################
### Análise da normalidade e homocedasticidade dos resíduos e dos efeitos aleatórios

### Diagnóstico completo para modelos mistos (adaptado ao seu código)

run_model_diagnostics <- function(model_object, model_name) {
  
  old_opts <- options(scipen = 999, digits = 4)
  old_par <- par(no.readonly = TRUE)
  
  on.exit({
    options(old_opts)
    par(old_par)
  })
  
  cat(paste0("\n=============================="))
  cat(paste0("\nDiagnostics for: ", model_name))
  cat(paste0("\n==============================\n"))
  
  # =========================
  # RESÍDUOS
  # =========================
  
  cat("\n--- Residual Diagnostics ---\n")
  
  res <- residuals(model_object)
  fit <- fitted(model_object)
  
  par(mfrow = c(2, 2))
  
  # Histograma
  hist(res,
       main = paste("Histogram -", model_name),
       col = "lightblue",
       border = "black")
  
  # QQ-plot
  qqnorm(res, main = paste("QQ-plot -", model_name))
  qqline(res, col = "red")
  
  # Resíduos vs ajustados
  plot(fit, res,
       main = "Residuals vs Fitted",
       xlab = "Fitted",
       ylab = "Residuals",
       pch = 19,
       col = "darkgreen")
  abline(h = 0, col = "red", lty = 2)
  
  # Scale-location (homocedasticidade)
  plot(fit, sqrt(abs(res)),
       main = "Scale-Location",
       xlab = "Fitted",
       ylab = "√|Residuals|",
       pch = 19,
       col = "purple")
  
  # =========================
  # TESTES DE NORMALIDADE
  # =========================
  
  cat("\nShapiro-Francia Test (residuals):\n")
  print(sf.test(res))
  
  cat("\nLilliefors Test (residuals):\n")
  print(lillie.test(res))
  
  # =========================
  # EFEITOS ALEATÓRIOS
  # =========================
  
  cat("\n--- Random Effects (atleta) ---\n")
  
  re <- tryCatch({
    ranef(model_object)$atleta[, "(Intercept)"]
  }, error = function(e) {
    cat("Erro ao extrair efeitos aleatórios\n")
    return(NULL)
  })
  
  if (!is.null(re) && length(re) > 2) {
    
    par(mfrow = c(1, 2))
    
    hist(re,
         main = "Random Effects Histogram",
         col = "lightgreen",
         border = "black")
    
    qqnorm(re, main = "QQ-plot Random Effects")
    qqline(re, col = "red")
    
    cat("\nShapiro-Francia Test (random effects):\n")
    print(sf.test(re))
    
    cat("\nLilliefors Test (random effects):\n")
    print(lillie.test(re))
    
  } else {
    cat("Sem efeitos aleatórios suficientes.\n")
  }
  
}
# =========================
# Rodando para seus modelos
# =========================

modelos <- list(
  modelo_1 = modelo_1,
  modelo_2 = modelo_2
)

for (nome in names(modelos)) {
  run_model_diagnostics(modelos[[nome]], nome)
}

# =========================
# Teste de colinearidade
# =========================
check_collinearity(modelo_1)
check_collinearity(modelo_2)

# ========================
# Homocedasticidade
# ========================
res <- residuals(modelo_1)
fit <- fitted(modelo_1)

bptest(res ~ fit)


res <- residuals(modelo_2)
fit <- fitted(modelo_2)

bptest(res ~ fit)








# =============================================================================
# Análise exploratória dos dados
# ============================================================================
summary(dados$distanciatotalminutos)



# 1. Somar minutos por indivíduo + jogo
min_por_jogo <- dados %>%
  group_by(atleta, numero_jg) %>%
  summarise(min_total_jogo = sum(duracao_total_min, na.rm = TRUE), .groups = "drop")
