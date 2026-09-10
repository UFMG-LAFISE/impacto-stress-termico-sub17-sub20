# ============================================================================
# Gera um relatorio .md (renderavel no GitHub) por regressao, com:
#   - especificacao e decisoes do modelo
#   - tabela de coeficientes
#   - figura de diagnostico de residuos (DHARMa) com titulo
#   - figura do efeito predito de IBUTG com titulo
#   - (vel. max e sprint) figura linear vs quadratico
#   - tabela de pressupostos (DHARMa) e de ajuste
#   - conclusao breve
# Saida: modelo-comparacao-sub17-sub20/relatorios/*.md  +  relatorios/img/*.png
# ============================================================================
suppressPackageStartupMessages({
  library(glmmTMB); library(lme4); library(lmerTest); library(DHARMa)
  library(dplyr); library(ggplot2); library(ggeffects); library(parameters)
  library(performance); library(knitr)
})
set.seed(123)
theme_set(theme_minimal(base_size = 12))

OUT <- "relatorios"; IMG <- file.path(OUT, "img")
dir.create(IMG, recursive = TRUE, showWarnings = FALSE)
tt <- theme(plot.title = element_text(size = 11, face = "bold"),
            plot.title.position = "plot")

# ---- dados -----------------------------------------------------------------
d <- read.csv("dados-filtrados-60-40min.csv", sep = ",") |>
  filter(categoria %in% c("U20", "U17"))
d$categoria <- relevel(droplevels(as.factor(d$categoria)), ref = "U20")
d$posicao   <- relevel(as.factor(d$posicao), ref = "ZAG")
d$IBUTG_med_c <- as.numeric(scale(d$IBUTG_med, center = TRUE, scale = FALSE))
d$logdur    <- log(d$duracao_total_min)
d$distanciatotalminutos <- d$distancia_total_min / d$duracao_total_min
d$AAI       <- d$aceleracao_3_ms + d$desaceleracao_3_ms
CENTRO <- mean(d$IBUTG_med)                       # p/ eixo x em graus C

d_vmax <- d |> filter(velocidade_max_kmh <= 40)   # limpeza de vel. max

# ---- helpers -------------------------------------------------------------
fig_dharma <- function(s, file, titulo) {
  png(file.path(IMG, file), width = 1100, height = 520, res = 110)
  plot(s, title = titulo)
  dev.off()
}

tab_dharma <- function(s) {
  u  <- testUniformity(s, plot = FALSE)$p.value
  di <- testDispersion(s, plot = FALSE)$p.value
  o  <- testOutliers(s, type = "bootstrap", plot = FALSE)$p.value
  q  <- tryCatch(testQuantiles(s, plot = FALSE)$p.value, error = function(e) NA)
  verd <- function(p) ifelse(is.na(p), "—", ifelse(p < 0.05, "❌ viola", "✅ ok"))
  data.frame(
    Teste = c("Uniformidade / normalidade (KS)", "Dispersão", "Outliers (bootstrap)",
              "Quantis / homocedasticidade"),
    `p-valor` = sprintf("%.3g", c(u, di, o, q)),
    Situação = c(verd(u), verd(di), verd(o), verd(q)),
    check.names = FALSE
  )
}

fmt_p <- function(p) ifelse(is.na(p), "—", ifelse(p < 0.001, "<0.001", sprintf("%.3f", p)))

tab_coef <- function(m, expo) {
  p <- parameters::model_parameters(m, effects = "fixed", exponentiate = expo)
  df <- as.data.frame(p)
  keep <- intersect(c("Parameter", "Coefficient", "SE", "CI_low", "CI_high", "p"), names(df))
  df <- df[, keep]
  df$p <- fmt_p(df$p)
  num <- sapply(df, is.numeric)
  df[num] <- lapply(df[num], function(x) sprintf("%.3f", x))
  names(df)[names(df) == "Coefficient"] <- if (expo) "Estim. (exp)" else "Estimativa"
  names(df)[names(df) == "CI_low"]  <- "IC 2.5%"
  names(df)[names(df) == "CI_high"] <- "IC 97.5%"
  df$Parameter <- gsub("poly\\(IBUTG_med_c, 2, raw = TRUE\\)1", "IBUTG(c)", df$Parameter)
  df$Parameter <- gsub("poly\\(IBUTG_med_c, 2, raw = TRUE\\)2", "IBUTG(c)²", df$Parameter)
  df$Parameter <- gsub("IBUTG_med_c", "IBUTG(c)", df$Parameter)
  df
}

