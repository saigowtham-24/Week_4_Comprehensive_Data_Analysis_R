# Week 3: Statistical Analysis and Predictive Modeling using R
# Dataset: public Titanic training dataset (891 passenger records)
# Run from the project root in RStudio.
# Required packages: ggplot2, dplyr, tidyr, caret, randomForest, pROC

required <- c("ggplot2", "scales", "dplyr", "tidyr", "caret", "randomForest", "pROC")
missing_pkgs <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs)) {
  install.packages(missing_pkgs, repos = "https://cloud.r-project.org")
}
invisible(lapply(required, library, character.only = TRUE))

dir.create("plots", showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)
dir.create("screenshots", showWarnings = FALSE)
dir.create("data", showWarnings = FALSE)

data_url <- "https://raw.githubusercontent.com/datasciencedojo/datasets/master/titanic.csv"
data_file <- file.path("data", "titanic_train.csv")
if (!file.exists(data_file)) {
  download.file(data_url, data_file, mode = "wb", quiet = FALSE)
}
raw <- read.csv(data_file, stringsAsFactors = FALSE)
stopifnot(all(c("Survived", "Pclass", "Sex", "Age", "SibSp", "Parch", "Fare", "Embarked") %in% names(raw)))

df <- raw %>%
  select(Survived, Pclass, Sex, Age, SibSp, Parch, Fare, Embarked) %>%
  mutate(
    Survived = factor(ifelse(Survived == 1, "Yes", "No"), levels = c("No", "Yes")),
    Pclass = factor(Pclass, levels = c(1, 2, 3), labels = c("First", "Second", "Third")),
    Sex = factor(Sex),
    Embarked = na_if(Embarked, "")
  )

# Save raw missingness before imputation.
missing_before <- data.frame(variable = names(df),
                             missing_count = sapply(df, function(x) sum(is.na(x))),
                             missing_percent = round(sapply(df, function(x) mean(is.na(x)) * 100), 2))
write.csv(missing_before, "outputs/missing_values_before.csv", row.names = FALSE)

# Impute numeric fields with medians and categorical Embarked with mode.
median_age <- median(df$Age, na.rm = TRUE)
median_fare <- median(df$Fare, na.rm = TRUE)
mode_embarked <- names(which.max(table(df$Embarked)))
df$Age[is.na(df$Age)] <- median_age
df$Fare[is.na(df$Fare)] <- median_fare
df$Embarked[is.na(df$Embarked)] <- mode_embarked

missing_after <- data.frame(variable = names(df),
                            missing_count = sapply(df, function(x) sum(is.na(x))),
                            missing_percent = round(sapply(df, function(x) mean(is.na(x)) * 100), 2))
write.csv(missing_after, "outputs/missing_values_after.csv", row.names = FALSE)

# Dataset overview and descriptive statistics.
overview <- data.frame(rows = nrow(df), columns = ncol(df),
                       survivors = sum(df$Survived == "Yes"),
                       non_survivors = sum(df$Survived == "No"),
                       survival_rate_percent = round(mean(df$Survived == "Yes") * 100, 2))
write.csv(overview, "outputs/dataset_overview.csv", row.names = FALSE)
desc <- data.frame(
  variable = c("Age", "Fare", "SibSp", "Parch"),
  mean = c(mean(df$Age), mean(df$Fare), mean(df$SibSp), mean(df$Parch)),
  median = c(median(df$Age), median(df$Fare), median(df$SibSp), median(df$Parch)),
  sd = c(sd(df$Age), sd(df$Fare), sd(df$SibSp), sd(df$Parch)),
  min = c(min(df$Age), min(df$Fare), min(df$SibSp), min(df$Parch)),
  max = c(max(df$Age), max(df$Fare), max(df$SibSp), max(df$Parch))
)
write.csv(desc, "outputs/descriptive_statistics.csv", row.names = FALSE)

# Hypothesis tests. Chi-square for categorical associations; Wilcoxon for age between outcomes.
sex_tab <- table(df$Sex, df$Survived)
sex_chi <- chisq.test(sex_tab)
class_tab <- table(df$Pclass, df$Survived)
class_chi <- chisq.test(class_tab)
age_wilcox <- wilcox.test(Age ~ Survived, data = df, exact = FALSE)
age_sample <- sample(df$Age, min(500, length(df$Age)))
age_shapiro <- shapiro.test(age_sample)
fare_sample <- sample(df$Fare, min(500, length(df$Fare)))
fare_shapiro <- shapiro.test(fare_sample)

test_results <- data.frame(
  test = c("Chi-square: Sex vs Survival", "Chi-square: Class vs Survival",
           "Wilcoxon: Age by Survival", "Shapiro-Wilk: Age sample", "Shapiro-Wilk: Fare sample"),
  statistic = c(unname(sex_chi$statistic), unname(class_chi$statistic),
                unname(age_wilcox$statistic), unname(age_shapiro$statistic), unname(fare_shapiro$statistic)),
  df = c(unname(sex_chi$parameter), unname(class_chi$parameter), NA, NA, NA),
  p_value = c(sex_chi$p.value, class_chi$p.value, age_wilcox$p.value,
              age_shapiro$p.value, fare_shapiro$p.value),
  null_hypothesis = c("Sex and survival are independent", "Passenger class and survival are independent",
                      "Age distributions are equal between survival groups",
                      "Sampled age values follow a normal distribution",
                      "Sampled fare values follow a normal distribution")
)
test_results$decision_alpha_0_05 <- ifelse(test_results$p_value < 0.05, "Reject H0", "Fail to reject H0")
write.csv(test_results, "outputs/hypothesis_test_results.csv", row.names = FALSE)

