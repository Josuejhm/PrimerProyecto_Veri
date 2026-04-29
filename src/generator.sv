// Clase auxiliar para el modo alternancia.
// randc garantiza que los cuatro patrones de maxima alternancia de bits
// se usen al menos una vez antes de repetirse.
class patron_randc #(parameter width = 16);
  randc bit [width-1:0] patron;
  constraint c_patron {
    patron inside {({width{1'b0}}),     // 0x0000
                   ({width/2{2'b01}}),  // 0x5555
                   ({width/2{2'b10}}),  // 0xAAAA
                   ({width{1'b1}})};    // 0xFFFF
  }
endclass

// Generador: recibe instrucciones del Test y produce secuencias de transacciones
// para el Agente. El escenario principal es prueba_base, que controla todos sus
// parametros mediante plusargs en tiempo de ejecucion:
//
//   +peso_escritura=N   porcentaje de escrituras      (default 40)
//   +peso_lectura=N     porcentaje de lecturas        (default 35)
//   +peso_lect_escr=N   porcentaje de lect_escritura  (default 15)
//   +peso_reset=N       porcentaje de resets          (default 10)
//   +n_trans_min=N      minimo de transacciones       (default 16)
//   +n_trans_max=N      maximo de transacciones       (default 32)
//   +retardo_min=N      minimo retardo en ciclos      (default 1)
//   +retardo_max=N      maximo retardo en ciclos      (default max_retardo-1)
//   +dato_min=N         valor minimo del dato         (default 0)
//   +dato_max=N         valor maximo del dato         (default 2^width-1)
//   +prefijo=N          escrituras forzadas antes de la prueba (default 0)
//   +alternancia=1      usa randc sobre {0x0000,0x5555,0xAAAA,0xFFFF} (default 0)
class generator #(parameter width = 16, parameter depth = 8);

  trans_fifo_mbx         gen_agnt_mbx;
  comando_test_agent_mbx test_gen_mbx;

  int             num_transacciones;
  int             max_retardo;
  int             ret_spec;
  tipo_trans      tpo_spec;
  bit [width-1:0] dto_spec;

  instrucciones_agente        instruccion;
  trans_fifo #(.width(width)) transaccion;

  function new;
    num_transacciones = 2;
    max_retardo       = 10;
    ret_spec          = 0;
    tpo_spec          = escritura;
    dto_spec          = '0;
  endfunction

  // Crea y envia una transaccion con tipo forzado y limites de retardo/dato parametrizables
  task enviar_trans(
    tipo_trans tpo,
    int        ret_min,
    int        ret_max,
    int        dat_min,
    int        dat_max
  );
    transaccion             = new;
    transaccion.max_retardo = max_retardo;
    transaccion.retardo_min = ret_min;
    transaccion.retardo_max = ret_max;
    transaccion.dato_min    = dat_min;
    transaccion.dato_max    = dat_max;
    void'(transaccion.randomize() with { tipo == tpo; });
    transaccion.print("Generador: prueba_base");
    gen_agnt_mbx.put(transaccion);
  endtask

  task run;
    $display("[%g]  El Generador fue inicializado", $time);

    forever begin
      #1
      if (test_gen_mbx.num() > 0) begin
        $display("[%g]  Generador: se recibe instruccion del Test", $time);
        test_gen_mbx.get(instruccion);

        case (instruccion)

          // N escrituras aleatorias seguidas de N lecturas
          llenado_aleatorio: begin
            $display("[%g]  Generador: escenario llenado_aleatorio (%0d transacciones)", $time, num_transacciones);
            for (int i = 0; i < num_transacciones; i++) begin
              transaccion             = new;
              transaccion.max_retardo = max_retardo;
              void'(transaccion.randomize());
              transaccion.tipo = escritura;
              transaccion.print("Generador: escritura generada");
              gen_agnt_mbx.put(transaccion);
            end
            for (int i = 0; i < num_transacciones; i++) begin
              transaccion             = new;
              void'(transaccion.randomize());
              transaccion.tipo = lectura;
              transaccion.print("Generador: lectura generada");
              gen_agnt_mbx.put(transaccion);
            end
          end

          // Una transaccion de tipo y dato aleatorio
          trans_aleatoria: begin
            $display("[%g]  Generador: escenario trans_aleatoria", $time);
            transaccion             = new;
            transaccion.max_retardo = max_retardo;
            void'(transaccion.randomize());
            transaccion.print("Generador: transacción aleatoria generada");
            gen_agnt_mbx.put(transaccion);
          end

          // Una transaccion con tipo y dato fijos
          trans_especifica: begin
            $display("[%g]  Generador: escenario trans_especifica (tipo=%s, dato=%0h)", $time, tpo_spec.name(), dto_spec);
            transaccion         = new;
            transaccion.tipo    = tpo_spec;
            transaccion.dato    = dto_spec;
            transaccion.retardo = ret_spec;
            transaccion.print("Generador: transacción específica generada");
            gen_agnt_mbx.put(transaccion);
          end

          // Secuencia de num_transacciones transacciones completamente aleatorias
          sec_trans_aleatorias: begin
            $display("[%g]  Generador: escenario sec_trans_aleatorias (%0d transacciones)", $time, num_transacciones);
            for (int i = 0; i < num_transacciones; i++) begin
              transaccion             = new;
              transaccion.max_retardo = max_retardo;
              void'(transaccion.randomize());
              transaccion.print("Generador: transacción en secuencia generada");
              gen_agnt_mbx.put(transaccion);
            end
          end

          // Secuencia de lectura_escritura simultaneas
          sec_lect_escr: begin
            $display("[%g]  Generador: escenario sec_lect_escr (%0d transacciones)", $time, num_transacciones);
            for (int i = 0; i < num_transacciones; i++) begin
              transaccion             = new;
              transaccion.max_retardo = max_retardo;
              void'(transaccion.randomize());
              transaccion.tipo = lectura_escritura;
              transaccion.print("Generador: transaccion lectura_escritura generada");
              gen_agnt_mbx.put(transaccion);
            end
          end

          // Prueba base: todos los parametros controlados por plusargs.
          // Flujo: prefijo de escrituras forzadas → fase aleatoria ponderada.
          // En modo alternancia los datos de escritura provienen de randc
          // sobre los cuatro patrones de maxima alternancia de bits.
          prueba_base: begin
            int peso_escritura, peso_lectura, peso_lect_escr, peso_reset;
            int n_trans_min, n_trans_max, num_trans;
            int ret_min, ret_max;
            int dat_min, dat_max;
            int prefijo;
            int alternancia;
            int acum_e, acum_l, acum_le;
            int peso;

            peso_escritura = 40; void'($value$plusargs("peso_escritura=%d",  peso_escritura));
            peso_lectura   = 35; void'($value$plusargs("peso_lectura=%d",    peso_lectura));
            peso_lect_escr = 15; void'($value$plusargs("peso_lect_escr=%d",  peso_lect_escr));
            peso_reset     = 10; void'($value$plusargs("peso_reset=%d",      peso_reset));

            n_trans_min = 16; void'($value$plusargs("n_trans_min=%d", n_trans_min));
            n_trans_max = 32; void'($value$plusargs("n_trans_max=%d", n_trans_max));

            ret_min = 1;             void'($value$plusargs("retardo_min=%d", ret_min));
            ret_max = max_retardo-1; void'($value$plusargs("retardo_max=%d", ret_max));

            dat_min = 0;                void'($value$plusargs("dato_min=%d", dat_min));
            dat_max = (1 << width) - 1; void'($value$plusargs("dato_max=%d", dat_max));

            prefijo     = 0; void'($value$plusargs("prefijo=%d",     prefijo));
            alternancia = 0; void'($value$plusargs("alternancia=%d", alternancia));

            acum_e  = peso_escritura;
            acum_l  = peso_escritura + peso_lectura;
            acum_le = peso_escritura + peso_lectura + peso_lect_escr;

            $display("[%g]  Generador: prueba_base | pesos E=%0d L=%0d LE=%0d R=%0d | trans=[%0d,%0d] | retardo=[%0d,%0d] | dato=[%0d,%0d] | prefijo=%0d | alternancia=%0d",
                     $time, peso_escritura, peso_lectura, peso_lect_escr, peso_reset,
                     n_trans_min, n_trans_max, ret_min, ret_max, dat_min, dat_max,
                     prefijo, alternancia);

            // Fase prefijo: escrituras forzadas para llevar el FIFO al estado deseado
            if (prefijo > 0) begin
              $display("[%g]  Generador: fase prefijo (%0d escrituras)", $time, prefijo);
              for (int i = 0; i < prefijo; i++)
                enviar_trans(escritura, ret_min, ret_max, dat_min, dat_max);
            end

            if (alternancia) begin
              // Las escrituras y lectura_escritura usan randc para ciclar los patrones
              begin
                patron_randc #(.width(width)) pr = new;
                int num_alt;
                num_alt = $urandom_range(n_trans_min, n_trans_max);
                $display("[%g]  Generador: alternancia - %0d transacciones ponderadas con patrones randc", $time, num_alt);
                for (int i = 0; i < num_alt; i++) begin
                  tipo_trans tpo_alt;
                  peso = $urandom_range(0, 99);
                  if      (peso < acum_e)  tpo_alt = escritura;
                  else if (peso < acum_l)  tpo_alt = lectura;
                  else if (peso < acum_le) tpo_alt = lectura_escritura;
                  else                     tpo_alt = reset;
                  if (tpo_alt == escritura || tpo_alt == lectura_escritura) begin
                    void'(pr.randomize());
                    enviar_trans(tpo_alt, ret_min, ret_max, pr.patron, pr.patron);
                  end else begin
                    enviar_trans(tpo_alt, ret_min, ret_max, dat_min, dat_max);
                  end
                end
              end

            end else begin
              // Fase aleatoria ponderada segun los pesos dados
              num_trans = $urandom_range(n_trans_min, n_trans_max);
              $display("[%g]  Generador: fase aleatoria (%0d transacciones)", $time, num_trans);
              for (int i = 0; i < num_trans; i++) begin
                tipo_trans tpo_sel;
                peso = $urandom_range(0, 99);
                if      (peso < acum_e)  tpo_sel = escritura;
                else if (peso < acum_l)  tpo_sel = lectura;
                else if (peso < acum_le) tpo_sel = lectura_escritura;
                else                     tpo_sel = reset;
                enviar_trans(tpo_sel, ret_min, ret_max, dat_min, dat_max);
              end
            end

          end

          default: begin
            $display("[%g]  Generador: instruccion desconocida, se ignora", $time);
          end

        endcase
      end
    end
  endtask

endclass
