#!/bin/bash

# Exit on any error
set -e

# Step 1: Backup the old RSLC list
cp listRSLC.txt listRSLC_old.txt
echo "Backed up listRSLC.txt to listRSLC_old.txt"

# Step 2: Create a new updated list from the RSLC directory
#ls -1 RSLC > listRSLC_updated.txt
echo "Generated new listRSLC_updated.txt from RSLC directory"

# Step 3: Compare old and new list, create Updated_list.txt with new entries only
comm -13 <(sort listRSLC_old.txt) <(sort listRSLC_updated.txt) > Updated_list_new.txt
echo "Created Updated_list.txt with new RSLC entries"

# Step 4: Extract last 2 lines from dates_longs.txt and append to Updated_list.txt
tail -n 10 dates_longs.txt >> Updated_list_old.txt
echo "Appended last 2 lines from dates_longs.txt to Updated_list.txt"

echo "Done. Output is in Updated_list.txt"