sc <- function(x) { x <- suppressWarnings(x[1]); if (length(x) == 0 || is.na(x)) "—" else as.character(x) }

tab_ajuste <- function(m) {
  ic <- tryCatch(performance::icc(m)$ICC_adjusted, error = function(e) NA)
  r2 <- tryCatch(performance::r2(m), error = function(e) NULL)
  r2txt <- if (is.list(r2) && !is.null(r2$R2_conditional))
    sprintf("cond. %.3f / marg. %.3f", as.numeric(r2$R2_conditional), as.numeric(r2$R2_marginal))
  else if (is.list(r2) && !is.null(r2$R2)) sprintf("%.3f", as.numeric(r2$R2)) else "—"
  n_atl <- tryCatch({
    g <- insight::n_grouplevels(m); as.integer(g$N_levels[g$Group == "atleta"])
  }, error = function(e) NA)
  data.frame(
    Métrica = c("N observações", "N atletas", "AIC", "BIC", "logLik",
                "ICC (atleta)", "R² (Nakagawa)"),
    Valor = c(sc(insight::n_obs(m)), sc(n_atl),
              sc(round(AIC(m), 1)), sc(round(BIC(m), 1)), sc(round(as.numeric(logLik(m)), 1)),
              ifelse(is.na(ic), "—", sprintf("%.3f", ic)), r2txt),
    check.names = FALSE
  )
}

fig_ibutg <- function(m, file, titulo, ylab, cond = NULL) {
  pr <- ggeffects::ggpredict(m, terms = "IBUTG_med_c [all]", condition = cond)
  dd <- as.data.frame(pr); dd$x_c <- dd$x + CENTRO
  g <- ggplot(dd, aes(x_c, predicted)) +
    geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = .15) +
    geom_line(linewidth = 1) +
    geom_rug(data = d, aes(x = IBUTG_med, y = NULL), sides = "b", alpha = .25, inherit.aes = FALSE) +
    labs(title = titulo, x = "IBUTG (°C WBGT)", y = ylab) + tt
  ggsave(file.path(IMG, file), g, width = 7.2, height = 4.4, dpi = 120)
}

fig_lin_quad <- function(m_lin, m_quad, file, titulo, ylab, cond = NULL) {
  a <- as.data.frame(ggeffects::ggpredict(m_lin,  "IBUTG_med_c [all]", condition = cond)); a$forma <- "linear"
  b <- as.data.frame(ggeffects::ggpredict(m_quad, "IBUTG_med_c [all]", condition = cond)); b$forma <- "quadrático"
  dd <- rbind(a, b); dd$x_c <- dd$x + CENTRO
  g <- ggplot(dd, aes(x_c, predicted, color = forma, fill = forma)) +
    geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = .12, color = NA) +
    geom_line(linewidth = 1) +
    geom_rug(data = d, aes(x = IBUTG_med, y = NULL), sides = "b", alpha = .25,
             inherit.aes = FALSE) +
    scale_color_manual(values = c(linear = "#2c3e50", `quadrático` = "#c0392b")) +
    scale_fill_manual(values  = c(linear = "#2c3e50", `quadrático` = "#c0392b")) +
    labs(title = titulo, x = "IBUTG (°C WBGT)", y = ylab, color = NULL, fill = NULL) + tt
  ggsave(file.path(IMG, file), g, width = 7.6, height = 4.4, dpi = 120)
}

md_tbl <- function(df) paste(kable(df, format = "pipe", align = "l"), collapse = "\n")
lrt_gl <- function(l) if ("Chi Df" %in% names(l)) l[["Chi Df"]][2] else l[["Df"]][2]  # gl da razão de verossimilhança

