# Verificación Funcional de FIFO Genérica

Ambiente de verificación en SystemVerilog para `fifo_generic`, una FIFO parametrizable en ancho de dato y profundidad.

## Estructura del repositorio

```
PrimerProyecto_Veri/
├── src/                        # Archivos del ambiente de verificación
│   ├── interface_transactions.sv
│   ├── generator.sv
│   ├── agent.sv
│   ├── driver.sv
│   ├── monitor.sv
│   ├── checker.sv
│   ├── score_board.sv
│   ├── ambiente.sv
│   └── test.sv
├── tb/
│   └── test_bench.sv           # Módulo raíz del testbench
├── fifo.sv                     # DUT (fifo_generic)
├── fifo_new.sv                 # DUT alternativo
├── comando.sh                  # Script de compilación y ejecución
└── README.md
```

## Cómo correr en el servidor

Todos los archivos deben estar en **una misma carpeta** en el servidor.

```bash
# 1. Cargar el ambiente de Synopsys
source /mnt/vol_NFS_rh003/estudiantes/archivos_config/synopsys_tools2.sh

# 2. Correr el script
bash comando.sh
```

El script compila y ejecuta la prueba base automáticamente.

## Parámetros del DUT

`depth` y `width` se configuran en compilación editando las variables al inicio de `comando.sh`:

```bash
DEPTH=8
WIDTH=16
```

Rango soportado: 2 a 256 para ambos parámetros.

## Prueba base

Sin plusargs corre la prueba general aleatoria con los siguientes defaults:

| Parámetro | Default | Descripción |
|-----------|---------|-------------|
| `+peso_escritura=N` | 40 | % de escrituras |
| `+peso_lectura=N` | 35 | % de lecturas |
| `+peso_lect_escr=N` | 15 | % de lectura/escritura simultánea |
| `+peso_reset=N` | 10 | % de resets |
| `+n_trans_min=N` | 16 | Mínimo de transacciones |
| `+n_trans_max=N` | 32 | Máximo de transacciones |
| `+retardo_min=N` | 1 | Mínimo retardo entre transacciones (ciclos) |
| `+retardo_max=N` | 7 | Máximo retardo entre transacciones (ciclos) |
| `+dato_min=N` | 0 | Valor mínimo del dato |
| `+dato_max=N` | 2^width-1 | Valor máximo del dato |
| `+prefijo=N` | 0 | Escrituras forzadas antes de la prueba aleatoria |
| `+alternancia=1` | 0 | Datos de escritura ciclados entre 0x0000, 0x5555, 0xAAAA, 0xFFFF |
| `+semilla=N` | automática | Semilla de aleatorización (para reproducir resultados) |

Para reproducir un resultado específico:

```bash
./salida -cm line+tgl+cond+fsm+branch+assert +semilla=12345
```

## Casos de esquina

Descomentar el caso deseado en `comando.sh`, o ejecutar directamente:

```bash
# Overflow
./salida -cm line+tgl+cond+fsm+branch+assert \
         +peso_escritura=100 +peso_lectura=0 +peso_lect_escr=0 +peso_reset=0 \
         +n_trans_min=12 +n_trans_max=16 +retardo_min=1 +retardo_max=2

# Underflow
./salida -cm line+tgl+cond+fsm+branch+assert \
         +peso_lectura=100 +peso_escritura=0 +peso_lect_escr=0 +peso_reset=0 \
         +n_trans_min=12 +n_trans_max=16 +retardo_min=1 +retardo_max=2

# Pop/Push simultáneo con FIFO bajo (1 elemento)
./salida -cm line+tgl+cond+fsm+branch+assert \
         +prefijo=1 \
         +peso_lect_escr=100 +peso_escritura=0 +peso_lectura=0 +peso_reset=0 \
         +n_trans_min=6 +n_trans_max=10 +retardo_min=1 +retardo_max=4

# Pop/Push simultáneo con FIFO a la mitad (depth/2 elementos)
./salida -cm line+tgl+cond+fsm+branch+assert \
         +prefijo=4 \
         +peso_lect_escr=100 +peso_escritura=0 +peso_lectura=0 +peso_reset=0 \
         +n_trans_min=6 +n_trans_max=10 +retardo_min=1 +retardo_max=4

# Pop/Push simultáneo con FIFO alto (depth-1 elementos)
./salida -cm line+tgl+cond+fsm+branch+assert \
         +prefijo=7 \
         +peso_lect_escr=100 +peso_escritura=0 +peso_lectura=0 +peso_reset=0 \
         +n_trans_min=6 +n_trans_max=10 +retardo_min=1 +retardo_max=4

# Reset con FIFO lleno
./salida -cm line+tgl+cond+fsm+branch+assert \
         +prefijo=8 \
         +peso_reset=100 +peso_escritura=0 +peso_lectura=0 +peso_lect_escr=0 \
         +n_trans_min=1 +n_trans_max=3 +retardo_min=1 +retardo_max=4

# Reset con FIFO vacío
./salida -cm line+tgl+cond+fsm+branch+assert \
         +peso_reset=100 +peso_escritura=0 +peso_lectura=0 +peso_lect_escr=0 \
         +n_trans_min=1 +n_trans_max=3 +retardo_min=1 +retardo_max=4

# Reset con FIFO a la mitad
./salida -cm line+tgl+cond+fsm+branch+assert \
         +prefijo=4 \
         +peso_reset=100 +peso_escritura=0 +peso_lectura=0 +peso_lect_escr=0 \
         +n_trans_min=1 +n_trans_max=3 +retardo_min=1 +retardo_max=4

# Patrón de alternancia (0x0000, 0x5555, 0xAAAA, 0xFFFF)
./salida -cm line+tgl+cond+fsm+branch+assert \
         +alternancia=1 \
         +n_trans_min=24 +n_trans_max=40 \
         +peso_escritura=70 +peso_lectura=20 +peso_lect_escr=5 +peso_reset=5 \
         +retardo_min=1 +retardo_max=3
```

## Ver cobertura

Al finalizar el script se abre Verdi con el reporte de cobertura:

```bash
verdi -cov -covdir salida.vdb&
```

## Nota sobre la estructura del repositorio

Los archivos están organizados en carpetas en el repositorio por buenas prácticas, pero para ejecutar en el servidor deben estar todos en una misma carpeta ya que los `include` del `test_bench.sv` usan rutas relativas sin subdirectorio.
