#' Medium Test: Grand Tour Boundary Comparison (rpart vs PPtreeExt)
#'
#' This script compares classification boundaries from rpart and PPtreeExt
#' on the data69-1 (waveform) dataset using tourr's guided and slice tours.
#' Reproduces Figure 11 subplots (b) and (c) from arxiv.org/abs/2602.21130.
#'
#' Required packages: tourr, rpart, PPtreeExt, classbound, gifski

library(tourr)
library(rpart)
library(PPtreeExt)
library(classbound)

# Create output directory
dir.create("gifs", showWarnings = FALSE)

# ---- 1. Load data ----
data(data69_1)
str(data69_1)

# Y is the class variable (3 classes), V1-V21 are predictors
data69_1$Y <- as.factor(data69_1$Y)
pred_vars <- names(data69_1)[-1]  # V1 to V21

# ---- 2. Fit models ----
# rpart (CART)
rpart_mod <- rpart::rpart(Y ~ ., data = data69_1)

# PPtreeExt (multiple splits)
ppext_mod <- PPtreeExt::PPtreeExtclass(
  Y ~ .,
  data = data69_1,
  PPmethod = "LDA"
)

# ---- 3. Guided tour on raw data (LDA index) ----
# Finds the best 2D projection separating the 3 classes.
# Corresponds to Figure 11(a) in the paper.

set.seed(2025)
guided_path <- save_history(
  data69_1[, -1],
  tour = guided_tour(lda_pp(data69_1$Y)),
  max_bases = 100
)

# Extract the best (last) projection basis
best_basis <- matrix(guided_path[, , dim(guided_path)[3]],
                     ncol = 2)

# Color palette matching the paper (blue=class0, red=class1, gold=class2)
color_map <- c("dodgerblue", "red", "gold")
data_col <- color_map[as.numeric(data69_1$Y)]

# Save guided tour as GIF
render_gif(
  data69_1[, -1],
  planned_tour(guided_path),
  display_xy(col = data_col,
             axes = "bottomleft"),
  gif_file = "gifs/data69_1_guided_tour.gif",
  frames = 200,
  loop = FALSE
)
cat("Guided tour GIF saved to gifs/data69_1_guided_tour.gif\n")

# ---- 4. Generate points NEAR the data ----
# In 21D, uniform random points are mostly in empty space.
# Instead, we jitter real data points to stay near the data manifold
# where the classifiers actually differ at the boundaries.

n_pts <- 50000
set.seed(42)

# Compute per-variable standard deviation for noise scaling
sds <- sapply(data69_1[, pred_vars], sd)

# Sample rows from the data with replacement, then add Gaussian noise
sampled_rows <- data69_1[sample(nrow(data69_1), n_pts, replace = TRUE), pred_vars]
noise <- matrix(rnorm(n_pts * length(pred_vars)), ncol = length(pred_vars))
# Scale noise to ~30% of each variable's SD
noise <- sweep(noise, 2, sds * 0.3, "*")
grid_pts <- as.data.frame(as.matrix(sampled_rows) + noise)
colnames(grid_pts) <- pred_vars

# ---- 5. Predict using both models ----
grid_pts$rpart_pred <- predict(rpart_mod, newdata = grid_pts, type = "class")
ppext_pred_result   <- predict(object = ppext_mod, newdata = grid_pts[, pred_vars])
grid_pts$ppext_pred <- ppext_pred_result[[2]]

# Check how many predictions differ between models
cat("Predictions differ on",
    sum(as.character(grid_pts$rpart_pred) != as.character(grid_pts$ppext_pred)),
    "out of", n_pts, "points\n")

# ---- 6. Prepare boundary data with consistent colors ----
ppext_boundary <- grid_pts[, pred_vars]
ppext_col <- color_map[as.numeric(as.factor(grid_pts$ppext_pred))]

rpart_boundary <- grid_pts[, pred_vars]
rpart_col <- color_map[as.numeric(grid_pts$rpart_pred)]

# ---- 7. Slice tour on boundaries ----
# Uses the same projection path from the guided tour.
# Corresponds to Figure 11(b) and (c) in the paper.

# PPtreeExt boundaries - slice tour (Figure 11b)
cat("Rendering PPtreeExt boundary GIF...\n")
render_gif(
  ppext_boundary,
  planned_tour(guided_path),
  display_slice(
    v_rel = 0.04,
    col = ppext_col,
    axes = "bottomleft"
  ),
  gif_file = "gifs/data69_1_ppext_boundaries.gif",
  frames = 200,
  loop = FALSE
)
cat("PPtreeExt boundary GIF saved.\n")

# rpart boundaries - slice tour (Figure 11c)
cat("Rendering rpart boundary GIF...\n")
render_gif(
  rpart_boundary,
  planned_tour(guided_path),
  display_slice(
    v_rel = 0.04,
    col = rpart_col,
    axes = "bottomleft"
  ),
  gif_file = "gifs/data69_1_rpart_boundaries.gif",
  frames = 200,
  loop = FALSE
)
cat("rpart boundary GIF saved.\n")

# ---- 8. Static comparison at the best projection ----
data_proj <- as.matrix(data69_1[, -1]) %*% best_basis
ppext_proj <- as.matrix(ppext_boundary) %*% best_basis
rpart_proj <- as.matrix(rpart_boundary) %*% best_basis

par(mfrow = c(1, 3), mar = c(4, 4, 3, 1))

# (a) Data
plot(data_proj[, 1], data_proj[, 2],
     col = data_col,
     pch = 16, cex = 0.6,
     xlab = "Proj 1", ylab = "Proj 2",
     main = "(a) data")

# (b) PPtreeExt boundaries
plot(ppext_proj[, 1], ppext_proj[, 2],
     col = ppext_col,
     pch = 16, cex = 0.3,
     xlab = "Proj 1", ylab = "Proj 2",
     main = "(b) PPtreeExt")

# (c) rpart boundaries
plot(rpart_proj[, 1], rpart_proj[, 2],
     col = rpart_col,
     pch = 16, cex = 0.3,
     xlab = "Proj 1", ylab = "Proj 2",
     main = "(c) rpart")

par(mfrow = c(1, 1))

cat("\nDone! Compare the GIFs and static plots.\n")
cat("PPtreeExt should show clean oblique boundaries.\n")
cat("rpart should show messy/boxy boundaries.\n")
