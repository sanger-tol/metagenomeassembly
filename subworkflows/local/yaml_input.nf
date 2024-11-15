#!/usr/bin/env nextflow

def readYAML( yamlfile ) {
    return new org.yaml.snakeyaml.Yaml().load( new FileReader( yamlfile.toString() ) )
}

workflow YAML_INPUT {
    take:
    input_file  // params.input

    main:
    // ch_versions = Channel.empty()

    yamlfile = Channel.from(input_file)
        .map { file -> readYAML(file) }

    //
    // LOGIC: PARSES THE TOP LEVEL OF YAML VALUES
    //
    input = yamlfile
        | flatten()
        | multiMap { data ->
                pacbio_fasta: ( data.pacbio ? [
                    [ id: data.tolid ],
                    data.pacbio.fasta.collect { file(it, checkIfExists: true) }
                ] : error("ERROR: Pacbio reads not provided! Pipeline will not run as there is nothing to do.") )
                hic_cram: ( data.hic ? [
                    [ id: data.tolid ],
                    data.hic.cram.collect { file(it, checkIfExists: true) }
                ] : [] )
                hic_enzymes: ( data.hic ?
                    data.hic.enzymes.collect { it } :
                    error("ERROR: Hi-C files provided but no enzymes!")
                )
        }

    ch_pacbio_fasta = input.pacbio_fasta
        | filter { !it.isEmpty() }

    ch_hic_cram = input.hic_cram
        | filter { !it.isEmpty() }

    // collect as have to ensure this is a value channel
    ch_hic_enzymes = input.hic_enzymes
        | filter { !it.isEmpty() }
        | collect

    //
    // LOGIC: PARSES THE SECOND LEVEL OF YAML VALUES PER ABOVE OUTPUT CHANNEL
    //
    // group
    //     .assembly
    //     .multiMap { data ->
    //                 assem_level:        data.assem_level
    //                 assem_version:      data.assem_version
    //                 sample_id:          data.sample_id
    //                 latin_name:         data.latin_name
    //                 defined_class:      data.defined_class
    //                 project_id:         data.project_id
    //         }
    //     .set { assembly_data }

    // //
    // // LOGIC: COMBINE SOME CHANNELS INTO VALUES REQUIRED DOWNSTREAM
    // //
    // assembly_data.sample_id
    //     .combine( assembly_data.assem_version )
    //     .map { it1, it2 ->
    //         ("${it1}_${it2}")}
    //     .set { tolid_version }

    emit:
    pacbio_fasta = ch_pacbio_fasta
    hic_cram     = ch_hic_cram
    hic_enzymes  = ch_hic_enzymes
}
