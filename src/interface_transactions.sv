// Tipos de transaccion soportados por la FIFO
typedef enum { lectura, escritura, reset, lectura_escritura } tipo_trans; 

// Objeto de transaccion que circula entre los componentes del testbench.
// dato      : valor que se escribe en el FIFO (aplica a escritura y lectura_escritura)
// dato_leido: valor leido del FIFO (aplica a lectura y lectura_escritura)
// retardo   : ciclos de espera antes de ejecutar la transaccion
// Los limites de retardo y dato son ajustables en tiempo de simulacion
// para implementar casos de esquina via plusargs.
class trans_fifo #(parameter width = 16);
  rand int retardo;
  rand bit[width-1:0] dato;
  bit[width-1:0] dato_leido;
  int tiempo;
  rand tipo_trans tipo;
  int max_retardo;

  int retardo_min;
  int retardo_max;
  int dato_min;
  int dato_max;

  constraint const_retardo { retardo >= retardo_min; retardo <= retardo_max; }
  constraint const_dato    { dato    >= dato_min;    dato    <= dato_max;    }

  function new(int ret=0, bit[width-1:0] dto=0, int tmp=0, tipo_trans tpo=lectura, int mx_rtrd=10);
    this.retardo     = ret;
    this.dato        = dto;
    this.dato_leido  = 0;
    this.tiempo      = tmp;
    this.tipo        = tpo;
    this.max_retardo = mx_rtrd;
    this.retardo_min = 1;
    this.retardo_max = mx_rtrd - 1;
    this.dato_min    = 0;
    this.dato_max    = (1 << width) - 1;
  endfunction
  
  function clean;
    this.retardo    = 0;
    this.dato       = 0;
    this.dato_leido = 0;
    this.tiempo     = 0;
    this.tipo       = lectura;
  endfunction
    
  // Imprime solo los campos relevantes segun el tipo de transaccion
  function void print(string tag = "");
    case (this.tipo)
      lectura:
        $display("[%g] %s Tiempo=%g Tipo=%s Retardo=%g dato_out=0x%h",
                 $time, tag, tiempo, this.tipo, this.retardo, this.dato_leido);
      escritura:
        $display("[%g] %s Tiempo=%g Tipo=%s Retardo=%g dato_in=0x%h",
                 $time, tag, tiempo, this.tipo, this.retardo, this.dato);
      lectura_escritura:
        $display("[%g] %s Tiempo=%g Tipo=%s Retardo=%g dato_in=0x%h dato_out=0x%h",
                 $time, tag, tiempo, this.tipo, this.retardo, this.dato, this.dato_leido);
      default:
        $display("[%g] %s Tiempo=%g Tipo=%s Retardo=%g",
                 $time, tag, tiempo, this.tipo, this.retardo);
    endcase
  endfunction
endclass


// Interface de conexion con el DUT
interface fifo_if #(parameter width =16) (input clk);
  logic rst;
  logic pndng;
  logic full;
  logic push;
  logic pop;
  logic [width-1:0] dato_in; 
  logic [width-1:0] dato_out;
endinterface


// Objeto de transaccion usado por el Checker para comunicarse con el ScoreBoard.
// Registra tiempos de push/pop, latencia y tipo de evento (completado, overflow, underflow, reset).
class trans_sb #(parameter width=16);
  bit [width-1:0] dato_enviado;
  int tiempo_push;
  int tiempo_pop;
  bit completado;
  bit overflow;
  bit underflow;
  bit reset;
  int latencia;
  
  function void clean();
    this.dato_enviado = 0;
    this.tiempo_push  = 0;
    this.tiempo_pop   = 0;
    this.completado   = 0;
    this.overflow     = 0;
    this.underflow    = 0;
    this.reset        = 0;
    this.latencia     = 0;
  endfunction

  task calc_latencia;
    this.latencia = this.tiempo_pop - this.tiempo_push;
  endtask
  
  function void print(string tag);
    $display("[%g] %s dato=%h,t_push=%g,t_pop=%g,cmplt=%g,ovrflw=%g,undrflw=%g,rst=%g,ltncy=%g", 
             $time, tag, 
             this.dato_enviado, 
             this.tiempo_push,
             this.tiempo_pop,
             this.completado,
             this.overflow,
             this.underflow,
             this.reset,
             this.latencia);
  endfunction
endclass

// Comandos que el Test envia al ScoreBoard
typedef enum {retardo_promedio, reporte} solicitud_sb;

// Instrucciones que el Test envia al Generador.
// prueba_base cubre tanto la prueba general como los casos de esquina via plusargs.
typedef enum {
  llenado_aleatorio,
  trans_aleatoria,
  trans_especifica,
  sec_trans_aleatorias,
  sec_lect_escr,
  prueba_base
} instrucciones_agente;

// Tipos de mailbox usados en el testbench
typedef mailbox #(trans_fifo)           trans_fifo_mbx;
typedef mailbox #(trans_sb)             trans_sb_mbx;
typedef mailbox #(solicitud_sb)         comando_test_sb_mbx;
typedef mailbox #(instrucciones_agente) comando_test_agent_mbx;
