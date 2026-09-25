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

import logging
import sys
from pathlib import Path

import click
import pyfastx

logger = logging.getLogger(__name__)


def get_extension(file: Path) -> str:
    if file.suffix == ".gz":
        return "".join(file.suffixes[-2:])
    return file.suffix


def get_basename(file: Path) -> str:
    if file.suffix == ".gz":
        return file.name.rsplit(".", 2)[0]
    else:
        return file.name.rsplit(".", 1)[0]


@click.command()
@click.version_option(version="1.0.0")
@click.argument("bindir", type=click.Path(exists=True), required=True)
@click.option("--prefix", type=str, required=True)
@click.option("--rename/--no-rename", default=False)
def contig2bin(bindir, prefix, rename):
    binfiles = list(
        p
        for p in Path(bindir).glob("*")
        if get_extension(p)
        in {".fa", ".fna", ".fasta", ".fa.gz", ".fna.gz", ".fasta.gz"}
    )
    logger.info(f"Found {len(binfiles)} FASTA files")

    if not binfiles:
        raise click.ClickException(f"No FASTA files found in '{bindir}'")

    with open(f"{prefix}.contig2bin", "w") as fout:
        for idx, file in enumerate(binfiles, start=1):
            logger.info(f"Processing file {idx}/{len(binfiles)}: {file}")
            out_bin = get_basename(file)
            if rename:
                out_bin = f"{prefix}_{idx}"
                logger.info(f"  Renaming bin to: {out_bin}")
            f = pyfastx.Fastx(str(file))

            for name, _seq in f:
                fout.write(f"{name}\t{out_bin}\n")

    logger.info("Completed successfully")


if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO, format="%(levelname)s: %(message)s", stream=sys.stdout
    )

    contig2bin()
