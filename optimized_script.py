#!/usr/bin/env python3

import sys
import statistics

def read_gzip():
    """Accumulate numbers and on regex match compute median and add to results list."""
    numbers = []
    
    # Pre-allocate write function for faster output
    write = sys.stdout.write
    
    for line in sys.stdin:
        # Use rstrip() instead of strip() - only removes trailing whitespace
        line = line.rstrip('\n\r')
        
        # Use startswith() instead of regex - much faster
        if line.startswith("Read"):
            if numbers:
                med = statistics.median(numbers)
                write(f"{med}\n")
                numbers.clear()  # clear() is faster than reassigning
            continue

        # Skip empty lines quickly
        if not line:
            continue
            
        try:
            # Direct int conversion without intermediate variable
            numbers.append(int(line))
        except ValueError:
            sys.stderr.write(f"Error: non-numeric line: {line}\n")
            sys.exit(1)

    # Final median calculation
    if numbers:
        med = statistics.median(numbers)
        write(f"{med}\n")

if __name__ == '__main__':
    read_gzip()