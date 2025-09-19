include { BIN_RRNAS                         } from '../../../modules/local/bin_rrnas/main'
include { CHECKM2_PREDICT                   } from '../../../modules/nf-core/checkm2/predict/main'
include { COVERM_GENOME                     } from '../../../modules/nf-core/coverm/genome/main'
include { GENOME_STATS as GENOME_STATS_BINS } from '../../../modules/local/genome_stats/main'
include { TRNASCAN_SE                       } from '../../../modules/local/trnascan_se/main'
include { GAWK as GAWK_TRNASCAN_SUMMARY     } from '../../../modules/nf-core/gawk/main'

workflow BIN_QC {
    take:
    ch_bin_sets
    ch_contig2bin
    ch_circular_list
    ch_mapped_bam
    ch_assembly_rrna_tbl
    ch_checkm2_db

    main:
    ch_versions = Channel.empty()

    ch_genome_stats_input = ch_bin_sets
        | map { meta, bins ->
            def meta_join = meta.subMap(["id", "assembler"])
            [ meta_join, meta, bins ]
        }
        | combine(ch_circular_list, by: 0)
        | map { _meta_join, meta, bins, circles -> [ meta, bins, circles ] }

    //
    // MODULE: Calculate bin statistics, including counts of circles
    //
    GENOME_STATS_BINS(ch_genome_stats_input)
    ch_versions = ch_versions.mix(GENOME_STATS_BINS.out.versions)

    //
    // MODULE: Calculate the coverage of bins using coverm genome
    //
    ch_bam_to_join = ch_mapped_bam
        | map { meta, bam -> [ meta.subMap(["id", "assembler"]), bam ] }

    ch_coverm_genome_input = ch_bin_sets
        | map { meta, bins ->
            def meta_join = meta.subMap(["id", "assembler"])
            [ meta_join, meta, bins ]
        }
        | combine(ch_bam_to_join, by: 0)
        | multiMap { meta_join, meta, bins, bam ->
            bam: [ meta, bam ]
            bins: [ meta, bins ]
        }

    COVERM_GENOME(
        ch_coverm_genome_input.bam,
        ch_coverm_genome_input.bins,
        true,  // bam input
        false, // interleaved
        "file" // genome file input
    )
    ch_versions = ch_versions.mix(COVERM_GENOME.out.versions)

    if(params.enable_checkm2) {
        // Collate all bins together so CheckM2 operates in a single process.
        ch_bins_for_checkm = ch_bin_sets
            | map { meta, bins ->
                [ meta.subMap("id"), bins]
            }
            | transpose
            | groupTuple(by: 0)

        //
        // MODULE: Estimate bin completeness/contamination using CheckM2
        //
        CHECKM2_PREDICT(ch_bins_for_checkm, ch_checkm2_db)
        ch_versions = ch_versions.mix(CHECKM2_PREDICT.out.versions)
        ch_checkm2_tsv = CHECKM2_PREDICT.out.checkm2_tsv
    } else {
        ch_checkm2_tsv = Channel.empty()
    }

    if(params.enable_trnascan_se) {
        ch_bins_for_trnascan = ch_bin_sets
            | transpose
            | map { meta, bin ->
                // Can't use getSimpleName() as some bin names are like ["a.1.fa.gz", "a.2.fa.gz"]
                def meta_new = meta + [binid: bin.getBaseName() - ~/\.[^\.]+$/]
                [ meta_new, bin ]
            }

        //
        // MODULE: Find tRNAs in bins
        //
        TRNASCAN_SE(ch_bins_for_trnascan, [], [], [])
        ch_versions = ch_versions.mix(TRNASCAN_SE.out.versions)

        ch_trna_tsvs = TRNASCAN_SE.out.tsv
            | map { meta, tsv -> [ meta - meta.subMap("binid"), tsv ] }
            | groupTuple(by: 0)

        //
        // MODULE: Summarise tRNA results for each bin
        //
        GAWK_TRNASCAN_SUMMARY(ch_trna_tsvs, file("${projectDir}/bin/trnascan_summary.awk"), false)
        ch_versions = ch_versions.mix(GAWK_TRNASCAN_SUMMARY.out.versions)

        ch_trnascan_summary = GAWK_TRNASCAN_SUMMARY.out.output
    } else {
        ch_trnascan_summary = Channel.empty()
    }

    if(params.enable_rrna_prediction) {
        ch_bin_rrna_input = ch_contig2bin
            | map { meta, c2b ->
                def meta_join = meta.subMap(["id", "assembler"])
                [ meta_join, meta, c2b ]
            }
            | combine(ch_assembly_rrna_tbl, by: 0)
            | map { _meta_join, meta, c2b, rrna -> [ meta, c2b, rrna ] }

        //
        // MODULE: Summarise identified rRNAs across bins
        //
        BIN_RRNAS(ch_bin_rrna_input)
        ch_versions = ch_versions.mix(BIN_RRNAS.out.versions)
        ch_rrna_summary = BIN_RRNAS.out.tsv
    } else {
        ch_rrna_summary = Channel.empty()
    }

    emit:
    stats            = GENOME_STATS_BINS.out.stats
    coverage         = COVERM_GENOME.out.coverage
    checkm2_tsv      = ch_checkm2_tsv
    trnascan_summary = ch_trnascan_summary
    rrna_summary     = ch_rrna_summary
    versions         = ch_versions
}
