process BIN3C_CLUSTER {
    tag "${meta.id}"

    container "docker.io/cerebis/bin3c:latest"

    input:
    tuple val(meta), path(contigs), path(map)

    output:
    tuple val(meta), path("*.fa")         , emit: fasta, optional: true
    tuple val(meta), path("*.[!fna,log]*"), emit: clustering
    tuple val(meta), path("*.log")        , emit: log
    path("versions.yml")                  , emit: versions

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def contigs_basename = contigs.getBaseName()
    """
    zcat ${contigs} | bgzip -c > ${contigs_basename}.bgz

    bin3C cluster \\
        ${args} \\
        --fasta ${contigs_basename}.bgz \\
        ${map} \\
        bin3c/

    # bin3c renames contigs, we don't want that
    for bin in bin3c/fasta/*.fna; do
        basename=`basename \$bin`
        awk -F" " '{if(\$1~">"){print ">" substr(\$2,8)}else{print \$0}}' \$bin > ${prefix}.\${basename%.fna}.fa
    done

    find bin3c -maxdepth 1 -type f -exec sh -c 'name=`basename {}`; mv {} ${prefix}.\$name' \\;

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bin3c: \$( bin3C --version | grep bin3C | sed 's/bin3C //' )
        gzip: \$( gzip --version | grep gzip | sed 's/gzip //' )
        bgzip: \$( bgzip --version | grep bgzip | sed 's/bgzip (htslib) //' )
    END_VERSIONS
    """
}
