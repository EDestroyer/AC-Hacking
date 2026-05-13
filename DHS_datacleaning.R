# Install the package (only needed once)
install.packages("haven")
library(haven)

# Read the DHS file
dhs <- read_sav("C:/ACHacking/Ghana_DHS/GHHR8CSV/GHHR8CFL.SAV")

# See what columns exist
colnames(dhs)


#Extract Neccessary Variables from Ghana 2022 Survey
# Define all variables of interest
vars <- c("HV001",   # Cluster ID (for joining to shapefile)
          "HV201",   # Main drinking water source
          "HV202",   # Main water source for household use
          "HV201A",  # Water unavailable 1+ full day in past 2 weeks
          "HV204",   # Time to water source (minutes)
          "HV206",   # Electricity
          "HV207",   # Radio
          "HV208",   # Television
          "HV209",   # Refrigerator
          "HV235",   # Location of water source
          "HV270",   # Wealth index (categorical)
          "HV271",   # Wealth index factor score
          "HV270A",  # Wealth index urban/rural
          "HV271A")  # Wealth index factor score urban/rural

# Check which ones actually exist in the dataset
found <- vars %in% colnames(dhs)
print(data.frame(Variable=vars, Found=found))

# Extract only the ones that exist
vars_found <- vars[found]
dhs_small <- dhs[, vars_found]

# Quick summary of key variables
print(table(dhs_small$HV201))   # Water source codes
print(summary(dhs_small$HV271)) # Wealth score range
print(table(dhs_small$HV206))   # Electricity yes/no

# Export
write.csv(dhs_small, "C:/ACHacking/Ghana_DHS/wealth_water.csv", row.names = FALSE)
print("Done!")

#Extract Variable Response Labels
# See the actual labels attached to the data
print(attr(dhs_small$HV201, "labels"))
print(attr(dhs_small$HV202, "labels"))
print(attr(dhs_small$HV235, "labels"))
print(attr(dhs_small$HV204, "labels"))

# ── Water Insecurity Index ──────────────────────────────────────────

# Category 1 — Unsafe water source (quality problem)
# Unprotected well (32), unprotected spring (42), 
# river/dam/lake (43), rainwater (51)
dhs_small$unsafe_source <- ifelse(
  dhs_small$HV201 %in% c(32, 42, 43, 51), 1, 0)

# Category 2 — Water not on premises (access problem)
# Source elsewhere (HV235=3) or not on premises (HV204=998)
dhs_small$no_water_onpremises <- ifelse(
  dhs_small$HV235 == 3 | dhs_small$HV204 == 998, 1, 0)

# Category 3 — Either vulnerability (combined)
dhs_small$water_vulnerable <- ifelse(
  dhs_small$unsafe_source == 1 | 
    dhs_small$no_water_onpremises == 1, 1, 0)

# Category 4 — Both vulnerabilities simultaneously (highest priority)
dhs_small$both_vulnerable <- ifelse(
  dhs_small$unsafe_source == 1 & 
    dhs_small$no_water_onpremises == 1, 1, 0)

# ── Summary Statistics ──────────────────────────────────────────────
print(paste("Unsafe source:        ", round(mean(dhs_small$unsafe_source,        na.rm=TRUE)*100, 1), "%"))
print(paste("No water on premises: ", round(mean(dhs_small$no_water_onpremises,  na.rm=TRUE)*100, 1), "%"))
print(paste("Either vulnerability: ", round(mean(dhs_small$water_vulnerable,     na.rm=TRUE)*100, 1), "%"))
print(paste("Both vulnerabilities: ", round(mean(dhs_small$both_vulnerable,      na.rm=TRUE)*100, 1), "%"))

# Save Full File
write.csv(dhs_small, "C:/ACHacking/Ghana_DHS/wealth_water.csv", row.names=FALSE)
print("Saved!")

#to int
# Re-read if needed
# dhs_small is probably still in memory, check top right panel

# Make sure all columns are numeric
dhs_small$unsafe_source <- as.integer(dhs_small$unsafe_source)
dhs_small$no_water_onpremises <- as.integer(dhs_small$no_water_onpremises)
dhs_small$water_vulnerable <- as.integer(dhs_small$water_vulnerable)
dhs_small$both_vulnerable <- as.integer(dhs_small$both_vulnerable)
dhs_small$HV271 <- as.numeric(dhs_small$HV271)
dhs_small$HV206 <- as.integer(dhs_small$HV206)
dhs_small$HV001 <- as.integer(dhs_small$HV001)

# Verify
str(dhs_small[, c("HV001", "unsafe_source", "no_water_onpremises", 
                  "water_vulnerable", "both_vulnerable", "HV271", "HV206")])

# Re-export
write.csv(dhs_small, "C:/ACHacking/Ghana_DHS/wealth_water.csv", row.names=FALSE)
print("Saved with correct numeric types!")

#Deal with Null Values
# Replace NAs with 0 for binary columns
dhs_small$unsafe_source[is.na(dhs_small$unsafe_source)] <- 0
dhs_small$no_water_onpremises[is.na(dhs_small$no_water_onpremises)] <- 0
dhs_small$water_vulnerable[is.na(dhs_small$water_vulnerable)] <- 0
dhs_small$both_vulnerable[is.na(dhs_small$both_vulnerable)] <- 0

# Check NAs are gone
print(colSums(is.na(dhs_small)))

# Re-export
write.csv(dhs_small, "C:/ACHacking/Ghana_DHS/wealth_water.csv", row.names=FALSE)
print("Saved!")

#Aggregate Cluster Data
install.packages("dplyr")
library(dplyr)

