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

            // Detectar si una lectura es valida
            if (vif.pop && vif.pndng) begin
                transaction = new;
                transaction.tipo = lectura;
                transaction.dato = vif.dato_out;   // Captura el dato que sale de la FIFO
                transaction.tiempo = $time;
                transaction.print("Monitor: transaccion de lectura observada");
                mon_chkr_mbx.put(transaction);
            end

            // Detectar una escritura
            if (vif.push) begin
                transaction = new;
                transaction.tipo = escritura;
                transaction.dato = vif.dato_in;     // Captura el dato que se va a escribir en la FIFO
                transaction.tiempo = $time;
                transaction.print("Monitor: transaccion de escritura observada");
                mon_chkr_mbx.put(transaction);
            end


            // Detectar un reset para que vaciar el Checker
            if (vif.rst) begin
                transaction = new;
                transaction.tipo = reset;
                transaction.tiempo = $time;
                transaction.print("Monitor: transaccion de reset observada");
                mon_chkr_mbx.put(transaction);
            end
        end
    endtask
 endclass