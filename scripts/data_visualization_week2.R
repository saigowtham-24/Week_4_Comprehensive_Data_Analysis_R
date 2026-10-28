# Week 2: Data Visualization and Insight Communication using R
# Student: SONTYANA SAI GOWTHAM
# Submission date: 21/10/2026
# Dataset: Titanic passenger training dataset (891 records)
#
# Run this script from the project folder in R/RStudio.
# It creates nine PNG visualizations in plots/ and summary tables in outputs/.
# Review the actual generated graphs and values before finalizing the report.

# ----------------------------- 1. Setup --------------------------------------

required_packages <- c("titanic", "dplyr", "ggplot2", "tidyr", "scales", "readr")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

library(titanic)
library(dplyr)
library(ggplot2)
library(tidyr)
library(scales)
library(readr)

set.seed(123)

if (!dir.exists("plots")) dir.create("plots", recursive = TRUE)
if (!dir.exists("outputs")) dir.create("outputs", recursive = TRUE)

# -------------------------- 2. Load dataset ----------------------------------

data("titanic_train", package = "titanic")
raw_data <- titanic_train

cat("\n--- Dataset dimensions ---\n")
print(dim(raw_data))
cat("\n--- Variable names ---\n")
print(names(raw_data))
cat("\n--- Dataset summary ---\n")
print(summary(raw_data))

write.csv(
  data.frame(
    rows = nrow(raw_data),
    columns = ncol(raw_data),
    duplicate_rows = sum(duplicated(raw_data))
  ),
  file = file.path("outputs", "dataset_overview.csv"),
  row.names = FALSE
)

# ----------------------- 3. Prepare analysis data ----------------------------

data_clean <- raw_data

# Preserve cabin availability as a separate meaningful category.
data_clean$CabinKnown <- ifelse(
  is.na(data_clean$Cabin) | trimws(as.character(data_clean$Cabin)) == "",
  "Unknown", "Known"
)
data_clean$CabinKnown <- factor(data_clean$CabinKnown,
                                levels = c("Unknown", "Known"))

# Impute selected missing values for plots that need complete observations.
age_median <- median(data_clean$Age, na.rm = TRUE)
fare_median <- median(data_clean$Fare, na.rm = TRUE)
data_clean$Age[is.na(data_clean$Age)] <- age_median
data_clean$Fare[is.na(data_clean$Fare)] <- fare_median

get_mode <- function(x) {
  observed <- x[!is.na(x) & trimws(as.character(x)) != ""]
  if (length(observed) == 0) return(NA_character_)
  names(which.max(table(observed)))
}
embarked_mode <- get_mode(data_clean$Embarked)
if (!is.na(embarked_mode)) {
  missing_embarked <- is.na(data_clean$Embarked) |
    trimws(as.character(data_clean$Embarked)) == ""
  data_clean$Embarked[missing_embarked] <- embarked_mode
}

data_clean <- data_clean |>
  mutate(
    Survived = factor(Survived, levels = c(0, 1),
                      labels = c("Did not survive", "Survived")),
    Pclass = factor(Pclass, levels = c(1, 2, 3),
                    labels = c("First class", "Second class", "Third class")),
    Sex = factor(Sex),
    Embarked = factor(Embarked),
    AgeGroup = cut(
      Age,
      breaks = c(-Inf, 12, 18, 35, 60, Inf),
      labels = c("Child (0–12)", "Teen (13–18)", "Young adult (19–35)",
                 "Adult (36–60)", "Older adult (60+)"),
      right = TRUE
    ),
    LogFare = log1p(Fare)
  )

# Save missingness audit so the report can describe the preprocessing.
missing_before <- data.frame(
  variable = names(raw_data),
  missing_count = colSums(is.na(raw_data)),
  missing_percent = round(100 * colSums(is.na(raw_data)) / nrow(raw_data), 2)
)
missing_after <- data.frame(
  variable = names(data_clean),
  missing_count = colSums(is.na(data_clean)),
  missing_percent = round(100 * colSums(is.na(data_clean)) / nrow(data_clean), 2)
)
write.csv(missing_before, file.path("outputs", "missing_values_before.csv"),
          row.names = FALSE)
write.csv(missing_after, file.path("outputs", "missing_values_after.csv"),
          row.names = FALSE)

# ------------------------ 4. Chart 1: Survival counts ------------------------

p1 <- ggplot(data_clean, aes(x = Survived)) +
  geom_bar() +
  labs(
    title = "Titanic Passenger Survival Counts",
    subtitle = "Number of passengers who survived and did not survive",
    x = "Outcome", y = "Number of passengers"
  ) +
  theme_minimal(base_size = 12)

# --------------------- 5. Chart 2: Age distribution --------------------------

p2 <- ggplot(data_clean, aes(x = Age)) +
  geom_histogram(bins = 30, color = "white") +
  labs(
    title = "Age Distribution of Titanic Passengers",
    subtitle = "Missing ages were filled using the median for analysis",
    x = "Age (years)", y = "Number of passengers"
  ) +
  theme_minimal(base_size = 12)

# --------------------- 6. Chart 3: Fare distribution -------------------------

p3 <- ggplot(data_clean, aes(x = LogFare)) +
  geom_histogram(bins = 30, color = "white") +
  labs(
    title = "Passenger Fare Distribution",
    subtitle = "The horizontal axis uses log(1 + fare) to make skew easier to inspect",
    x = "log(1 + fare)", y = "Number of passengers"
  ) +
  theme_minimal(base_size = 12)

# -------------------- 7. Chart 4: Age vs fare scatter ------------------------

