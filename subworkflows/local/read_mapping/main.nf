include { COVERM_CONTIG                                } from '../../../modules/nf-core/coverm/contig/main'
include { SAMTOOLS_SORT                                } from '../../../modules/nf-core/samtools/sort/main'

include { CRAM_MAP_ILLUMINA_HIC                        } from '../../../subworkflows/sanger-tol/cram_map_illumina_hic/main'
include { FASTX_MAP_LONG_READS                         } from '../../../subworkflows/sanger-tol/fastx_map_long_reads/main'

workflow READ_MAPPING {
    take:
    ch_assemblies
    ch_pacbio
    ch_hic_cram
    val_hic_binning
    val_hic_aligner
    val_cram_chunk_size
    val_reads_per_fasta_chunk

    main:
    ch_versions = channel.empty()

    //
    // Subworkflow: run chunked hi-c mapping
    //
    ch_hic_mapping_inputs = ch_assemblies
        | filter { val_hic_binning }
        | combine(ch_hic_cram)
        | multiMap { meta, asm, _meta_hic, cram ->
            assemblies: [ meta, asm ]
            cram: [ meta, cram ]
        }

    CRAM_MAP_ILLUMINA_HIC(
        ch_hic_mapping_inputs.assemblies,
        ch_hic_mapping_inputs.cram,
        val_hic_aligner,
        val_cram_chunk_size
    )
    ch_versions = ch_versions.mix(CRAM_MAP_ILLUMINA_HIC.out.versions)

    //
    // Module: sort output BAM file by name
    //
    SAMTOOLS_SORT(
        CRAM_MAP_ILLUMINA_HIC.out.bam,
        [[],[]],
        "csi"
    )
    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions)

    //
    // Subworkflow: Chunked mapping of long reads to metagenome assembly
    //
    ch_pacbio_mapping_inputs = ch_assemblies
        | combine(ch_pacbio)
        | multiMap { meta, asm, _meta_pb, reads ->
            assemblies: [ meta, asm ]
            reads: [ meta, reads ]
        }

    FASTX_MAP_LONG_READS(
        ch_pacbio_mapping_inputs.assemblies,
        ch_pacbio_mapping_inputs.reads,
        val_reads_per_fasta_chunk,
        true
    )

    //
    // Module: Calculate per-contig coverage using coverm
    //
    COVERM_CONTIG(
        FASTX_MAP_LONG_READS.out.bam,
        [[],[]], // reference
        true,    // bam_input
        false    // interleaved
    )
    ch_versions = ch_versions.mix(COVERM_CONTIG.out.versions)

    emit:
    pacbio_bam = FASTX_MAP_LONG_READS.out.bam
    hic_bam    = SAMTOOLS_SORT.out.bam
    depths     = COVERM_CONTIG.out.coverage
    versions   = ch_versions
}
