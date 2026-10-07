include { COMEBIN_RUNCOMEBIN                       } from '../../../modules/nf-core/comebin/runcomebin'
include { CONVERT_DEPTHS as CONVERT_DEPTHS_MAXBIN2 } from '../../../modules/local/convert_depths'
include { MAXBIN2                                  } from '../../../modules/nf-core/maxbin2'
include { METABAT2_METABAT2                        } from '../../../modules/nf-core/metabat2/metabat2'
include { METATOR_PIPELINE                         } from '../../../modules/nf-core/metator/pipeline'
include { SEMIBIN_MULTIEASYBIN                     } from '../../../modules/nf-core/semibin/multieasybin/main'
include { SEMIBIN_SINGLEEASYBIN                    } from '../../../modules/nf-core/semibin/singleeasybin'
include { SEQKIT_SPLIT2 as SPLIT_CIRCLES           } from '../../../modules/nf-core/seqkit/split2'
include { METABINTOOLS_IMPORTBINSET                } from '../../../modules/local/metabintools/importbinset'
include { METABINTOOLS_EXPORTFASTA                 } from '../../../modules/local/metabintools/exportfasta'
include { BINNING_VAMB                             } from '../../../subworkflows/local/binning_vamb'
include { BINNING_VAMB as BINNING_TAXVAMB          } from '../../../subworkflows/local/binning_vamb'

