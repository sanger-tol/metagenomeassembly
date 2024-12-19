## Summarise information about tRNA and rRNA contents
## given by Prokka for a genome bin
##
## Author: Jim Downie, 2024

BEGIN {
    FS = "\t"
    OFS = FS
    print "bin", "total_trnas", "unique_trnas", "rrna_23s", "rrna_16s", "rrna_5s"
}
BEGINFILE {
    bin = FILENAME
    sub(".*/", "", bin)
    sub(/\.[^\.]+$/, "", bin)
    total_trnas = 0
    unique_trnas = 0
    pos_23s = 0
    pos_16s = 0
    pos_5s = 0
}
$2 == "tRNA" {
    total_trnas++
    trna_arr[$7] = 1
}
$2 == "rRNA" {
    if($7 == "23S ribosomal RNA") { pos_23s = 1 }
    if($7 == "16S ribosomal RNA") { pos_16s = 1 }
    if($7 == "5S ribosomal RNA") { pos_5s = 1 }
}
ENDFILE {
    for (i in trna_arr) { unique_trnas++ }
    delete trna_arr
    print bin, total_trnas, unique_trnas, pos_23s, pos_16s, pos_5s
}
