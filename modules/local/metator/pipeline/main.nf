process METATOR_PIPELINE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community​.wave​.seqera​.io/library/metator:6da10b3046cef708' :
        'community.wave.seqera.io/library/metator:366d773d23cc8da8' }"

    input:
    tuple val(meta), path(contigs), path(hic_input), path(depths)
    val hic_enzymes

    output:
    tuple val(meta), path("bin_summary.txt")  , emit: bin_summary
    tuple val(meta), path("binning.txt")      , emit: contig2bin
    tuple val(meta), path("final_bin/*.fasta"), emit: bins
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args           = task.ext.args   ?: ''
    def prefix         = task.ext.prefix ?: "${meta.id}"
    def enzyme_input   = hic_enzymes ? "-e ${hic_enzymes.join(",")}" : ""
    def depth_input    = depths ? "--depth ${depths}" : ""
    def assembly_input = contigs =~ /\.gz$/ ? "${contigs.getBaseName()}" : contigs
    def gunzip         = contigs =~ /\.gz$/ ? "gunzip -c ${contigs} > ${assembly_input}" : ""
    """
    ## do this until we get better container image!
    wget https://github.com/koszullab/metaTOR/raw/refs/heads/master/external/louvain-generic.tar.gz
    tar -xvzf louvain-generic.tar.gz
    cd gen-louvain
    make
    cd ..
    export LOUVAIN_PATH=gen-louvain/

    $gunzip

    metator pipeline \\
        --forward ${hic_input[0]} \\
        --reverse ${hic_input[1]} \\
        --assembly ${assembly_input} \\
        ${enzyme_input} \\
        ${depth_input} \\
        -t ${task.cpus} \\
        --prefix ${prefix} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metator: \$( metator -v )
    END_VERSIONS
    """

    stub:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch bin_summary.txt
    touch binning.txt
    mkdir final_bin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        metator: \$( metator -v )
    END_VERSIONS
    """
}
