include { BINETTE                                 } from '../../../modules/nf-core/binette/main'
include { CONTIG2BINTOFASTA                       } from '../../../modules/local/contig2bintofasta/main'
include { DASTOOL_DASTOOL                         } from '../../../modules/nf-core/dastool/dastool/main'
include { GAWK as GAWK_RENAME_BINS                } from '../../../modules/nf-core/gawk/main'
include { PYRODIGAL                               } from '../../../modules/nf-core/pyrodigal/main'

workflow BIN_REFINEMENT {
    take:
    ch_assemblies
    ch_contig2bin
    ch_checkm2_db
    val_enable_dastool
    val_enable_binette

    main:
    ch_refined_contig2bin = channel.empty()
    ch_refined_bins = channel.empty()

    //
    // Module: Identify ORFs in assembly using Pyrodigal
    //
    PYRODIGAL(ch_assemblies, 'gff')

    //
    // Logic: Enable bin refinement with DAS_Tool. Note that DAS_Tool does not give control over the names of the bins
    // they output - this causes issues with file collisions and expected name conventions
    // downstream. Rename the bins inside the contig2bin script and write to fasta separately
    //
    if (val_enable_dastool) {
        ch_contig2bins_to_merge = ch_contig2bin
            .map { meta, tsv -> [meta - meta.subMap(['binner']), tsv] }
            .groupTuple(by: 0)

        ch_dastool_input = ch_assemblies
            .combine(ch_contig2bins_to_merge, by: 0)
            .combine(PYRODIGAL.out.faa, by: 0)

        //
        // Module: Refine bins using DAS_Tool + ORFs
        //
        DASTOOL_DASTOOL(ch_dastool_input, [])
        ch_dastool_contig2bin_raw = DASTOOL_DASTOOL.out.contig2bin.map { meta, c2b -> [meta + [binner: "dastool"], c2b] }

        //
        // Module: Rename bins inside contig2bin files
        //
        GAWK_RENAME_BINS(
            ch_dastool_contig2bin_raw,
            file("${projectDir}/bin/rename_bins.awk"),
            false,
        )
        ch_refined_contig2bin = ch_refined_contig2bin.mix(GAWK_RENAME_BINS.out.output)

        ch_c2b_to_combine = GAWK_RENAME_BINS.out.output
            .map { meta, c2b ->
                [meta - meta.subMap("binner"), meta, c2b]
            }

        ch_contig2bintofasta_input = ch_assemblies
            .combine(ch_c2b_to_combine, by: 0)
            .map { _meta, contigs, meta_c2b, c2b -> [meta_c2b, contigs, c2b] }

        //
        // Module: Create binned fasta files using contig2bin files
        //
        CONTIG2BINTOFASTA(ch_contig2bintofasta_input)
        ch_refined_bins = ch_refined_bins.mix(CONTIG2BINTOFASTA.out.bins)
    }

    if (val_enable_binette && params.checkm2_db) {
        ch_contig2bins_to_merge = ch_contig2bin
            .map { meta, tsv -> [meta - meta.subMap(['binner']), tsv] }
            .groupTuple(by: 0)

        ch_binette_input = ch_assemblies
            .combine(ch_contig2bins_to_merge, by: 0)
            .combine(PYRODIGAL.out.faa, by: 0)
            .map { meta, asm, c2b, prot -> [meta, c2b, [], asm, prot] }

        BINETTE(
            ch_binette_input,
            ch_checkm2_db
        )

        ch_refined_contig2bin = ch_refined_contig2bin.mix(
            BINETTE.out.contig2bin.map { meta, c2b -> [meta + [binner: "binette"], c2b] }
        )

        ch_refined_bins = ch_refined_bins.mix(
            BINETTE.out.final_bins.map { meta, bins -> [meta + [binner: "binette"], bins] }
        )
    }

    emit:
    refined_bins = ch_refined_bins
    contig2bin   = ch_refined_contig2bin
}
