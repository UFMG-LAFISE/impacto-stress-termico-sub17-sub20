#=========================
# ESTATÍSTICA DESCRITIVA
# TABELAS POR POSIÇÃO
# =========================

library(dplyr)
library(readr)
library(tidyr)
#--------------------------

# IMPORTAR DADOS
dados <- read.csv("../data/dados-filtrados-60-40min.csv")

#--------------------------
#Tratamento de dados
dados$categoria <- as.factor(dados$categoria)
dados$posicao <- as.factor(dados$posicao)
dados$resultado <- as.factor(dados$resultado)
# Tratamento da variavel distancia total em minutos
dados$distanciatotalminutos <- dados$distancia_total_min/dados$duracao_total_min

#-------------------------
# Tabela 1

tabela_1 <- dados %>%
  
  group_by(posicao) %>%
  
  summarise(
    
    `Nº de observações` = as.character(n()),
    
    `Nº de jogadores` = as.character(n_distinct(atleta)),
    
    `Idade` = paste0(
      round(mean(idade, na.rm = TRUE), 1),
      " ± ",
      round(sd(idade, na.rm = TRUE), 1)
    ),
    
    `Percentual de gordura` = paste0(
      round(mean(percentual_gordura, na.rm = TRUE), 1),
      " ± ",
      round(sd(percentual_gordura, na.rm = TRUE), 1)
    ),
    
    `Massa corporal (kg)` = paste0(
      round(mean(massa, na.rm = TRUE), 1),
      " ± ",
      round(sd(massa, na.rm = TRUE), 1)
    ),
    
    `Estatura (cm)` = paste0(
      round(mean(estatura, na.rm = TRUE), 1),
      " ± ",
      round(sd(estatura, na.rm = TRUE), 1)
    )
    
  ) %>%
  
  pivot_longer(
    cols = -posicao,
    names_to = "Variavel",
    values_to = "Valor"
  ) %>%
  
  pivot_wider(
    names_from = posicao,
    values_from = Valor
  )

tabela_1

#---------------------------
#Tabela 2
tabela_2 <- dados %>%
  
  group_by(posicao) %>%
  
  summarise(
    
    `Distância total em min` = paste0(
      round(mean(distanciatotalminutos, na.rm = TRUE), 1),
      " ± ",
      round(sd(distanciatotalminutos, na.rm = TRUE), 1)
    ),
    
    `DAI` = paste0(
      round(mean(soma_3_valoc19.8kmh_min, na.rm = TRUE), 1),
      " ± ",
      round(sd(soma_3_valoc19.8kmh_min, na.rm = TRUE), 1)
    ),
    
    `Velocidade máxima` = paste0(
      round(mean(velocidade_max_kmh, na.rm = TRUE), 1),
      " ± ",
      round(sd(velocidade_max_kmh, na.rm = TRUE), 1)
    )
    
  ) %>%
  
  pivot_longer(
    cols = -posicao,
    names_to = "Variavel",
    values_to = "Valor"
  ) %>%
  
  pivot_wider(
    names_from = posicao,
    values_from = Valor
  )
tabela_2



