include { CENTRIFUGER_CENTRIFUGER } from '../../../modules/nf-core/centrifuger/centrifuger'
include { CENTRIFUGER_LINEAGE     } from '../../../modules/local/centrifuger_lineage'
include { CONVERT_DEPTHS          } from '../../../modules/local/convert_depths'
include { VAMB_BIN                } from '../../../modules/nf-core/vamb/bin'

workflow BINNING_VAMB {
    take:
    ch_assemblies
    ch_depths
    val_enable_centrifuger
    ch_centrifuger_db

    main:
    //
    // Module: Convert depths TSV to format acceptable to VAMB
    //
    CONVERT_DEPTHS(
        ch_depths,
        "vamb",
    )

    if (val_enable_centrifuger) {
        //
        // Module: taxonomic classification of contigs for taxVAMB
        //
        CENTRIFUGER_CENTRIFUGER(
            ch_assemblies.map { meta, asm -> [meta + [single_end: true], asm] },
            ch_centrifuger_db,
            false,
            false,
            [],
            [],
        )

        //
        // Module: convert centrifuger output to a lineage TSV for VAMB
        //
        CENTRIFUGER_LINEAGE(
            CENTRIFUGER_CENTRIFUGER.out.classification_file,
            ch_centrifuger_db,
        )

        ch_vamb_taxonomy_input = CENTRIFUGER_LINEAGE.out.lineage_tsv.map { meta, tsv -> [meta - meta.subMap("single_end"), tsv] }

        ch_centrifuger_output = CENTRIFUGER_CENTRIFUGER.out.classification_file.map { meta, tsv -> [meta - meta.subMap("single_end"), tsv] }
    }
    else {
        ch_vamb_taxonomy_input = ch_assemblies.map { meta, _asm -> [meta, []] }
        ch_centrifuger_output = channel.empty()
    }

    //
    // Module: Bin contigs with VAMB
    //
    ch_vamb_input = ch_assemblies
        .combine(CONVERT_DEPTHS.out.depths, by: 0)
        .combine(ch_vamb_taxonomy_input, by: 0)
        .map { meta, contigs, depths, taxonomy ->
            def binner = taxonomy ? "taxvamb" : "vamb"
            def run_type = meta?.collated ? "multi" : "single"
            [meta + [binner: "${binner}_${run_type}"], contigs, depths, [], taxonomy]
        }

    VAMB_BIN(ch_vamb_input)

    ch_vamb_single_bins = VAMB_BIN.out.bins.filter { meta, _bins -> !meta?.collated }

    ch_vamb_multi = VAMB_BIN.out.bins
        .join(VAMB_BIN.out.abundance)
        .join(VAMB_BIN.out.composition)
        .join(VAMB_BIN.out.log)
        .join(VAMB_BIN.out.taxometer_results, remainder: true)
        .join(VAMB_BIN.out.latent_encoding, remainder: true)
        .filter { meta, _bins, _abundance, _composition, _log, _taxometer, _latent -> meta?.collated }
        .flatMap { meta, bins, abundance, composition, vamb_log, taxometer, latent ->
            return meta.ids
                .withIndex()
                .collect { id, idx ->
                    def bins_subset = bins.findAll { bin -> bin.getName() =~ id }
                    def assembler = meta.assemblers[idx]
                    def platform = meta.platforms[idx]
                    return [[id: id, binner: "${meta.binner}", assembler: assembler, platform: platform], bins_subset, abundance, composition, vamb_log, taxometer, latent]
                }
        }

    ch_vamb_multi_bins = ch_vamb_multi.map { meta, bins, abundance, composition, vamb_log, taxometer, latent ->
        [meta, bins]
    }

    ch_vamb_single_output = VAMB_BIN.out.log
        .join(VAMB_BIN.out.abundance)
        .join(VAMB_BIN.out.composition)
        .join(VAMB_BIN.out.taxometer_results, remainder: true)
        .join(VAMB_BIN.out.latent_encoding, remainder: true)
        .map { meta, vamb_log, abundance, composition, taxometer_results, latent_encoding ->
            [meta, [vamb_log, abundance, composition, taxometer_results, latent_encoding].findAll().flatten()]
        }
        .filter { meta, _bins -> !meta?.collated }

    ch_vamb_multi_output = ch_vamb_multi.map { meta, _bins, abundance, composition, vamb_log, taxometer, latent ->
        [meta, [abundance, composition, vamb_log, taxometer, latent].findAll().flatten()]
    }

    emit:
    centrifuger = ch_centrifuger_output
    single_bins = ch_vamb_single_bins
    multi_bins  = ch_vamb_multi_bins
    vamb_single = ch_vamb_single_output
    vamb_multi  = ch_vamb_multi_output
}
