process TRNASCAN_SE {
    tag "${meta.id}"
    label "process_medium"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/trnascan-se:2.0.12--pl5321h7b50bb2_2':
        'biocontainers/trnascan-se:2.0.12--pl5321h7b50bb2_2' }"

    input:
    tuple val(meta), path(fasta)
    val(emit_fasta)
    val(emit_gff)
    val(emit_bed)

    output:
    tuple val(meta), path("*.tsv")   , emit: tsv
    tuple val(meta), path("*.log")   , emit: log
    tuple val(meta), path("*.stats") , emit: stats
    tuple val(meta), path("*.fasta") , emit: fasta , optional: true
    tuple val(meta), path("*.gff")   , emit: gff   , optional: true
    tuple val(meta), path("*.bed")   , emit: bed   , optional: true
    path("versions.yml")             , emit: versions

    script:
    def args      = task.ext.args   ?: ''
    def prefix    = task.ext.prefix ?: "${meta.id}"
    def fasta_out = emit_fasta      ? "-a ${prefix}.fasta" : ""
    def gff       = emit_gff        ? "-j ${prefix}.gff" : ""
    def bed       = emit_bed        ? "-a ${prefix}.bed" : ""
    def input     = fasta.toString() - ~/\.gz$/
    def unzip     = fasta.getExtension() == "gz" ? "gunzip -c ${fasta} > ${input}" : ""
    def cleanup   = fasta.getExtension() == "gz" ? "rm ${input}" : ""
    """
    ${unzip}

    ## large genomes can fill up the limited temp space fast in singularity container.
    ## expected (!) location of the default config file is with the exectuable?
    ## copy this and modify to use the working dir as the temp directory
    conf=\$(which tRNAscan-SE).conf
    cp \${conf} trnascan.conf
    sed -i s#/tmp#.#g trnascan.conf

    tRNAscan-SE \\
        --thread ${task.cpus} \\
        -c trnascan.conf \\
        ${args} \\
        -o ${prefix}.tsv \\
        -l ${prefix}.log \\
        -m ${prefix}.stats \\
        ${fasta_out} \\
        ${gff} \\
        ${bed} \\
        ${input}

    ${cleanup}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tRNAscan-SE: 2.0.12
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv
    touch ${prefix}.log
    touch ${prefix}.stats
    touch ${prefix}.fasta
    touch ${prefix}.gff
    touch ${prefix}.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tRNAscan-SE: 2.0.12
    END_VERSIONS
    """
}
