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

"""
Convert cmsearch output to GFF format.
Parses model lengths from Rfam CM file and filters by e-value threshold.

Translated from https://github.com/ARU-life-sciences/hmm_to_gff/blob/main/src/main.rs
using GitHub Copilot.
"""

import gzip
from pathlib import Path

import click


def parse_cm_file(cm_file: str) -> dict[str, int]:
    """
    Parse Rfam CM file and extract model names and their lengths.

    Returns:
        Dictionary mapping model accession/name to CLEN (model length)
    """
    models = {}
    current_name = None
    current_acc = None

    if Path(cm_file).stem == ".gz":
        opener = gzip.open
    else:
        opener = open

    with opener(cm_file, "rt") as f:
        for line in f:
            line = line.strip()

            # Extract model name (e.g., "5S_rRNA")
            if line.startswith("NAME"):
                name = line.split(None, 1)[1] if len(line.split()) > 1 else None
                current_name = name.replace(" ", "") if name else None

            # Extract model accession (e.g., "RF00001")
            elif line.startswith("ACC"):
                current_acc = line.split(None, 1)[1] if len(line.split()) > 1 else None

            # Extract model length (CLEN = calibrated length)
            elif line.startswith("CLEN"):
                try:
                    clen = int(line.split()[1])
                    # Store with both name and accession if available
                    if current_name:
                        models[current_name] = clen
                    if current_acc:
                        models[current_acc] = clen
                except (ValueError, IndexError):
                    continue

    return models


def extract_rrna_type(model_name: str) -> str:
    """
    Extract rRNA type from Rfam model name.

    Examples: "5S_rRNA" -> "5S ribosomal RNA", "SSU_rRNA_bacteria" -> "SSU ribosomal RNA"

    Args:
        model_name: Model name from Rfam CM file (with spaces stripped)

    Returns:
        rRNA type string (5S, SSU, LSU, etc.)
    """
    if "5S" in model_name:
        return "5S ribosomal RNA"
    elif "SSU" in model_name:
        return "16S ribosomal RNA"
    elif "LSU" in model_name:
        return "23S ribosomal RNA"
    else:
        # Fallback: return the model name itself
        return f"{model_name} ribosomal RNA"


def process_cmsearch(
    cmsearch_records: list[dict],
    model_lengths: dict[str, int],
    e_value_threshold: float,
    coverage_threshold: float,
    output,
    filter_partial: bool = False,
) -> None:
    """
    Process cmsearch records and output GFF format.

    Args:
        cmsearch_records: List of parsed cmsearch records
        model_lengths: Dictionary mapping model names to their CLEN values
        e_value_threshold: E-value significance threshold
        coverage_threshold: Coverage threshold for partial marking
        output: Output file object
        filter_partial: If True, skip records with coverage below threshold
    """
    gff_records = []
    record_id = 1

    for record in cmsearch_records:
        # Skip records that don't meet the significance threshold
        if record["e_value"] > e_value_threshold:
            continue

        seqid = record["target_name"]
        source = "cmsearch"
        feature_type = "rRNA"

        start = record["seq_from"]
        end = record["seq_to"]

        # Account for reversed coordinates
        updated_start = min(start, end)
        updated_end = max(start, end)

        score = record["score"]
        strand = record["strand"]

        # Length analysis for coverage
        aligned_length = float(updated_end - updated_start)
        model_name = record["query_name"]

        if model_name not in model_lengths or model_lengths[model_name] is None:
            click.echo(f"Warning: Model '{model_name}' not found in CM file", err=True)
            continue

        gene_length = float(model_lengths[model_name])

        # Coverage tag
        coverage_ratio = aligned_length / gene_length
        if coverage_ratio < coverage_threshold:
            coverage = f"partial:{coverage_ratio * 100:.2f}"
            # Skip partial hits if filtering is enabled
            if filter_partial:
                continue
        else:
            coverage = "full"

        # Extract rRNA type from model name
        product = extract_rrna_type(model_name)

        # Build attributes
        attributes = (
            f"ID={seqid}_{record_id};"
            f"Name={model_name};"
            f"product={product};"
            f"coverage={coverage};"
            f"e_value={record['e_value']:.2e}"
        )

        gff_records.append(
            (
                seqid,
                source,
                feature_type,
                updated_start,
                updated_end,
                score,
                strand,
                ".",
                attributes,
            )
        )

        record_id += 1

    # Sort by sequence name, then by start position
    gff_records.sort(key=lambda x: (x[0], x[3]))

    # Output GFF
    click.echo("##gff-version 3", file=output)
    for record in gff_records:
        gff_line = "\t".join(str(field) for field in record)
        click.echo(gff_line, file=output)