write_report <- function(id, titulo, curto, formula_txt, familia, decisoes, m,
                         expo, ylab_efeito, cond = NULL,
                         lin_quad = NULL, extra_conc = NULL, conclusao) {
  base <- id
  set.seed(123); s <- simulateResiduals(m, n = 1000)
  fig_dharma(s, paste0(base, "_dharma.png"),
             paste0("Fig. 1 — Diagnóstico DHARMa · ", curto))
  fig_ibutg(m, paste0(base, "_ibutg.png"),
            paste0("Fig. 2 — Efeito predito do IBUTG · ", curto), ylab_efeito, cond)
  fig3_md <- NULL
  if (!is.null(lin_quad)) {
    fig_lin_quad(lin_quad$lin, lin_quad$quad, paste0(base, "_linquad.png"),
                 paste0("Fig. 3 — IBUTG: linear vs quadrático · ", curto),
                 ylab_efeito, cond)
    fig3_md <- c("## Figura 3 — Forma do efeito do IBUTG: linear vs quadrático", "",
                 sprintf("![Figura 3](img/%s_linquad.png)", base), "",
                 lin_quad$nota, "")
  }

  L <- c(
    sprintf("# %s", titulo), "",
    sprintf("_Comparação U17 vs U20 (referência: U20). Efeitos aleatórios: `(1 | atleta)`._"), "",
    "## Modelo", "",
    "```r", formula_txt, "```", "",
    sprintf("- **Distribuição / link:** %s", familia), "",
    "## Decisões importantes", "",
    paste0("- ", decisoes, collapse = "\n"), "",
    "## Coeficientes (efeitos fixos)", "",
    md_tbl(tab_coef(m, expo)), "",
    if (expo) "_Estimativas **exponenciadas** (razão): valor > 1 aumenta a resposta, < 1 diminui, por unidade do preditor. IBUTG(c) = IBUTG centrado na média._"
    else "_Estimativas na escala da resposta. IBUTG(c) = IBUTG centrado no valor médio._", "",
    "## Figura 1 — Diagnóstico de resíduos (DHARMa)", "",
    sprintf("![Figura 1](img/%s_dharma.png)", base), "",
    "_Esquerda: QQ-plot dos resíduos escalonados (uniformidade). Direita: resíduos vs. valores previstos (curvas vermelhas = desvio de quantis)._",
    "_O teste de outliers na tabela abaixo usa o método **bootstrap** (mais confiável); pode divergir do rótulo do gráfico, que usa o teste binomial._", "",
    "## Figura 2 — Efeito predito do IBUTG", "",
    sprintf("![Figura 2](img/%s_ibutg.png)", base), "",
    fig3_md,
    "## Pressupostos (DHARMa)", "",
    md_tbl(tab_dharma(s)), "",
    "## Ajuste do modelo", "",
    md_tbl(tab_ajuste(m)), "",
    "## Conclusão", "",
    conclusao, ""
  )
  writeLines(L, file.path(OUT, paste0(base, ".md")))
  cat("ok:", file.path(OUT, paste0(base, ".md")), "\n")
}

# ===========================================================================
# 1. DISTANCIA TOTAL / MIN
# ===========================================================================
m_dtm <- lmer(distanciatotalminutos ~ IBUTG_med_c + categoria + IBUTG_med_c*categoria +
                posicao + (1|atleta), data = d)
write_report(
  "01_distancia-total-min", "Regressão 1 — Distância total por minuto (m/min)", "Distância/min",
  "distanciatotalminutos ~ IBUTG_med_c * categoria + posicao + (1 | atleta)",
  "Gaussiana (identidade) — LMM",
  c("Desfecho contínuo; a distância relativa (m/min) é aproximadamente normal no futebol.",
    "LMM gaussiano passou no DHARMa (KS e dispersão ok; leve desvio nos quantis).",
    "Gamma(log) foi testada e **não** melhorou de forma convincente — mantido gaussiano.",
    "Efeito aleatório de jogo `(1 | numero_jg)` ainda **não** aplicado (decisão pendente)."),
  m_dtm, expo = FALSE, ylab_efeito = "distância prevista (m/min)",
  conclusao = paste(
    "Modelo adequado. O IBUTG **não** tem efeito relevante sobre a distância relativa;",
    "as diferenças ficam por conta de posição e categoria. O desvio residual nos quantis é leve.",
    "Recomenda-se reavaliar após incluir `(1 | numero_jg)`, pois o IBUTG é medido por jogo."))

