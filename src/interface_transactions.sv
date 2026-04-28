//////////////////////////////////////////////////////////////
// Definición del tipo de transacciones posibles en la fifo //
//////////////////////////////////////////////////////////////

typedef enum { lectura, escritura, reset, lectura_escritura } tipo_trans; 

/////////////////////////////////////////////////////////////////////////////////////////
//Transacción: este objeto representa las transacciones que entran y salen de la fifo. //
/////////////////////////////////////////////////////////////////////////////////////////
class trans_fifo #(parameter width = 16);
  rand int retardo;           // retardo en ciclos antes de ejecutar la transaccion
  rand bit[width-1:0] dato;   // dato que SE ESCRIBE (dato_in): escritura y lectura_escritura
  bit[width-1:0] dato_leido;  // dato que SE LEE  (dato_out): lectura y lectura_escritura
  int tiempo;                 // tiempo de simulacion en que se ejecuto la transaccion
  rand tipo_trans tipo;       // lectura, escritura, reset, lectura_escritura
  int max_retardo;

  // -----------------------------------------------------------------------
  // Constraints flexibles: límites ajustables en tiempo de simulación.
  // El generador los modifica antes de llamar randomize() para
  // implementar casos de esquina via plusargs.
  // -----------------------------------------------------------------------
  int retardo_min;   // límite inferior del retardo (default 1)
  int retardo_max;   // límite superior del retardo (default max_retardo-1)
  int dato_min;      // límite inferior del dato    (default 0)
  int dato_max;      // límite superior del dato    (default 2^width - 1)

  constraint const_retardo { retardo >= retardo_min; retardo <= retardo_max; }
  constraint const_dato    { dato    >= dato_min;    dato    <= dato_max;    }

  function new(int ret=0, bit[width-1:0] dto=0, int tmp=0, tipo_trans tpo=lectura, int mx_rtrd=10);
    this.retardo     = ret;
    this.dato        = dto;
    this.dato_leido  = 0;
    this.tiempo      = tmp;
    this.tipo        = tpo;
    this.max_retardo = mx_rtrd;
    // Valores por defecto de los límites
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


////////////////////////////////////////////////////////////////
// Interface: Esta es la interface que se conecta con la FIFO //
////////////////////////////////////////////////////////////////

interface fifo_if #(parameter width =16) (
  input clk
);
  logic rst;
  logic pndng;
  logic full;
  logic push;
  logic pop;
  logic [width-1:0] dato_in; 
  logic [width-1:0] dato_out;
endinterface


////////////////////////////////////////////////////
// Objeto de transacción usado en el scoreboard   //
////////////////////////////////////////////////////

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

/////////////////////////////////////////////////////////////////////////
// Definición de estructura para generar comandos hacia el scoreboard  //
/////////////////////////////////////////////////////////////////////////
typedef enum {retardo_promedio, reporte} solicitud_sb;

/////////////////////////////////////////////////////////////////////////
// Definición de estructura para generar comandos hacia el generador   //
/////////////////////////////////////////////////////////////////////////
typedef enum {
  llenado_aleatorio,
  trans_aleatoria,
  trans_especifica,
  sec_trans_aleatorias,
  sec_lect_escr,
  prueba_base       // Prueba general + casos de esquina via plusargs
} instrucciones_agente;

///////////////////////////////////////////////////////////////////////////////////////
// Definicion de mailboxes                                                           //
///////////////////////////////////////////////////////////////////////////////////////
typedef mailbox #(trans_fifo)           trans_fifo_mbx;
typedef mailbox #(trans_sb)             trans_sb_mbx;
typedef mailbox #(solicitud_sb)         comando_test_sb_mbx;
typedef mailbox #(instrucciones_agente) comando_test_agent_mbx;