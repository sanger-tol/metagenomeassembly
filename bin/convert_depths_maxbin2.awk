## Convert a depths file in MetaBat2 format
## to a set of files appropriate for MaxBin2.
##
## Author: Jim Downie

BEGIN {
    FS = OFS = "\t"
}
NR == 1 {
    for(i=4; i<=NF; i+=2) {
        sub("\.bam", "", $i)
        file[i] = $i
    }
}
NR > 1 {
    for(i=4; i<=NF; i+=2) {
        print $1, $(i) > file[i] ".maxbin2.depth.tsv"
    }
}
