process MYLOASM {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/67/67f705c8fa26ae809d73e5ee2c872c3087fe8abaad12e133bdba8ba4f8cdc553/data'
        : 'community.wave.seqera.io/library/myloasm_findutils_gzip:154a360acd2dca07'}"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*"), emit: results
    tuple val(meta), path("${prefix}.assembly_primary.fa.gz"), emit: contigs
    tuple val(meta), path("${prefix}.final_contig_graph.gfa.gz"), emit: gfa
    tuple val(meta), path("alternate_assemblies/${prefix}.assembly_alternate.fa.gz"), emit: contigs_alt
    tuple val(meta), path("alternate_assemblies/${prefix}.duplicated_contigs.fa.gz"), emit: contigs_dup
    tuple val(meta), path("3-mapping/${prefix}.map_to_unitigs.paf.gz"), emit: mapping
    tuple val(meta), path("*.log"), emit: log
    tuple val("${task.process}"), val('myloasm'), eval("myloasm --version | sed 's/.* //'"), emit: versions_myloasm, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    myloasm \\
        ${reads} \\
        -o . \\
        -t ${task.cpus} \\
        ${args}

    find . \\( -name "*.fa" -o -name "*.gfa" -o -name "*.edges" -o -name "*.paf.gz" \\) -type f | while read file; do
        dirname=\$(dirname "\${file}")
        basename=\$(basename "\${file}")
        mv "\$file" "\${dirname}/${prefix}.\${basename}"
        gzip \${dirname}/${prefix}.\${basename}
    done
    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}

    mkdir -p alternate_assemblies
    mkdir -p 3-mapping
    echo "" | gzip > ${prefix}.assembly_primary.fa.gz
    echo "" | gzip > ${prefix}.final_contig_graph.gfa.gz
    echo "" | gzip > alternate_assemblies/${prefix}.assembly_alternate.fa.gz
    echo "" | gzip > alternate_assemblies/${prefix}.duplicated_contigs.fa.gz
    echo "" | gzip > 3-mapping/${prefix}.map_to_unitigs.paf.gz
    touch myloasm_1.log
    """
}
