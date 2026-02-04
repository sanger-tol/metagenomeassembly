## Rename bins in a contig2bin file. Iterate over bins and sequentially number them
##
## Author: Jim Downie

BEGIN { OFS = "\t" }
{
    if($2 != prev) { count++ }
    print $1, prefix "_" count
    prev = $2
}
