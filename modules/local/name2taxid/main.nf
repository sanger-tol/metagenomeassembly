process TAXONKIT_CSVTK_NAME2TAXID {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'community.wave.seqera.io/library/csvtk_taxonkit:9b28c254a08052b5':
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/fe/fe96e23a2b9e7b1e6f451b3202fbe224ceb33501fbf7d45812f2e580d7e0ec85/data' }"

    input:
    tuple val(meta), val(name), path(names_txt)
    path taxdb
    val header

    output:
    tuple val(meta), path("*.tsv"), emit: tsv
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    assert (!name && names_txt) || (name && !names_txt)
    """
    taxonkit \\
        name2taxid \\
        $args \\
        --data-dir $taxdb \\
        --threads $task.cpus \\
        --out-file ${prefix}.tsv \\
        ${name? "<<< '$name'": names_txt} |\\
        csvtk -t add-header -n ${header}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        taxonkit: \$( taxonkit version | sed 's/.* v//' )
        csvtk: \$(echo \$( csvtk version | sed -e "s/csvtk v//g" ))
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        taxonkit: \$( taxonkit version | sed 's/.* v//' )
        csvtk: \$(echo \$( csvtk version | sed -e "s/csvtk v//g" ))
    END_VERSIONS
    """
}
