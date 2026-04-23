////////////////////////////////////////////////////////////////////////////////////////////////////
// Checker/scoreboard: este objeto es responsable de verificar que el comportamiento del DUT sea el esperado //
////////////////////////////////////////////////////////////////////////////////////////////////////

class checker_c #(parameter width=16, parameter depth =8);
  trans_fifo #(.width(width)) transaccion; //transacción recibida en el mailbox 
  trans_fifo #(.width(width)) auxiliar; //transacción usada como auxiliar para leer el fifo emulado 
  trans_sb   #(.width(width)) to_sb; // transacción usada para comunicarse con el scoreboard
  trans_fifo  emul_fifo[$]; //this queue is going to be used as golden reference for the fifo
  trans_fifo_mbx mon_chkr_mbx; // Este mailbox es el que comunica con el monitor
  trans_sb_mbx  chkr_sb_mbx; // Este mailbox es el que comunica el checker con el scoreboard
  int contador_auxiliar;     // Auxiliar para iterar sobre la cola en caso de reset

  function new();
    this.emul_fifo = {};
    this.contador_auxiliar = 0;
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
         if(0 !== emul_fifo.size()) begin //Revisa si el Fifo no está vacía

          // Si el FIFO emulado tiene datos, saca el primero y compara con el observado
           auxiliar = emul_fifo.pop_front();

           // Si el dato es correcto lo manda al Scoreboard
           if(transaccion.dato == auxiliar.dato) begin
             to_sb.dato_enviado = auxiliar.dato;
             to_sb.tiempo_push = auxiliar.tiempo;
             to_sb.tiempo_pop = transaccion.dato;
             to_sb.completado = 1;
             to_sb.calc_latencia();
             to_sb.print("Checker:Transaccion Completada");
             chkr_sb_mbx.put(to_sb);
           end else begin
            // Si el dato es incorrecto, muestra un error
            transaccion.print("Checker: Error el dato de la transacción no calza con el esperado");
            $display("Dato_leido= %h, Dato_Esperado = %h",transaccion.dato,auxiliar.dato);
            $finish; 
           end
         end else begin // si está vacía genera un underflow 
             to_sb.tiempo_pop = transaccion.tiempo;
             to_sb.underflow = 1;
             to_sb.print("Checker: Underflow");
             chkr_sb_mbx.put(to_sb);
         end
       end
       escritura: begin
         if(emul_fifo.size() == depth)begin // Revisa si la Fifo está llena para generar un overflow
           auxiliar = emul_fifo.pop_front();
           to_sb.dato_enviado = auxiliar.dato;
           to_sb.tiempo_push = auxiliar.tiempo;
           to_sb.overflow = 1;
           to_sb.print("Checker: Overflow");
           chkr_sb_mbx.put(to_sb);
           emul_fifo.push_back(transaccion);  // Igual inserta el nuevo dato
         end else begin  // En caso de no estar llena simplemente guarda el dato en la fifo simulada
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
           // No hay dato para leer → underflow, pero igual se escribe el nuevo dato
           to_sb.tiempo_pop  = transaccion.tiempo;
           to_sb.underflow   = 1;
           to_sb.print("Checker: lectura_escritura con FIFO vacío → Underflow en lectura, se escribe igual");
           chkr_sb_mbx.put(to_sb);
           emul_fifo.push_back(transaccion);  // Escribir el dato nuevo
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
       reset: begin // en caso de reset vacía la fifo simulada y envía todos los datos perdidos al SB
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
         $display("[%g] Checker Error: la transacción recibida no tiene tipo valido",$time);
         $finish;
       end
     endcase    
   end 
  endtask
endclass 