include { SAMTOOLS_SORT as SORT_HIC_BAM  } from '../../modules/nf-core/samtools/sort/main'
include { BWAMEM2_INDEX                  } from '../../modules/nf-core/bwamem2/index/main'
include { BWAMEM2_MEM                    } from '../../modules/nf-core/bwamem2/mem/main'
include { MINIMAP2_ALIGN                 } from '../../modules/nf-core/minimap2/align/main'
include { COVERM_CONTIG                  } from '../../modules/nf-core/coverm/contig/main'

workflow READ_MAPPING {
    take:
    assemblies
    pacbio
    hic

    main:
    ch_versions = Channel.empty()

    if(params.enable_metator) {
        BWAMEM2_INDEX(assemblies)

        BWAMEM2_MEM(
            hic,
            BWAMEM2_INDEX.out.index,
            assemblies,
            false
        )

        SORT_HIC_BAM(BWAMEM2_MEM.out.bam, [[],[]])
        ch_hic_bam = SORT_HIC_BAM.out.bam
    } else {
        ch_hic_bam   = Channel.empty()
    }

    MINIMAP2_ALIGN(
        pacbio,
        assemblies,
        true,
        "csi",
        false,
        false
    )

    COVERM_CONTIG(
        MINIMAP2_ALIGN.out.bam,
        [[],[]],
        true,
        false
    )

    ch_versions = ch_versions
        | mix(
            BWAMEM2_INDEX.out.versions,
            BWAMEM2_MEM.out.versions,
            SORT_HIC_BAM.out.versions,
            MINIMAP2_ALIGN.out.versions,
            COVERM_CONTIG.out.versions
        )

    emit:
    pacbio_bam = MINIMAP2_ALIGN.out.bam
    hic_bam    = ch_hic_bam
    depths     = COVERM_CONTIG.out.coverage
    versions   = ch_versions
}