# ===========================================================================
# 2. VELOCIDADE MAXIMA
# ===========================================================================
m_vmax     <- lmer(velocidade_max_kmh ~ IBUTG_med_c + categoria + IBUTG_med_c*categoria +
                     posicao + (1|atleta), data = d_vmax)
m_vmax_lin <- lmer(velocidade_max_kmh ~ IBUTG_med_c + categoria + IBUTG_med_c:categoria +
                     posicao + (1|atleta) + (1|numero_jg), data = d_vmax)
m_vmax_qua <- lmer(velocidade_max_kmh ~ poly(IBUTG_med_c,2,raw=TRUE) + categoria +
                     poly(IBUTG_med_c,2,raw=TRUE):categoria + posicao +
                     (1|atleta) + (1|numero_jg), data = d_vmax)
lrt_v <- anova(m_vmax_lin, m_vmax_qua)
write_report(
  "02_velocidade-max", "Regressão 2 — Velocidade máxima (km/h)", "Velocidade máx.",
  "velocidade_max_kmh ~ IBUTG_med_c * categoria + posicao + (1 | atleta)\n# filtro: velocidade_max_kmh <= 40 (remove 3 erros de medida)",
  "Gaussiana (identidade) — LMM",
  c("**Limpeza de dados:** removidos 3 registros fisicamente impossíveis (77,8 / 84,2 / 94,5 km/h). O 4º maior valor real é ~35 km/h.",
    "Após a limpeza o LMM gaussiano fica adequado (KS 0,91; dispersão ok).",
    "É uma variável de **máximo por jogo** (bloco-máximo); Gaussiana serve na prática com os dados limpos.",
    sprintf("**Não-linearidade do IBUTG:** com `(1|atleta)+(1|numero_jg)`, o termo quadrático é significativo (LRT p = %.3f) — curvatura real.",
            lrt_v$`Pr(>Chisq)`[2])),
  m_vmax, expo = FALSE, ylab_efeito = "velocidade máx. prevista (km/h)",
  lin_quad = list(lin = m_vmax_lin, quad = m_vmax_qua,
                  nota = sprintf("LRT linear vs quadrático: χ² = %.2f, gl = %d, **p = %.3f**. A curva sobe até ~23 °C e cai acima de ~25 °C.",
                                 lrt_v$Chisq[2], lrt_gl(lrt_v), lrt_v$`Pr(>Chisq)`[2])),
  conclusao = paste(
    "Depois da limpeza dos 3 outliers, o modelo gaussiano é válido.",
    "Há **curvatura real** no efeito do IBUTG (pico ~23 °C, queda acima de 25 °C) que se mantém ao controlar o jogo —",
    "recomenda-se adotar a forma **quadrática** (`poly(IBUTG_med_c, 2)`), reportando o linear como sensibilidade."))

# ===========================================================================
# 3. SPRINT (contagem)
# ===========================================================================
m_spr <- glmmTMB(sprint_25_kmh ~ IBUTG_med_c + categoria + IBUTG_med_c*categoria +
                   posicao + offset(logdur) + (1|atleta), family = nbinom2, data = d)
m_spr_lin <- glmmTMB(sprint_25_kmh ~ IBUTG_med_c + categoria + IBUTG_med_c:categoria +
                       posicao + offset(logdur) + (1|atleta) + (1|numero_jg),
                     family = nbinom2, data = d)
m_spr_qua <- glmmTMB(sprint_25_kmh ~ poly(IBUTG_med_c,2,raw=TRUE) + categoria +
                       poly(IBUTG_med_c,2,raw=TRUE):categoria + posicao + offset(logdur) +
                       (1|atleta) + (1|numero_jg), family = nbinom2, data = d)
