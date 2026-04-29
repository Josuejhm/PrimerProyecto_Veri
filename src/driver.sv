// Driver: traduce transacciones del Agent en señales de la interfaz del DUT.
// Aplica el retardo indicado por cada transaccion antes de activar la señal.
class driver #(parameter width =16);
  virtual fifo_if #(.width(width)) vif;
  trans_fifo_mbx agnt_drv_mbx;
  int espera;

  task run();
    $display("[%g]  El driver fue inicializado",$time);
    // Reset inicial de un ciclo al arrancar la simulacion
    vif.rst  = 1;
    vif.push = 0;
    vif.pop  = 0;
    vif.dato_in = 0;
    @(posedge vif.clk);
    @(posedge vif.clk);
    vif.rst = 0;

    forever begin
      trans_fifo #(.width(width)) transaction; 

      vif.push = 0;
      vif.rst = 0;
      vif.pop = 0;
      vif.dato_in = 0;

      $display("[%g] el Driver espera por una transacción",$time);
      espera = 0;
      @(posedge vif.clk);

      agnt_drv_mbx.get(transaction);
      transaction.print("Driver: Transaccion recibida");
      $display("Transacciones pendientes en el mbx agnt_drv = %g",agnt_drv_mbx.num());

      // Esperar los ciclos de retardo manteniendo dato_in si la transaccion escribe
      while(espera < transaction.retardo)begin
        @(posedge vif.clk);
        espera = espera+1;
        if (transaction.tipo == escritura || transaction.tipo == lectura_escritura)
          vif.dato_in = transaction.dato;
      end

      case(transaction.tipo)
        lectura: begin
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
        lectura_escritura: begin
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
