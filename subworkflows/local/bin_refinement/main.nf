include { CONTIG2BINTOFASTA                       } from '../../../modules/local/contig2bintofasta/main'
include { DASTOOL_DASTOOL                         } from '../../../modules/nf-core/dastool/dastool/main'
include { GAWK as GAWK_PROCESS_HMM_TBLOUT         } from '../../../modules/nf-core/gawk/main'
include { GAWK as GAWK_MAGSCOT_PROCESS_CONTIG2BIN } from '../../../modules/nf-core/gawk/main'
include { GAWK as GAWK_RENAME_BINS                } from '../../../modules/nf-core/gawk/main'
include { HMMER_HMMSEARCH                         } from '../../../modules/nf-core/hmmer/hmmsearch/main'
include { MAGSCOT_MAGSCOT                         } from '../../../modules/local/magscot/magscot/main'
include { PYRODIGAL                               } from '../../../modules/nf-core/pyrodigal/main'

workflow BIN_REFINEMENT {
    take:
    assembly
    contig2bin
    magscot_gtdb_hmm_db

    main:
    ch_versions               = Channel.empty()
    ch_refined_bins           = Channel.empty()
    ch_refined_contig2bin_raw = Channel.empty()

    //
    // MODULE: Identify ORFs in assembly using Pyrodigal
    //
    PYRODIGAL(assembly, 'gff')
    ch_versions = ch_versions.mix(PYRODIGAL.out.versions)
    ch_proteins = PYRODIGAL.out.faa

    if(params.enable_dastool) {
        ch_contig2bins_to_merge = contig2bin
            | map {meta, tsv -> [meta - meta.subMap(['binner']), tsv] }
            | groupTuple(by: 0)

        ch_dastool_input = assembly
            | combine(ch_contig2bins_to_merge, by: 0)
            | combine(ch_proteins, by: 0)

        //
        // MODULE: Refine bins using DAS_Tool + ORFs
        //
        DASTOOL_DASTOOL(ch_dastool_input, [])
        ch_versions = ch_versions.mix(DASTOOL_DASTOOL.out.versions)

        ch_dastool_c2b = DASTOOL_DASTOOL.out.contig2bin
            | map { meta, c2b -> [ meta + [binner: "dastool"], c2b ]}

        ch_refined_contig2bin_raw = ch_refined_contig2bin_raw.mix(ch_dastool_c2b)
    }

    if(params.enable_magscot && workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() == 0) {
        //
        // LOGIC: MagScoT needs a TSV file of gene predictions in each contig
        //        Run hmmsearch using the provided hmm files on the predicted
        //        proteins for each assembly and process with gawk
        //

        ch_hmmsearch_gtdb_input = ch_proteins
            | combine(magscot_gtdb_hmm_db)
            | map { meta, faa, hmmfile ->
                [ meta, hmmfile, faa, false, true, false ]
            }

        //
        // MODULE: Determine which ORFs are GTDB marker genes
        //
        HMMER_HMMSEARCH(ch_hmmsearch_gtdb_input)
        ch_versions = ch_versions.mix(HMMER_HMMSEARCH.out.versions)

        ch_hmm_output = HMMER_HMMSEARCH.out.target_summary
            | groupTuple(by: 0)

        //
        // MODULE: Process HMM output to summarise per-contig
        //
        GAWK_PROCESS_HMM_TBLOUT(ch_hmm_output, [], false)
        ch_versions = ch_versions.mix(GAWK_PROCESS_HMM_TBLOUT.out.versions)

        //
        // MODULE: reformat contig2bin files to bin\tcontig\tbinner
        // from contig\tbin format
        //
        GAWK_MAGSCOT_PROCESS_CONTIG2BIN(
            contig2bin,
            [],
            false
        )
        ch_versions = ch_versions.mix(GAWK_MAGSCOT_PROCESS_CONTIG2BIN.out.versions)

        //
        // LOGIC: Run MagScoT
        //
        ch_magscot_contig2bin = GAWK_MAGSCOT_PROCESS_CONTIG2BIN.out.output
            | map { meta, c2b -> [ meta - meta.subMap(['binner']), c2b ] }
            | groupTuple(by: 0)

        ch_magscot_input = GAWK_PROCESS_HMM_TBLOUT.out.output
            | combine(ch_magscot_contig2bin, by: 0)

        //
        // MODULE: Bin refinement with MagScoT
        //
        MAGSCOT_MAGSCOT(ch_magscot_input)
        ch_versions = ch_versions.mix(MAGSCOT_MAGSCOT.out.versions)

        ch_magscot_c2b = MAGSCOT_MAGSCOT.out.contig2bin
            | map { meta, c2b -> [ meta + [binner: "magscot"], c2b ]}

        ch_refined_contig2bin_raw = ch_refined_contig2bin_raw.mix(ch_magscot_c2b)
    }

    //
    // LOGIC: DAS_Tool and MagScoT do not give control over the names of the bins
    //        they output - this causes issues with file collisions and expected name conventions
    //        downstream. Rename the bins inside the contig2bin script and write to fasta separately
    //
    if(params.enable_dastool || params.enable_magscot) {
        //
        // MODULE: Rename bins inside contig2bin files
        //
        GAWK_RENAME_BINS(ch_refined_contig2bin_raw, [], false)
        ch_versions = ch_versions.mix(GAWK_RENAME_BINS.out.versions)
        ch_refined_contig2bin = GAWK_RENAME_BINS.out.output

        ch_c2b_to_combine = GAWK_RENAME_BINS.out.output
            | map { meta, c2b -> [ meta - meta.subMap("binner"), meta, c2b ]}

        ch_contig2bintofasta_input = assembly
            | combine(ch_c2b_to_combine, by: 0)
            | map { _meta, contigs, meta_c2b, c2b -> [ meta_c2b, contigs, c2b ]}

        //
        // MODULE: Create binned fasta files using contig2bin files
        //
        CONTIG2BINTOFASTA(ch_contig2bintofasta_input)
        ch_versions = ch_versions.mix(CONTIG2BINTOFASTA.out.versions)

        ch_refined_bins = CONTIG2BINTOFASTA.out.bins
    }

    emit:
    refined_bins = ch_refined_bins
    contig2bin   = ch_refined_contig2bin
    versions     = ch_versions
}
