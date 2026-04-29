// Checker: verifica el comportamiento del DUT comparando lo observado por el Monitor
// contra un modelo de referencia (emul_fifo). Detecta errores de datos, overflows,
// underflows y resets, y reporta cada evento al ScoreBoard.
//
// reads_ahead: cuenta cuantos pops ha ejecutado el hardware sobre posiciones invalidas.
// Cuando es >0, el puntero de lectura del DUT esta adelantado respecto a los datos
// validos en emul_fifo. Esto provoca lecturas stale y escrituras orphaned hasta que
// se sincroniza con un reset o la diferencia se cancela.
class checker_c #(parameter width=16, parameter depth =8);
  trans_fifo #(.width(width)) transaccion;
  trans_fifo #(.width(width)) auxiliar;
  trans_sb   #(.width(width)) to_sb;
  trans_fifo  emul_fifo[$];      // cola de referencia que emula el comportamiento del FIFO
  trans_fifo_mbx mon_chkr_mbx;
  trans_sb_mbx  chkr_sb_mbx;
  mailbox #(int) error_mbx;
  int contador_auxiliar;
  int errores;
  int reads_ahead;

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
     mon_chkr_mbx.get(transaccion);     
     transaccion.print("Checker: Se recibe trasacción desde el monitor");
     to_sb.clean();

     case(transaccion.tipo)
       lectura: begin
         if (reads_ahead > 0) begin
           // rdPtr adelantado: el dato leido es invalido (stale)
           reads_ahead++;
           to_sb.tiempo_pop = transaccion.tiempo;
           to_sb.underflow = 1;
           to_sb.print("Checker: Lectura stale (rdPtr adelantado), underflow");
           chkr_sb_mbx.put(to_sb);
         end else if (emul_fifo.size() == 0) begin
           // FIFO vacio: underflow, rdPtr queda adelantado para futuras escrituras
           reads_ahead++;
           to_sb.tiempo_pop = transaccion.tiempo;
           to_sb.underflow = 1;
           to_sb.print("Checker: Underflow");
           chkr_sb_mbx.put(to_sb);
         end else begin
           // Lectura normal: verificar dato contra el frente de emul_fifo
           auxiliar = emul_fifo.pop_front();
           if(transaccion.dato_leido == auxiliar.dato) begin
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
           // rdPtr adelantado: la escritura cae en una posicion que rdPtr ya supero
           reads_ahead--;
           $display("[%g] Checker: Escritura orphaned (rdPtr adelantado=%0d), dato 0x%h se pierde",$time, reads_ahead+1, transaccion.dato);
         end else if(emul_fifo.size() == depth) begin
           // FIFO lleno: overflow, el dato mas antiguo se descarta
           auxiliar = emul_fifo.pop_front();
           to_sb.dato_enviado = auxiliar.dato;
           to_sb.tiempo_push = auxiliar.tiempo;
           to_sb.overflow = 1;
           to_sb.print("Checker: Overflow");
           chkr_sb_mbx.put(to_sb);
           emul_fifo.push_back(transaccion);
         end else begin
           transaccion.print("Checker: Escritura");
           emul_fifo.push_back(transaccion);
         end
       end

       lectura_escritura: begin
         // Push y pop simultaneos: el tamaño del FIFO no cambia pero el contenido si.
         // Si reads_ahead>0: pop y push se cancelan mutuamente pero ambos datos son invalidos.
         // Si FIFO vacio: ambos punteros avanzan juntos, el dato escrito se pierde.
         // Si FIFO con datos: se saca el mas antiguo y se mete el nuevo.
         if (reads_ahead > 0) begin
           to_sb.tiempo_pop = transaccion.tiempo;
           to_sb.underflow  = 1;
           to_sb.print("Checker: lectura_escritura con rdPtr adelantado, underflow");
           chkr_sb_mbx.put(to_sb);
         end else if (emul_fifo.size() == 0) begin
           to_sb.tiempo_pop = transaccion.tiempo;
           to_sb.underflow  = 1;
           to_sb.print("Checker: lectura_escritura FIFO vacio, underflow, dato escrito se pierde");
           chkr_sb_mbx.put(to_sb);
         end else begin
           auxiliar = emul_fifo.pop_front();
           if (transaccion.dato_leido == auxiliar.dato) begin
             to_sb.dato_enviado = auxiliar.dato;
             to_sb.tiempo_push  = auxiliar.tiempo;
             to_sb.tiempo_pop   = transaccion.tiempo;
             to_sb.completado   = 1;
             to_sb.calc_latencia();
             to_sb.print("Checker: lectura_escritura completada");
             chkr_sb_mbx.put(to_sb);
           end else begin
             transaccion.print("Checker: ERROR lectura_escritura - dato leido no calza con el esperado");
             $display("[%g] Checker ERROR #%0d: Dato_leido=0x%h, Dato_Esperado=0x%h",
                      $time, errores+1, transaccion.dato_leido, auxiliar.dato);
             errores++;
             if (error_mbx != null) error_mbx.put(1);
             $display("[%g] Checker: Total errores = %0d, se continua la simulacion",$time, errores);
           end
           // Se crea un objeto nuevo para no contaminar emul_fifo con dato_leido de la lectura
           begin
             trans_fifo #(.width(width)) entrada_escritura;
             entrada_escritura        = new;
             entrada_escritura.tipo   = escritura;
             entrada_escritura.dato   = transaccion.dato;
             entrada_escritura.tiempo = transaccion.tiempo;
             emul_fifo.push_back(entrada_escritura);
           end
         end
       end

       reset: begin
         // Vaciar emul_fifo y resetear reads_ahead.
         // Se crea un trans_sb nuevo por cada dato para evitar que el mailbox
         // guarde multiples referencias al mismo objeto.
         reads_ahead = 0;
         contador_auxiliar = emul_fifo.size();
         if (contador_auxiliar == 0) begin
           begin
             trans_sb #(.width(width)) to_sb_rst;
             to_sb_rst       = new();
             to_sb_rst.reset = 1;
             to_sb_rst.print("Checker: Reset (fifo ya estaba vacia)");
             chkr_sb_mbx.put(to_sb_rst);
           end
         end else begin
           for(int i = 0; i < contador_auxiliar; i++) begin
             trans_sb #(.width(width)) to_sb_rst;
             to_sb_rst              = new();
             auxiliar               = emul_fifo.pop_front();
             to_sb_rst.dato_enviado = auxiliar.dato;
             to_sb_rst.tiempo_push  = auxiliar.tiempo;
             to_sb_rst.reset        = 1;
             to_sb_rst.print("Checker: Reset");
             chkr_sb_mbx.put(to_sb_rst);
           end
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
