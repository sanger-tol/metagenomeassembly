include { SAMTOOLS_FASTQ as HIC_TO_FASTQ } from '../../modules/nf-core/samtools/fastq/main'
include { SAMTOOLS_MERGE as MERGE_HIC_CRAM } from '../../modules/nf-core/samtools/merge/main'

workflow PREPARE_DATA {
    take:
    hic_cram

    main:
    ch_versions = Channel.empty()

    ch_hic_cram_split = hic_cram
        | branch { meta, cram ->
            merge: cram.size() > 1
            asis: true
        }

    MERGE_HIC_CRAM(
        ch_hic_cram_split.merge,
        [],
        []
    )

    ch_hic_cram = ch_hic_cram_split.asis
        | mix(MERGE_HIC_CRAM.out.cram)

    HIC_TO_FASTQ(ch_hic_cram, false)
    ch_hic_fastq = HIC_TO_FASTQ.out.fastq

    emit:
    hic_reads = ch_hic_fastq
    versions  = ch_versions
}