workflow BINNING {
    take:
    ch_assemblies
    ch_assemblies_binfiles
    ch_circular_contigs
    ch_depths
    ch_bams
    ch_hic_pairs
    ch_centrifuger_db
    val_binners

    main:
    ch_bins = channel.empty()
    ch_binning_out = channel.empty()
    ch_centrifuger_output = channel.empty()

    ch_assemblies_individual = ch_assemblies.filter { meta, _fasta -> !meta?.collated }
    ch_assemblies_collated = ch_assemblies.filter { meta, _fasta -> meta?.collated }
    ch_bam_individual = ch_bams.filter { meta, _bam -> !meta?.collated }
    ch_bam_collated = ch_bams.filter { meta, _bam -> meta?.collated }
    ch_depths_individual = ch_depths.filter { meta, _depth -> !meta?.collated }
    ch_depths_collated = ch_depths.filter { meta, _depth -> meta?.collated }

    //
    // Module: Split circular contigs into separate bin files
    //
    if (val_binners.circular) {
        SPLIT_CIRCLES(ch_circular_contigs.map { meta, contigs -> [meta + [single_end: true], contigs] })

        ch_circular_bins = SPLIT_CIRCLES.out.reads.map { meta, fasta ->
            [meta - meta.subMap("single_end") + [binner: "circular"], fasta]
        }
        ch_bins = ch_bins.mix(ch_circular_bins)
    }

    //
    // Module: Bin assembly using Metabat2
    //
    if (val_binners.metabat2) {
        METABAT2_METABAT2(
            ch_assemblies_individual.combine(ch_depths, by: 0)
        )

        ch_bins = ch_bins.mix(
            METABAT2_METABAT2.out.fasta.map { meta, fasta -> [meta + [binner: "metabat2"], fasta] }
        )
    }

    //
    // Logic: Bin assembly with MaxBin2
    //
    if (val_binners.maxbin2) {
        CONVERT_DEPTHS_MAXBIN2(
            ch_depths_individual,
            "maxbin2",
        )

        ch_maxbin2_input = ch_assemblies_individual
            .combine(CONVERT_DEPTHS_MAXBIN2.out.depths, by: 0)
            .map { meta, contigs, depths ->
                [meta, contigs, [], depths]
            }

        //
        // Module: Bin assembly using MaxBin2
        //
        MAXBIN2(ch_maxbin2_input)

        ch_bins = ch_bins.mix(
            MAXBIN2.out.binned_fastas.map { meta, fasta -> [meta + [binner: "maxbin2"], fasta] }
        )

        ch_maxbin2_out = MAXBIN2.out.summary
            .join(MAXBIN2.out.abundance, remainder: true)
            .join(MAXBIN2.out.log, remainder: true)
            .join(MAXBIN2.out.marker_counts, remainder: true)
            .join(MAXBIN2.out.marker_bins, remainder: true)
            .join(MAXBIN2.out.marker_genes, remainder: true)
            .map { meta, summary, abundance, maxbin_log, marker_counts, marker_bins, marker_genes ->
                [meta + [binner: "maxbin2"], [summary, abundance, maxbin_log, marker_counts, marker_bins, marker_genes].findAll().flatten()]
            }

        ch_binning_out = ch_binning_out.mix(ch_maxbin2_out)
    }

    if (val_binners.comebin) {
        //
        // Module: Bin assembly using Comebin
        //
        ch_comebin_input = ch_assemblies_individual
            .combine(ch_bam_individual, by: 0)
            .map { meta, asm, bam -> [meta, asm, bam] }

        COMEBIN_RUNCOMEBIN(ch_comebin_input)

        ch_bins = ch_bins.mix(
            COMEBIN_RUNCOMEBIN.out.bins.map { meta, fasta -> [meta + [binner: "comebin"], fasta] }
        )

        ch_comebin_out = COMEBIN_RUNCOMEBIN.out.tsv
            .join(COMEBIN_RUNCOMEBIN.out.log)
            .join(COMEBIN_RUNCOMEBIN.out.embeddings)
            .join(COMEBIN_RUNCOMEBIN.out.covembeddings)
            .join(COMEBIN_RUNCOMEBIN.out.embedding_ids)
            .map { meta, tsv, log, embeddings, covembeddings, embedding_ids ->
                [meta + [binner: "comebin"], [tsv, log, embeddings, covembeddings, embedding_ids].findAll().flatten()]
            }

        ch_binning_out = ch_binning_out.mix(ch_comebin_out)
    }

    if (val_binners.semibin2) {
        if (!val_binners.multisplit) {
            //
            // Module: Bin assembly using Semibin
            //
            ch_semibin_input = ch_assemblies_individual
                .combine(ch_bam_individual, by: 0)
                .map { meta, asm, bam -> [meta, asm, bam] }

            SEMIBIN_SINGLEEASYBIN(ch_semibin_input)

            ch_bins = ch_bins.mix(
                SEMIBIN_SINGLEEASYBIN.out.output_fasta.map { meta, fasta -> [meta + [binner: "semibin_single"], fasta] }
            )

            ch_semibin_single_out = SEMIBIN_SINGLEEASYBIN.out.csv
                .join(SEMIBIN_SINGLEEASYBIN.out.model)
                .join(SEMIBIN_SINGLEEASYBIN.out.tsv)
                .map { meta, csv, model, tsv ->
                    [meta + [binner: "semibin_single"], [csv, model, tsv].findAll().flatten()]
                }

            ch_binning_out = ch_binning_out.mix(ch_semibin_single_out)
        }
        else {
            ch_semibin_input = ch_assemblies_collated
                .combine(ch_bam_collated, by: 0)
                .map { meta, asm, bam -> [meta, asm, bam, []] }

            SEMIBIN_MULTIEASYBIN(ch_semibin_input)

            ch_semibin_multi_bins = SEMIBIN_MULTIEASYBIN.out.bins.flatMap { meta, bins ->
                return meta.ids
                    .withIndex()
                    .collect { id, idx ->
                        def bins_subset = bins.findAll { bin -> bin.getName() =~ id }
                        def assembler = meta.assemblers[idx]
                        def platform = meta.platforms[idx]
                        return [[id: id, binner: "semibin_multi", assembler: assembler, platform: platform], bins_subset]
                    }
            }
            ch_bins = ch_bins.mix(ch_semibin_multi_bins)

            ch_semibin_multi_output = ch_semibin_multi_bins
                .combine(SEMIBIN_MULTIEASYBIN.out.csv)
                .combine(SEMIBIN_MULTIEASYBIN.out.tsv)
                .combine(SEMIBIN_MULTIEASYBIN.out.log)
                .map { meta, _bins, _meta_csv, csv, _meta_tsv, tsv, _meta_log, semibin_log ->
                    [meta + [binner: "semibin_multi"], [csv, tsv, semibin_log].flatten().findAll { f -> f.toUriString() =~ "${meta.id}" }]
                }

            ch_binning_out = ch_binning_out.mix(ch_semibin_multi_output)
        }
    }

    if (val_binners.vamb) {
        ch_vamb_input_assemblies = val_binners.multisplit ? ch_assemblies_collated : ch_assemblies_individual
        ch_vamb_input_depths = val_binners.multisplit ? ch_depths_collated : ch_depths_individual

        //
        // Subworkflow: Bin assembly with VAMB in standard mode
        //
        BINNING_VAMB(
            ch_vamb_input_assemblies,
            ch_vamb_input_depths,
            false,
            channel.empty(),
        )

        ch_bins = ch_bins
            .mix(BINNING_VAMB.out.single_bins)
            .mix(BINNING_VAMB.out.multi_bins)

        ch_binning_out = ch_binning_out
            .mix(BINNING_VAMB.out.vamb_single)
            .mix(BINNING_VAMB.out.vamb_multi)
    }

    if (val_binners.taxvamb) {
        ch_taxvamb_input_assemblies = val_binners.multisplit ? ch_assemblies_collated : ch_assemblies_individual
        ch_taxvamb_input_depths = val_binners.multisplit ? ch_depths_collated : ch_depths_individual

        //
        // Subworkflow: Bin assembly with VAMB with taxonomy
        //
        BINNING_TAXVAMB(
            ch_taxvamb_input_assemblies,
            ch_taxvamb_input_depths,
            true,
            ch_centrifuger_db,
        )

        ch_bins = ch_bins
            .mix(BINNING_TAXVAMB.out.single_bins)
            .mix(BINNING_TAXVAMB.out.multi_bins)

        ch_binning_out = ch_binning_out
            .mix(BINNING_TAXVAMB.out.vamb_single)
            .mix(BINNING_TAXVAMB.out.vamb_multi)

        ch_centrifuger_output = ch_centrifuger_output.mix(BINNING_TAXVAMB.out.centrifuger)
    }

    if (val_binners.metator) {
        //
        // Module: Bin assembly using Metator
        //
        ch_metator_inputs = ch_assemblies_individual
            .combine(ch_hic_pairs, by: 0)
            .map { meta, asm, pairs ->
                [meta, asm, pairs, []]
            }

        METATOR_PIPELINE(ch_metator_inputs)

        ch_bins = ch_bins.mix(METATOR_PIPELINE.out.bins.map { meta, bins -> [meta + [binner: "metator"], bins] })

        ch_metator_output = METATOR_PIPELINE.out.network
            .join(METATOR_PIPELINE.out.contig_data)
            .join(METATOR_PIPELINE.out.plots)
            .map { meta, network, contig_data, plots ->
                [meta + [binner: "metator"], [network, contig_data, plots].findAll().flatten()]
            }

        ch_binning_out = ch_binning_out.mix(ch_metator_output)
    }

    //
    // Module: Import each set of bins to a binsfile with the assembly
    // Each bin is renamed to a consistent naming schema.
    //
    ch_metatools_import_input = ch_assemblies_binfiles
        .combine(ch_bins)
        .filter { meta_asm, _binsfile, meta_bins, _bins -> meta_asm.id == meta_bins.id }
        .map { _meta_asm, binsfile, meta_bins, bins -> [meta_bins, binsfile, bins] }

    METABINTOOLS_IMPORTBINSET(ch_metatools_import_input)

    //
    // Module: Write renamed bins to FASTA
    //
    METABINTOOLS_EXPORTFASTA(METABINTOOLS_IMPORTBINSET.out.binsfile)

    ch_binning_publish = METABINTOOLS_EXPORTFASTA.out.fasta
        .join(ch_binning_out, by: 0, remainder: true)
        .map { meta, bins, extra_files -> meta + [bins: bins, extra_files: extra_files] }

    emit:
    bins_fasta      = METABINTOOLS_EXPORTFASTA.out.fasta
    bins_binsfile   = METABINTOOLS_IMPORTBINSET.out.binsfile
    binning_publish = ch_binning_publish
    centrifuger     = ch_centrifuger_output
}
