#!/bin/bash

# Define input directory
input_directory="/home/tamas/dataset/test3/rawdata"

# File size list
file_size_list="file_size_list.txt"

# AVG Function
calculate_average() {
    local sum=0
    for val in "${@:2}"; do
        sum=$(echo "$sum + $val" | bc)
    done
    echo "scale=2; $sum / $1" | bc
}

# Main loop -- directory reading
for input_file in "$input_directory"/*; do
    echo "Processing file: $input_file"

    # Get the filename without extension
    filename=$(basename -- "$input_file")
    filename_no_extension="${filename%.*}"

    # Create -total.txt file for each input file
    echo "--------------------" > "$filename_no_extension-total.txt"
    echo $(date '+%Y-%m-%d %H:%M:%S') | tee -a "$filename_no_extension-total.txt"
    echo "---------------------------------------------------------------------" | tee -a "$filename_no_extension-total.txt"
    printf "%-12s | %-13s | %-9s | %-20s\n" "Compr. Level" "Comp. Time (s)" "Comp. Rate" "Comp. Speed (bytes/s)" | tee -a "$filename_no_extension-total.txt"
    echo "---------------------------------------------------------------------" | tee -a "$filename_no_extension-total.txt"

    total_avg_time=0
    total_avg_ratio=0
    total_avg_speed=0

    # Loop for each round
    for ((i=1; i<=15; i++)); do
        echo "Round $i" | tee -a "$filename_no_extension-total.txt"
        total_time=0
        total_ratio=0
        total_speed=0

        # Loop for each compression level
        for level in {1..9}; do
            echo -n "$level            | " | tee -a "$filename_no_extension-total.txt"

            # Gzip
            start=$(date +%s.%N)
            gzip -"$level" -c "$input_file" > "${filename_no_extension}_$level.gz"
            end=$(date +%s.%N)

            # Time
            execution_time=$(echo "$end - $start" | bc)

            # Ratio
            uncompressed_size=$(du -b "$input_file" | cut -f1)
            compressed_size=$(du -b "${filename_no_extension}_$level.gz" | cut -f1)
            compression_ratio=$(echo "scale=2; $uncompressed_size / $compressed_size" | bc)

            # Speed
            compression_speed=$(echo "scale=2; $uncompressed_size / $execution_time" | bc)

            # Print compression details
            printf "%.9f   | %.2f      | %.2f\n" "$execution_time" "$compression_ratio" "$compression_speed" | tee -a "$filename_no_extension-total.txt"

            # Accumulate averages
            total_time=$(echo "$total_time + $execution_time" | bc)
            total_ratio=$(echo "$total_ratio + $compression_ratio" | bc)
            total_speed=$(echo "$total_speed + $compression_speed" | bc)
        done

        # AVG / level
        avg_time=$(calculate_average 9 $total_time)
        avg_ratio=$(calculate_average 9 $total_ratio)
        avg_speed=$(calculate_average 9 $total_speed)
        echo "----------------------------------------------------------------------" | tee -a "$filename_no_extension-total.txt"
        printf "AVG:         | %.9f       | %.2f         | %.2f\n" "$avg_time" "$avg_ratio" "$avg_speed" | tee -a "$filename_no_extension-total.txt"
        echo "----------------------------------------------------------------------" | tee -a "$filename_no_extension-total.txt"

        # Accumulate TOTAL averages
        total_avg_time=$(echo "$total_avg_time + $avg_time" | bc)
        total_avg_ratio=$(echo "$total_avg_ratio + $avg_ratio" | bc)
        total_avg_speed=$(echo "$total_avg_speed + $avg_speed" | bc)
    done

    # Calculate overall total average
    num_rounds=15
    total_avg_time=$(calculate_average $num_rounds $total_avg_time)
    total_avg_ratio=$(calculate_average $num_rounds $total_avg_ratio)
    total_avg_speed=$(calculate_average $num_rounds $total_avg_speed)

    echo "----------------------------------------------------------------------" | tee -a "$filename_no_extension-total.txt"
    printf "Total AVG:   | %.9f | %.2f | %.2f\n" "$total_avg_time" "$total_avg_ratio" "$total_avg_speed" | tee -a "$filename_no_extension-total.txt"
    echo "----------------------------------------------------------------------" | tee -a "$filename_no_extension-total.txt"
    echo "Compression test done!"
    #cat *.txt > allresults-gzip.txt
    #echo "Writing all results to allresults-gzip.txt file."
    echo ""

    # Write file size to file size list
    compressed_sizes=""
    for level in {1..9}; do
        compressed_size=$(du -b "${filename_no_extension}_$level.gz" | cut -f1)
        compressed_sizes+=" $compressed_size"
    done
    echo "$filename_no_extension $compressed_sizes" >> "$file_size_list"

    # Uncompress .gz file write to .txt file
    start=$(date +%s.%N)
    gzip -d -k "${filename_no_extension}_1.gz"
    end=$(date +%s.%N)

    # Uncompression Time
    decomp_time=$(echo "$end - $start" | bc)

    # Uncompression Ratio
    compressed_size=$(du -b "${filename_no_extension}_1.gz" | cut -f1)
    raw_size=$(du -b "$input_file" | cut -f1)
    decompression_ratio=$(echo "scale=2; $compressed_size / $raw_size" | bc)

    # Uncompression Speed
    uncompression_speed=$(echo "scale=2; $compressed_size / $decomp_time" | bc)

    # Print compression details
    echo "Start extracting file..."
    echo " "
    echo "---------------------------------------------------------------------------"
    echo "Uncompression time  |  Uncompression Ratio  | Uncompression Speed (bytes/s)" | tee -a "$filename_no_extension-uncompressed.txt"
    echo "---------------------------------------------------------------------------"
    printf "%.9f            | %.2f                  | %.2f\n" "$decomp_time" "$decompression_ratio" "$uncompression_speed" | tee -a "$filename_no_extension-uncompressed.txt"
    echo "---------------------------------------------------------------------------"
    echo " "
    echo "Uncompressing $filename_no_extension.gz...done."
    echo "Writing uncompression details to $filename_no_extension-uncompressed.txt"
    echo " "
done
echo "Writing file to totalresult-gzip.txt...done"
cat *.txt > totalresult-gzip.txt
