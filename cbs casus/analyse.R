# Casus 1 - consumentenprijzen
library(cbsodataR)
library(ggplot2)
library(DBI)
library(RPostgres)

# Gegevens ophalen van CBS StatLine
gegevens <- cbs_get_data(
  "86141NED",
  Bestedingscategorieen = c("CPI012200", "CPI045100"),
  Perioden = has_substring("MM")
)

# Alleen de maanden die we nodig hebben
gegevens <- gegevens[grepl("^[0-9]{4}MM(0[1-9]|1[0-2])$", gegevens$Perioden), ]
gegevens$jaar <- as.integer(substr(gegevens$Perioden, 1, 4))
gegevens$maand <- as.integer(substr(gegevens$Perioden, 7, 8))
gegevens <- gegevens[gegevens$jaar >= 2021 & gegevens$jaar <= 2025, ]
gegevens$kwartaalnr <- (gegevens$maand - 1) %/% 3 + 1
gegevens$kwartaal <- paste0(gegevens$jaar, "Q", gegevens$kwartaalnr)
gegevens$product <- ifelse(gegevens$Bestedingscategorieen == "CPI012200", "Koffie", "Elektriciteit")

# Per kwartaal het gemiddelde van de drie maanden berekenen
kwartalen <- unique(gegevens[, c("product", "kwartaal", "jaar")])
kwartalen$gemiddelde <- NA_real_

for (i in 1:nrow(kwartalen)) {
  regels <- gegevens[gegevens$product == kwartalen$product[i] &
                       gegevens$kwartaal == kwartalen$kwartaal[i], ]
  if (nrow(regels) == 3 && length(unique(regels$maand)) == 3 &&
      !any(is.na(regels$CPI_1))) {
    kwartalen$gemiddelde[i] <- mean(regels$CPI_1)
  }
}

# Functie voor de verandering ten opzichte van het vorige kwartaal
kwartaalmutatie <- function(verslagperiode) {
  if (length(verslagperiode) != 1 || is.na(verslagperiode) ||
      !grepl("^[0-9]{4}Q[1-4]$", verslagperiode)) {
    stop("Gebruik bijvoorbeeld 2025Q2.")
  }

  jaar <- as.integer(substr(verslagperiode, 1, 4))
  nummer <- as.integer(substr(verslagperiode, 6, 6))

  if (nummer == 1) {
    vorig <- paste0(jaar - 1, "Q4")
  } else {
    vorig <- paste0(jaar, "Q", nummer - 1)
  }

  uitkomst <- data.frame()
  for (product in c("Koffie", "Elektriciteit")) {
    nu <- kwartalen$gemiddelde[kwartalen$product == product &
                                kwartalen$kwartaal == verslagperiode]
    eerder <- kwartalen$gemiddelde[kwartalen$product == product &
                                    kwartalen$kwartaal == vorig]

    if (length(nu) != 1 || length(eerder) != 1 ||
        is.na(nu) || is.na(eerder) || eerder <= 0) {
      stop(paste("Geen volledige gegevens voor", verslagperiode))
    }

    verandering <- (nu - eerder) / eerder * 100
    uitkomst <- rbind(uitkomst, data.frame(
      product = product,
      verslagperiode = verslagperiode,
      cpi_vorig = eerder,
      cpi_huidig = nu,
      kwartaalmutatie_pct = verandering
    ))
  }
  return(uitkomst)
}

# Alle kwartalen van 2022 tot en met 2025 berekenen
resultaten <- data.frame()
for (jaar in 2022:2025) {
  for (nummer in 1:4) {
    periode <- paste0(jaar, "Q", nummer)
    resultaten <- rbind(resultaten, kwartaalmutatie(periode))
  }
}

# Een voorbeeld van de functie
print(kwartaalmutatie("2025Q2"))

# Grafieken maken
if (!dir.exists("grafieken")) dir.create("grafieken")

plotdata <- kwartalen[kwartalen$jaar >= 2022 & kwartalen$jaar <= 2025, ]
plotdata$kwartaal <- factor(plotdata$kwartaal, levels = unique(resultaten$verslagperiode))
resultaten$verslagperiode <- factor(resultaten$verslagperiode,
                                  levels = unique(resultaten$verslagperiode))

plot1 <- ggplot(plotdata, aes(x = kwartaal, y = gemiddelde, color = product, group = product)) +
  geom_line() + geom_point() +
  labs(title = "Consumentenprijzen per kwartaal", x = "Kwartaal", y = "Gemiddelde CPI") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

plot2 <- ggplot(resultaten, aes(x = verslagperiode, y = kwartaalmutatie_pct, fill = product)) +
  geom_col(position = "dodge") +
  labs(title = "Verandering per kwartaal", x = "Kwartaal", y = "Verandering (%)") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("grafieken/prijzen.png", plot1, width = 10, height = 5)
ggsave("grafieken/verandering.png", plot2, width = 10, height = 5)

# Resultaten opslaan in PostgreSQL
# De standaardinstellingen zijn voor de lokale database.
instellingen <- list(
  drv = RPostgres::Postgres(),
  dbname = Sys.getenv("PGDATABASE", "cbs_casus"),
  host = Sys.getenv("PGHOST", "localhost"),
  port = as.integer(Sys.getenv("PGPORT", "5432"))
)
if (Sys.getenv("PGUSER") != "") instellingen$user <- Sys.getenv("PGUSER")
if (Sys.getenv("PGPASSWORD") != "") instellingen$password <- Sys.getenv("PGPASSWORD")

con <- do.call(dbConnect, instellingen)
resultaten$verslagperiode <- as.character(resultaten$verslagperiode)
dbWriteTable(con, "resultaten", resultaten, overwrite = TRUE, row.names = FALSE)
print(dbGetQuery(con, "SELECT COUNT(*) AS aantal_rijen FROM resultaten"))
dbDisconnect(con)

print("Klaar")