# Correlations use numeric variables; report Pearson matrix.
num_df <- df %>% transmute(Age, Fare, SibSp, Parch, SurvivedNumeric = as.numeric(Survived == "Yes"))
cor_mat <- cor(num_df, use = "complete.obs", method = "pearson")
write.csv(round(cor_mat, 4), "outputs/correlation_matrix.csv")

# Plot helper
theme_set(theme_minimal(base_size = 12))
p1 <- ggplot(df, aes(Survived, fill = Survived)) +
  geom_bar(show.legend = FALSE) + labs(title = "Titanic Survival Counts", x = "Outcome", y = "Passenger count")
ggsave("plots/survival_distribution.png", p1, width = 7, height = 5, dpi = 160)

p2 <- ggplot(df, aes(Age, fill = Survived)) +
  geom_histogram(bins = 25, alpha = 0.65, position = "identity") +
  labs(title = "Age Distribution by Survival", x = "Age", y = "Passenger count")
ggsave("plots/age_distribution.png", p2, width = 7, height = 5, dpi = 160)

p3 <- ggplot(df, aes(Pclass, Fare, fill = Pclass)) +
  geom_boxplot(show.legend = FALSE) + labs(title = "Fare by Passenger Class", x = "Passenger class", y = "Fare")
ggsave("plots/fare_by_class_boxplot.png", p3, width = 7, height = 5, dpi = 160)

p4 <- ggplot(df, aes(Pclass, fill = Survived)) +
  geom_bar(position = "fill") + scale_y_continuous(labels = scales::percent) +
  labs(title = "Survival Proportion by Passenger Class", x = "Passenger class", y = "Proportion")
ggsave("plots/survival_by_class.png", p4, width = 7, height = 5, dpi = 160)

p5 <- ggplot(df, aes(Sex, fill = Survived)) +
  geom_bar(position = "fill") + scale_y_continuous(labels = scales::percent) +
  labs(title = "Survival Proportion by Sex", x = "Sex", y = "Proportion")
ggsave("plots/survival_by_sex.png", p5, width = 7, height = 5, dpi = 160)

p6 <- ggplot(df, aes(Age, Fare, colour = Survived)) +
  geom_point(alpha = 0.45) + labs(title = "Age versus Fare", x = "Age", y = "Fare")
ggsave("plots/age_vs_fare_scatter.png", p6, width = 7, height = 5, dpi = 160)

p7 <- ggplot(df, aes(Age, fill = Survived)) +
  geom_density(alpha = 0.35) + labs(title = "Age Density by Survival", x = "Age", y = "Density")
ggsave("plots/age_density.png", p7, width = 7, height = 5, dpi = 160)

# Train/test split and cross-validation.
set.seed(42)
train_index <- createDataPartition(df$Survived, p = 0.80, list = FALSE)
train_df <- df[train_index, ]
test_df <- df[-train_index, ]

ctrl <- trainControl(method = "repeatedcv", number = 5, repeats = 3,
                     classProbs = TRUE, summaryFunction = twoClassSummary,
                     savePredictions = "final", verboseIter = FALSE)
set.seed(42)
logit_fit <- train(Survived ~ ., data = train_df, method = "glm",
                   family = binomial(), metric = "ROC", trControl = ctrl)
set.seed(42)
rf_fit <- train(Survived ~ ., data = train_df, method = "rf",
                ntree = 400, metric = "ROC", trControl = ctrl,
                tuneLength = 3, importance = TRUE)

# Held-out predictions; positive class is Yes because factor levels are No, Yes.
logit_prob <- predict(logit_fit, newdata = test_df, type = "prob")[, "Yes"]
rf_prob <- predict(rf_fit, newdata = test_df, type = "prob")[, "Yes"]
logit_pred <- factor(ifelse(logit_prob >= 0.5, "Yes", "No"), levels = c("No", "Yes"))
rf_pred <- factor(ifelse(rf_prob >= 0.5, "Yes", "No"), levels = c("No", "Yes"))

metrics <- function(actual, predicted, prob, model_name) {
  cm <- confusionMatrix(predicted, actual, positive = "Yes")
  roc_obj <- roc(response = actual, predictor = prob, levels = c("No", "Yes"), direction = "<", quiet = TRUE)
  data.frame(model = model_name,
             accuracy = unname(cm$overall["Accuracy"]),
             precision = unname(cm$byClass["Precision"]),
             recall = unname(cm$byClass["Sensitivity"]),
             specificity = unname(cm$byClass["Specificity"]),
             f1 = unname(cm$byClass["F1"]),
             roc_auc = as.numeric(auc(roc_obj)))
}
model_comparison <- bind_rows(
  metrics(test_df$Survived, logit_pred, logit_prob, "Logistic Regression"),
  metrics(test_df$Survived, rf_pred, rf_prob, "Random Forest")
)
write.csv(model_comparison, "outputs/model_comparison.csv", row.names = FALSE)

