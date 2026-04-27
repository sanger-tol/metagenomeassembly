process BIN3C_CLUSTER {
    tag "${meta.id}"
    label "process_medium"

    container "docker.io/cerebis/bin3c:latest"

    input:
    tuple val(meta), path(contigs), path(map)

    output:
    tuple val(meta), path("*.fa.gz"), emit: fasta, optional: true
    tuple val(meta), path("*.[!fna,log]*"), emit: clustering
    tuple val(meta), path("*.log"), emit: log
    tuple val("${task.process}"), val('bin3c'), eval("bin3C --version | grep bin3C | sed 's/bin3C //'"), topic: versions, emit: versions_bin3c

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("ERROR: Bin3C is only avaliable as a Docker or Singularity container. If you need to run with conda, run with --enable_bin3c false")
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    bin3C cluster \\
        ${args} \\
        --fasta ${contigs} \\
        ${map} \\
        bin3c/

    # bin3c renames contigs, we don't want that
    for bin in bin3c/fasta/*.fna; do
        bn=`basename \$bin .fna`
        awk -F" " '{if(\$1~">"){print ">" substr(\$2,8)}else{print \$0}}' \$bin > ${prefix}.\${bn}.fa
    done

    find bin3c -maxdepth 1 -type f -exec sh -c 'name=`basename {}`; mv {} ${prefix}.\$name' \\;
    find . -name "*.fa" -exec gzip {} \\;
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.infomap.log
    touch ${prefix}.cluster_plot.png
    touch ${prefix}.cluster_report.csv
    touch ${prefix}.clustering.mcl
    echo "" | gzip > ${prefix}.clustering.p.gz
    touch ${prefix}.cm_graph.edges
    touch ${prefix}.cm_graph.tree
    echo "" | gzip > ${prefix}.CL01.fa.gz
    """
}
