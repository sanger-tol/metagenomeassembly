include { SAMTOOLS_FASTQ as HIC_TO_FASTQ } from '../../modules/nf-core/samtools/fastq/main'
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
    ch_versions   = Channel.empty()

    if(params.enable_metator) {
        HIC_TO_FASTQ(hic, false)
        ch_hic_fastq = HIC_TO_FASTQ.out.fastq.collect()

        BWAMEM2_INDEX(assemblies)

        BWAMEM2_MEM(
            ch_hic_fastq,
            BWAMEM2_INDEX.out.index,
            assemblies,
            false
        )

        SORT_HIC_BAM(BWAMEM2_MEM.out.bam, [[],[]])
        ch_hic_bam = SORT_HIC_BAM.out.bam
    } else {
        ch_hic_fastq = Channel.empty()
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
            HIC_TO_FASTQ.out.versions,
            BWAMEM2_INDEX.out.versions,
            BWAMEM2_MEM.out.versions,
            SORT_HIC_BAM.out.versions,
            MINIMAP2_ALIGN.out.versions,
            COVERM_CONTIG.out.versions
        )

    emit:
    hic_fastq  = ch_hic_fastq
    pacbio_bam = MINIMAP2_ALIGN.out.bam
    hic_bam    = ch_hic_bam
    depths     = COVERM_CONTIG.out.coverage
    versions   = ch_versions
}
