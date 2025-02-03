def readYAML(yamlfile) {
    return new org.yaml.snakeyaml.Yaml().load(yamlfile.text)
}

process YAML_INPUT {
    executor "local"

    input:
    val(yaml)

    output:
    tuple val(meta), val(pacbio)  , emit: pacbio_fasta
    tuple val(meta), val(hic_cram), emit: hic_cram
    val(hic_enzymes)              , emit: hic_enzymes

    exec:
    // Read input
    def input = readYAML(yaml)

    // Check input types
    if(input.hic.cram.find() && !input.hic.enzymes.find()) {
        error("ERROR: Hi-C files provided but no enzymes!")
    }
    if(!input.pacbio.fasta.find()) {
        error("ERROR: Pacbio reads not provided! Pipeline will not run as there is nothing to do.")
    }

    // Generate meta map
    id          = input.id
    meta        = [id: id]

    // Process input files
    pacbio      = input.pacbio.fasta.flatten()
    hic_cram    = input.hic.cram.find()    ? input.hic.cram.flatten()    : []
    hic_enzymes = input.hic.enzymes.find() ? input.hic.enzymes.flatten() : []
}
