#!/usr/bin/env python3

import sys
import numpy as np

def read_gzip():
    """Ultra-fast version using NumPy for median calculation."""
    numbers = []
    
    # Use a larger buffer for batch processing
    batch_size = 10000
    current_batch = []
    
    # Pre-allocate write function
    write = sys.stdout.write
    
    for line_num, line in enumerate(sys.stdin, 1):
        # Strip only newline characters for speed
        line = line.rstrip('\n\r')
        
        # Fast string comparison
        if line[:4] == "Read":  # Even faster than startswith for short strings
            if numbers:
                # Convert to numpy array for fast median
                arr = np.array(numbers, dtype=np.int32)
                med = np.median(arr)
                write(f"{med}\n")
                numbers.clear()
            continue
        
        # Skip empty lines
        if not line:
            continue
            
        try:
            # Convert and add to current batch
            current_batch.append(int(line))
            
            # Process in batches for better memory usage
            if len(current_batch) >= batch_size:
                numbers.extend(current_batch)
                current_batch.clear()
                
        except ValueError:
            sys.stderr.write(f"Error on line {line_num}: non-numeric value '{line}'\n")
            sys.exit(1)
    
    # Add remaining batch
    if current_batch:
        numbers.extend(current_batch)
    
    # Final median calculation
    if numbers:
        arr = np.array(numbers, dtype=np.int32)
        med = np.median(arr)
        write(f"{med}\n")

if __name__ == '__main__':
    try:
        read_gzip()
    except KeyboardInterrupt:
        sys.exit(0)
    except BrokenPipeError:
        # Handle broken pipe gracefully
        sys.exit(0)