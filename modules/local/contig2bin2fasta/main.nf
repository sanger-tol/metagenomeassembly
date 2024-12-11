process CONTIG2BIN2FASTA {
    tag "${meta.id}"
    label "process_low"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/seqkit:2.8.1--h9ee0642_0':
        'biocontainers/seqkit:2.8.1--h9ee0642_0' }"

    input:
    tuple val(meta), path(contigs), path(contig2bin)
    val input_is_prodigal_aa

    output:
    tuple val(meta), path("*.fa*"), emit: bins
    path("versions.yml")          , emit: versions

    script:
    def args        = task.ext.args   ?: ''
    def prefix      = task.ext.prefix ?: "${meta.id}"
    def extension   = input_is_prodigal_aa ? "faa" : "fa"
    def input_aa    = input_is_prodigal_aa ? "_.*" : ""
    def seqkit_mode = input_is_prodigal_aa ? "-rf" : "-f"
    """
    awk '{print \$2}' ${contig2bin} | sort -u | while read bin
    do
        grep -w \${bin} ${contig2bin} | awk '{print \$1\"${input_aa}\"}' > \${bin}.ctglst
        seqkit grep ${seqkit_mode} \${bin}.ctglst ${contigs} > \${bin}.${extension}
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """
}
