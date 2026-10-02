include { CHECKM2_PREDICT                           } from '../../../modules/nf-core/checkm2/predict/main'
include { COVERM_GENOME                             } from '../../../modules/nf-core/coverm/genome/main'
include { CSVTK_CONCAT as CONCATENATE_COVERM_GENOME } from '../../../modules/nf-core/csvtk/concat/main'

workflow BIN_QC {
    take:
    ch_bin_sets
    ch_mapped_bam
    ch_checkm2_db

    main:
    //
    // Module: Calculate the coverage of bins using coverm genome.
    //
    ch_coverm_genome_input = ch_bin_sets
        .combine(ch_mapped_bam)
        .filter { meta_bins, _bins, meta_bam, _bam -> meta_bins.id == meta_bam.id }
        .map { meta_bins, bins, _meta_bam, bam ->
            [meta_bins + [bins: bins], bam]
        }
        .groupTuple(by: 0)
        .map { meta, bams -> [meta - meta.subMap("bins"), meta.bins, bams.sort { it -> it.getName() }] }
        .multiMap { meta, bins, bam ->
            bam: [meta, bam]
            bins: [meta, bins]
        }

    COVERM_GENOME(
        ch_coverm_genome_input.bam,
        ch_coverm_genome_input.bins,
        true,
        false,
        "file",
        false
    )

    //
    // Module: concatenate CoverM genome coverages
    //
    CONCATENATE_COVERM_GENOME(
        COVERM_GENOME.out.coverage.map { meta, coverage -> [meta - meta.subMap("binner"), coverage] }.groupTuple(by: 0),
        "tsv",
        "tsv",
    )

    //
    // Logic: Collate all bins together so CheckM2 operates in a single process.
    //
    ch_bins_for_checkm = ch_bin_sets
        .map { meta, bins ->
            [meta.subMap("id", "platform", "assembler"), bins]
        }
        .transpose()
        .groupTuple(by: 0)

    //
    // Module: Estimate bin completeness/contamination using CheckM2
    //
    CHECKM2_PREDICT(ch_bins_for_checkm, ch_checkm2_db)

    ch_binqc_publish = CHECKM2_PREDICT.out.checkm2_tsv
        .join(CONCATENATE_COVERM_GENOME.out.csv, by: 0)
        .map { meta, checkm2_tsv, coverage ->
            meta + [checkm2_tsv: checkm2_tsv, coverage: coverage]
        }

    emit:
    coverage         = COVERM_GENOME.out.coverage
    checkm2_tsv      = CHECKM2_PREDICT.out.checkm2_tsv
    binqc_publish    = ch_binqc_publish
}
