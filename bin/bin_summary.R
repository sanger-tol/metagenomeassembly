#!/usr/bin/env Rscript

## Collates the various bin-level summary TSV files exported at
## various points in the metagenomeassembly pipeline run
##
## Author: Jim Downie, 2024

library(optparse)
library(tidyverse)

parser <- OptionParser()
parser <- add_option(
    object = parser,
    opt_str = c("-s", "--stats"),
    type = "character",
    action = "store",
    default = NULL,
    help = "Comma-separated list of TSV files output by seqkit stats.",
    metavar="filename"
)

parser <- add_option(
    object = parser,
    opt_str = c("-c", "--checkm2"),
    type = "character",
    action = "store",
    default = NULL,
    help = "Comma-separated list of TSV files output by checkm2 predict.",
    metavar="filename"
)

parser <- add_option(
    object = parser,
    opt_str = c("-t", "--taxonomy"),
    type = "character",
    action = "store",
    default = NULL,
    help = "Comma-separated list of TSV files output by GTDB-Tk.",
    metavar="filename"
)

parser <- add_option(
    object = parser,
    opt_str = c("-l", "--trnas"),
    type = "character",
    action = "store",
    default = NULL,
    help = "Comma-separated list of TSV files output by GAWK_TRNASCAN_SUMMARY.",
    metavar="filename"
)

parser <- add_option(
    object = parser,
    opt_str = c("-g", "--rrnas"),
    type = "character",
    action = "store",
    default = NULL,
    help = "Comma-separated list of TSV files output by BIN_RRNAS",
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
    default = 1,
    help = "Output file prefix",
    metavar="filename"
)

parser <- add_option(
    object = parser,
    opt_str = c("-y", "--contamination_score"),
    type = "numeric",
    action = "store",
    default = 0.5,
    help = "Output file prefix",
    metavar="filename"
)

input <- parse_args(parser)

## Functions to read in summary information about each bin
## Each should be named in the format "read_X", and X
## should be the full name of one of the arguments defined in
## the optparse section
read_stats <- function(file) {
    df <- read_tsv(file) |>
        mutate(
            file = str_extract(file, "(.*)\\.fa", group = 1),
            assembler = str_split(file, "[\\.|_]", simplify = TRUE)[,2],
            binner = str_split(file, "[\\.|_]", simplify = TRUE)[,3]
        ) |>
        select(bin = file, assembler, binner, num_seqs, n_circ, sum_len, min_len, max_len, N50, L50 = N50_num, GC = `GC(%)`)

    return(df)
}

read_checkm2 <- function(file) {
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
    if(ncol(df) == 3) {
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
    # gtdb doesn't drop the extension
    df <- df |>
        mutate(bin = str_extract(bin, "(.*)\\.[^\\.]+$", group = 1))

    return(df)
}

read_trnas <- read_tsv
read_rrnas <- read_tsv

## Takes the arg input list and a defined input type
## Check if the arg has been passed, then split the string into
## filenames, read them, and call the relevant
## read_X function
split_and_read <- function(input, input_type) {
    if(!is.null(pluck(input, input_type))){
        function_name <- paste0("read_", input_type)
        files <- unlist(str_split(pluck(input, input_type), ","))
        df <- map(files, \(x) do.call(function_name, list(file = x))) |>
            list_rbind()
        return(df)
    }
}

## Score bins
## High quality bins: contamination < 5%; either >90% complete, or >50% but all contigs circular.
##                    >=18 unique tRNA genes; all ribosomal rRNA genes
## Medium quality bins: completeness >= 50%, contamination < 10%
## Low quality bins: all other bins
score_bins <- function(summary_df, comp_score, cont_score) {
    summary_df <- summary_df |>
        mutate(
            quality = case_when(
                contamination <= 5 & unique_trnas >= 18 & n_ssu > 0 & n_lsu > 0 & n_5s > 0 &
                    (
                        (completeness >= 50 & num_seqs == n_circ) | (completeness >= 90)
                    ) ~ "high",
                completeness >= 50 & contamination <= 10 ~ "medium",
                .default = "low"
            ),
            score = (completeness * comp_score) - (contamination * cont_score)
        )
    return(summary_df)
}

## Map across all input types, read them, discard any that weren't provided
## and then bind them all together by bin
input_types <- c("stats", "checkm2", "taxonomy", "trnas", "rrnas")
bin_summary <- map(input_types, \(x) split_and_read(input, x)) |>
    discard(is.null) |>
    reduce(\(x, y) left_join(x, y, by = "bin"))

## If we have all required input types, score bins
if(all(c("stats", "checkm2", "trnas", "rrnas") %in% names(input))) {
    bin_summary <- score_bins(
        bin_summary,
        input$completeness_score,
        input$contamination_score
    )
    groups <- c("assembler", "binner", "quality")
} else {
    groups <- c("assembler", "binner")
}

## Summarise bin counts at the group level
group_summary <- bin_summary |>
    group_by(across(all_of(groups))) |>
    summarise(n = n())

if(all(input_types %in% names(input))) {
    group_summary <- group_summary |>
        mutate(quality = factor(quality, levels = c("high", "medium", "low"))) |>
        pivot_wider(names_from = "quality", values_from = "n", names_sort = TRUE)
}

write_tsv(bin_summary, glue::glue("{input$prefix}.bin_summary.tsv"))
write_tsv(group_summary, glue::glue("{input$prefix}.group_summary.tsv"))
