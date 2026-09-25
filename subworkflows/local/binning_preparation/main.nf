include { FILTER_ASSEMBLY                         } from '../../../modules/local/filter_assembly'
include { COVERM_CONTIG as COVERM_CONTIG_FILTERED } from '../../../modules/nf-core/coverm/contig'
include { COVERM_CONTIG as COVERM_CONTIG_ALL      } from '../../../modules/nf-core/coverm/contig'

include { LONG_READ_MAPPING                       } from '../../../subworkflows/local/long_read_mapping'
include { HIC_MAPPING                             } from '../../../subworkflows/local/hic_mapping'

workflow BINNING_PREPARATION {
    take:
    ch_assemblies
    ch_concatenated_assemblies
    ch_long_reads
    ch_hic_reads
    ch_tiara_classifications
    val_binners
    val_mapping_options

    main:
    //
    // Module: Filter the assembled contigs to remove circles (if requested), as well
    // as too-large or too-small contigs. If tiara was run, it can also be used to
    // filter the assembly.
    //
    ch_tiara_classifications_collated = ch_tiara_classifications
        .toSortedList { a, b -> a[0].id <=> b[0].id }
        .filter { val_binners.multisplit }
        .map { list ->
            def ids = []
            def assemblers = []
            def out_classifications = []
            list.collect { meta, classification ->
                ids << meta.id
                assemblers << meta.assembler
                out_classifications << classification
            }

            return [[id: "collated", collated: true, ids: ids, assemblers: assemblers], out_classifications]
        }

    ch_filter_assembly_input = ch_assemblies
        .mix(ch_concatenated_assemblies)
        .join(ch_tiara_classifications.mix(ch_tiara_classifications_collated), by: 0, remainder: true)
        .multiMap { meta, fasta, tiara ->
            asm: [meta, fasta]
            tiara: tiara ? [meta, tiara, meta?.ids ?: []] : [meta, [], []]
        }

    FILTER_ASSEMBLY(
        ch_filter_assembly_input.asm,
        ch_filter_assembly_input.tiara
    )

    //
    // Subworkflow: run chunked hi-c mapping
    //
    HIC_MAPPING(
        ch_assemblies.filter { val_binners.metator },
        ch_hic_reads,
        FILTER_ASSEMBLY.out.include_list,
        val_mapping_options,
    )

    //
    // Subworkflow: Long read mapping
    //
    LONG_READ_MAPPING(
        ch_assemblies.mix(ch_concatenated_assemblies),
        ch_long_reads,
        FILTER_ASSEMBLY.out.exclude_list,
        val_mapping_options,
    )

    //
    // Module: Calculate per-contig coverage from the filtered BAM files
    //
    COVERM_CONTIG_FILTERED(
        LONG_READ_MAPPING.out.filtered_bam,
        [[], []],
        true,
        false,
        false,
    )

    //
    // Module: Calculate per-contig coverage from the unfiltered BAM files\
    // for annotation in the output binsfiles.
    //
    COVERM_CONTIG_ALL(
        LONG_READ_MAPPING.out.bam.filter { meta, _bam -> meta.id == meta.read_id },
        [[], []],
        true,
        false,
        false,
    )

    ch_binning_preparation_out = LONG_READ_MAPPING.out.bam
        .map { meta, bam -> [meta - meta.subMap("read_id"), bam] }
        .groupTuple(by: 0)
        .join(HIC_MAPPING.out.bam.map { meta, bam -> [meta - meta.subMap("hic_id"), bam] }, remainder: true)
        .join(HIC_MAPPING.out.pairs, remainder: true)
        .join(COVERM_CONTIG_FILTERED.out.coverage, remainder: true)
        .filter { meta, _bam, _hic_bam, _pairs, _depths -> !meta?.collated }
        .map { meta, bam, hic_bam, pairs, depths ->
            return meta + [bams: bam, hic_bam: hic_bam ?: [], pairs: pairs ?: [], depths: depths ?: []]
        }

    emit:
    filtered_assembly          = FILTER_ASSEMBLY.out.filtered
    circles_fasta              = FILTER_ASSEMBLY.out.circles_fasta.filter { meta, _circles -> !meta?.collated }
    circles_list               = FILTER_ASSEMBLY.out.circles_list.filter { meta, _circles -> !meta?.collated }
    full_bam                   = LONG_READ_MAPPING.out.bam
    filtered_bam               = LONG_READ_MAPPING.out.filtered_bam
    hic_bam                    = HIC_MAPPING.out.bam
    hic_pairs                  = HIC_MAPPING.out.pairs
    filtered_contig_depths     = COVERM_CONTIG_FILTERED.out.coverage
    sample_contig_depths       = COVERM_CONTIG_ALL.out.coverage
    binning_preparation_output = ch_binning_preparation_out
}
