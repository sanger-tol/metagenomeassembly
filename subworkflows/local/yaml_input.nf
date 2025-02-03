#!/usr/bin/env nextflow

include { SAMTOOLS_INDEX } from '../../modules/nf-core/samtools/index/main'

def readYAML( yamlfile ) {
    return new org.yaml.snakeyaml.Yaml().load(yamlfile.text)
}

workflow YAML_INPUT {
    take:
    input_file  // params.input

    main:
    ch_versions = Channel.empty()
    yamlfile = Channel.fromPath(input_file)
        | map { file -> readYAML(file) }

    //
    // LOGIC: PARSES THE TOP LEVEL OF YAML VALUES
    //
    input = yamlfile
        | flatten()
        | multiMap { data ->
                pacbio_fasta: ( data.pacbio ? [
                    [ id: data.id ],
                    data.pacbio.fasta.collect { file(it, checkIfExists: true) }
                ] : error("ERROR: Pacbio reads not provided! Pipeline will not run as there is nothing to do.") )
                hic_cram: ( data.hic ? [
                    [ id: data.id ],
                    data.hic.cram.collect { file(it, checkIfExists: true) }
                ] : [] )
                hic_enzymes: ( data.hic ?
                    data.hic.enzymes.collect { it } :
                    error("ERROR: Hi-C files provided but no enzymes!")
                )
        }

    ch_pacbio_fasta = input.pacbio_fasta

    // Check if CRAM files are accompanied by an index
    // Index those that aren't
    ch_hic_cram_raw = input.hic_cram
        | filter { !it.isEmpty() }
        | transpose()
        | branch { meta, cram ->
            def index = cram.getParent() + "/" + cram.getBaseName() + ".crai"
            have_index: file(index).exists()
                return [ meta, cram, file(index, checkIfExists: true) ]
            no_index: true
                return [ meta, cram ]
        }

    SAMTOOLS_INDEX(ch_hic_cram_raw.no_index)
    ch_versions = SAMTOOLS_INDEX.out.versions

    ch_hic_cram = ch_hic_cram_raw.have_index
        | mix(SAMTOOLS_INDEX.out.crai)

    // collect as have to ensure this is a value channel
    ch_hic_enzymes = input.hic_enzymes
        | filter { !it.isEmpty() }
        | collect

    emit:
    pacbio_fasta = ch_pacbio_fasta
    hic_cram     = ch_hic_cram
    hic_enzymes  = ch_hic_enzymes
    versions     = ch_versions
}
