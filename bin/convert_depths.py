#!/usr/bin/env python3
#
#    Copyright (C) 2026 Genome Research Ltd.
#
#    Author: Jim Downie <jd42@sanger.ac.uk>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

import click
import polars as pl


@click.command()
@click.version_option(version="1.0.0")
@click.argument("depths_file", type=click.Path(exists=True))
@click.option(
    "--format",
    "-f",
    type=click.Choice(["maxbin2", "vamb"]),
    required=True,
    help="Output format.",
)
@click.option(
    "--prefix",
    "-p",
    type=str,
    default="",
    help="Prefix for output file(s).",
)
def convert_depths(depths_file: str, format: str, prefix: str):
    """
    Convert MetaBat2 depths file to MaxBin2 or VAMB format.

    DEPTHS_FILE: Input depths file in MetaBat2 format.
    """
    # Read the depths file
    df = pl.read_csv(depths_file, separator="\t")

    # MetaBat2 format: contigName, length, totalAvgDepth, sample1.bam, sample1-var, sample2.bam, sample2-var, ...
    sample_cols = list(range(3, len(df.columns), 2))

    sample_names = [df.columns[i].replace(".bam", "") for i in sample_cols]

    if format == "maxbin2":
        write_maxbin2(df, sample_cols, sample_names, prefix)
    else:
        write_vamb(df, sample_cols, sample_names, prefix)


def write_maxbin2(df: pl.DataFrame, sample_cols: list, sample_names: list, prefix: str):
    """Write MaxBin2 format: separate file per sample with contig and depth."""
    for col_idx, sample_name in zip(sample_cols, sample_names):
        output_file = f"{prefix}.{sample_name}.maxbin2.depth.tsv"
        output_df = df.select(
            [
                pl.col(df.columns[0]).alias("contig"),
                pl.col(df.columns[col_idx]).alias("depth"),
            ]
        )
        output_df.write_csv(output_file, separator="\t", include_header=False)
        click.echo(f"Written {output_file}")


def write_vamb(df: pl.DataFrame, sample_cols: list, sample_names: list, prefix: str):
    """Write VAMB format: single file with contig names and all depth columns."""
    output_file = f"{prefix}.vamb.depths.tsv"

    output_df = df.select(
        [pl.col(df.columns[0]).alias("contigname")]
        + [
            pl.col(df.columns[i]).alias(name)
            for i, name in zip(sample_cols, sample_names)
        ]
    )

    output_df.write_csv(output_file, separator="\t")
    click.echo(f"  Written {output_file}")


if __name__ == "__main__":
    convert_depths()
