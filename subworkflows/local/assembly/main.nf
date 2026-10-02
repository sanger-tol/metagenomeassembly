include { GUNZIP                 } from '../../../modules/nf-core/gunzip/main'
include { METAMDBG_ASM           } from '../../../modules/nf-core/metamdbg/asm'
include { MYLOASM                } from '../../../modules/nf-core/myloasm'
include { CONCATENATE_FASTA      } from '../../../modules/local/concatenate_fasta/main'
include { METABINTOOLS_IMPORTASM } from '../../../modules/local/metabintools/importasm'

workflow ASSEMBLY {
    take:
    ch_long_reads_assemblies
    val_assembler
    val_binners

    main:

    //
    // Logic: Filter the input datasets to remove those where the assemblies have been provided.
    // Initialise the output channels with these assemblies.
    //
    ch_assemblies = ch_long_reads_assemblies
        .filter { _meta, _reads, assembly -> assembly }
        .map { meta, _reads, assembly ->
            log.info("Skipping assembly for ${meta.id}: assembly provided")
            [meta, assembly]
        }

    ch_assembly_out = ch_long_reads_assemblies
        .filter { _meta, _reads, assembly -> assembly }
        .map { meta, _reads, assembly ->
            [meta, assembly, []]
        }

    ch_assembly_input = ch_long_reads_assemblies
        .filter { _meta, _reads, assembly -> !assembly }
        .map { meta, reads, _assembly -> [meta, reads] }

    if (val_assembler == "metamdbg") {
        //
        // Module: Assemble PacBio reads using metaMDBG
        //
        ch_metamdbg_input = ch_assembly_input.multiMap { meta, reads ->
            reads: [meta + [assembler: "metamdbg"], reads]
            input_type: meta.platform == "pacbio_hifi" ? "hifi" : "ont"
        }

        METAMDBG_ASM(
            ch_metamdbg_input.reads,
            ch_metamdbg_input.input_type,
        )

        ch_assemblies = ch_assemblies.mix(METAMDBG_ASM.out.contigs)

        ch_assembly_out = ch_assembly_out
            .mix(
                METAMDBG_ASM.out.contigs
                .join(METAMDBG_ASM.out.log)
                .map { meta, asm, metamdbg_log -> [meta, asm, [metamdbg_log]] }
            )

    }
    else if (val_assembler == "myloasm") {
        //
        // Module: Assemble PacBio reads using myloasm
        //
        MYLOASM(ch_assembly_input.map { meta, reads -> [meta + [assembler: "myloasm"], reads] })

        ch_assemblies = ch_assemblies.mix(MYLOASM.out.contigs)

        ch_assembly_out = ch_assembly_out.mix(
            MYLOASM.out.contigs.join(MYLOASM.out.results, by: 0)
            .map { meta, asm, results ->
                [meta, asm, results.findAll { f -> !(f.getName() =~ "assembly_primary.fa.gz") }]
            }
        )
    }

    //
    // Module: ungzip gzipped assemblies
    //
    ch_assemblies_split = ch_assemblies
        .branch { _meta, asm ->
            gzipped: asm.getExtension() == "gz"
            ungzipped: true
        }

    GUNZIP(ch_assemblies_split.gzipped)
    ch_assemblies_unzipped = ch_assemblies_split.ungzipped.mix(GUNZIP.out.gunzip)

    //
    // Module: Concatenate FASTAs for multisample split binning if requested
    //
    ch_assemblies_to_concatenate = ch_assemblies_unzipped
        .toSortedList { a, b -> a[0].id <=> b[0].id }
        .filter { val_binners.multisplit }
        .map { list ->
            def ids = []
            def assemblers = []
            def out_assemblies = []
            def out_platforms = []
            list.collect { meta, fasta ->
                ids << meta.id
                assemblers << meta.assembler
                out_platforms << meta.platform
                out_assemblies << fasta
            }

            return [[id: "collated", collated: true, ids: ids, assemblers: assemblers, platforms: out_platforms], out_assemblies]
        }

    //
    // Module: Concatenate assemblies to a single file for binsplitting binners
    //
    CONCATENATE_FASTA(ch_assemblies_to_concatenate.map { meta, fasta -> [meta, fasta, meta.ids] })

    //
    // Module: Import assemblies to binsfiles
    //
    METABINTOOLS_IMPORTASM(ch_assemblies_unzipped.filter { meta, _fasta -> !meta?.collated })

    emit:
    assembly_output = ch_assembly_out
    assemblies = ch_assemblies_unzipped
    concatenated_assembly = CONCATENATE_FASTA.out.concat_fasta
    assembly_binsfile = METABINTOOLS_IMPORTASM.out.binsfile
}
