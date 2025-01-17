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
    path("versions.yml")                        , emit: versions

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "ERROR: MagScoT is only avaliable as a Docker or Singularity container. If you need to run with conda, run with --enable_magscot false"
    }
    """
    cat ${contig2bin} > input.tsv

    MAGScoT.R \\
        -i input.tsv \\
        --hmm ${hmm} \\
        ${args}

    mv MAGScoT.scores.out ${prefix}.MAGScoT.scores.out
    mv MAGScoT.refined.out ${prefix}.MAGScoT.refined.out

    ## magscot puts out contig2bin file in wrong format
    awk 'BEGIN{OFS="\t"} NR > 1 {print \$2,\$1}' MAGScoT.refined.contig_to_bin.out > ${prefix}.MAGScoT.refined.contig_to_bin.out
    rm MAGScoT.refined.contig_to_bin.out

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        magscot: 1.1
    END_VERSIONS
    """
}
