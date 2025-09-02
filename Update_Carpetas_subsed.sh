#!/bin/bash

if [ -z "$1" ]; then
  echo "Uso: $0 <nombre_carpeta> Numeroid(optional)"
  exit 1
fi

NOMBRE=$1
NUMERO=$2

#NUMERO=$(python3 VER_Nombre_volcan_V2.py "$NOMBRE" | tr -d '[]')
#if [ $? -ne 0 ] || [ -z "$NUMERO" ]; then
#  echo "Error ejecutando VER_Nombre_volcan.py o valor vacío"
#  exit 1
#fi


# Si NUMERO no se pasa como argumento, lo buscamos con Python
if [ -z "$NUMERO" ]; then
    NUMERO=$(python3 VER_Nombre_volcan_V2.py "$NOMBRE" | tr -d '[]')
    if [ $? -ne 0 ] || [ -z "$NUMERO" ]; then
        echo "Error ejecutando VER_Nombre_volcan_V2.py o valor vacío"
        exit 1
    fi
fi

echo "Número obtenido: $NUMERO"

# Replace spaces, dots, and dashes with underscores
NOMBRE_CLEAN=$(echo "$NOMBRE" | sed -E 's/[ .-]+/_/g')



# Create the directory
mkdir -p "$NOMBRE_CLEAN"


echo "Directory created: $NOMBRE_CLEAN"


cd "$NOMBRE_CLEAN" || { echo "No se pudo entrar a la carpeta $NOMBRE"; exit 1; }

RUTA_BASE="/gws/nopw/j04/nceo_geohazards_vol1/projects/LiCS/proc/current/subsets/volc/$NUMERO"

CARPETAS=( $(ls -d "$RUTA_BASE"/*/ 2>/dev/null | xargs -n 1 basename) )

if [ ${#CARPETAS[@]} -eq 0 ]; then
  echo "No se encontraron carpetas dentro de $RUTA_BASE"
  exit 1
fi

TOTAL_PASOS=$((${#CARPETAS[@]} * 3))
PASO_ACTUAL=0

for CARPETA in "${CARPETAS[@]}"; do
  mkdir -p "$CARPETA/geo"
  mkdir -p "$CARPETA/RSLC"
  mkdir -p "$CARPETA/SLC"
  mkdir -p "$CARPETA/GEOC/geo"

  # Verificar carpeta geo.30m o geo
  if [ -d "$RUTA_BASE/$CARPETA/geo.30m" ]; then
    GEO_FOLDER="geo.30m"
  elif [ -d "$RUTA_BASE/$CARPETA/geo" ]; then
    GEO_FOLDER="geo"
  else
    echo "No se encontró carpeta geo.30m o geo en $RUTA_BASE/$CARPETA"
    continue
  fi

  ((PASO_ACTUAL++))
  PORCENTAJE=$(( PASO_ACTUAL * 100 / TOTAL_PASOS ))
  echo "[$PORCENTAJE%] Copiando $GEO_FOLDER en $CARPETA/geo..."
  rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/$GEO_FOLDER/" "$CARPETA/geo/" 2>&1 | tee -a ../debug.log

  ((PASO_ACTUAL++))
  PORCENTAJE=$(( PASO_ACTUAL * 100 / TOTAL_PASOS ))
  echo "[$PORCENTAJE%] Copiando RSLC en $CARPETA..."
  rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/RSLC/" "$CARPETA/RSLC/" 2>&1 | tee -a ../debug.log

  ((PASO_ACTUAL++))
  PORCENTAJE=$(( PASO_ACTUAL * 100 / TOTAL_PASOS ))
  echo "[$PORCENTAJE%] Copiando SLC en $CARPETA..."
  rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/SLC/" "$CARPETA/SLC/" 2>&1 | tee -a ../debug.log


  rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/local_config.py" "$CARPETA/SLC/"

  # GEOC.meta.30m
  if [ -d "$RUTA_BASE/$CARPETA/GEOC.meta.30m" ]; then
    echo "Copiando GEOC.meta.30m..."
    rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/GEOC.meta.30m/" "$CARPETA/GEOC/geo/" 2>&1 | tee -a ../debug.log
    rsync -a --ignore-existing "$RUTA_BASE/$CARPETA/GEOC.meta.30m/" "$CARPETA/GEOC/" 2>&1 | tee -a ../debug.log
  fi

  # GEOC.MLI.30m
  if [ -d "$RUTA_BASE/$CARPETA/GEOC.MLI.30m" ]; then
    echo "Copiando GEOC.MLI.30m..."
    find "$RUTA_BASE/$CARPETA/GEOC.MLI.30m" -type f | while read -r archivo; do
      rsync -a --ignore-existing "$archivo" "$CARPETA/GEOC/geo/" 2>&1 | tee -a ../debug.log
      rsync -a --ignore-existing "$archivo" "$CARPETA/GEOC/" 2>&1 | tee -a ../debug.log
    done
  fi

  # Buscar archivo corners_clip.*
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
  
  # Renombrar .png si existe
  png_file=$(ls "$CARPETA/GEOC/"*.geo.mli.png 2>/dev/null | head -n 1)
  if [ -n "$png_file" ]; then
    mv "$png_file" "$CARPETA/GEOC/$basename.geo.mli.png"
  fi




  # Remove leading zeros by forcing numeric interpretation
  trackID=$((10#$digits))
  echo "trackID=$trackID"


  echo "############# GACOS link ##############"
  
  # ############# GACOS link ##############
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
  # ############# ERA5 link ##############
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
  

  # Clonar y mover Create_list_ifs
  echo "Clonando Matriz_Coherencia en $CARPETA..."
  (
    cd "$CARPETA" || { echo "No se pudo entrar a $CARPETA"; exit 1; }
    echo "$NOMBRE" > NameVolcano.txt
    git clone https://github.com/alejobeap/Create_list_ifs.git
    mv Create_list_ifs/* ./
    rm -rf Create_list_ifs/
    chmod +x *.sh
    # sbatch --wrap="./multilookRSLC.sh" (descomentar si se desea ejecutar)
    #./Run_all.sh
  )

done

echo "Proceso finalizado."
