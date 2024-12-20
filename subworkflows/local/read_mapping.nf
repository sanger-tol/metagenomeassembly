include { SAMTOOLS_SORT as SAMTOOLS_SORT_HIC_BAM  } from '../../modules/nf-core/samtools/sort/main'
include { BWAMEM2_INDEX                           } from '../../modules/nf-core/bwamem2/index/main'
include { BWAMEM2_MEM                             } from '../../modules/nf-core/bwamem2/mem/main'
include { MINIMAP2_ALIGN                          } from '../../modules/nf-core/minimap2/align/main'
include { COVERM_CONTIG                           } from '../../modules/nf-core/coverm/contig/main'

workflow READ_MAPPING {
    take:
    assemblies
    pacbio
    hic

    main:
    ch_versions = Channel.empty()

    if(params.enable_metator || params.enable_bin3c) {
        BWAMEM2_INDEX(assemblies)
        ch_versions = ch_versions.mix(BWAMEM2_INDEX.out.versions)

        BWAMEM2_MEM(
            hic,
            BWAMEM2_INDEX.out.index,
            assemblies,
            false // sort independently
        )
        ch_versions = ch_versions.mix(BWAMEM2_MEM.out.versions)

        SAMTOOLS_SORT_HIC_BAM(BWAMEM2_MEM.out.bam, [[],[]])
        ch_versions = ch_versions.mix(SAMTOOLS_SORT_HIC_BAM.out.versions)

        ch_hic_bam = SAMTOOLS_SORT_HIC_BAM.out.bam
    } else {
        ch_hic_bam   = Channel.empty()
    }

    MINIMAP2_ALIGN(
        pacbio,
        assemblies,
        true,  // bam_format
        "csi", // bam_index_extension
        false, // cigar_paf_format
        false  // cigar_bam
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)

    COVERM_CONTIG(
        MINIMAP2_ALIGN.out.bam,
        [[],[]], // reference
        true,    // bam_input
        false    // interleaved
    )

    ch_versions = ch_versions.mix(COVERM_CONTIG.out.versions)

    emit:
    pacbio_bam = MINIMAP2_ALIGN.out.bam
    hic_bam    = ch_hic_bam
    depths     = COVERM_CONTIG.out.coverage
    versions   = ch_versions
}
