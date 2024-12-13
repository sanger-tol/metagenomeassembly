process FASTATOCONTIG2BIN {
    tag "${meta.id}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.3.0' :
        'biocontainers/gawk:5.3.0' }"

    input:
    tuple val(meta), path(bins)
    val(extension)

    output:
    tuple val(meta), path("*.tsv"), emit: contig2bin
    path("versions.yml")          , emit: versions

    script:
    def args        = task.ext.args   ?: ''
    def prefix      = task.ext.prefix ?: "${meta.id}"
    """
    awk \\
        'BEGIN { OFS = "\t" }
        BEGINFILE {
            cmd=sprintf("basename %s .%s", FILENAME, "${extension}")
            cmd | getline bin
        }
        /^>/ {
            sub(/>/, "", \$1)
            print \$1,bin
        }' ${bins} > ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk -Wversion | sed '1!d; s/.*Awk //; s/,.*//')
    END_VERSIONS
    """

    stub:
    def prefix      = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$(awk -Wversion | sed '1!d; s/.*Awk //; s/,.*//')
    END_VERSIONS
    """
}
