////////////////////////////////////////////////////////////////////////////////////////////////////
// Agente (Transactor): Este bloque actúa como intermediario entre el Generador y el Driver.   //
// Rol principal:                                                                                //
//   1. Recibe transacciones del Generador via gen_agnt_mbx.                                   //
//   2. Reenvía cada transacción al Driver via agnt_drv_mbx.                                   //
//   3. Notifica al ScoreBoard de TODAS las transacciones via agnt_sb_mbx,                     //
//      para que el SB tenga visibilidad completa de lo enviado al DUT.                        //
////////////////////////////////////////////////////////////////////////////////////////////////////

class agent #(parameter width = 16, parameter depth = 8);

  // --- Mailboxes ---
  trans_fifo_mbx  gen_agnt_mbx;  // Mailbox del Generador al Agente   (entrada)
  trans_fifo_mbx  agnt_drv_mbx;  // Mailbox del Agente al Driver       (salida al DUT)
  trans_sb_mbx    agnt_sb_mbx;   // Mailbox del Agente al ScoreBoard   (notificación)

  // --- Variables internas ---
  trans_fifo #(.width(width))  transaccion;
  trans_sb   #(.width(width))  notif_sb;

  // -----------------------------------------------------------------------
  // run: bucle principal — recibe del Generador, reenvía al Driver y al SB
  // -----------------------------------------------------------------------
  task run;
    $display("[%g]  El Agente fue inicializado", $time);

    forever begin
      #1

      if (gen_agnt_mbx.num() > 0) begin

        // Paso 1: Obtener transacción del Generador
        gen_agnt_mbx.get(transaccion);
        transaccion.print("Agente: transacción recibida del Generador");

        // Paso 2: Reenviar al Driver
        agnt_drv_mbx.put(transaccion);
        transaccion.print("Agente: transacción enviada al Driver");
        $display("[%g]  Agente: transacciones pendientes en agnt_drv_mbx = %0d",
                 $time, agnt_drv_mbx.num());

        // Paso 3: Notificar al ScoreBoard todas las transacciones
        notif_sb              = new;
        notif_sb.dato_enviado = transaccion.dato;
        notif_sb.tiempo_push  = $time;
        notif_sb.completado   = 0;
        notif_sb.overflow     = 0;
        notif_sb.underflow    = 0;
        notif_sb.reset        = (transaccion.tipo == reset) ? 1 : 0;
        notif_sb.latencia     = 0;
        notif_sb.print("Agente: notificación enviada al ScoreBoard");
        agnt_sb_mbx.put(notif_sb);

      end
    end
  endtask

endclass