////////////////////////////////////////////////////////////////////////////////////////////////////
// Checker/scoreboard: este objeto es responsable de verificar que el comportamiento del DUT sea el esperado //
////////////////////////////////////////////////////////////////////////////////////////////////////

class checker_c #(parameter width=16, parameter depth =8);
  trans_fifo #(.width(width)) transaccion; //transacción recibida en el mailbox 
  trans_fifo #(.width(width)) auxiliar; //transacción usada como auxiliar para leer el fifo emulado 
  trans_sb   #(.width(width)) to_sb; // transacción usada para comunicarse con el scoreboard
  trans_fifo  emul_fifo[$]; //this queue is going to be used as golden reference for the fifo
  trans_fifo_mbx mon_chkr_mbx; // Este mailbox es el que comunica con el monitor
  trans_sb_mbx  chkr_sb_mbx;  // Este mailbox es el que comunica el checker con el scoreboard
  mailbox #(int) error_mbx;   // Mailbox para notificar errores del DUT al ScoreBoard
  int contador_auxiliar;      // Auxiliar para iterar sobre la cola en caso de reset
  int errores;                // Contador de errores de verificacion detectados en el DUT
  int reads_ahead;            // Cuantos pops adelante esta rdPtr respecto a datos validos en emul_fifo
                              // >0 significa que el hardware leyo datos invalidos (stale) y rdPtr quedo adelante

  function new();
    this.emul_fifo = {};
    this.contador_auxiliar = 0;
    this.errores = 0;
    this.reads_ahead = 0;
  endfunction 

  task run;
   $display("[%g]  El checker fue inicializado",$time);
   to_sb = new();

   forever begin
     to_sb = new();

     // Se bloquea hasta que se reciba una transaccion del Monitor
     mon_chkr_mbx.get(transaccion);     
     transaccion.print("Checker: Se recibe trasacción desde el monitor");
     to_sb.clean();

     case(transaccion.tipo)
       lectura: begin
         // reads_ahead > 0: rdPtr esta adelantado por pops anteriores sin datos validos.
         // El hardware leyo dato stale; el checker no puede verificar.
         // reads_ahead == 0 y emul_fifo vacio: underflow normal, rdPtr se adelanta.
         // reads_ahead == 0 y emul_fifo con datos: verificacion normal.
         if (reads_ahead > 0) begin
           // Lectura stale: rdPtr sigue adelantado, no hay dato valido que verificar
           reads_ahead++;
           to_sb.tiempo_pop = transaccion.tiempo;
           to_sb.underflow = 1;
           to_sb.print("Checker: Lectura stale (rdPtr adelantado), underflow");
           chkr_sb_mbx.put(to_sb);
         end else if (emul_fifo.size() == 0) begin
           // Underflow normal: emul_fifo vacio, rdPtr avanza en el hardware
           reads_ahead++;  // rdPtr se adelanto, futuras escrituras quedan orphaned
           to_sb.tiempo_pop = transaccion.tiempo;
           to_sb.underflow = 1;
           to_sb.print("Checker: Underflow");
           chkr_sb_mbx.put(to_sb);
         end else begin
           // Verificacion normal: hay datos en emul_fifo y rdPtr esta sincronizado
           auxiliar = emul_fifo.pop_front();
           if(transaccion.dato == auxiliar.dato) begin
             to_sb.dato_enviado = auxiliar.dato;
             to_sb.tiempo_push = auxiliar.tiempo;
             to_sb.tiempo_pop = transaccion.tiempo;
             to_sb.completado = 1;
             to_sb.calc_latencia();
             to_sb.print("Checker:Transaccion Completada");
             chkr_sb_mbx.put(to_sb);
           end else begin
             transaccion.print("Checker: ERROR - dato recibido no calza con el esperado");
             $display("[%g] Checker ERROR #%0d: Dato_leido=0x%h, Dato_Esperado=0x%h",$time, errores+1, transaccion.dato, auxiliar.dato);
             errores++;
             if (error_mbx != null) error_mbx.put(1);
             $display("[%g] Checker: Total errores = %0d, se continua la simulacion",$time, errores);
           end
         end
       end
       escritura: begin
         if (reads_ahead > 0) begin
           // wrPtr se acerca a rdPtr: este dato va a una posicion que rdPtr ya supero o aun no llega
           reads_ahead--;  // wrPtr avanzo, acortando la brecha
           // El dato va a mem[wrPtr_antes], rdPtr esta en wrPtr_antes + reads_ahead_anterior
           // Si reads_ahead llego a 0: wrPtr alcanzo a rdPtr, proxima escritura sera valida
           $display("[%g] Checker: Escritura orphaned (rdPtr adelantado=%0d), dato 0x%h se pierde",$time, reads_ahead+1, transaccion.dato);
           // NO se agrega a emul_fifo: rdPtr ya paso esa posicion
         end else if(emul_fifo.size() == depth) begin
           // Overflow normal
           auxiliar = emul_fifo.pop_front();
           to_sb.dato_enviado = auxiliar.dato;
           to_sb.tiempo_push = auxiliar.tiempo;
           to_sb.overflow = 1;
           to_sb.print("Checker: Overflow");
           chkr_sb_mbx.put(to_sb);
           emul_fifo.push_back(transaccion);
         end else begin
           // Escritura normal
           transaccion.print("Checker: Escritura");
           emul_fifo.push_back(transaccion);
         end
       end
       lectura_escritura: begin
         // Caso: push=1 y pop=1 en el mismo ciclo
         // El FIFO saca el dato más antiguo y mete el nuevo dato simultáneamente.
         // El tamaño del FIFO no cambia, pero sí su contenido.
         // Casos borde:
         //   - FIFO vacío: no hay nada que sacar → se genera underflow, igual se escribe
         //   - FIFO lleno: se saca uno y se mete uno → no hay overflow
         if (emul_fifo.size() == 0) begin
           // FIFO vacio: ambos punteros (wrPtr y rdPtr) avanzan juntos en el hardware.
           // El dato escrito queda en una posicion que rdPtr ya supero → dato PERDIDO.
           // El FIFO sigue vacio despues de la operacion.
           to_sb.tiempo_pop = transaccion.tiempo;
           to_sb.underflow  = 1;
           to_sb.print("Checker: lectura_escritura FIFO vacio, underflow, dato escrito se pierde");
           chkr_sb_mbx.put(to_sb);
           // NO se agrega a emul_fifo: el hardware deja el FIFO vacio
         end else begin
           // Hay dato disponible: sacar el más antiguo y meter el nuevo
           auxiliar = emul_fifo.pop_front();
           to_sb.dato_enviado = auxiliar.dato;
           to_sb.tiempo_push  = auxiliar.tiempo;
           to_sb.tiempo_pop   = transaccion.tiempo;
           to_sb.completado   = 1;
           to_sb.calc_latencia();
           to_sb.print("Checker: lectura_escritura completada");
           chkr_sb_mbx.put(to_sb);
           emul_fifo.push_back(transaccion);  // Escribir el dato nuevo
         end
       end
       reset: begin // en caso de reset vacia la fifo simulada, resetea reads_ahead
         reads_ahead = 0;  // Despues del reset ambos punteros van a 0, se resincroniza
         contador_auxiliar = emul_fifo.size();
         for(int i =0; i<contador_auxiliar; i++)begin
           auxiliar = emul_fifo.pop_front();
           to_sb.clean();
           to_sb.dato_enviado = auxiliar.dato;
           to_sb.tiempo_push = auxiliar.tiempo;
           to_sb.reset = 1;
           to_sb.print("Checker: Reset");
           chkr_sb_mbx.put(to_sb);
         end
       end
       default: begin
         $display("[%g] Checker Error: tipo de transaccion desconocido, se ignora",$time);
         errores++;
       end
     endcase    
   end 
  endtask
endclass