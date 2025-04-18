include { BIN_RRNAS                         } from '../../../modules/local/bin_rrnas/main'
include { CHECKM2_DATABASEDOWNLOAD          } from '../../../modules/nf-core/checkm2/databasedownload/main'
include { CHECKM2_PREDICT                   } from '../../../modules/nf-core/checkm2/predict/main'
include { GENOME_STATS as GENOME_STATS_BINS } from '../../../modules/local/genome_stats/main'
include { TRNASCAN_SE                       } from '../../../modules/local/trnascan_se/main'
include { GAWK as GAWK_TRNASCAN_SUMMARY     } from '../../../modules/nf-core/gawk/main'

workflow BIN_QC {
    take:
    bin_sets
    contig2bin
    circular_list
    assembly_rrna_tbl
    checkm2_db

    main:
    ch_versions = Channel.empty()

    ch_genome_stats_input = bin_sets
        | map {meta, bins ->
            def meta_join = meta.subMap(["id", "assembler"])
            [ meta_join, meta, bins ]
        }
        | combine(circular_list, by: 0)
        | map { _meta_join, meta, bins, circles -> [ meta, bins, circles ] }

    //
    // MODULE: Calculate bin statistics, including counts of circles
    //
    GENOME_STATS_BINS(ch_genome_stats_input)
    ch_versions = ch_versions.mix(GENOME_STATS_BINS.out.versions)

    if(params.enable_checkm2) {
        // Collate all bins together so CheckM2 operates in a single process.
        ch_bins_for_checkm = bin_sets
            | map { meta, bins ->
                [ meta.subMap("id"), bins]
            }
            | transpose
            | groupTuple(by: 0)

        if(!params.checkm2_db) {
            //
            // MODULE: Download the CheckM2 database
            //
            CHECKM2_DATABASEDOWNLOAD("5571251")
            ch_versions   = ch_versions.mix(CHECKM2_DATABASEDOWNLOAD.out.versions)
            ch_checkm2_db = CHECKM2_DATABASEDOWNLOAD.out.database
        } else {
            ch_checkm2_db = checkm2_db
        }

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
        ch_bins_for_trnascan = bin_sets
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
        ch_bin_rrna_input = contig2bin
            | map { meta, c2b ->
                def meta_join = meta.subMap(["id", "assembler"])
                [ meta_join, meta, c2b ]
            }
            | combine(assembly_rrna_tbl, by: 0)
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
    checkm2_tsv      = ch_checkm2_tsv
    trnascan_summary = ch_trnascan_summary
    rrna_summary     = ch_rrna_summary
    versions         = ch_versions
}