best_row <- which.max(model_comparison$roc_auc)
best_name <- model_comparison$model[best_row]
best_pred <- if (best_name == "Logistic Regression") logit_pred else rf_pred
best_prob <- if (best_name == "Logistic Regression") logit_prob else rf_prob
best_fit <- if (best_name == "Logistic Regression") logit_fit else rf_fit

cm_table <- as.data.frame.matrix(table(Actual = test_df$Survived, Predicted = best_pred))
write.csv(cm_table, "outputs/confusion_matrix.csv")
pred_out <- data.frame(actual = test_df$Survived, predicted = best_pred, probability_survived = best_prob)
write.csv(pred_out, "outputs/test_predictions.csv", row.names = FALSE)

# ROC plot
roc_logit <- roc(test_df$Survived, logit_prob, levels = c("No", "Yes"), direction = "<", quiet = TRUE)
roc_rf <- roc(test_df$Survived, rf_prob, levels = c("No", "Yes"), direction = "<", quiet = TRUE)
png("plots/roc_curve.png", width = 1200, height = 900, res = 150)
plot(roc_logit, col = "steelblue", lwd = 3, main = "ROC Curves on Held-out Test Set")
plot(roc_rf, col = "darkorange", lwd = 3, add = TRUE)
legend("bottomright", legend = c(paste0("Logistic Regression AUC = ", round(auc(roc_logit), 3)),
                                  paste0("Random Forest AUC = ", round(auc(roc_rf), 3))),
       col = c("steelblue", "darkorange"), lwd = 3)
dev.off()

png("plots/confusion_matrix.png", width = 1000, height = 800, res = 150)
fourfoldplot(table(Actual = test_df$Survived, Predicted = best_pred),
             color = c("lightgray", "steelblue"), main = paste("Confusion Matrix:", best_name))
dev.off()

# Random Forest variable importance.
imp <- varImp(rf_fit)$importance
imp$feature <- rownames(imp)
write.csv(imp, "outputs/random_forest_variable_importance.csv", row.names = FALSE)
imp_long <- imp %>% pivot_longer(cols = -feature, names_to = "class", values_to = "importance")
p_imp <- ggplot(imp_long, aes(reorder(feature, importance), importance)) +
  geom_col(fill = "steelblue") + coord_flip() +
  labs(title = "Random Forest Variable Importance", x = "Predictor", y = "Importance")
ggsave("plots/variable_importance.png", p_imp, width = 7, height = 5, dpi = 160)

# Logistic regression residual diagnostics on the training model.
logit_glm <- glm(Survived ~ ., data = train_df, family = binomial())
png("plots/logistic_diagnostics.png", width = 1200, height = 900, res = 150)
par(mfrow = c(2, 2))
plot(logit_glm)
dev.off()

writeLines(capture.output(sessionInfo()), "outputs/session_info.txt")
writeLines(capture.output(summary(logit_glm)), "outputs/logistic_regression_summary.txt")
writeLines(capture.output(rf_fit), "outputs/random_forest_cv_summary.txt")

cat("\nAnalysis completed.\n")
cat("Dataset rows:", nrow(df), "\n")
cat("Survival rate:", round(mean(df$Survived == "Yes") * 100, 2), "%\n")
print(model_comparison)
cat("Selected model by test ROC-AUC:", best_name, "\n")


# Submission output names requested for the project package
file.copy("outputs/missing_values_after.csv", "outputs/missing_values.csv", overwrite = TRUE)

# Export permutation importance in a consistent two-column format.
perm_imp <- tryCatch({
  rf_imp <- randomForest::importance(rf_fit$finalModel, type = 1)
  data.frame(feature = rownames(rf_imp), importance_mean = as.numeric(rf_imp[, 1]))
}, error = function(e) data.frame(feature = character(), importance_mean = numeric()))
write.csv(perm_imp, "outputs/permutation_importance.csv", row.names = FALSE)

# Grouped survival plot used in the report.
p_sex_class <- ggplot(df, aes(x = Pclass, fill = Survived)) +
  geom_bar(position = "fill") + facet_wrap(~ Sex) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Survival Proportion by Sex and Passenger Class", x = "Passenger class", y = "Survival proportion")
ggsave("plots/survival_by_sex_class.png", p_sex_class, width = 8, height = 5, dpi = 160)

summary_lines <- c(
  "WEEK 3 ANALYSIS SUMMARY",
  paste("Dataset rows:", nrow(df)),
  paste("Survival rate:", round(mean(df$Survived == "Yes") * 100, 2), "%"),
  paste("Selected model by held-out ROC-AUC:", best_name),
  "Model metrics are available in outputs/model_comparison.csv.",
  "Interpret statistical associations and feature importance as non-causal."
)
writeLines(summary_lines, "outputs/analysis_summary.txt")
