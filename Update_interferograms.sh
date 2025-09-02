#!/bin/bash

parent_dir=$(basename "$(dirname "$(pwd)")")
current_dir=$(basename "$(pwd)")
subsetnumero=$(python3 VER_Nombre_volcan_V2.py "$parent_dir" | tr -d '[]')


OLD_FILE="Updated_list_old.txt"
NEW_FILE="Updated_list_new.txt"
OUTPUT_FILE="IFSforLiCSBAS_${current_dir}_${parent_dir}_${subsetnumero}_update.txt"
Chilescase="n"  # Cambiar a "y" para excluir meses 6 a 9

[[ ! -f $OLD_FILE ]] && { echo "❌ $OLD_FILE no encontrado"; exit 1; }
[[ ! -f $NEW_FILE ]] && { echo "❌ $NEW_FILE no encontrado"; exit 1; }

> "$OUTPUT_FILE"

mapfile -t old_dates < <(sort "$OLD_FILE")
mapfile -t new_dates < <(sort "$NEW_FILE")

month_diff() {
  local s=$1 e=$2
  local sy=${s:0:4} sm=${s:4:2} ey=${e:0:4} em=${e:4:2}
  echo $(((10#$ey - 10#$sy)*12 + (10#$em - 10#$sm)))
}

day_diff() {
  local d1=$1 d2=$2
  local ts1=$(date -d "${d1:0:4}-${d1:4:2}-${d1:6:2}" +%s)
  local ts2=$(date -d "${d2:0:4}-${d2:4:2}-${d2:6:2}" +%s)
  local diff=$(( (ts2 - ts1) / 86400 ))
  echo ${diff#-}  # valor absoluto
}

is_excluded() {
  local m=$((10#${1:4:2}))
  [[ $Chilescase == "y" && $m -ge 6 && $m -le 9 ]]
}

valid_diff() {
  local d=$1
  [[ $d == 3 || $d == 6 || $d == 9 || $d == 12 ]]
}

combo_exists() {
  local c1="$1"
  local c2="$2"
  grep -q -E "^${c1}$|^${c2}$" "$OUTPUT_FILE"
}

# Generar combinaciones entre old y new
for old_date in "${old_dates[@]}"; do
  count_intervals=([3]=0 [6]=0 [9]=0 [12]=0)
  next3=0

  for new_date in "${new_dates[@]}"; do
    if is_excluded "$old_date" || is_excluded "$new_date"; then
      continue
    fi

    diff_m=$(month_diff "$old_date" "$new_date")
    diff_d=$(day_diff "$old_date" "$new_date")

    # Para meses 3,6,9,12 considerar ±12 días
    if valid_diff "$diff_m" && (( count_intervals[$diff_m] < 2 )); then
      if (( diff_d <= 12 )); then
        if ! combo_exists "${old_date}_${new_date}" "${new_date}_${old_date}"; then
          echo "${old_date}_${new_date}" >> "$OUTPUT_FILE"
          ((count_intervals[$diff_m]++))
          continue
        fi
      fi
    fi

    # combos con siguientes 3 fechas sin importar diff
    if (( next3 < 3 )); then
      if ! combo_exists "${old_date}_${new_date}" "${new_date}_${old_date}"; then
        echo "${old_date}_${new_date}" >> "$OUTPUT_FILE"
        ((next3++))
      fi
    else
      break
    fi
  done
done

# Forzar combinaciones de las últimas 3 fechas old con todas las new (sin filtros)
len=${#old_dates[@]}
start_index=$(( len > 3 ? len - 3 : 0 ))

for ((i = start_index; i < len; i++)); do
  for new_date in "${new_dates[@]}"; do
    if ! combo_exists "${old_dates[i]}_${new_date}" "${new_date}_${old_dates[i]}"; then
      echo "${old_dates[i]}_${new_date}" >> "$OUTPUT_FILE"
    fi
  done
done


echo "Total combinaciones generadas: $(wc -l < "$OUTPUT_FILE")"
echo "Script terminado."


IFS_FILE=$(ls IFSforLiCSBAS_${current_dir}_${parent_dir}_${subsetnumero}.txt 2>/dev/null | head -n 1)


if [[ ${#IFS_FILES[@]} -gt 0 ]]; then
    IFS_FILE="${IFS_FILES[0]}"
    echo "Found $IFS_FILE, using only the last 20 lines to filter combinations."

    # Leer últimas 20 líneas reales del archivo (sin encabezados vacíos o líneas en blanco)
    mapfile -t last_lines < <(grep -v '^$' "$IFS_FILE" | tail -n 20)

    for name in "${names[@]}"; do
        for line in "${last_lines[@]}"; do
            if [[ "$line" == *"$name"* ]]; then
                echo "$line" >> "$OUTPUT_FILE"
            fi
        done
    done

else
    echo "IFSforLiCSBAS*.txt not found. Using second column of TS*/info/13resid.txt"

    for file in TS*/info/13resid.txt; do
        if [[ -f "$file" ]]; then
            # Leer últimas 20 líneas reales (sin encabezado ni líneas vacías)
            mapfile -t last_lines < <(tail -n +2 "$file" | grep -v '^$' | tail -n 20)

            for name in "${names[@]}"; do
                for line in "${last_lines[@]}"; do
                    if [[ "$line" == *"$name"* ]]; then
                        # Extraer solo la primera columna
                        echo "$line" | awk '{ print $1 }' >> "$OUTPUT_FILE"
                    fi
                done
            done
        fi
    done
fi


sort -u "$OUTPUT_FILE"

line_count=$(wc -l < "$OUTPUT_FILE")
echo "Número total de combinaciones generadas: $line_count"



echo "framebatch_gapfill.sh -l -I /work/scratch-pw3/licsar/alejobea/batchdir/${parent_dir}/${current_dir}/IFSforLiCSBAS_${current_dir}_${parent_dir}_update.txt 5 200 7 2"

framebatch_gapfill.sh -l -I /work/scratch-pw3/licsar/alejobea/batchdir/${parent_dir}/${current_dir}/IFSforLiCSBAS_${current_dir}_${parent_dir}_update.txt 5 200 7 2


