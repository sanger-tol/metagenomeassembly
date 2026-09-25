process CREATE_CONTIG2BIN {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/74/747d2092b8ec4907620889a7303084bd544d476436ce14297e1d8372cde3e43a/data'
        : 'community.wave.seqera.io/library/pyfastx_click:044745d38b4e55c4' }"

    input:
    tuple val(meta), path(bins, stageAs: "bins/*")

    output:
    tuple val(meta), path("*.contig2bin"), emit: contig2bin
    tuple val("${task.process}"), val('create_contig2bin.py'), eval('create_contig2bin.py --version'), emit: versions_create_contig2bin, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ""
    """
    create_contig2bin.py \\
        --prefix ${prefix} \\
        ${args} \\
        bins/
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.contig2bin
    """
}
