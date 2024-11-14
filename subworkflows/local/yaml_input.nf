#!/usr/bin/env nextflow

def readYAML( yamlfile ) {
    return new org.yaml.snakeyaml.Yaml().load( new FileReader( yamlfile.toString() ) )
}

workflow YAML_INPUT {
    take:
    input_file  // params.input

    main:
    // ch_versions = Channel.empty()

    Channel.from(input_file)
        .map { file -> readYAML(file) }
        .set { yamlfile }

    //
    // LOGIC: PARSES THE TOP LEVEL OF YAML VALUES
    //
    yamlfile
        .flatten()
        .multiMap { data ->
                pacbio: ( data.pacbio ? [
                    [ id: data.tolid ],
                    data.pacbio.reads.collect { file(it, checkIfExists: true) }
                ] : [] )
                // hic: if(data.hic) { [ [ id: data.tolid ], data.hic.cram.collect { file(it, checkIfExists: true) } ] }
                hic: ( data.hic ? [
                    [ id: data.tolid ],
                    data.hic.cram.collect { file(it, checkIfExists: true) }
                ] : [] )
        }
        .set{ group }

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
    // assembly_id                      = tolid_version
    pacbio = group.pacbio
    hic    = group.hic
    // versions                         = ch_versions.ifEmpty(null)
}
