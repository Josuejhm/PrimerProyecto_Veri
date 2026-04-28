 /////////////////////////////////////////////////////////////////////////////////////////////////////////////
 // Driver: se encarga de manejar las entradas de la FIFO                                                   //
 /////////////////////////////////////////////////////////////////////////////////////////////////////////////
class driver #(parameter width =16);
  virtual fifo_if #(.width(width)) vif;    // Puntero a la interfaz virtual de la FIFO
  trans_fifo_mbx agnt_drv_mbx;             // Mailbox que comunica el Agent con el Driver. Recibe las transacciones del Agent
  int espera;                              // Contador de los ciclos de retardo

  task run();
    $display("[%g]  El driver fue inicializado",$time);
    // Reset inicial: mantener rst=1 por un ciclo completo y luego soltar
    vif.rst  = 1;
    vif.push = 0;
    vif.pop  = 0;
    vif.dato_in = 0;
    @(posedge vif.clk);
    @(posedge vif.clk);
    vif.rst = 0;

    forever begin
      trans_fifo #(.width(width)) transaction; 

      // Colocar en 0 todas las señales activas al inicio de cada transacción
      vif.push = 0;
      vif.rst = 0;
      vif.pop = 0;
      vif.dato_in = 0;

      $display("[%g] el Driver espera por una transacción",$time);
      espera = 0;
      @(posedge vif.clk);

      // Se bloquea hasta que haya un transacción del Agent
      agnt_drv_mbx.get(transaction);
      transaction.print("Driver: Transaccion recibida");
      $display("Transacciones pendientes en el mbx agnt_drv = %g",agnt_drv_mbx.num());

      // Esperar el número de ciclos de retardo que se indique en la transacción.
      // dato_in solo se mantiene durante el retardo si la transaccion escribe datos.
      while(espera < transaction.retardo)begin
        @(posedge vif.clk);
        espera = espera+1;
        if (transaction.tipo == escritura || transaction.tipo == lectura_escritura)
          vif.dato_in = transaction.dato;
      end

      // Activar la señal correspondiente dependiendo del tipo de transacción
      case(transaction.tipo)
	      lectura: begin
	        // Activa pop en el ciclo actual; el flanco final del loop cierra la transaccion
	        vif.pop = 1;
	        transaction.tiempo = $time;
	        transaction.print("Driver: Transaccion lectura ejecutada");
	      end
	      escritura: begin
	        vif.push = 1;
	        transaction.tiempo = $time;
	        transaction.print("Driver: Transaccion escritura ejecutada");
	      end
	      reset: begin
	        vif.rst = 1;
	        transaction.tiempo = $time;
	        transaction.print("Driver: Transaccion reset ejecutada");
	      end
	      lectura_escritura: begin   // Activa push y pop en el mismo ciclo
	        vif.push    = 1;
	        vif.pop     = 1;
	        vif.dato_in = transaction.dato;
	        transaction.tiempo = $time;
	        transaction.print("Driver: Transaccion lectura_escritura ejecutada");
	      end
  
	      default: begin
	        $display("[%g] Driver Error: la transacción recibida no tiene tipo valido",$time);
	        $finish;
	      end 
	    endcase    
	  @(posedge vif.clk);
    end
  endtask
endclass