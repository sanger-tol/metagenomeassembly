include { COVERM_CONTIG             } from '../../../modules/nf-core/coverm/contig'
include { PAIRTOOLS_PARSESORTFILTER } from '../../../modules/local/paritools/parsesortfilter'
include { SAMTOOLS_FAIDX            } from '../../../modules/nf-core/samtools/faidx'
include { SAMTOOLS_SORT             } from '../../../modules/nf-core/samtools/sort'

include { CRAM_MAP_ILLUMINA_HIC     } from '../../../subworkflows/sanger-tol/cram_map_illumina_hic'
include { FASTX_MAP_LONG_READS      } from '../../../subworkflows/sanger-tol/fastx_map_long_reads'

workflow READ_MAPPING {
    take:
    ch_assemblies
    ch_filter_list
    ch_long_reads
    ch_hic_cram
    val_hic_binning
    val_hic_aligner
    val_cram_chunk_size
    val_reads_per_fasta_chunk
    val_extract_circular_contigs

    main:
    //
    // Subworkflow: run chunked hi-c mapping
    //
    ch_hic_mapping_inputs = ch_assemblies
        .filter { val_hic_binning }
        .combine(ch_hic_cram)
        .multiMap { meta, asm, _meta_hic, cram ->
            assemblies: [meta, asm]
            cram: [meta, cram]
        }

    //
    // Logic: Index input assemblies to get chromsizes
    //
    SAMTOOLS_FAIDX(
        ch_assemblies.map { meta, asm -> [meta, asm, []] },
        true
    )

    CRAM_MAP_ILLUMINA_HIC(
        ch_hic_mapping_inputs.assemblies,
        ch_hic_mapping_inputs.cram,
        val_hic_aligner,
        val_cram_chunk_size,
    )

    //
    // Module: Parse BAM into pairs format
    //
    ch_pairtools_parse_input = CRAM_MAP_ILLUMINA_HIC.out.bam
        .combine(SAMTOOLS_FAIDX.out.sizes)
        .combine(ch_filter_list)

    PAIRTOOLS_PARSESORTFILTER(ch_pairtools_parse_input)

    //
    // Subworkflow: Chunked mapping of long reads to metagenome assembly
    //
    ch_pacbio_mapping_inputs = ch_assemblies
        .combine(ch_long_reads)
        .multiMap { meta, asm, _meta_pb, reads ->
            assemblies: [meta, asm]
            reads: [meta, reads]
        }

    FASTX_MAP_LONG_READS(
        ch_pacbio_mapping_inputs.assemblies,
        ch_pacbio_mapping_inputs.reads,
        val_reads_per_fasta_chunk,
        true,
    )

    //
    // Module: Calculate per-contig coverage using coverm
    //
    COVERM_CONTIG(
        FASTX_MAP_LONG_READS.out.bam,
        [[], []],
        true,
        false,
        false
    )

    emit:
    pacbio_bam = FASTX_MAP_LONG_READS.out.bam
    hic_bam    = SAMTOOLS_SORT.out.bam
    hic_pairs  = PAIRTOOLS_PARSESORTFILTER.out.pairs
    depths     = ch_output_depths
}
