## Convert a depths file in MetaBat2 format
## to a set of files appropriate for VAMB.
##
## Author: Jim Downie

BEGIN {
    FS = OFS = "\t"
}
NR == 1 {
    $1 = "contigname"
    header = $1
    for(i=4; i<=NF; i+=2) {
        sub("\.bam", "", $i)
        header = header OFS $i
    }
    print header
}
NR > 1 {
    line = $1
    for(i=4; i<=NF; i+=2) {
        line = line OFS $(i)
    }
    print line
}
