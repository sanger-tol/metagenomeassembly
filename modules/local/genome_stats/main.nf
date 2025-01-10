process GENOME_STATS {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/02/027c4b158d44d33842c852cdc9d77e053056b073d1cd89e825f485fd331122ae/data' :
        'community.wave.seqera.io/library/seqkit_csvtk:9c819c012173d4b9' }"

    input:
    tuple val(meta), path(fasta), path(circular_list)

    output:
    tuple val(meta), path("*.tsv"), emit: stats
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: '--all'
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    seqkit stats \\
        --tabular \\
        $args \\
        $fasta > '${prefix}.stats'

    echo -e "file\tn_circ" > ${prefix}.circles
    for file in ${fasta}; do
        n_circ=\$(seqkit grep -Cf ${circular_list} \$file)
        echo -e "\${file}\t\${n_circ}" >> ${prefix}.circles
    done

    csvtk join -f file --left-join --na NA -tT ${prefix}.stats ${prefix}.circles > ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """
}
