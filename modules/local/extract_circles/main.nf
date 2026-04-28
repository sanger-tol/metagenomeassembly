process EXTRACT_CIRCLES {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c107a3a3017f6606e46111881ba8555185d1be20713f50b7f7f4ea0128f1a05/data'
        : 'community.wave.seqera.io/library/samtools_seqkit_gawk:5f1679612f236815'}"

    input:
    tuple val(meta), path(fasta)
    val(min_mag_length)

    output:
    tuple val(meta), path("*.circles.fasta"), emit: circles
    tuple val(meta), path("*.linear.fasta") , emit: linear
    tuple val(meta), path("*.circles.list")    , emit: circles_list
    tuple val("${task.process}"), val('seqkit'), eval('seqkit version | sed "s/seqkit v//"'), emit: versions_seqkit, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    // This regex will never match anything
    def regex = "\$-"
    if (meta.assembler == "metamdbg") {
        regex = "circular=yes"
    } else if (meta.assembler == "myloasm") {
        regex = "circular-yes|circular-possibly"
    }
    """
    seqkit grep -nrp "${regex}" ${fasta} |\\
        seqkit seq -m ${min_mag_length} \\
        > ${prefix}.circles.fasta

    seqkit fx2tab \\
        --length \\
        --gc \\
        --name \\
        ${prefix}.circles.fasta |\\
        awk '{ print \$1 }' \\
        > ${prefix}.circles.list

    seqkit grep -vf ${prefix}.circles.list ${fasta} > ${prefix}.linear.fasta
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | ${prefix}.circles.fasta.gz
    echo "" | ${prefix}.linear.fasta.gz
    touch ${prefix}.circles.stats
    """
}
