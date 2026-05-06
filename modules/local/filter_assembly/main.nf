process FILTER_ASSEMBLY {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c107a3a3017f6606e46111881ba8555185d1be20713f50b7f7f4ea0128f1a05/data'
        : 'community.wave.seqera.io/library/samtools_seqkit_gawk:5f1679612f236815'}"

    input:
    tuple val(meta), path(fasta), path(tiara_classifications)
    val(minimum_contig_size)
    val(maximum_contig_size)
    val(extract_circular_contigs)
    val(minimum_circular_contig_length)
    val(tiara_exclude_classifications)

    output:
    tuple val(meta), path("*.circles.fa.gz")   , emit: circles
    tuple val(meta), path("*.filtered.fasta")  , emit: filtered
    tuple val(meta), path("*.circles.list")    , emit: circles_list
    tuple val("${task.process}"), val('seqkit'), eval('seqkit version | sed "s/seqkit v//"'), emit: versions_seqkit, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    // This regex will never match anything
    def circular_regex = "\$-"
    if (meta.assembler == "metamdbg") {
        circular_regex = "circular=yes"
    } else if (meta.assembler == "myloasm") {
        circular_regex = "circular-yes|circular-possibly"
    }
    def filter_tiara = (tiara_classifications && tiara_exclude_classifications)
    def exclude_small = minimum_contig_size ? "\$2 < ${minimum_contig_size} { print header[1] > \"${prefix}.exclude.list.tmp\" }" : ""
    def exclude_large = maximum_contig_size ? "\$2 > ${maximum_contig_size} { print header[1] > \"${prefix}.exclude.list.tmp\" }" : ""
    def exclude_circular = extract_circular_contigs ? "print header[1] > \"${prefix}.exclude.list.tmp\"" : ""
    """
    seqkit fx2tab \\
        --length \\
        --gc \\
        --name \\
        ${fasta} |\\
        awk \\
        'BEGIN { FS = OFS = "\t"}
        { split(\$1, header, /\s+/) }
        ${exclude_small}
        ${exclude_large}
        (\$1 ~ /${circular_regex}/ & \$2 >= ${minimum_circular_contig_length}) {
            print header[1] > "${prefix}.circles.list"
            ${exclude_circular}
        }'

    if [ ${filter_tiara} = true ]; then
        awk \\
            'BEGIN { FS = OFS = "\t" }
            { \$2 ~ /${tiara_exclude_classifications.join("|")}/ }' \\
            ${tiara_classifications} \\
            >> ${prefix}.exclude.list.tmp
    fi

    sort -u ${prefix}.exclude.list.tmp > ${prefix}.exclude.list

    seqkit grep -vf ${prefix}.exclude.list ${fasta} > ${prefix}.filtered.fasta
    seqkit grep -f ${prefix}.circles.list ${fasta} |\\
        bgzip -@${task.cpus} \\
        > ${prefix}.circles.fasta.gz
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | ${prefix}.circles.fasta.gz
    echo "" | ${prefix}.linear.fasta.gz
    touch ${prefix}.circles.stats
    """
}
