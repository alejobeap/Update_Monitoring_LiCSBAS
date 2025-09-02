#!/usr/bin/env python3
# P.Espin 2025-09-02
# Update network for monitoring

import os
import sys
import glob
import subprocess
import datetime as dt
import numpy as np
import LiCSBAS_plot_lib as plot_lib
import LiCSBAS_io_lib as io_lib
import LiCSBAS_tools_lib as tools_lib

def run_bash_update() -> None:
    """Ejecuta el script bash para regenerar el archivo de baselines."""
    subprocess.run(["bash", "mk_bperp_file_update.sh"], check=True)

def read_ifg_list(filelist):
    """Lee listas de interferogramas desde archivos de texto."""
    ifgs = []
    for f in filelist:
        if os.path.exists(f):
            with open(f, "r") as fh:
                for line in fh:
                    line = line.strip()
                    if line:
                        ifgs.append(line)
    return ifgs

def safe_read_ifg_list(filepath):
    """Lee lista de IFGs si existe, si no devuelve lista vacía."""
    if os.path.exists(filepath):
        return io_lib.read_ifg_list(filepath)
    return []

def update_bperp_file(bperp_file, imdates_all):
    """
    Actualiza bperp_file: detecta formato (nuevo o viejo) y añade solo las fechas faltantes.
    Devuelve lista bperp.
    """
    import datetime as dt
    bperp_dict = {}
    existing_lines = []

    # Detectar si existe el archivo
    if os.path.exists(bperp_file):
        with open(bperp_file, 'r') as f:
            for l in f:
                line = l.strip()
                if not line:
                    continue
                parts = line.split()
                existing_lines.append(line)
                if len(parts) >= 4:
                    # Asumimos que smdate + sdate están en columnas 0,1 (nuevo) o 1,2 (viejo)
                    if parts[0].isdigit() and len(parts) >= 9:
                        # formato viejo
                        sdate = parts[2]
                        bperp_dict[sdate] = float(parts[3])
                    else:
                        # formato nuevo
                        sdate = parts[1]
                        bperp_dict[sdate] = float(parts[2])
        fmt_type = 'old' if len(existing_lines[0].split()) >= 9 else 'new'
    else:
        fmt_type = 'new'
        print(f"WARNING: {bperp_file} no existe. Se creará nuevo archivo.")

    # Base para calcular dt
    base_date = imdates_all[0]
    updated_lines = []

    for i, sdate in enumerate(imdates_all):
        if sdate in bperp_dict:
            continue  # ya existe, no modificar
        # dummy bp
        bp = 0.0

        # Calcular dt
        dt_val = dt.datetime.strptime(sdate, '%Y%m%d').toordinal() - dt.datetime.strptime(base_date, '%Y%m%d').toordinal()
        dt_val_fmt = dt_val if dt_val >= 0 else -dt_val

        if fmt_type == 'new':
            line = f"{base_date} {sdate} {bp:5.2f} {dt_val}"
        else:
            # formato viejo
            num = len(existing_lines) + len(updated_lines) + 1
            dt_m_sm = 0.0
            dt_s_sm = dt_val
            bp_m_sm = 0.0
            bp_s_sm = bp
            line = f"{num:3d} {base_date} {sdate} {bp:5.2f} {dt_val} {dt_m_sm:5.1f} {dt_s_sm:5.1f} {bp_m_sm:5.1f} {bp_s_sm:5.1f}"

        updated_lines.append(line)
        bperp_dict[sdate] = bp

    # Guardar solo las nuevas líneas
    with open(bperp_file, 'a') as f:
        for line in updated_lines:
            f.write(line + '\n')

    # Retornar lista bperp en orden de imdates_all
    bperp = [bperp_dict[sd] for sd in imdates_all]
    return bperp


def main():
    netdir = "network_update"
    os.makedirs(netdir, exist_ok=True)

    bperp_file = "baselines_updated"

    # ---------------- Borrar y regenerar ----------------
    if os.path.exists(bperp_file):
        print(f"Borrando archivo existente: {bperp_file}")
        os.remove(bperp_file)
    run_bash_update()

    # ---------------- Leer IFGs ----------------
    ifs_files = glob.glob("IFSforLiCSBAS_*.txt")
    ifs_update_files = glob.glob("IFSforLiCSBAS_*_update.txt")
    ifglist = sorted(set(read_ifg_list(ifs_files) + read_ifg_list(ifs_update_files)))

    # ---------------- Extraer fechas ----------------
    if hasattr(tools_lib, "ifglists2ifgdates"):
        ifgdates_all = tools_lib.ifglists2ifgdates(ifglist)
    else:
        ifgdates_all = ifglist
    imdates_all = tools_lib.ifgdates2imdates(ifgdates_all)

    # ---------------- Leer bad IFGs ----------------
    bad_ifg11 = safe_read_ifg_list("info/11bad_ifg.txt")
    bad_ifg12 = safe_read_ifg_list("info/12bad_ifg.txt")
    bad_ifg12no = safe_read_ifg_list("info/12no_loop_ifg.txt")
    bad_ifg120 = safe_read_ifg_list("info/120bad_ifg.txt")
    bad_ifg_all = list(set(bad_ifg11 + bad_ifg12 + bad_ifg12no + bad_ifg120))

    # ---------------- Filtrar IFGs válidos ----------------
    ifgdates = sorted(set(ifgdates_all) - set(bad_ifg_all))
    imdates = tools_lib.ifgdates2imdates(ifgdates)

    # ---------------- Actualizar baselines ----------------
    smdate = imdates_all[0]  # master date
    bperp_all = update_bperp_file(bperp_file, imdates_all)

    # ---------------- Graficar ----------------
    plot_lib.plot_network(ifgdates_all, bperp_all, [], os.path.join(netdir, "network13_all.png"))
    plot_lib.plot_network(ifgdates_all, bperp_all, bad_ifg_all, os.path.join(netdir, "network13.png"))
    plot_lib.plot_network(ifgdates_all, bperp_all, bad_ifg_all, os.path.join(netdir, "network13_nobad.png"), plot_bad=False)

if __name__ == "__main__":
    main()
