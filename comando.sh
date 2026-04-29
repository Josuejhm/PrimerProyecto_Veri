#!/bin/bash
source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh
rm -rfv `ls | grep -v ".*\.sv\|.*\.sh"`

DEPTH=8
WIDTH=16

vcs -Mupdate test_bench.sv \
    -o salida \
    -full64 -sverilog \
    -kdb -lca \
    -debug_acc+all -debug_region+cell+encrypt \
    -l log_test \
    +lint=TFIPC-L \
    -cm line+tgl+cond+fsm+branch+assert \
    -pvalue+test_bench.depth=${DEPTH} \
    -pvalue+test_bench.width=${WIDTH}

echo "Compilado con depth=${DEPTH} width=${WIDTH}"

# Prueba general
./salida -cm line+tgl+cond+fsm+branch+assert

# Para reproducir con semilla especifica:
#./salida -cm line+tgl+cond+fsm+branch+assert +semilla=12345

# Casos de esquina — descomentar el deseado

# Overflow
#./salida -cm line+tgl+cond+fsm+branch+assert \
#         +peso_escritura=100 +peso_lectura=0 +peso_lect_escr=0 +peso_reset=0 \
#         +n_trans_min=12 +n_trans_max=16 +retardo_min=1 +retardo_max=2

# Underflow
#./salida -cm line+tgl+cond+fsm+branch+assert \
#         +peso_lectura=100 +peso_escritura=0 +peso_lect_escr=0 +peso_reset=0 \
#         +n_trans_min=12 +n_trans_max=16 +retardo_min=1 +retardo_max=2

# Pop/Push simultaneo con FIFO bajo (1 elemento)
#./salida -cm line+tgl+cond+fsm+branch+assert \
#         +prefijo=1 \
#         +peso_lect_escr=100 +peso_escritura=0 +peso_lectura=0 +peso_reset=0 \
#         +n_trans_min=6 +n_trans_max=10 +retardo_min=1 +retardo_max=4

# Pop/Push simultaneo con FIFO a la mitad (depth/2 elementos)
#./salida -cm line+tgl+cond+fsm+branch+assert \
#         +prefijo=4 \
#         +peso_lect_escr=100 +peso_escritura=0 +peso_lectura=0 +peso_reset=0 \
#         +n_trans_min=6 +n_trans_max=10 +retardo_min=1 +retardo_max=4

# Pop/Push simultaneo con FIFO alto (depth-1 elementos)
#./salida -cm line+tgl+cond+fsm+branch+assert \
#         +prefijo=7 \
#         +peso_lect_escr=100 +peso_escritura=0 +peso_lectura=0 +peso_reset=0 \
#         +n_trans_min=6 +n_trans_max=10 +retardo_min=1 +retardo_max=4

# Reset con FIFO lleno
#./salida -cm line+tgl+cond+fsm+branch+assert \
#         +prefijo=8 \
#         +peso_reset=100 +peso_escritura=0 +peso_lectura=0 +peso_lect_escr=0 \
#         +n_trans_min=1 +n_trans_max=3 +retardo_min=1 +retardo_max=4

# Reset con FIFO vacio
#./salida -cm line+tgl+cond+fsm+branch+assert \
#         +peso_reset=100 +peso_escritura=0 +peso_lectura=0 +peso_lect_escr=0 \
#         +n_trans_min=1 +n_trans_max=3 +retardo_min=1 +retardo_max=4

# Reset con FIFO a la mitad
#./salida -cm line+tgl+cond+fsm+branch+assert \
#         +prefijo=4 \
#         +peso_reset=100 +peso_escritura=0 +peso_lectura=0 +peso_lect_escr=0 \
#         +n_trans_min=1 +n_trans_max=3 +retardo_min=1 +retardo_max=4

# Patron de alternancia
#./salida -cm line+tgl+cond+fsm+branch+assert \
#         +alternancia=1 \
#         +n_trans_min=24 +n_trans_max=40 \
#         +peso_escritura=70 +peso_lectura=20 +peso_lect_escr=5 +peso_reset=5 \
#         +retardo_min=1 +retardo_max=3

verdi -cov -covdir salida.vdb&