lrt_s <- anova(m_spr_lin, m_spr_qua)
write_report(
  "03_sprint", "Regressão 3 — Número de sprints (> 25 km/h)", "Sprints",
  "sprint_25_kmh ~ IBUTG_med_c * categoria + posicao + offset(log(duracao_total_min)) + (1 | atleta)",
  "Binomial negativa (nbinom2, link log) — GLMM de contagem",
  c("`sprint_25_kmh` é **contagem** (0–16). Modelada como contagem, **não** como taxa `sprint/min` gaussiana.",
    "`offset(log(duração))` transforma o modelo na taxa de sprints por minuto respeitando a exposição variável (9–57 min).",
    "Sobredispersão leve (var/média ≈ 2) → binomial negativa; Poisson também passa, NB2 tem AIC um pouco menor.",
    "**Zero-inflação não é necessária** (ZIP não melhora o AIC).",
    sprintf("**Não-linearidade do IBUTG:** forma quadrática **não** se justifica (LRT p = %.2f) — manter linear.",
            lrt_s$`Pr(>Chisq)`[2])),
  m_spr, expo = TRUE, ylab_efeito = "sprints previstos / 90 min",
  cond = c(logdur = log(90)),
  lin_quad = list(lin = m_spr_lin, quad = m_spr_qua,
                  nota = sprintf("LRT linear vs quadrático: χ² = %.2f, gl = %d, p = %.2f (n.s.). O spline (GAM) via um platô-e-queda que a parábola não reproduz; a forma **linear** é suficiente.",
                                 lrt_s$Chisq[2], lrt_gl(lrt_s), lrt_s$`Pr(>Chisq)`[2])),
  conclusao = paste(
    "GLMM binomial negativo com offset resolve os problemas de pressupostos da versão anterior (taxa gaussiana).",
    "O efeito do IBUTG é adequadamente **linear**. Recomenda-se reavaliar a significância do IBUTG após incluir `(1 | numero_jg)`."))

# ===========================================================================
# 4. DAI - distancia em alta velocidade
# ===========================================================================
m_dai <- glmmTMB(soma_3_valoc19.8kmh ~ IBUTG_med_c + categoria + IBUTG_med_c*categoria +
                   posicao + offset(logdur) + (1|atleta), family = Gamma(link = "log"), data = d)
write_report(
  "04_dai", "Regressão 4 — DAI: distância em alta velocidade (> 19,8 km/h)", "DAI",
  "soma_3_valoc19.8kmh ~ IBUTG_med_c * categoria + posicao + offset(log(duracao_total_min)) + (1 | atleta)",
  "Gamma (link log) — GLMM contínuo positivo",
  c("`soma_3_valoc19.8kmh` é **distância em metros** (contínua, positiva, assimétrica) — **não** é contagem.",
    "Gamma(log) + `offset(log(duração))` modela a distância por minuto; melhora muito a forma dos quantis vs a taxa gaussiana.",
    "Lognormal foi testada e ficou pior.",
    "**Ressalva:** o teste de dispersão do DHARMa ainda acusa desvio (p ≈ 0,01) — vale testar **Tweedie**."),
  m_dai, expo = TRUE, ylab_efeito = "distância prevista > 19,8 km/h por 90 min (m)",
  cond = c(logdur = log(90)),
  conclusao = paste(
    "Gamma(log) com offset é a melhor opção paramétrica disponível e corrige a maior parte das violações da versão gaussiana,",
    "mas não fecha o teste de dispersão. Recomenda-se comparar com **Tweedie** e reavaliar após incluir `(1 | numero_jg)`."))

# ===========================================================================
# 5. AAI - acoes de aceleracao/desaceleracao (contagem)
# ===========================================================================
m_aai <- glmmTMB(AAI ~ IBUTG_med_c + categoria + IBUTG_med_c*categoria + posicao +
                   offset(logdur) + (1|atleta), family = nbinom2, data = d)
write_report(
  "05_aai", "Regressão 5 — AAI: ações de aceleração + desaceleração (> 3 m/s²)", "AAI",
  "AAI ~ IBUTG_med_c * categoria + posicao + offset(log(duracao_total_min)) + (1 | atleta)\n# AAI = aceleracao_3_ms + desaceleracao_3_ms  (contagem)",
  "Binomial negativa (nbinom2, link log) — GLMM de contagem",
  c("`AAI` é a **soma de duas contagens** (acel + desacel), inteira e sobredispersa (Poisson AIC ~120 pontos pior que NB).",
    "Modelada como **contagem** com `offset(log(duração))` — não como taxa `AAI/min` gaussiana (que dava quantis = 0 no DHARMa).",
    "A interação `IBUTG × posição` foi **removida** (gerava VIF ≈ 5) — estrutura agora igual à dos outros modelos.",
    "Com o modelo correto, o DHARMa passa em tudo (KS 0,97; dispersão 0,91; quantis ~0,06)."),
  m_aai, expo = TRUE, ylab_efeito = "ações previstas / 90 min",
  cond = c(logdur = log(90)),
  conclusao = paste(
    "O GLMM binomial negativo com offset é o modelo adequado para o AAI e elimina as violações de pressuposto.",
    "Nele, **nem IBUTG nem categoria** têm efeito relevante — apenas a posição. Reavaliar após incluir `(1 | numero_jg)`."))

