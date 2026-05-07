include { CENTRIFUGER_CENTRIFUGER  } from '../../../modules/nf-core/centrifuger/centrifuger'
include { CENTRIFUGER_LINEAGE      } from '../../../modules/local/centrifuger_lineage'
include { GAWK as GAWK_VAMB_DEPTHS } from '../../../modules/nf-core/gawk'
include { VAMB_BIN                 } from '../../../modules/nf-core/vamb/bin'

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
    GAWK_VAMB_DEPTHS(ch_depths, file("${projectDir}/bin/convert_depths_vamb.awk"), false)

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
            []
        )

        //
        // Module: convert centrifuger output to a lineage TSV for VAMB
        //
        CENTRIFUGER_LINEAGE(
            CENTRIFUGER_CENTRIFUGER.out.classification_file,
            ch_centrifuger_db
        )

        ch_vamb_taxonomy_input = CENTRIFUGER_LINEAGE.out.lineage_tsv
            .map { meta, tsv -> [meta - meta.subMap("single_end"), tsv] }
    } else {
        ch_vamb_taxonomy_input = ch_assemblies.map { meta, _asm -> [meta, []] }
    }

    //
    // Module: Bin contigs with VAMB
    //
    ch_vamb_input = ch_assemblies
        .combine(GAWK_VAMB_DEPTHS.out.output, by: 0)
        .combine(ch_vamb_taxonomy_input, by: 0)
        .map { meta, contigs, depths, taxonomy ->
            [meta, contigs, depths, [], taxonomy]
        }

    VAMB_BIN(ch_vamb_input)

    emit:
    bins = VAMB_BIN.out.bins
}
