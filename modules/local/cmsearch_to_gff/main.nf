process CMSEARCH_TO_GFF {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/74/747d2092b8ec4907620889a7303084bd544d476436ce14297e1d8372cde3e43a/data'
        : 'community.wave.seqera.io/library/pyfastx_click:044745d38b4e55c4'}"

    input:
    tuple val(meta), path(tblout), val(cmfile)

    output:
    tuple val(meta), path("*.gff"), emit: gff
    tuple val("${task.process}"), val('cmsearch_to_gff.py'), eval('cmsearch_to_gff.py --version'), emit: versions_cmsearch_to_gff, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cmsearch_to_gff.py \\
        ${args}  \\
        ${tblout} \\
        ${cmfile} > ${prefix}.gff
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.gff
    """
}
