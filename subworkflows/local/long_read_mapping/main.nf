include { FILTER_BAM           } from '../../../modules/local/filter_bam'

include { FASTX_MAP_LONG_READS } from '../../../subworkflows/sanger-tol/fastx_map_long_reads'

workflow LONG_READ_MAPPING {
    take:
    ch_assemblies
    ch_long_reads
    ch_filter_list
    val_mapping_options

    main:
    //
    // Subworkflow: Chunked mapping of long reads to metagenome assembly
    //
    ch_pacbio_mapping_inputs = ch_assemblies
        .combine(ch_long_reads)
        .multiMap { meta, asm, meta_pb, reads ->
            def meta_new = meta + [read_id: meta_pb.id]
            assemblies: [meta_new, asm]
            reads: [meta_new, reads]
        }

    FASTX_MAP_LONG_READS(
        ch_pacbio_mapping_inputs.assemblies,
        ch_pacbio_mapping_inputs.reads,
        val_mapping_options.long_read_mapping_reads_per_chunk,
        true,
        channel.empty(),
    )

    //
    // Logic: if we have removed circular contigs from binning, strip them
    // out of the coverage TSV
    //
    ch_filter_bam_input = FASTX_MAP_LONG_READS.out.bam
        .combine(ch_filter_list)
        .filter { meta_bam, _bam, meta_asm, _filt -> meta_bam.id == meta_asm.id }
        .branch { meta_bam, bam, meta_asm, filt ->
            filter: filt && filt?.size() > 0
                return [meta_bam, bam, filt]
            skip_filter: true
                return [meta_asm, bam]
        }

    //
    // Module: filter unwanted references from bam
    //
    FILTER_BAM(ch_filter_bam_input.filter)

    ch_output_filtered_bam = FILTER_BAM.out.bam
        .mix(ch_filter_bam_input.skip_filter)
        .map { meta, bam -> [meta - meta.subMap("read_id"), bam] }
        .groupTuple(by: 0)
        .map { meta, bams -> [meta, bams.sort { it -> it.getName() }] }

    emit:
    bam          = FASTX_MAP_LONG_READS.out.bam
    filtered_bam = ch_output_filtered_bam
}
