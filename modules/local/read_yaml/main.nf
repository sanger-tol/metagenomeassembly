def readYAML(yamlfile) {
    return new org.yaml.snakeyaml.Yaml().load(yamlfile.text)
}

process READ_YAML {
    executor "local"

    input:
    val(yaml)
    val(enable_assembly)

    output:
    tuple val(meta)    , val(pacbio)  , emit: pacbio_fasta
    tuple val(meta)    , val(hic_cram), emit: hic_cram
    tuple val(asm_meta), val(assembly), emit: assembly
    val(hic_enzymes)                  , emit: hic_enzymes

    exec:
    // Read input
    def input = readYAML(yaml)

    // Check input types
    if(!input?.pacbio?.fasta) {
        error("ERROR: Pacbio reads not provided! Pipeline will not run as there is nothing to do.")
    }
    if(input?.hic?.cram && !input?.hic?.enzymes) {
        error("ERROR: Hi-C files provided but no enzymes!")
    }
    if(!input?.assembly?.fasta && !enable_assembly) {
        error("ERROR: Assembly mode was not enabled, but a pre-existing assembly was not provided!")
    }
    if(input?.assembly?.fasta && !input?.assembly?.assembler) {
        error("ERROR: Assembly FASTA provided but the assembler was not named!")
    }


    // Generate meta map
    id          = input.id
    meta        = [id: id]

    // Process input files
    // Raw data
    pacbio      = input.pacbio.fasta.flatten()
    hic_cram    = input?.hic?.cram    ? input.hic.cram.flatten()    : []
    hic_enzymes = input?.hic?.enzymes ? input.hic.enzymes.flatten() : []

    // Assembly
    assembly    = input?.assembly?.fasta     ? input.assembly.fasta                          : []
    asm_meta    = input?.assembly?.assembler ? meta + [assembler: input.assembly.assembler]  : meta
}