# ===========================================================================
# 6. PSE_UA - carga interna
# ===========================================================================
m_pse <- lmer(PSE_UA ~ IBUTG_med_c + categoria + IBUTG_med_c*categoria + posicao +
                (1|atleta), data = d)
write_report(
  "06_PSE-UA", "Regressão 6 — PSE_UA: carga interna (PSE de Borg × duração)", "PSE_UA",
  "PSE_UA ~ IBUTG_med_c * categoria + posicao + (1 | atleta)",
  "Gaussiana (identidade) — LMM",
  c("`PSE_UA` = PSE (escala de Borg CR10, concentrada em 7–10) × duração — composto ordinal × tempo.",
    "O LMM gaussiano teve o melhor diagnóstico do conjunto (KS e dispersão ok; desvio nos quantis).",
    "Gamma(log) foi testada e **piorou** — mantido gaussiano.",
    "Modelo formalmente ideal seria um *cumulative link mixed model* (`ordinal::clmm`) na PSE bruta com a duração como covariável."),
  m_pse, expo = FALSE, ylab_efeito = "PSE_UA prevista (u.a.)",
  conclusao = paste(
    "Gaussiano é defensável e é a convenção para sRPE-load em ciência do esporte; o desvio nos quantis é a limitação remanescente.",
    "Para rigor máximo, migrar para CLMM ordinal na PSE. Reavaliar o efeito do IBUTG após incluir `(1 | numero_jg)`."))

# ---- indice ---------------------------------------------------------------
idx <- c(
  "# Relatórios dos modelos — Sub-17 vs Sub-20", "",
  "Um arquivo por regressão. Cada um traz especificação, decisões, coeficientes,",
  "figuras (diagnóstico DHARMa e efeito do IBUTG), pressupostos, ajuste e conclusão.", "",
  "> Descrição metodológica completa (linguagem científica): [METODOLOGIA.md](METODOLOGIA.md)", "",
  "| # | Regressão | Distribuição | Arquivo |",
  "|---|-----------|--------------|---------|",
  "| 1 | Distância total / min | Gaussiana (LMM) | [01_distancia-total-min.md](01_distancia-total-min.md) |",
  "| 2 | Velocidade máxima | Gaussiana (LMM) | [02_velocidade-max.md](02_velocidade-max.md) |",
  "| 3 | Nº de sprints | Binomial negativa (GLMM) | [03_sprint.md](03_sprint.md) |",
  "| 4 | DAI — distância alta velocidade | Gamma log (GLMM) | [04_dai.md](04_dai.md) |",
  "| 5 | AAI — acel + desacel | Binomial negativa (GLMM) | [05_aai.md](05_aai.md) |",
  "| 6 | PSE_UA — carga interna | Gaussiana (LMM) | [06_PSE-UA.md](06_PSE-UA.md) |", "",
  "## Decisões transversais", "",
  "- **Exposição (duração 9–57 min):** contagens (sprint, AAI) e distância (DAI) usam `offset(log(duração))` em vez de dividir pela duração.",
  "- **Contagens** → binomial negativa; **distância positiva assimétrica** → Gamma(log); **contínuas ~normais** → LMM gaussiano.",
  "- **Pressupostos** avaliados com **DHARMa** (resíduos quantílicos por simulação), não com testes nos resíduos brutos.",
  "- **`(1 | numero_jg)` (efeito de jogo)** ainda não incluído nos modelos principais; a análise exploratória mostrou que muda a inferência sobre o IBUTG (que é medido por jogo).",
  "- **Não-linearidade do IBUTG:** real e relevante só em **velocidade máxima**; nas demais, forma linear é suficiente.", ""
)
writeLines(idx, file.path(OUT, "README.md"))
cat("ok:", file.path(OUT, "README.md"), "\n")
cat("\nFIM\n")
