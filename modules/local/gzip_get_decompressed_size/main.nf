process GZIP_GET_DECOMPRESSED_SIZE {
    tag "${meta.id}_${meta.assembler}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/52/52ccce28d2ab928ab862e25aae26314d69c8e38bd41ca9431c67ef05221348aa/data'
        : 'community.wave.seqera.io/library/coreutils_grep_gzip_lbzip2_pruned:838ba80435a629f8'}"

    input:
    tuple val(meta), path(file)

    output:
    tuple val(meta), env('size'), emit: fasta_with_size
    path("versions.yml")        , emit: versions

    script:
    """
    if gzip -t ${file}; then
        uncompressed_size=\$(gzip -l --quiet ${file} | awk '{print \$2}')
    else
        uncompressed_size=0
    fi

    if [ "\${uncompressed_size}" -ne "0" ]; then
        size="\$uncompressed_size"
    else
        size=\$(wc -c < "${file}")
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(echo \$(gunzip --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """

    stub:
    """
    size=10000

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gunzip: \$(echo \$(gunzip --version 2>&1) | sed 's/^.*(gzip) //; s/ Copyright.*\$//')
    END_VERSIONS
    """
}
