////////////////////////////////////////////////////////////////////////////////////////////////////
// Agente (Transactor): Este bloque actúa como intermediario entre el Generador y el Driver.   //
// Rol principal:                                                                                //
//   1. Recibe transacciones del Generador via gen_agnt_mbx.                                   //
//   2. Reenvía cada transacción al Driver via agnt_drv_mbx.                                   //
//   3. Notifica al ScoreBoard de cada transacción enviada via agnt_sb_mbx,                    //
//      de modo que el SB tenga visibilidad de lo que se esperaba en el DUT.                   //
//                                                                                              //
// Nota: Según el modelo estándar (VMM), el Agente también se llama "transactor". Su trabajo    //
// es convertir instrucciones del Generador en estímulos concretos para el Driver y mantener    //
// al ScoreBoard informado de las transacciones que fueron enviadas al DUT.                     //
////////////////////////////////////////////////////////////////////////////////////////////////////

class agent #(parameter width = 16, parameter depth = 8);

  // --- Mailboxes ---
  trans_fifo_mbx  gen_agnt_mbx;  // Mailbox del Generador al Agente   (entrada)
  trans_fifo_mbx  agnt_drv_mbx;  // Mailbox del Agente al Driver       (salida al DUT)
  trans_sb_mbx    agnt_sb_mbx;   // Mailbox del Agente al ScoreBoard   (notificación)

  // --- Variables internas ---
  trans_fifo #(.width(width))  transaccion; // Transacción recibida del Generador
  trans_sb   #(.width(width))  notif_sb;    // Notificación de estado para el ScoreBoard

  // -----------------------------------------------------------------------
  // run: bucle principal — recibe del Generador, reenvía al Driver y al SB
  // -----------------------------------------------------------------------
  task run;
    $display("[%g]  El Agente fue inicializado", $time);

    forever begin
      #1  // Cede tiempo al simulador

      if (gen_agnt_mbx.num() > 0) begin

        // ------------------------------------------------------------------
        // Paso 1: Obtener transacción del Generador
        // ------------------------------------------------------------------
        gen_agnt_mbx.get(transaccion);
        transaccion.print("Agente: transacción recibida del Generador");

        // ------------------------------------------------------------------
        // Paso 2: Reenviar la transacción al Driver para estimular el DUT
        // ------------------------------------------------------------------
        agnt_drv_mbx.put(transaccion);
        transaccion.print("Agente: transacción enviada al Driver");
        $display("[%g]  Agente: transacciones pendientes en agnt_drv_mbx = %0d",
                 $time, agnt_drv_mbx.num());

        // ------------------------------------------------------------------
        // Paso 3: Crear y enviar notificación al ScoreBoard
        // El SB necesita saber qué transacciones se generaron para poder
        // comparar contra lo que el Checker verifica.
        // ------------------------------------------------------------------
        notif_sb               = new;
        notif_sb.dato_enviado  = transaccion.dato;
        notif_sb.tiempo_push   = $time;
        notif_sb.completado    = 0;   // Aún no verificada por el Checker
        notif_sb.overflow      = 0;
        notif_sb.underflow     = 0;
        notif_sb.reset         = (transaccion.tipo == reset) ? 1 : 0;
        notif_sb.latencia      = 0;

        notif_sb.print("Agente: notificación enviada al ScoreBoard");
        agnt_sb_mbx.put(notif_sb);

      end // if gen_agnt_mbx not empty
    end // forever
  endtask

endclass
