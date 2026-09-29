#!/usr/bin/env Rscript

# Note: originally forked from:
# https://github.com/scrna-bench/datasets/tree/use-anndatar
# Adapted from:
# https://github.com/omni-scrna/1-data

suppressPackageStartupMessages({
  library(argparser)
  library(yaml)
})

source("src/common/cli.R")

p <- arg_parser("DATA module")
p <- add_base_args(p)
p <- add_argument(p, "--dataset_name", type = "character", help = "dataset identifier")
p <- add_argument(p, "--batch_var", type = "character", help = "batch column name")
p <- add_argument(p, "--sample_var", type = "character", help = "sample column name")
p <- add_argument(p, "--labels_var", type = "character", help = "cell type labels column name")
args <- parse_args(p)

h5ad_path <- file.path(args$output_dir, paste0(args$name, ".h5ad"))
clusters_truth_path <- file.path(args$output_dir, paste0(args$name, ".clusters_truth.tsv"))
num_clusters_truth_path <- file.path(args$output_dir, paste0(args$name, ".clusters_truth_num.txt"))
properties_path <- file.path(args$output_dir, paste0(args$name, "_properties.yaml"))

dataset_catalog <- list(
  p31_s42_narrow_signal = list(
    repository = "btraven/splatter-cube-pbmc3k",
    source = "huggingface",
    revision = "main",
    filename = "data/p31_s42.h5ad",
    labels_var = "Group"

  ),
  p35_s42_broad_signal = list(
    repository = "btraven/splatter-cube-pbmc3k",
    source = "huggingface",
    revision = "main",
    filename = "data/p35_s42.h5ad",
    labels_var = "Group"
  ),
  p38_s42_strong_signal = list(
    repository = "btraven/splatter-cube-pbmc3k",
    source = "huggingface",
    revision = "main",
    filename = "data/p38_s42.h5ad",
    labels_var = "Group"
  ),
  human_mec_50362 = list(
    source = "cellxgene",
    repository = "283d65eb-dd53-496d-adb7-7570c7caa443",
    revision = "73118fbf-bb19-49c8-bfad-bdf9eb8e103d",
    filename = "73118fbf-bb19-49c8-bfad-bdf9eb8e103d.h5ad",
    url = paste0(
      "https://datasets.cellxgene.cziscience.com/",
      "73118fbf-bb19-49c8-bfad-bdf9eb8e103d.h5ad"
    ),
    labels_var = "supercluster_term"
)
)

if (!(args$dataset_name %in% names(dataset_catalog))) {
  stop(sprintf("Unknown dataset: %s", args$dataset_name))
}

dataset <- dataset_catalog[[args$dataset_name]]

labels_var <- args$labels_var
if (is.null(labels_var) || is.na(labels_var) || !nzchar(labels_var)) {
  labels_var <- dataset$labels_var
}


if (!is.null(dataset$url)) {
  url <- dataset$url
} else {
  url <- sprintf(
    "https://huggingface.co/datasets/%s/resolve/%s/%s",
    dataset$repository,
    dataset$revision,
    dataset$filename
  )
}

options(timeout = max(3600, getOption("timeout", 60)))

write(sprintf("downloading: %s", url), stderr())
download.file(url, destfile = h5ad_path, mode = "wb", ethod = "libcurl")

# Read only cell IDs and labels from the H5AD metadata.
obs_listing <- rhdf5::h5ls(h5ad_path, recursive = TRUE)
obs_columns <- obs_listing$name[obs_listing$group == "/obs"]

if (!(labels_var %in% obs_columns)) {
  stop(sprintf(
    "Label column '%s' not found. Available obs columns: %s",
    labels_var,
    paste(obs_columns, collapse = ", ")
  ))
}

obs_attributes <- rhdf5::h5readAttributes(h5ad_path, "/obs")
index_name <- obs_attributes[["_index"]]

if (is.null(index_name) || !nzchar(index_name)) {
  index_name <- "_index"
}

cell_ids <- rhdf5::h5read(
  h5ad_path,
  paste0("/obs/", index_name)
)

label_object <- rhdf5::h5read(
  h5ad_path,
  paste0("/obs/", labels_var)
)

# AnnData normally stores categorical obs columns as categories + integer codes.
if (is.list(label_object) &&
    all(c("categories", "codes") %in% names(label_object))) {
  categories <- as.character(label_object$categories)
  codes <- as.integer(label_object$codes)

  labels <- rep(NA_character_, length(codes))
  valid <- codes >= 0L
  labels[valid] <- categories[codes[valid] + 1L]
} else {
  labels <- as.character(label_object)
}

clusters_truth <- data.frame(
  cell_id = as.character(cell_ids),
  label = labels
)

if (anyNA(clusters_truth$label)) {
  stop(sprintf("Label column '%s' contains missing values", labels_var))
}

write.table(
  clusters_truth,
  clusters_truth_path,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)

num_clusters_truth <- length(unique(clusters_truth$label))
writeLines(as.character(num_clusters_truth), num_clusters_truth_path)

yaml::write_yaml(
  list(
    dataset_name = args$dataset_name,
    source = "huggingface",
    source_repository = dataset$repository,
    source_revision = dataset$revision,
    source_url = url,
    source_filename = dataset$filename,
    batch_var = args$batch_var,
    sample_var = args$sample_var,
    labels_var = labels_var,
    num_clusters_truth = num_clusters_truth
  ),
  properties_path
)

write(sprintf("wrote: %s", h5ad_path), stderr())
write(sprintf("wrote: %s", clusters_truth_path), stderr())
write(sprintf("wrote: %s", num_clusters_truth_path), stderr())
write(sprintf("wrote: %s", properties_path), stderr())