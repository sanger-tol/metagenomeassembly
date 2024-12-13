#!/usr/bin/env Rscript

library(optparse)
library(tidyverse)

parser <- OptionParser()
parser <- add_option(
    object = parser,
    opt_str = c("-s", "--stats"),
    type = "character",
    action = "store",
    default = NULL,
    help = "Comma-separated list of TSV files output by seqkit stats",
    metavar="filename"
)

parser <- add_option(
    object = parser,
    opt_str = c("-c", "--checkm2"),
    type = "character",
    action = "store",
    default = NULL,
    help = "Comma-separated list of TSV files output by checkm2 predict",
    metavar="filename"
)

parser <- add_option(
    object = parser,
    opt_str = c("-t", "--taxonomy"),
    type = "character",
    action = "store",
    default = NULL,
    help = "Comma-separated list of TSV files output by GTDB-Tk",
    metavar="filename"
)

parser <- add_option(
    object = parser,
    opt_str = c("-o", "--prefix"),
    type = "character",
    action = "store",
    default = "output",
    help = "Output file prefix",
    metavar="filename"
)

parser <- add_option(
    object = parser,
    opt_str = c("-x", "--completeness_score"),
    type = "numeric",
    action = "store",
    default = 5,
    help = "Output file prefix",
    metavar="filename"
)

parser <- add_option(
    object = parser,
    opt_str = c("-y", "--contam_score"),
    type = "numeric",
    action = "store",
    default = 1,
    help = "Output file prefix",
    metavar="filename"
)

input <- parse_args(parser)

read_stats <- function(file) {
    df <- read_tsv(file) |>
        mutate(
            file = str_extract(file, "(.*)\\.fa", group = 1),
            assembler = str_split(file, "[\\.|_]", simplify = TRUE)[,2],
            binner = str_split(file, "[\\.|_]", simplify = TRUE)[,3]
        ) |>
        select(bin = file, assembler, binner, num_seqs, sum_len, min_len, max_len, N50, L50 = N50_num, GC = `GC(%)`)

    return(df)
}

read_checkm <- function(file) {
    df <- read_tsv(file) |>
        select(bin = Name,
            completeness = Completeness,
            contamination = Contamination,
            checkm2_model = Completeness_Model_Used
        )

    return(df)
}

read_taxonomy <- function(file) {
    df <- read_tsv(file)
    if(ncol(df) > 3) {
        df <- select(df,
            bin = `Genome ID`,
            gtdb_classification = `GTDB classification`,
            ncbi_classification = `Majority vote NCBI classification`)
    } else {
        df <- select(df,
            bin = `Genome ID`,
            gtdb_classification = `GTDB classification`,
            ncbi_classification = `Majority vote NCBI classification`,
            taxid)
    }

    return(df)
}

data <- list()
if(rlang::has_name(input, "stats")) {
    stats_files <- unlist(str_split(input$stats, ","))
    stats_df <- map(stats_files, read_stats) |> list_rbind()
    data <- c(data, list(stats_df))
} else {
    stop("Error: no stats file provided!")
}

if(rlang::has_name(input, "checkm2")) {
    checkm_files <- unlist(str_split(input$checkm2, ","))
    checkm_df <- map(checkm_files, read_checkm) |> list_rbind()
    data <- c(data, list(checkm_df))
}

if(rlang::has_name(input, "taxonomy")) {
    tax_files <- unlist(str_split(input$taxonomy, ","))
    tax_df <- map(tax_files, read_taxonomy) |> list_rbind()
    data <- c(data, list(tax_df))
}

summary <- reduce(data, \(x, y) left_join(x, y, by = "bin"))

write_tsv(summary, glue::glue("{input$prefix}.bin_summary.tsv"))

writeLines(
    c("BIN_SUMMARY:",
        paste0("    R: ", paste0(R.Version()[c("major","minor")], collapse = ".")),
        paste0("    tidyverse: ", packageVersion("tidyverse"))
    ),
    "versions.yml"
)
