include { BINETTE                                 } from '../../../modules/nf-core/binette/main'
include { DASTOOL_DASTOOL                         } from '../../../modules/nf-core/dastool/dastool/main'
include { PYRODIGAL                               } from '../../../modules/nf-core/pyrodigal/main'
include { METABINTOOLS_IMPORTBINSET               } from '../../../modules/local/metabintools/importbinset'
include { METABINTOOLS_EXPORTCONTIG2BIN           } from '../../../modules/local/metabintools/exportcontig2bin'
include { METABINTOOLS_EXPORTFASTA                } from '../../../modules/local/metabintools/exportfasta'

workflow BIN_REFINEMENT {
    take:
    ch_assemblies
    ch_assemblies_binfiles
    ch_bins_binfiles
    ch_checkm2_db
    val_enable_dastool
    val_enable_binette

    main:
    ch_refined_bins = channel.empty()
    ch_bin_refinement_output = channel.empty()

    //
    // Module: Write contig2bin files with the renamed bins.
    //
    METABINTOOLS_EXPORTCONTIG2BIN(ch_bins_binfiles)

    //
    // Module: Identify ORFs in assembly using Pyrodigal
    //
    PYRODIGAL(ch_assemblies.filter { meta, _asm -> !meta?.collated }, 'gff')

    //
    // Logic: Enable bin refinement with DAS_Tool. Note that DAS_Tool does not give control over the names of the bins
    // it outputs - this causes issues with file collisions and expected name conventions
    // downstream. Rename the bins inside the contig2bin script and write to fasta separately
    //
    if (val_enable_dastool) {
        ch_contig2bins_to_merge = METABINTOOLS_EXPORTCONTIG2BIN.out.contig2bin
            .map { meta, tsv -> [meta - meta.subMap(['binner']), tsv] }
            .groupTuple(by: 0)

        ch_dastool_input = ch_assemblies
            .combine(ch_contig2bins_to_merge, by: 0)
            .combine(PYRODIGAL.out.faa, by: 0)

        //
        // Module: Refine bins using DAS_Tool + ORFs
        //
        DASTOOL_DASTOOL(ch_dastool_input, [])

        ch_refined_bins = ch_refined_bins.mix(
            DASTOOL_DASTOOL.out.bins.map { meta, bins -> [meta + [binner: "dastool"], bins] }
        )

        ch_dastool_output = DASTOOL_DASTOOL.out.log
            .join(DASTOOL_DASTOOL.out.eval, remainder: true)
            .join(DASTOOL_DASTOOL.out.pdfs, remainder: true)
            .join(DASTOOL_DASTOOL.out.fasta_archaea_scg, remainder: true)
            .join(DASTOOL_DASTOOL.out.fasta_bacteria_scg, remainder: true)
            .map { meta, log, eval, pdfs, fasta_archaea_scg, fasta_bacteria_scg ->
                [meta + [binner: "dastool"], [
                    log,
                    eval ?: [],
                    pdfs ?: [],
                    fasta_archaea_scg ?: [],
                    fasta_bacteria_scg ?: [],
                ].findAll().flatten()]
            }

        ch_bin_refinement_output = ch_bin_refinement_output.mix(ch_dastool_output)
    }

    if (val_enable_binette) {
        ch_contig2bins_to_merge = METABINTOOLS_EXPORTCONTIG2BIN.out.contig2bin
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

        ch_refined_bins = ch_refined_bins.mix(
            BINETTE.out.final_bins.map { meta, bins -> [meta + [binner: "binette"], bins] }
        )

        ch_binette_output = BINETTE.out.final_bins_quality_report
            .join(BINETTE.out.input_bins_quality_reports, by: 0, remainder: true)
            .map { meta, final_qr, input_qr ->
                [meta + [binner: "binette"], [final_qr, input_qr].findAll().flatten()]
            }

        ch_bin_refinement_output = ch_bin_refinement_output.mix(ch_binette_output)
    }

    //
    // Module: Import each set of bins to a binsfile with the assembly
    // Each bin is renamed to a consistent naming schema.
    //
    ch_metatools_import_input = ch_assemblies_binfiles
        .combine(ch_refined_bins)
        .filter { meta_asm, _binsfile, meta_bins, _bins -> meta_asm.id == meta_bins.id }
        .map { _meta_asm, binsfile, meta_bins, bins -> [meta_bins, binsfile, bins] }

    METABINTOOLS_IMPORTBINSET(ch_metatools_import_input)

    //
    // Module: Write renamed bisn to FASTA
    //
    METABINTOOLS_EXPORTFASTA(METABINTOOLS_IMPORTBINSET.out.binsfile)

    ch_bin_refinement_publish = METABINTOOLS_EXPORTFASTA.out.fasta
        .join(ch_bin_refinement_output, by:0, remainder: true)
        .map { meta, bins, extra_files -> meta + [bins: bins, extra_files: extra_files] }


    emit:
    refined_bins_fasta     = METABINTOOLS_EXPORTFASTA.out.fasta
    refined_bins_binsfile  = METABINTOOLS_IMPORTBINSET.out.binsfile
    bin_refinement_publish = ch_bin_refinement_publish
    annotations            = PYRODIGAL.out.annotations
}
