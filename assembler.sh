#!/bin/bash

    for weight in 128 64 32 16 8 4 2 1
    do
        if (( temp >= weight ))
        then
            binary="${binary}1"
            temp=$((temp - weight))
        else
            binary="${binary}0"
        fi
    done

    echo "$binary"
}


# --------------------------------------------------
# Convert register number to 2-bit binary
# --------------------------------------------------

register_to_binary()
{
    local reg=$1

    if [ "$reg" -eq 0 ]
    then
        echo "00"
    elif [ "$reg" -eq 1 ]
    then
        echo "01"
    elif [ "$reg" -eq 2 ]
    then
        echo "10"
    else
        echo "11"
    fi
}


# ==================================================
# 1. Check number of arguments
# ==================================================

if [ "$#" -eq 0 ]
then
    echo "usage: no argument is provided"
    exit 1
else

    if [ "$#" -gt 1 ]
    then
        echo "usage: more than one arguments are provided"
        exit 1
    else

        # ==========================================
        # 2. Check input file
        # ==========================================

        if [ ! -f "$1" ]
        then
            echo "usage: input is not a file or it does not exist"
            exit 1
        else

            # ======================================
            # 3. Check file extension
            # ======================================

            if [[ "$1" != *.vsc ]]
            then
                echo "usage: input does not have the extension .vsc"
                exit 1
            else

                input_file="$1"
                output_file="${input_file%.vsc}.bin"

                # ==================================
                # 4. Check empty file
                # ==================================

                if [ ! -s "$input_file" ]
                then
                    echo "usage: the file is empty – no .bin file is produced"
                    exit 1
                else

                    # Remove an old output file.
                    # We only create it again after successful validation.
                    rm -f "$output_file"

                    # ==================================
                    # 5. Read line 1
                    # ==================================

                    line1=$(sed -n '1p' "$input_file")
                    line1="${line1%$'\r'}"

                    if [[ ! "$line1" =~ ^[0-9]+$ ]]
                    then
                        echo "usage: line 1 must be 0 or 2"
                        exit 1
                    else

                        if [ "$line1" -ne 0 ] && [ "$line1" -ne 2 ]
                        then
                            echo "usage: line 1 must be 0 or 2"
                            exit 1
                        else

                            # ==========================================
                            # CASE 1: QUIT PROGRAM
                            # ==========================================

                            if [ "$line1" -eq 0 ]
                            then

                                line2=$(sed -n '2p' "$input_file")
                                line2="${line2%$'\r'}"

                                line_count=$(wc -l < "$input_file")

                                # Must have exactly:
                                #
                                # 0
                                # QUIT,0,0
                                #

                                if [ "$line_count" -ne 2 ]
                                then
                                    echo "usage: invalid QUIT program"
                                    exit 1
                                else

                                    if [ "$line2" != "QUIT,0,0" ]
                                    then
                                        echo "usage: invalid QUIT program"
                                        exit 1
                                    else

                                        # --------------------------------
                                        # QUIT
                                        #
                                        # opcode = 001000
                                        # register = 00
                                        #
                                        # first byte:
                                        # 00100000 = 0x20
                                        #
                                        # second byte:
                                        # 00000000 = 0x00
                                        # --------------------------------

                                        dataArray=()

                                        dataArray[0]="00100000"
                                        dataArray[1]="00000000"

                                        printf '\x20' >> "$output_file"
                                        printf '\x00' >> "$output_file"

                                        echo "It is a QUIT program"
                                        echo "************"
                                        echo "The content of the .bin file"

                                        xxd -p -c 1 "$output_file"

                                        exit 0
                                    fi
                                fi


                            # ==========================================
                            # CASE 2: ADD/SUB PROGRAM
                            # ==========================================

                            else

                                line_count=$(wc -l < "$input_file")

                                # Need at least:
                                #
                                # line 1 = 2
                                # line 2 = data
                                # line 3 = data
                                #

                                if [ "$line_count" -lt 3 ]
                                then
                                    echo "usage: two data values are required"
                                    exit 1
                                else

                                    # --------------------------------
                                    # Read static data
                                    # --------------------------------

                                    data1=$(sed -n '2p' "$input_file")
                                    data2=$(sed -n '3p' "$input_file")

                                    data1="${data1%$'\r'}"
                                    data2="${data2%$'\r'}"


                                    # ==================================
                                    # Validate first data value
                                    # ==================================

                                    if [[ ! "$data1" =~ ^[0-9]+$ ]]
                                    then
                                        echo "usage: invalid data value"
                                        exit 1
                                    else

                                        if [ "$data1" -lt 0 ] || [ "$data1" -ge 128 ]
                                        then
                                            echo "usage: data value must be between 0 and 127"
                                            exit 1
                                        else


                                            # ==================================
                                            # Validate second data value
                                            # ==================================

                                            if [[ ! "$data2" =~ ^[0-9]+$ ]]
                                            then
                                                echo "usage: invalid data value"
                                                exit 1
                                            else

                                                if [ "$data2" -lt 0 ] || [ "$data2" -ge 128 ]
                                                then
                                                    echo "usage: data value must be between 0 and 127"
                                                    exit 1
                                                else

                                                    # ==================================
                                                    # Convert static data
                                                    # ==================================

                                                    dataArray=()

                                                    dataArray[0]=$(decimal_to_binary "$data1")
                                                    dataArray[1]=$(decimal_to_binary "$data2")


                                                    # ==================================
                                                    # Process instructions
                                                    # ==================================

                                                    instruction_count=0
                                                    quit_found=0

                                                    while IFS= read -r line
                                                    do

                                                        # Remove Windows CR if present
                                                        line="${line%$'\r'}"

                                                        # Skip first three lines
                                                        if [ "$instruction_count" -lt 3 ]
                                                        then
                                                            ((instruction_count++))
                                                            continue
                                                        fi

                                                        # ----------------------------------
                                                        # Maximum 100 instructions
                                                        # ----------------------------------

                                                        if [ "$instruction_count" -ge 103 ]
                                                        then
                                                            echo "usage: maximum of 100 instructions exceeded"
                                                            exit 1
                                                        else

                                                            ((instruction_count++))


                                                            # ----------------------------------
                                                            # Check instruction length
                                                            # ----------------------------------

                                                            if [ "${#line}" -gt 11 ]
                                                            then
                                                                echo "usage: instruction is longer than 11 characters"
                                                                exit 1
                                                            else


                                                                # ----------------------------------
                                                                # Split line using comma
                                                                # ----------------------------------

                                                                IFS=',' read -r ins reg mem extra <<< "$line"


                                                                # ----------------------------------
                                                                # Make sure there are exactly 3 fields
                                                                # ----------------------------------

                                                                if [ -n "$extra" ]
                                                                then
                                                                    echo "usage: invalid instruction format"
                                                                    exit 1
                                                                else


                                                                    # ==================================
                                                                    # Find opcode
                                                                    # ==================================

                                                                    if [ "$ins" = "LOAD" ]
                                                                    then
                                                                        opcode="000001"

                                                                    elif [ "$ins" = "STORE" ]
                                                                    then
                                                                        opcode="000010"

                                                                    elif [ "$ins" = "ADD" ]
                                                                    then
                                                                        opcode="000011"

                                                                    elif [ "$ins" = "SUB" ]
                                                                    then
                                                                        opcode="000100"

                                                                    elif [ "$ins" = "QUIT" ]
                                                                    then
                                                                        opcode="001000"

                                                                    elif [ "$ins" = "PRINT" ]
                                                                    then
                                                                        opcode="001001"

                                                                    else
                                                                        echo "usage: invalid instruction"
                                                                        exit 1
                                                                    fi


                                                                    # ==================================
                                                                    # Validate register
                                                                    # ==================================

                                                                    if [[ ! "$reg" =~ ^[0-3]$ ]]
                                                                    then
                                                                        echo "usage: invalid register"
                                                                        exit 1
                                                                    else

                                                                        regbin=$(register_to_binary "$reg")


                                                                        # ==================================
                                                                        # Validate memory
                                                                        # ==================================

                                                                        if [[ ! "$mem" =~ ^[0-9]+$ ]]
                                                                        then
                                                                            echo "usage: invalid memory value"
                                                                            exit 1
                                                                        else


                                                                            if [ "$mem" -lt 0 ] || [ "$mem" -gt 255 ]
                                                                            then
                                                                                echo "usage: memory value must be between 0 and 255"
                                                                                exit 1
                                                                            else


                                                                                # ==================================
                                                                                # Special rules for QUIT
                                                                                # ==================================

                                                                                if [ "$ins" = "QUIT" ]
                                                                                then

                                                                                    if [ "$line" != "QUIT,0,0" ]
                                                                                    then
                                                                                        echo "usage: QUIT must be QUIT,0,0"
                                                                                        exit 1
                                                                                    else
                                                                                        quit_found=1
                                                                                    fi

                                                                                else


                                                                                    # ==================================
                                                                                    # Special rules for PRINT
                                                                                    # ==================================

                                                                                    if [ "$ins" = "PRINT" ]
                                                                                    then

                                                                                        if [ "$mem" -ne 0 ]
                                                                                        then
                                                                                            echo "usage: PRINT memory address must be 0"
                                                                                            exit 1
                                                                                        fi

                                                                                    fi

                                                                                fi


                                                                                # ==================================
                                                                                # First byte
                                                                                #
                                                                                # 6-bit opcode
                                                                                # +
                                                                                # 2-bit register
                                                                                # ==================================

                                                                                byte1="${opcode}${regbin}"


                                                                                # ==================================
                                                                                # Second byte
                                                                                #
                                                                                # 8-bit memory address
                                                                                # ==================================

                                                                                byte2=$(decimal_to_binary "$mem")


                                                                                # ==================================
                                                                                # Store in array
                                                                                # ==================================

                                                                                dataArray+=("$byte1")
                                                                                dataArray+=("$byte2")


                                                                                # ==================================
                                                                                # Stop after QUIT
                                                                                # ==================================

                                                                                if [ "$quit_found" -eq 1 ]
                                                                                then
                                                                                    break
                                                                                fi

                                                                            fi
                                                                        fi
                                                                    fi
                                                                fi
                                                            fi
                                                        fi

                                                    done < "$input_file"


                                                    # ==================================
                                                    # QUIT must exist
                                                    # ==================================

                                                    if [ "$quit_found" -eq 0 ]
                                                    then
                                                        echo "usage: program must contain QUIT,0,0"
                                                        exit 1
                                                    else


                                                        # ==================================
                                                        # Write binary file
                                                        # ==================================

                                                        for binary in "${dataArray[@]}"
                                                        do

                                                            # Convert 8-bit binary to decimal
                                                            decimal=0

                                                            for ((i=0; i<8; i++))
                                                            do

                                                                bit="${binary:$i:1}"

                                                                if [ "$bit" -eq 1 ]
                                                                then
                                                                    power=$((7-i))
                                                                    decimal=$((decimal + 2**power))
                                                                fi

                                                            done

                                                            printf "\\x$(printf '%02x' "$decimal")" >> "$output_file"

                                                        done


                                                        # ==================================
                                                        # Display result
                                                        # ==================================

                                                        echo "It is an ADD/SUB program"
                                                        echo "************"
                                                        echo "The content of the .bin file"

                                                        xxd -p -c1 "$output_file"

                                                        exit 0

                                                    fi

                                                fi
                                            fi
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi
fi
