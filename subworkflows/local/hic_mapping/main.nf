include { PAIRTOOLS_PARSESELECTSORT } from '../../../modules/local/pairtools/parseselectsort'
include { SAMTOOLS_FAIDX            } from '../../../modules/nf-core/samtools/faidx'

include { CRAM_MAP_ILLUMINA_HIC     } from '../../../subworkflows/sanger-tol/cram_map_illumina_hic'

workflow HIC_MAPPING {
    take:
    ch_assemblies
    ch_hic_reads
    ch_filter_list
    val_mapping_options

    main:
    //
    // Subworkflow: run chunked hi-c mapping
    //
    ch_hic_mapping_inputs = ch_assemblies
        .combine(ch_hic_reads)
        .filter { meta, _asm, meta_cram, _reads -> meta.id == meta_cram.id }
        .multiMap { meta, asm, meta_cram, reads ->
            def meta_new = meta + [hic_id: meta_cram.id]
            assemblies: [meta_new, asm]
            cram: [meta_new, reads]
        }

    //
    // Logic: Index input assemblies to get chromsizes
    //
    SAMTOOLS_FAIDX(
        ch_assemblies.map { meta, asm -> [meta, asm, []] },
        true,
    )

    CRAM_MAP_ILLUMINA_HIC(
        ch_hic_mapping_inputs.assemblies,
        ch_hic_mapping_inputs.cram,
        val_mapping_options.hic_aligner,
        val_mapping_options.hic_mapping_cram_slices_per_chunk,
    )

    //
    // Module: Parse BAM into pairs format
    //
    ch_pairtools_parse_input = CRAM_MAP_ILLUMINA_HIC.out.bam
        .combine(SAMTOOLS_FAIDX.out.sizes.join(ch_filter_list, by: 0, remainder: true))
        .filter { meta_bam, _bam, meta_asm, _sizes, _filt ->  meta_bam.id == meta_asm.id }
        .map { _meta_bam, bam, meta_asm, sizes, filt -> [meta_asm, bam, sizes, filt && filt?.size() > 0 ? filt : []] }

    PAIRTOOLS_PARSESELECTSORT(ch_pairtools_parse_input)

    emit:
    bam   = CRAM_MAP_ILLUMINA_HIC.out.bam
    pairs = PAIRTOOLS_PARSESELECTSORT.out.pairs
}
