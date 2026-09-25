process METABINTOOLS_IMPORTASM {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/5d/5d1d5e82aaf8de84b37ed767e3add46f0e2735766adc242cb14402db2ac2a349/data'
        : 'community.wave.seqera.io/library/metabintools:0.2.3--ef015426958ad7ca' }"

    input:
    tuple val(meta), path(assembly)

    output:
    tuple val(meta), path("*.bins.zstd"), emit: binsfile
    tuple val("${task.process}"), val('metabintools'), eval('metabintools --version | sed "s/metabintools, version //"'), emit: versions_metabintools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ""
    """
    metabintools import asm \\
        ${args} \\
        -o ${prefix}.bins.zstd \\
        ${assembly}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bins.zstd
    """
}
