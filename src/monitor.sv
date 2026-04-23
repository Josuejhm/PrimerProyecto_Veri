/////////////////////////////////////////////////////////////////////////////////////////////////////////////
 // Monitor: se encarga de observar las salidas de la FIFO                                                 //
 ////////////////////////////////////////////////////////////////////////////////////////////////////////////

 class monitor #(parameter width =  16);
    virtual fifo_if #(.width(width)) vif;    // Puntero a la interfaz virtual de la FIFO
    trans_fifo_mbx mon_chkr_mbx;             // Mailbox al Checker

    task run();
        $display("[%g] El monitor fue inicializado", $time);

        forever begin
            trans_fifo #(.width(width)) transaction;
            @(posedge vif.clk);   // Observar la interfaz en cada flanco positivo de reloj

            // Detectar lectura/escritura simultánea PRIMERO (antes que los casos individuales)
            // Si no se revisa primero, los if separados generarían dos transacciones en vez de una
            if (vif.push && vif.pop) begin
                transaction            = new;
                transaction.tipo       = lectura_escritura;
                transaction.dato       = vif.dato_in;   // dato que SE ESCRIBE en el FIFO
                transaction.dato_leido = vif.dato_out;  // dato que SE LEE del FIFO
                transaction.tiempo     = $time;
                if (vif.pndng)
                    transaction.print("Monitor: transaccion lectura_escritura observada (FIFO con datos)");
                else
                    transaction.print("Monitor: transaccion lectura_escritura observada (FIFO vacio)");
                mon_chkr_mbx.put(transaction);

            end else begin
                // Lectura (pop): se reporta SIEMPRE (pndng=0 o 1) para que el checker
                // rastree rdPtr correctamente incluso en underflow.
                // dato=0 porque dato_in no aplica en lectura.
                // dato_leido captura lo que realmente sale del FIFO (dato_out).
                if (vif.pop) begin
                    transaction            = new;
                    transaction.tipo       = lectura;
                    transaction.dato       = 0;            // dato_in no aplica en lectura
                    transaction.dato_leido = vif.dato_out; // dato que SE LEE del FIFO
                    transaction.tiempo     = $time;
                    if (vif.pndng)
                        transaction.print("Monitor: transaccion de lectura observada (FIFO con datos)");
                    else
                        transaction.print("Monitor: transaccion de lectura observada (FIFO vacio, underflow)");
                    mon_chkr_mbx.put(transaction);
                end

                // Escritura (push)
                if (vif.push) begin
                    transaction        = new;
                    transaction.tipo   = escritura;
                    transaction.dato   = vif.dato_in; // dato que SE ESCRIBE en el FIFO
                    transaction.tiempo = $time;
                    transaction.print("Monitor: transaccion de escritura observada");
                    mon_chkr_mbx.put(transaction);
                end
            end

            // Detectar un reset para vaciar el Checker
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