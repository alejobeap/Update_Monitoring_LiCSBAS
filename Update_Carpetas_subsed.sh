#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <folder_name> NumberID(optional)"
  exit 1
fi

NOMBRE=$1
NUMERO=$2

# If NUMERO is not passed as an argument, fetch it with Python
if [ -z "$NUMERO" ]; then
  NUMERO=$(python3 VER_Nombre_volcan_V2.py "$NOMBRE" | tr -d '[]')
  if [ $? -ne 0 ] || [ -z "$NUMERO" ]; then
    echo "Error running VER_Nombre_volcan_V2.py or empty value"
    exit 1
  fi
fi

echo "Number obtained: $NUMERO"

# Replace spaces, dots, and dashes with underscores
NOMBRE_CLEAN=$(echo "$NOMBRE" | sed -E 's/[ .-]+/_/g')

# Create the directory
mkdir -p "$NOMBRE_CLEAN"
echo "Directory created: $NOMBRE_CLEAN"

cd "$NOMBRE_CLEAN" || { echo "Could not enter folder $NOMBRE"; exit 1; }

RUTA_BASE="/gws/nopw/j04/nceo_geohazards_vol1/projects/LiCS/proc/current/subsets/volc/$NUMERO"

CARPETAS=( $(ls -d "$RUTA_BASE"/*/ 2>/dev/null | xargs -n 1 basename) )

if [ ${#CARPETAS[@]} -eq 0 ]; then
  echo "No folders found inside $RUTA_BASE"
  exit 1
fi

TOTAL_PASOS=$((${#CARPETAS[@]} * 3))
PASO_ACTUAL=0

echo "Checking for TS* folders..."

# Global check: if no TS* folder exists anywhere, exit early
if ! compgen -G "$RUTA_BASE"/*/TS* > /dev/null; then
  echo "There are no TS folders; no update will be performed."
  exit 0
fi

echo "TS folders found — starting update process."

for CARPETA in "${CARPETAS[@]}"; do
  if compgen -G "$RUTA_BASE/$CARPETA/TS*" > /dev/null; then
    rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/TS"* "$CARPETA/" 2>&1 | tee -a ../debug.log
    rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/IFSforLiCSBAS"*.txt "$CARPETA/" 2>&1 | tee -a ../debug.log
    rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/listarslc.txt"* "$CARPETA/" 2>&1 | tee -a ../debug.log
  fi

  mkdir -p "$CARPETA/geo" "$CARPETA/RSLC" "$CARPETA/SLC" "$CARPETA/GEOC/geo"

  # Check for geo.30m or geo folder
  if [ -d "$RUTA_BASE/$CARPETA/geo.30m" ]; then
    GEO_FOLDER="geo.30m"
  elif [ -d "$RUTA_BASE/$CARPETA/geo" ]; then
    GEO_FOLDER="geo"
  else
    echo "No geo.30m or geo folder found in $RUTA_BASE/$CARPETA"
    continue
  fi

  ((PASO_ACTUAL++))
  PORCENTAJE=$(( PASO_ACTUAL * 100 / TOTAL_PASOS ))
  echo "[$PORCENTAJE%] Copying $GEO_FOLDER to $CARPETA/geo..."
  rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/$GEO_FOLDER/" "$CARPETA/geo/" 2>&1 | tee -a ../debug.log

  ((PASO_ACTUAL++))
  PORCENTAJE=$(( PASO_ACTUAL * 100 / TOTAL_PASOS ))
  echo "[$PORCENTAJE%] Copying RSLC to $CARPETA..."
  rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/RSLC/" "$CARPETA/RSLC/" 2>&1 | tee -a ../debug.log

  ((PASO_ACTUAL++))
  PORCENTAJE=$(( PASO_ACTUAL * 100 / TOTAL_PASOS ))
  echo "[$PORCENTAJE%] Copying SLC to $CARPETA..."
  rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/SLC/" "$CARPETA/SLC/" 2>&1 | tee -a ../debug.log

  rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/local_config.py" "$CARPETA/SLC/"

  # GEOC.meta.30m
  if [ -d "$RUTA_BASE/$CARPETA/GEOC.meta.30m" ]; then
    echo "Copying GEOC.meta.30m..."
    rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/GEOC.meta.30m/" "$CARPETA/GEOC/geo/" 2>&1 | tee -a ../debug.log
    rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/GEOC.meta.30m/" "$CARPETA/GEOC/" 2>&1 | tee -a ../debug.log
  fi

  # GEOC.MLI.30m
  if [ -d "$RUTA_BASE/$CARPETA/GEOC.MLI.30m" ]; then
    echo "Copying GEOC.MLI.30m..."
    find "$RUTA_BASE/$CARPETA/GEOC.MLI.30m" -type f | while read -r archivo; do
      rsync -a --ignore-existing "$archivo" "$CARPETA/GEOC/geo/" 2>&1 | tee -a ../debug.log
      rsync -a --ignore-existing "$archivo" "$CARPETA/GEOC/" 2>&1 | tee -a ../debug.log
    done
  fi

  # Search for corners_clip.*
  file=$(ls "$RUTA_BASE/$CARPETA"/corners_clip.* 2>/dev/null | head -n 1)
  echo "$file"
  if [[ -n "$file" ]]; then
    basename="${file##*.}"
    [ -f "$CARPETA/sourceframe.txt" ] && rm "$CARPETA/sourceframe.txt"
    echo "$basename" > "$CARPETA/sourceframe.txt"

    geo_file=$(ls "$CARPETA/GEOC/"*.geo.mli.tif 2>/dev/null | head -n 1)
    if [ -n "$geo_file" ]; then
      mv "$geo_file" "$CARPETA/GEOC/$basename.geo.mli.tif"
    fi
  else
    echo "No corners_clip.* file found."
  fi

  frameID="$basename"

  # Take everything before the first letter
  digits="${frameID%%[A-Za-z]*}"

  # Remove leading zeros by forcing numeric interpretation
  trackID=$((10#$digits))

  echo "trackID=$trackID"

  LiCSARweb="/gws/nopw/j04/nceo_geohazards_vol1/public/LiCSAR_products"
  echo "$LiCSARweb/$trackID/$frameID/metadata/baselines"
  if [ -e "$LiCSARweb/$trackID/$frameID/metadata/baselines" ]; then
    rsync -a --ignore-existing \
      "$LiCSARweb/$trackID/$frameID/metadata/baselines" \
      "$CARPETA/GEOC/" 2>&1 | tee -a ../debug.log
  fi

  # Rename .png if exists
  png_file=$(ls "$CARPETA/GEOC/"*.geo.mli.png 2>/dev/null | head -n 1)
  if [ -n "$png_file" ]; then
    mv "$png_file" "$CARPETA/GEOC/$basename.geo.mli.png"
  fi

  echo "############# GACOS link ##############"
  epochdir="$LiCSARweb/$trackID/$frameID/epochs"
  gacosdir="$CARPETA/GACOS"
  mkdir -p "$gacosdir"

  if [ -d "$epochdir" ]; then
    for epoch_path in "$epochdir"/*; do
      epoch=$(basename "$epoch_path")
      gacosfile=$(ls "$epoch_path"/*sltd*.geo.tif 2>/dev/null | head -n 1)
      if [[ -n "$gacosfile" && -f "$gacosfile" ]]; then
        dest="$gacosdir/$(basename "$gacosfile")"
        [ ! -e "$dest" ] && ln -s "$gacosfile" "$dest"
      fi
    done
  fi

  echo "############# ERA5 link ##############"
  era5dir="$CARPETA/ERA5"
  mkdir -p "$era5dir"

  if [ -d "$epochdir" ]; then
    for epoch_path in "$epochdir"/*; do
      epoch=$(basename "$epoch_path")
      era5file=$(ls "$epoch_path"/*icams*.sltd.geo.tif 2>/dev/null | head -n 1)
      if [[ -n "$era5file" && -f "$era5file" ]]; then
        dest="$era5dir/$(basename "$era5file")"
        [ ! -e "$dest" ] && ln -s "$era5file" "$dest"
      fi
    done
  fi

  # Clone and move Create_list_ifs
  echo "Cloning Update files into $CARPETA..."
  (
    cd "$CARPETA" || { echo "Could not enter $CARPETA"; exit 1; }
    echo "$NOMBRE" > NameVolcano.txt
    git clone https://github.com/alejobeap/Update_Monitoring_LiCSBAS.git
    mv Update_Monitoring_LiCSBAS/* ./
    rm -rf Update_Monitoring_LiCSBAS/
    chmod +x *.sh
    # sbatch --wrap="./multilookRSLC.sh" (uncomment if needed)
    # ./Run_all.sh
  )
done

echo "Process finished."
