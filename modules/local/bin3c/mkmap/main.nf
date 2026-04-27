process BIN3C_MKMAP {
    tag "${meta.id}"
    label "process_medium"

    container "docker.io/cerebis/bin3c:latest"

    input:
    tuple val(meta), path(contigs), path(bam)
    val hic_enzymes

    output:
    tuple val(meta), path("*.p.gz"), emit: map
    tuple val(meta), path("*.log") , emit: log
    tuple val("${task.process}"), val('bin3c'), eval("bin3C --version | grep bin3C | sed 's/bin3C //'"), topic: versions, emit: versions_bin3c

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("ERROR: Bin3C is only avaliable as a Docker or Singularity container. If you need to run with conda, run with --enable_bin3c false")
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // if(!hic_enzymes) error("Error: no enzymes entry found in Hi-C meta object!")
    def enzymes = "-e ${hic_enzymes.join(" -e ")}"
    """
    bin3C mkmap \\
        ${enzymes} \\
        ${args} \\
        ${contigs} \\
        ${bam} \\
        bin3c/

    mv bin3c/contact_map.p.gz ${prefix}.contact_map.p.gz
    mv bin3c/bin3C.log ${prefix}.bin3C.log
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.contact_map.p.gz
    touch ${prefix}.bin3C.log
    """
}