cluster_summary <- dhs_small %>%
  group_by(HV001) %>%
  summarise(
    n_households   = n(),
    pct_unsafe     = round(mean(unsafe_source,       na.rm=TRUE)*100, 1),
    pct_nopremis   = round(mean(no_water_onpremises, na.rm=TRUE)*100, 1),
    pct_vulnerable = round(mean(water_vulnerable,    na.rm=TRUE)*100, 1),
    pct_both       = round(mean(both_vulnerable,     na.rm=TRUE)*100, 1),
    mean_wealth    = round(mean(HV271,               na.rm=TRUE), 1),
    pct_elec       = round(mean(HV206,               na.rm=TRUE)*100, 1)
  )

print(paste("Number of clusters:", nrow(cluster_summary)))
write.csv(cluster_summary, 
          "C:/ACHacking/Ghana_DHS/cluster_summary.csv", 
          row.names=FALSE)
print("Done!")

library(haven)
dhs_small <- read_sav("C:/ACHacking/Ghana_DHS/GHHR8CSV/GHHR8CFL.SAV")
water_counts <- table(dhs_small$HV201)
print(water_counts)

library(ggplot2)
library(haven)

install.packages("ggplot2")
library(ggplot2)


# Use exact counts from your data
water_sources <- data.frame(
  Source = c("Sachet Water (72)", 
             "Borehole/Tube Well (21)", 
             "Public Tap (14)", 
             "River/Lake/Dam (43)",
             "Piped to Yard (12)", 
             "Protected Well (31)",
             "Piped to Neighbor (13)",
             "Bottled Water (71)",
             "Piped to Dwelling (11)",
             "Unprotected Well (32)",
             "Unprotected Spring (42)",
             "Rainwater (51)"),
  Count = c(5089, 4662, 2289, 1783, 900, 847, 718, 271, 459, 537, 177, 137)
)

ggplot(water_sources, aes(x=reorder(Source, Count), y=Count,
                          fill=Source == "Sachet Water (72)")) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=c("#D4845A", "#8B3A2A")) +
  coord_flip() +
  labs(title="Primary Drinking Water Sources in Ghana",
       subtitle="DHS Household Recode 2022 (n=17,933 households)",
       x="", y="Number of Households") +
  theme_minimal() +
  theme(legend.position="none",
        plot.title=element_text(face="bold", size=14),
        axis.text=element_text(size=10),
        plot.subtitle=element_text(size=10, color="gray50")) +
  geom_text(aes(label=Count), hjust=-0.1, size=3.5)

ggsave("C:/ACHacking/water_sources_chart.png",
       width=10, height=6, dpi=300)
print("Saved!")


install.packages("jsonlite")

install.packages("curl", dependencies=TRUE)

library(showtext)
font_add_google("Alegreya Sans", "alegreya")
showtext_auto()

library(ggplot2)

total <- 17933

water_sources <- data.frame(
  Source = c("Sachet Water", 
             "Borehole/Tube Well", 
             "Public Tap", 
             "River/Lake/Dam",
             "Piped to Yard", 
             "Protected Well",
             "Piped to Neighbor",
             "Piped to Dwelling",
             "Unprotected Well",
             "Bottled Water",
             "Unprotected Spring",
             "Rainwater"),
  Count = c(5089, 4662, 2289, 1783, 900, 847, 718, 459, 537, 271, 177, 137),
  Pct = round(c(5089, 4662, 2289, 1783, 900, 847, 718, 459, 537, 271, 177, 137) 
              / total * 100, 1)
)

ggplot(water_sources, aes(x=reorder(Source, Pct), y=Pct,
                          fill=Source == "Sachet Water")) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=c("#D4845A", "#8B3A2A")) +
  coord_flip() +
  labs(title="Primary Drinking Water Sources in Ghana",
       subtitle="DHS Household Recode 2022 (n=17,933 households)",
       x="", y="% of Households Surveyed") +
  theme_minimal() +
  theme(legend.position="none",
        plot.title=element_text(face="bold", size=14, 
                                family="sans"),
        axis.text=element_text(size=10, family="sans"),
        plot.subtitle=element_text(size=10, color="gray50",
                                   family="sans")) +
  geom_text(aes(label=paste0(Pct, "%")), 
            hjust=-0.1, size=3.5, family="sans")

ggsave("C:/ACHacking/water_sources_chart.png",
       width=10, height=6, dpi=300, bg="white")
print("Saved!")

library(ggplot2)
library(showtext)
font_add_google("Alegreya Sans", "alegreya")
showtext_auto()

water_sources <- data.frame(
  Source = c("Sachet Water", 
             "Borehole/Tube Well", 
             "Public Tap",
             "River/Lake/Dam",
             "Piped to Yard"),
  Pct = c(28.4, 26.0, 12.8, 9.9, 5.0)
)

ggplot(water_sources, aes(x=reorder(Source, Pct), y=Pct,
                          fill=Source == "Sachet Water")) +
  geom_bar(stat="identity") +
  scale_fill_manual(values=c("#D4845A", "#8B3A2A")) +
  coord_flip() +
  labs(title="Top 5 Drinking Water Sources in Ghana",
       subtitle="DHS Household Recode 2022 (n=17,933)",
       x="", y="% of Households") +
  theme_minimal(base_size=50) +
  theme(legend.position="none",
        plot.title=element_text(face="bold", size=60, family="alegreya"),
        axis.text=element_text(size=50, family="alegreya"),
        plot.subtitle=element_text(size=40, family="alegreya", color="gray50")) +
  geom_text(aes(label=paste0(Pct, "%")), 
            hjust=-0.1, size=7, family="alegreya") +
  scale_y_continuous(limits=c(0,35))

ggsave("C:/ACHacking/water_sources_chart.png",
       width=10, height=5, dpi=300, bg="white")
print("Saved!")