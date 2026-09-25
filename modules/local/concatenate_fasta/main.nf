process CONCATENATE_FASTA {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/74/747d2092b8ec4907620889a7303084bd544d476436ce14297e1d8372cde3e43a/data'
        : 'community.wave.seqera.io/library/pyfastx_click:044745d38b4e55c4' }"

    input:
    tuple val(meta), path(fasta), val(ids)

    output:
    tuple val(meta), path("*.fasta"), emit: concat_fasta
    tuple val("${task.process}"), val('concatenate_fasta.py'), eval('concatenate_fasta.py --version'), emit: versions_concatenate_fasta, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // WARNING: This module includes the slice_fasta.py script as a module binary in
    // ${moduleDir}/resources/usr/bin/slice_fasta.py. To use this module, you will
    // either have to copy this file to ${projectDir}/bin or set the option
    // nextflow.enable.moduleBinaries = true
    // in your nextflow.config file.
    def args       = task.ext.args  ?: ''
    def prefix     = task.ext.prefix ?: "${meta.id}"
    def fasta_inputs = fasta.collect { f -> "--fasta ${f}" }.join(" ")
    def id_inputs = ids ? ids.collect { id -> "--id ${id}" }.join(" ") : ''
    """
    concatenate_fasta.py \\
        ${fasta_inputs} \\
        ${id_inputs} \\
        ${args} > ${prefix}.fasta
    """

    stub:
    def prefix     = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.fasta
    """
}
