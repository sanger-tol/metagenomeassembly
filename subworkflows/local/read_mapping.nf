include { SAMTOOLS_FASTQ as HIC_TO_FASTQ } from '../../modules/nf-core/samtools/fastq/main'
// include { BWAMEM2_INDEX                  } from '../../modules/nf-core/bwamem2/index/main'
// include { BWAMEM2_MEM                    } from '../../modules/nf-core/bwamem2/mem/main'
include { MINIMAP2_ALIGN                 } from '../../modules/nf-core/minimap2/align/main'

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

        // BWAMEM2_INDEX(assemblies)
        // BWAMEM2_MEM(
        //     ch_hic_fastq, 
        //     BWAMEM2_INDEX.out.index, 
        //     assemblies, 
        //     true
        // )
    } else {
        ch_hic_fastq = Channel.empty()
    }

    MINIMAP2_ALIGN(
        pacbio,
        assemblies,
        true,
        "csi",
        false,
        false
    )

    ch_hifi_bam = MINIMAP2_ALIGN.out.bam
        | combine(MINIMAP2_ALIGN.out.index, by: 0)

    emit:
    hic_fastq  = ch_hic_fastq
    pacbio_bam = ch_hifi_bam
    versions   = ch_versions
}