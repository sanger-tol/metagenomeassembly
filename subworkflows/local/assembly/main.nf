include { FILTER_ASSEMBLY                         } from '../../../modules/local/filter_assembly'
include { GENOMAD_ENDTOEND                        } from '../../../modules/nf-core/genomad/endtoend'
include { GENOME_STATS as GENOME_STATS_ASSEMBLIES } from '../../../modules/local/genome_stats'
include { GUNZIP                                  } from '../../../modules/nf-core/gunzip/main'
include { METAMDBG_ASM                            } from '../../../modules/nf-core/metamdbg/asm'
include { MYLOASM                                 } from '../../../modules/nf-core/myloasm'
include { TIARA_TIARA                             } from '../../../modules/nf-core/tiara/tiara'

workflow ASSEMBLY {
    take:
    ch_hifi_reads
    ch_assemblies
    val_assembler
    val_minimum_contig_size
    val_maximum_contig_size
    val_extract_circular_contigs
    val_minimum_circular_contig_length
    val_enable_tiara
    val_tiara_exclude_classifications
    val_enable_genomad
    ch_genomad_db

    main:
    ch_assembly_input = ch_hifi_reads
        .combine(ch_assemblies.ifEmpty([[:], []]))
        .filter { _meta, _reads, _meta_asm, asm -> !asm }
        .map { meta, reads, _meta_asm, _asm -> [meta, reads] }

    ch_local_assemblies = channel.empty()
    if (val_assembler == "metamdbg") {
        //
        // Module: Assemble PacBio reads using metaMDBG
        //
        METAMDBG_ASM(ch_assembly_input, 'hifi')
        ch_local_assemblies = METAMDBG_ASM.out.contigs
    } else if (val_assembler == "myloasm") {
        //
        // Module: Assemble PacBio reads using myloasm
        //
        MYLOASM(ch_assembly_input)
        ch_local_assemblies = MYLOASM.out.contigs
    }
    ch_local_assemblies = ch_local_assemblies.map { meta, contigs ->
        def meta_new = meta + [assembler: val_assembler]
        [meta_new, contigs]
    }

    ch_assemblies_all = ch_assemblies.mix(ch_local_assemblies)

    //
    // Module: ungzip gzipped assemblies
    //
    ch_assemblies_split = ch_assemblies_all.branch { _meta, asm ->
        gzipped: asm.getExtension() == "gz"
        ungzipped: true
    }

    GUNZIP(ch_assemblies_split.gzipped)
    ch_assemblies_unzipped = ch_assemblies_split.ungzipped.mix(GUNZIP.out.gunzip)

    if (val_enable_tiara) {
        //
        // Module: Classify assembled contigs with tiara to domain level
        TIARA_TIARA(ch_assemblies_unzipped)

        ch_filter_assembly_input = ch_assemblies_unzipped
            .combine(TIARA_TIARA.out.classifications, by: 0)

    } else {
        ch_filter_assembly_input = ch_assemblies_unzipped
            .map { meta, asm -> [meta, asm, []] }
    }

    //
    // Module: Filter the assembled contigs to remove circles (if requested), as well
    // as too-large or too-small contigs. If tiara was run, it can also be used to
    // filter the assembly.
    //
    FILTER_ASSEMBLY(
        ch_filter_assembly_input,
        val_minimum_contig_size ?: [],
        val_maximum_contig_size ?: [],
        val_extract_circular_contigs,
        val_minimum_circular_contig_length ?: [],
        val_tiara_exclude_classifications.split(",") ?: []
    )

    //
    // Module: Calculate assembly statistics, including counts of circles
    //
    GENOME_STATS_ASSEMBLIES(ch_assemblies_unzipped.combine(FILTER_ASSEMBLY.out.circles_list, by: 0))

    if (val_enable_genomad) {
        //
        // Module: Classify circular contigs using genomad
        //
        GENOMAD_ENDTOEND(
            ch_assemblies_unzipped.filter { val_enable_genomad },
            ch_genomad_db,
        )
    }

    emit:
    full_assemblies  = ch_assemblies_unzipped
    circular_contigs = FILTER_ASSEMBLY.out.circles
    filtered_contigs = FILTER_ASSEMBLY.out.filtered
    circles_list     = FILTER_ASSEMBLY.out.circles_list
    filter_list      = FILTER_ASSEMBLY.out.filter_list
}
