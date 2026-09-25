#!/usr/bin/env Rscript

# note: originally forked from here
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

hf_repo <- "btraven/splatter-cube-pbmc3k"
hf_revision <- "main"

simulation_files <- c(
  p31_s42_narrow_signal = "data/p31_s42.h5ad",
  p35_s42_broad_signal = "data/p35_s42.h5ad",
  p38_s42_strong_signal = "data/p38_s42.h5ad"
)

if (!(args$dataset_name %in% names(simulation_files))) {
  stop(sprintf("Unknown dataset: %s", args$dataset_name))
}

filename <- simulation_files[[args$dataset_name]]
url <- sprintf("https://huggingface.co/datasets/%s/resolve/%s/%s", hf_repo, hf_revision, filename)

write(sprintf("downloading: %s", url), stderr())
download.file(url, destfile = h5ad_path, mode = "wb")

yaml::write_yaml(
  list(
    dataset_name = args$dataset_name,
    source = "huggingface",
    source_repository = hf_repo,
    source_revision = hf_revision,
    batch_var = args$batch_var,
    sample_var = args$sample_var,
    labels_var = args$labels_var),
  properties_path
)

write(sprintf("wrote: %s", h5ad_path), stderr())
write(sprintf("wrote: %s", properties_path), stderr())