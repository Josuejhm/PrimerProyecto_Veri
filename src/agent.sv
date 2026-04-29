// Agente: recibe transacciones del Generador, las reenvía al Driver
// y notifica al ScoreBoard de cada transaccion enviada al DUT.
class agent #(parameter width = 16, parameter depth = 8);

  trans_fifo_mbx  gen_agnt_mbx;  // Generador → Agente
  trans_fifo_mbx  agnt_drv_mbx;  // Agente → Driver
  trans_sb_mbx    agnt_sb_mbx;   // Agente → ScoreBoard

  trans_fifo #(.width(width))  transaccion;
  trans_sb   #(.width(width))  notif_sb;

  task run;
    $display("[%g]  El Agente fue inicializado", $time);

    forever begin
      #1
      if (gen_agnt_mbx.num() > 0) begin

        gen_agnt_mbx.get(transaccion);
        transaccion.print("Agente: transacción recibida del Generador");

        agnt_drv_mbx.put(transaccion);
        transaccion.print("Agente: transacción enviada al Driver");
        $display("[%g]  Agente: transacciones pendientes en agnt_drv_mbx = %0d",
                 $time, agnt_drv_mbx.num());

        // Notificar al ScoreBoard para que lleve el conteo de transacciones esperadas
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
