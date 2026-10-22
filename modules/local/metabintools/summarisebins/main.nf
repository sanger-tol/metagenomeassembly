process METABINTOOLS_SUMMARISEBINS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e3/e3a2adb7abed4237d28f2a25fdb019acacef6b5d918ad1f1e96c862644809bdc/data'
        : 'community.wave.seqera.io/library/metabintools:0.4.0--e849d6679cb24725'}"

    input:
    tuple val(meta), path(binsfile)

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    tuple val("${task.process}"), val('metabintools'), eval('metabintools --version | sed "s/metabintools, version //"'), emit: versions_metabintools, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ""
    """
    metabintools summarise bins \\
        ${args} \\
        -o ${prefix}.bins_summary.tsv \\
        ${binsfile}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bins_summary.tsv
    """
}
