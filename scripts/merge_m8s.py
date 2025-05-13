#!/usr/bin/env python3

import os
import re
import glob
import argparse
import multiprocessing as mp
import tempfile
import subprocess
import sys
from tqdm import tqdm


def parse_args():
    parser = argparse.ArgumentParser(description="Process MMseqs2 output files")
    parser.add_argument(
        "--dir", "-d", required=True, help="Directory containing alignment files"
    )
    parser.add_argument(
        "--target", "-t", required=True, help="Target name (e.g., d6300)"
    )
    parser.add_argument("--output", "-o", help="Output file (default: {target}.tsv)")
    parser.add_argument(
        "--processes",
        "-p",
        type=int,
        default=mp.cpu_count(),
        help=f"Number of processes (default: {mp.cpu_count()})",
    )
    parser.add_argument(
        "--chunk-size",
        "-c",
        type=int,
        default=100000,
        help="Lines per chunk (default: 100000)",
    )
    parser.add_argument(
        "--quiet", "-q", action="store_true", help="Disable progress bars"
    )
    args = parser.parse_args()

    if not args.output:
        args.output = f"{args.target}.tsv"

    return args


def extract_query_from_filename(filepath, target):
    """Extract query name from filename pattern {target}.{query}.{ext}"""
    filename = os.path.basename(filepath)
    pattern = f"^{re.escape(target)}\\.(.+?)\\.(m8|tsv)$"
    match = re.match(pattern, filename)
    if match:
        return match.group(1)
    else:
        print(
            f"Warning: Could not extract query name from {filename}, using filename",
            file=sys.stderr,
        )
        return filename


def process_file(args):
    """Process a single file to add query column and swap fields"""
    filepath, target, temp_dir, chunk_size, disable_tqdm = args
    query_origin = extract_query_from_filename(filepath, target)

    # Count lines in file for progress bar if tqdm is enabled
    if not disable_tqdm:
        try:
            with open(filepath, "r") as f:
                total_lines = sum(1 for _ in f)
        except:
            total_lines = None
    else:
        total_lines = None

    output_file = os.path.join(temp_dir, os.path.basename(filepath) + ".processed")

    try:
        with open(filepath, "r") as f, open(output_file, "w") as out:
            # Use tqdm to show progress
            for line in tqdm(
                f,
                total=total_lines,
                desc=f"Processing {os.path.basename(filepath)}",
                unit=" lines",
                disable=disable_tqdm,
            ):
                if not line.strip():
                    continue

                fields = line.strip().split("\t")
                if len(fields) < 12:
                    continue

                # Swap columns 1 and 2, and add query_origin
                # Original: column1 = organism, column2 = node ID
                # New: subject = node ID, query = organism, query_origin = from filename
                organism = fields[0]
                node_id = fields[1]
                rest_of_fields = fields[2:]

                new_row = [node_id, organism, query_origin] + rest_of_fields
                out.write("\t".join(new_row) + "\n")

        return output_file
    except Exception as e:
        print(f"Error processing file {filepath}: {e}", file=sys.stderr)
        raise


def merge_files(files, output_file, header, disable_tqdm=False):
    """Merge files without sorting"""
    print(f"Merging {len(files)} files", file=sys.stderr)

    # Create an intermediate merged file without header
    merged_file = output_file + ".merged"
    with open(merged_file, "w") as out_f:
        for f in tqdm(files, desc="Merging files", disable=disable_tqdm):
            with open(f, "r") as in_f:
                for line in in_f:
                    out_f.write(line)

    # Sort the merged file using the Unix sort command (efficient for large files)
    # -k1,1n sorts numerically on the first field
    print("Sorting merged file by subject ID...", file=sys.stderr)
    sort_cmd = ["sort", "-k1,1n", merged_file, "-o", output_file + ".sorted"]
    subprocess.run(sort_cmd, check=True)

    # Add header to the sorted file
    with open(output_file, "w") as final_f:
        final_f.write(header + "\n")
        with open(output_file + ".sorted", "r") as sorted_f:
            for line in sorted_f:
                final_f.write(line)

    # Clean up temporary files
    os.remove(merged_file)
    os.remove(output_file + ".sorted")


def main():
    args = parse_args()

    # Find all input files - handle m8 and tsv separately then combine
    # This fixes the issue with brace expansion in glob
    m8_pattern = os.path.join(args.dir, f"{args.target}.*.m8")
    tsv_pattern = os.path.join(args.dir, f"{args.target}.*.tsv")

    m8_files = glob.glob(m8_pattern)
    tsv_files = glob.glob(tsv_pattern)
    input_files = m8_files + tsv_files

    if not input_files:
        print(f"Error: No alignment files found. Tried patterns:", file=sys.stderr)
        print(f"  - {m8_pattern}", file=sys.stderr)
        print(f"  - {tsv_pattern}", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(input_files)} alignment files to process", file=sys.stderr)

    # Define the header (now with 13 columns)
    header = "subject\tquery\tquery_origin\t%identity\talignment_length\tmismatches\tgap_openings\tquery_start\tquery_end\tsubject_start\tsubject_end\te_value\tbit_score"

    # Create temp directory
    with tempfile.TemporaryDirectory() as temp_dir:
        # Prepare arguments for parallel processing
        process_args = [
            (f, args.target, temp_dir, args.chunk_size, args.quiet) for f in input_files
        ]

        # Process files in parallel with progress bar for overall progress
        processed_files = []
        with mp.Pool(processes=args.processes) as pool:
            processed_files = list(
                tqdm(
                    pool.imap(process_file, process_args),
                    total=len(process_args),
                    desc="Overall progress",
                    unit=" files",
                    disable=args.quiet,
                )
            )

        # Merge all processed files and sort the result
        merge_files(processed_files, args.output, header, args.quiet)

        print(
            f"Successfully created merged and sorted output file: {args.output}",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
