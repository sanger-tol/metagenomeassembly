process MAGSCOT_MAGSCOT {
    tag "${meta.id}"
    label "process_low"

    container "sanger-tol/magscot:1.1-c2"

    input:
    tuple val(meta), path(hmm), path(contig2bin)

    output:
    tuple val(meta), path("*.scores.out")       , emit: scores
    tuple val(meta), path("*.refined.out")      , emit: refined
    tuple val(meta), path("*.contig_to_bin.out"), emit: contig2bin

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cat ${contig2bin} > input.tsv

    MAGScoT.R \\
        -i input.tsv \\
        --hmm ${hmm} \\
        ${args}

    mv MAGScoT.scores.out ${prefix}.MAGScoT.scores.out
    mv MAGScoT.refined.out ${prefix}.MAGScoT.refined.out
    mv MAGScoT.refined.contig_to_bin.out ${prefix}.MAGScoT.refined.contig_to_bin.out
    """
}
