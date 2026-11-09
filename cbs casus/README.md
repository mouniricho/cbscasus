# Casus 1

Voor deze casus heb ik de kwartaalmutaties van koffie en elektriciteit berekend met gegevens van het CBS. Hiervoor heb ik R en PostgreSQL gebruikt.

## Proces

### 1. Data ophalen

Met het package `cbsodataR` haal ik de maandelijkse consumentenprijsindex op uit CBS StatLine. Hiervoor gebruik ik tabel `86141NED` en de productcategorieën koffie en elektriciteit.

### 2. Berekeningen

Met de maandcijfers bereken ik eerst per kwartaal de gemiddelde CPI. Vervolgens bereken ik de procentuele verandering ten opzichte van het vorige kwartaal.

Hiervoor heb ik een functie gemaakt waarbij je een kwartaal kunt opgeven, bijvoorbeeld `2025Q2`.

### 3. Resultaten

De resultaten van 2022 tot en met 2025 worden opgeslagen in PostgreSQL, in de tabel `resultaten`.

Daarnaast maak ik twee grafieken: één met de ontwikkeling van de consumentenprijzen en één met de kwartaalmutaties. Deze worden opgeslagen in de map `grafieken`.

## Uitvoeren

Installeer eerst de benodigde R-packages:

```r
install.packages(c("cbsodataR", "dplyr", "ggplot2", "DBI", "RPostgres"))
```

Maak daarna in PostgreSQL een database aan met:

```sql
CREATE DATABASE cbs_casus;
```

Dit hoeft maar één keer.

Open vervolgens de projectmap in RStudio en voer het script uit:

```r
source("analyse.R")
```

Het script haalt de gegevens op, berekent de kwartaalmutaties en slaat de resultaten op in PostgreSQL. De grafieken worden opgeslagen in de map `grafieken`.