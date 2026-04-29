// Monitor: observa las señales del DUT en cada flanco de reloj y genera
// transacciones para el Checker. Detecta push, pop y reset independientemente,
// con prioridad a lectura_escritura cuando ambas señales estan activas.
// Las lecturas se reportan siempre (con o sin datos) para que el Checker
// pueda rastrear el puntero de lectura correctamente en casos de underflow.
class monitor #(parameter width =  16);
  virtual fifo_if #(.width(width)) vif;
  trans_fifo_mbx mon_chkr_mbx;

  task run();
    $display("[%g] El monitor fue inicializado", $time);

    forever begin
      trans_fifo #(.width(width)) transaction;
      @(posedge vif.clk);

      // Lectura/escritura simultanea: se revisa primero para generar
      // una sola transaccion en lugar de dos separadas
      if (vif.push && vif.pop) begin
        transaction            = new;
        transaction.tipo       = lectura_escritura;
        transaction.dato       = vif.dato_in;
        transaction.dato_leido = vif.dato_out;
        transaction.tiempo     = $time;
        if (vif.pndng)
          transaction.print("Monitor: transaccion lectura_escritura observada (FIFO con datos)");
        else
          transaction.print("Monitor: transaccion lectura_escritura observada (FIFO vacio)");
        mon_chkr_mbx.put(transaction);

      end else begin

        if (vif.pop) begin
          transaction            = new;
          transaction.tipo       = lectura;
          transaction.dato       = 0;
          transaction.dato_leido = vif.dato_out;
          transaction.tiempo     = $time;
          if (vif.pndng)
            transaction.print("Monitor: transaccion de lectura observada (FIFO con datos)");
          else
            transaction.print("Monitor: transaccion de lectura observada (FIFO vacio, underflow)");
          mon_chkr_mbx.put(transaction);
        end

        if (vif.push) begin
          transaction        = new;
          transaction.tipo   = escritura;
          transaction.dato   = vif.dato_in;
          transaction.tiempo = $time;
          transaction.print("Monitor: transaccion de escritura observada");
          mon_chkr_mbx.put(transaction);
        end
      end

      if (vif.rst) begin
        transaction = new;
        transaction.tipo   = reset;
        transaction.tiempo = $time;
        transaction.print("Monitor: transaccion de reset observada");
        mon_chkr_mbx.put(transaction);
      end
    end
  endtask
endclass
