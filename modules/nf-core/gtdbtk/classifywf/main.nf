process GTDBTK_CLASSIFYWF {
    tag "${prefix}"
    label 'process_medium'
    conda "${moduleDir}/environment.yml"
    container "sanger-tol/gtdbtk:2.4.0-c1"

    input:
    tuple val(meta)   , path("bins/*")
    tuple val(db_name), path("database/*")
    val use_pplacer_scratch_dir
    path mash_db
    path bacteria_md
    path archaea_md

    output:
    tuple val(meta), path("gtdbtk.${prefix}.*.summary.tsv")        , emit: summary
    tuple val(meta), path("gtdbtk.${prefix}.*.classify.tree.gz")   , emit: tree    , optional: true
    tuple val(meta), path("gtdbtk.${prefix}.*.markers_summary.tsv"), emit: markers , optional: true
    tuple val(meta), path("gtdbtk.${prefix}.*.msa.fasta.gz")       , emit: msa     , optional: true
    tuple val(meta), path("gtdbtk.${prefix}.*.user_msa.fasta.gz")  , emit: user_msa, optional: true
    tuple val(meta), path("gtdbtk.${prefix}.*.filtered.tsv")       , emit: filtered, optional: true
    tuple val(meta), path("gtdbtk.${prefix}.failed_genomes.tsv")   , emit: failed  , optional: true
    tuple val(meta), path("gtdbtk.${prefix}.log")                  , emit: log
    tuple val(meta), path("gtdbtk.${prefix}.warnings.log")         , emit: warnings
    tuple val(meta), path("gtdbtk.${prefix}_ncbi.tsv")             , emit: ncbi    , optional: true
    path ("versions.yml"), emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def pplacer_scratch = use_pplacer_scratch_dir ? "--scratch_dir pplacer_tmp" : ""
    def mash_mode       = mash_db                 ? "--mash_db ${mash_db}"      : "--skip_ani_screen"
    prefix = task.ext.prefix ?: "${meta.id}"
    def run_ncbi = ((bacteria_md || archaea_md) && workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() == 0) ? true : false
    def bac_md = bacteria_md ? "--bac120_metadata_file ${bacteria_md}" : ""
    def ar_md  = archaea_md ? "--ar53_metadata_file ${archaea_md}" : ""
    ncbi_command = run_ncbi ? """
        gtdb_to_ncbi_majority_vote.py \\
        --gtdbtk_output_dir . \\
        ${bac_md} ${ar_md} \\
        --gtdbtk_prefix gtdbtk.${prefix} \\
        --output_file gtdbtk.${prefix}_ncbi.tsv""" : ""
    """
    export GTDBTK_DATA_PATH="\${PWD}/database"
    if [ ${pplacer_scratch} != "" ] ; then
        mkdir pplacer_tmp
    fi

    gtdbtk classify_wf \\
        ${args} \\
        --genome_dir bins \\
        --prefix "gtdbtk.${prefix}" \\
        --out_dir "\${PWD}" \\
        --cpus ${task.cpus} \\
        ${mash_mode} \\
        ${pplacer_scratch}

    ${ncbi_command}

    ## If mash db given, classify/ and identify/ directories won't be created
    if [[ -d classify/ && \$(ls -A classify/) ]]; then
        mv classify/* .
    fi

    if [[ -d identify/ && \$(ls -A identify/) ]]; then
        mv identify/* .
    fi

    ## If nothing aligns, no output, so only run
    if [[ -d align/ && \$(ls -A align/) ]]; then
        mv align/* .
    fi

    mv gtdbtk.log "gtdbtk.${prefix}.log"

    mv gtdbtk.warnings.log "gtdbtk.${prefix}.warnings.log"

    find -name "gtdbtk.${prefix}.*.classify.tree" | xargs -r gzip # do not fail if .tree is missing

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gtdbtk: \$(echo \$(gtdbtk --version -v 2>&1) | sed "s/gtdbtk: version //; s/ Copyright.*//")
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch gtdbtk.${prefix}.stub.summary.tsv
    echo "" | gzip > gtdbtk.${prefix}.stub.classify.tree.gz
    touch gtdbtk.${prefix}.stub.markers_summary.tsv
    echo "" | gzip > gtdbtk.${prefix}.stub.msa.fasta.gz
    echo "" | gzip > gtdbtk.${prefix}.stub.user_msa.fasta.gz
    touch gtdbtk.${prefix}.stub.filtered.tsv
    touch gtdbtk.${prefix}.log
    touch gtdbtk.${prefix}.warnings.log
    touch gtdbtk.${prefix}.failed_genomes.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gtdbtk: \$(echo \$(gtdbtk --version -v 2>&1) | sed "s/gtdbtk: version //; s/ Copyright.*//")
    END_VERSIONS
    """
}
