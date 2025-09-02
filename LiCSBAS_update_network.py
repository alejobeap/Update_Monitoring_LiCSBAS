#!/usr/bin/env python3
# P.Espin 2025-09-02
  #Update network for monitoring based in LiCSBAS_plot_network.py and steps for bad and all interferograms from LiCSBAS13_inv.py

"""
LiCSBAS_update_network.py
-------------------------
Script to update LiCSBAS interferogram (IFG) networks, handle bad IFGs, 
and regenerate baseline plots 
The file need the all RSLC for create a baselines_update file

Usage:
    python LiCSBAS_update_network.py -d <ifgdir> [-t <tsadir>]
    e.g. LiCSBAS_update_network.py -d GEOCml2mask

Arguments:
    -d  Path to the IFG directory (mandatory).
    -t  Path to the output TS_GEOCml* directory (optional).


"""

import os
import sys
import glob
import argparse
import subprocess
import numpy as np
import datetime as dt
import numpy as np
import os
import sys
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




def update_bperp_file(bperp_file, imdates):
    """
    Actualiza el archivo de baselines agregando solo los imdates que faltan.
    Conserva los datos existentes y genera dummy para los faltantes.
    """
    # Leer baselines existentes
    bperp_dict = {}
    if os.path.exists(bperp_file):
        with open(bperp_file, 'r') as f:
            for l in f:
                parts = l.split()
                if len(parts) >= 4:
                    bperp_dict[parts[1]] = float(parts[2])  # suponer formato nuevo
    else:
        print(f"WARNING: {bperp_file} no existe. Se creará nuevo archivo.")

    # Añadir entradas faltantes
    base_date = imdates[0]
    updated_lines = []
    for i, imd in enumerate(imdates):
        if imd in bperp_dict:
            bp = bperp_dict[imd]
        else:
            # generar dummy baseline
            if i == 0:
                bp = 0
            elif i % 4 == 1:
                bp = np.random.rand()/2 + 0.5  # 0.5 ~ 1
            elif i % 4 == 2:
                bp = -np.random.rand()/2 - 0.5 # -1 ~ -0.5
            elif i % 4 == 3:
                bp = np.random.rand()/2         # 0 ~ 0.5
            else:
                bp = -np.random.rand()/2        # -0.5 ~ 0

            ifg_dt = dt.datetime.strptime(imd, '%Y%m%d').toordinal() - dt.datetime.strptime(base_date, '%Y%m%d').toordinal()
            # construir línea en formato old-style
            updated_lines.append('{:3d} {} {} {:5.2f} {:4d} {} {:4d} {} {:5.2f}'.format(
                i, base_date, imd, bp, ifg_dt, 0, ifg_dt, 0, bp
            ))
            bperp_dict[imd] = bp  # añadir al dict

    # Guardar de nuevo el archivo: primero las líneas existentes
    with open(bperp_file, 'a') as f:  # 'a' para añadir solo nuevas
        for line in updated_lines:
            f.write(line + '\n')

    # Crear lista de baselines en el orden de imdates
    bperp = [bperp_dict[imd] for imd in imdates]

    return bperp





def main():
    netdir = "network_update"
    os.makedirs(netdir, exist_ok=True)

    # ---------------- Ejecutar bash solo si falta el archivo ----------------
    bperp_file = "baselines_updated"



    # Borrar archivo si existe
    if os.path.exists(bperp_file):
        print(f"Borrando archivo existente: {bperp_file} y creando Nuevo")
        os.remove(bperp_file)
        run_bash_update()
    
    # ---------------- Leer listas de IFGs ----------------
    ifs_files = glob.glob("IFSforLiCSBAS_*.txt")
    ifs_update_files = glob.glob("IFSforLiCSBAS_*_update.txt")
    ifglist = read_ifg_list(ifs_files) + read_ifg_list(ifs_update_files)
    ifglist = sorted(set(ifglist))  # quitar repetidos

    # Extraer fechas de la lista directamente
    ifgdates_all = tools_lib.ifglists2ifgdates(ifglist) if hasattr(tools_lib, "ifglists2ifgdates") else ifglist
    imdates_all = tools_lib.ifgdates2imdates(ifgdates_all)

    # ---------------- Leer bad_ifg de info/* ----------------
    bad_ifg11 = safe_read_ifg_list("info/11bad_ifg.txt")
    bad_ifg12 = safe_read_ifg_list("info/12bad_ifg.txt")
    bad_ifg12no = safe_read_ifg_list("info/12no_loop_ifg.txt")

    if os.path.exists("info/120bad_ifg.txt"):
        print("Agregando IFGs de la etapa opcional 120...")
        bad_ifg120 = io_lib.read_ifg_list("info/120bad_ifg.txt")
        bad_ifg12 = list(set(bad_ifg12 + bad_ifg120))

    bad_ifg_all = list(set(bad_ifg11 + bad_ifg12 + bad_ifg12no))

    # ---------------- Filtrar IFGs válidos ----------------
    ifgdates = sorted(set(ifgdates_all) - set(bad_ifg_all))
    imdates = tools_lib.ifgdates2imdates(ifgdates)
    print(ifgdates)
    print(imdates)
    # ---------------- Leer baselines ----------------
    if os.path.exists(bperp_file):
        with open(bperp_file, "r") as f:
            lines = [line.strip() for line in f if line.strip()]

        if len(lines) >= len(imdates):
            bperp = io_lib.read_bperp_file(bperp_file, imdates)
            bperp_all = io_lib.read_bperp_file(bperp_file, imdates_all)
        else:
            print("WARNING: Baselines tiene menos entradas. Usando valores dummy.")
            #bperp = np.random.random(len(imdates)).tolist()
            #bperp_all = np.random.random(len(imdates_all)).tolist()
            bperp = update_bperp_file(bperp_file, imdates)
            bperp_all = update_bperp_file(bperp_file, imdates_all)
    else:
        print("ERROR: No se pudo generar 'baselines_updated'.")
        sys.exit(1)

    # ---------------- Graficar ----------------
    plot_lib.plot_network(ifgdates_all, bperp_all, [], os.path.join(netdir, "network13_all.png"))
    plot_lib.plot_network(ifgdates_all, bperp_all, bad_ifg_all, os.path.join(netdir, "network13.png"))
    plot_lib.plot_network(
        ifgdates_all, bperp_all, bad_ifg_all, os.path.join(netdir, "network13_nobad.png"), plot_bad=False
    )


if __name__ == "__main__":
    main()