def parse_cmsearch_output(file_path: str) -> list[dict]:
    """
    Parse cmsearch output table format.

    Standard cmsearch output format (with --tblout):
    target name        accession  query name          accession  mdl mdl from   mdl to seq from   seq to strand trunc type   gc  bias  score   E-value inc

    Returns:
        List of record dictionaries
    """
    records = []

    if Path(file_path).suffix == ".gz":
        opener = gzip.open
    else:
        opener = open

    with opener(file_path, "rt") as f:
        for line in f:
            line = line.strip()
            # Skip comments and empty lines
            if not line or line.startswith("#"):
                continue

            parts = line.split()
            if len(parts) < 15:
                continue

            try:
                record = {
                    "target_name": parts[0],
                    "target_accession": parts[1],
                    "query_name": parts[2],
                    "query_accession": parts[3],
                    "mdl_from": int(parts[5]),
                    "mdl_to": int(parts[6]),
                    "seq_from": int(parts[7]),
                    "seq_to": int(parts[8]),
                    "strand": parts[9],
                    "score": float(parts[14]),
                    "e_value": float(parts[15]),
                }
                records.append(record)
            except (ValueError, IndexError):
                continue

    return records


@click.command()
@click.version_option(version="1.0.0", message="%(version)s")
@click.argument("cmsearch_file", type=click.Path(exists=True))
@click.argument("cm_file", type=click.Path(exists=True))
@click.option(
    "--e-value-threshold",
    type=float,
    default=1e-05,
    help="E-value significance threshold for filtering records",
    show_default=True,
)
@click.option(
    "--coverage-threshold",
    type=float,
    default=0.8,
    help="Coverage threshold for marking records as partial (0-1)",
    show_default=True,
)
@click.option(
    "--output",
    "-o",
    type=click.File("w"),
    default="-",
    help="Output GFF file (default: stdout)",
)
@click.option(
    "--filter-partial",
    is_flag=True,
    help="Filter out partial hits (coverage below threshold)",
)
def main(
    cmsearch_file: str,
    cm_file: str,
    e_value_threshold: float,
    coverage_threshold: float,
    output,
    filter_partial: bool,
):
    """
    Convert cmsearch output to GFF3 format.

    Parses model lengths from the CM file and uses them to assess coverage.

    \b
    Arguments:
        CMSEARCH_FILE  Path to cmsearch output file (--tblout format)
        CM_FILE        Path to Rfam CM file (covariance model file)
    """
    try:
        click.echo(f"Parsing CM file: {cm_file}", err=True)
        model_lengths = parse_cm_file(cm_file)
        click.echo(f"Found {len(model_lengths)} models", err=True)

        click.echo(f"Parsing cmsearch output: {cmsearch_file}", err=True)
        records = parse_cmsearch_output(cmsearch_file)
        click.echo(f"Found {len(records)} records", err=True)

        process_cmsearch(
            records,
            model_lengths,
            e_value_threshold,
            coverage_threshold,
            output,
            filter_partial,
        )
    except FileNotFoundError as e:
        raise click.FileError(str(e), "File not found")
    except Exception as e:
        raise click.ClickException(f"Error processing files: {e}")


if __name__ == "__main__":
    main()
