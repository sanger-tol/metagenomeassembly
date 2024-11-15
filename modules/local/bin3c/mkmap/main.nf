process BIN3C_MKMAP {
    tag "${meta.id}"

    container "docker.io/cerebis/bin3c:latest"

    input:
    tuple val(meta), path(contigs), path(bam)
    val(hic_enzymes)

    output:
    tuple val(meta), path("*.p.gz"), emit: map
    tuple val(meta), path("*.log") , emit: log
    path("versions.yml")           , emit: versions

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    // if(!hic_enzymes) error("Error: no enzymes entry found in Hi-C meta object!")
    def enzymes =  "-e ${hic_enzymes.join(" -e ")}"
    """
    bin3C mkmap \\
        ${enzymes} \\
        ${args} \\
        ${contigs} \\
        ${bam} \\
        bin3c/

    mv bin3c/contact_map.p.gz ${prefix}.contact_map.p.gz
    mv bin3c/bin3C.log ${prefix}.bin3C.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bin3c: \$( bin3C --version | grep bin3C | sed 's/bin3C //' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.contact_map.p.gz
    touch ${prefix}.bin3C.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bin3c: \$( bin3C --version | grep bin3C | sed 's/bin3C //' )
    END_VERSIONS
    """
}