p4 <- ggplot(data_clean, aes(x = Age, y = Fare, color = Pclass)) +
  geom_point(alpha = 0.55, size = 1.8, position = position_jitter(width = 0.15,
                                                                  height = 0)) +
  scale_y_continuous(labels = label_number()) +
  labs(
    title = "Passenger Age and Fare",
    subtitle = "Each point represents one passenger; color indicates passenger class",
    x = "Age (years)", y = "Fare", color = "Passenger class"
  ) +
  theme_minimal(base_size = 12)

# ------------------ 8. Chart 5: Survival by passenger class ------------------

p5 <- ggplot(data_clean, aes(x = Pclass, fill = Survived)) +
  geom_bar(position = "fill") +
  scale_y_continuous(labels = label_percent()) +
  labs(
    title = "Survival Proportion by Passenger Class",
    subtitle = "Each bar represents 100% of passengers within that class",
    x = "Passenger class", y = "Proportion of passengers", fill = "Outcome"
  ) +
  theme_minimal(base_size = 12)

# ----------------------- 9. Chart 6: Survival by sex -------------------------

p6 <- ggplot(data_clean, aes(x = Sex, fill = Survived)) +
  geom_bar(position = "fill") +
  scale_y_continuous(labels = label_percent()) +
  labs(
    title = "Survival Proportion by Sex",
    subtitle = "Compare the share of survivors within each sex category",
    x = "Sex", y = "Proportion of passengers", fill = "Outcome"
  ) +
  theme_minimal(base_size = 12)

# ---------------------- 10. Chart 7: Fare box plot ---------------------------

p7 <- ggplot(data_clean, aes(x = Pclass, y = Fare)) +
  geom_boxplot(outlier.alpha = 0.45) +
  labs(
    title = "Fare Distribution by Passenger Class",
    subtitle = "Points beyond the whiskers are potential outliers, not automatic errors",
    x = "Passenger class", y = "Fare"
  ) +
  theme_minimal(base_size = 12)

# ----------------- 11. Chart 8: Survival by age group ------------------------

age_group_summary <- data_clean |>
  group_by(AgeGroup) |>
  summarise(
    passenger_count = n(),
    survivors = sum(Survived == "Survived"),
    survival_rate = mean(Survived == "Survived"),
    .groups = "drop"
  )

p8 <- ggplot(age_group_summary,
             aes(x = AgeGroup, y = survival_rate, group = 1)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 3) +
  scale_y_continuous(labels = label_percent(), limits = c(0, 1)) +
  labs(
    title = "Survival Rate Across Age Groups",
    subtitle = "Age groups are ordered from youngest to oldest",
    x = "Age group", y = "Survival rate"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

# --------------------- 12. Chart 9: Correlation heatmap ----------------------

numeric_data <- data_clean |>
  select(Age, Fare, SibSp, Parch)

cor_matrix <- cor(numeric_data, use = "pairwise.complete.obs",
                  method = "pearson")
write.csv(round(cor_matrix, 3),
          file.path("outputs", "correlation_matrix.csv"))

cor_long <- as.data.frame(as.table(cor_matrix))
names(cor_long) <- c("Variable1", "Variable2", "Correlation")

p9 <- ggplot(cor_long, aes(x = Variable1, y = Variable2, fill = Correlation)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.2f", Correlation)), size = 3.5) +
  scale_fill_gradient2(limits = c(-1, 1)) +
  labs(
    title = "Correlation Between Numerical Variables",
    subtitle = "Pearson correlation ranges from -1 to +1",
    x = NULL, y = NULL, fill = "Correlation"
  ) +
  theme_minimal(base_size = 12)

# --------------------- 13. Save high-resolution charts -----------------------

plot_list <- list(
  survival_counts = p1,
  age_distribution = p2,
  fare_distribution = p3,
  age_vs_fare_scatter = p4,
  survival_by_class = p5,
  survival_by_sex = p6,
  fare_boxplot = p7,
  survival_by_age_group = p8,
  correlation_heatmap = p9
)

for (plot_name in names(plot_list)) {
  ggsave(
    filename = file.path("plots", paste0(plot_name, ".png")),
    plot = plot_list[[plot_name]],
    width = 8, height = 5.5, units = "in", dpi = 300,
    bg = "white"
  )
}

# --------------------- 14. Export summary outputs ----------------------------

write.csv(age_group_summary,
          file.path("outputs", "visualization_summary.csv"),
          row.names = FALSE)

survival_by_sex <- data_clean |>
  group_by(Sex) |>
  summarise(
    passengers = n(),
    survivors = sum(Survived == "Survived"),
    survival_rate = mean(Survived == "Survived"),
    .groups = "drop"
  )

survival_by_class <- data_clean |>
  group_by(Pclass) |>
  summarise(
    passengers = n(),
    survivors = sum(Survived == "Survived"),
    survival_rate = mean(Survived == "Survived"),
    .groups = "drop"
  )

write.csv(survival_by_sex, file.path("outputs", "survival_by_sex.csv"),
          row.names = FALSE)
write.csv(survival_by_class, file.path("outputs", "survival_by_class.csv"),
          row.names = FALSE)

writeLines(capture.output(sessionInfo()),
           file.path("outputs", "session_info.txt"))

cat("\nWeek 2 visualization script completed.\n")
cat("Nine PNG charts were saved to the 'plots' folder.\n")
cat("Summary tables and reproducibility information were saved to 'outputs'.\n")
cat("Review the generated charts and CSV files before writing final conclusions.\n")
