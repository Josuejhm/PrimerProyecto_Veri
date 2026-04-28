////////////////////////////////////////////////////////////////////////////////////////////////////
// Generador: Este bloque se encarga de manejar ESCENARIOS de prueba para la FIFO.              //
// Recibe instrucciones de alto nivel desde el Test (via test_gen_mbx) y las convierte          //
// en secuencias de transacciones individuales (trans_fifo) que envía al Agente.               //
//                                                                                              //
// Escenarios soportados:                                                                        //
//   llenado_aleatorio  : Genera num_transacciones escrituras seguidas del mismo nº de lecturas //
//   trans_aleatoria    : Genera UNA transacción totalmente aleatoria                           //
//   trans_especifica   : Genera UNA transacción con parámetros fijos (caso esquina)            //
//   sec_trans_aleatorias: Genera una secuencia de num_transacciones transacciones aleatorias   //
////////////////////////////////////////////////////////////////////////////////////////////////////

class generator #(parameter width = 16, parameter depth = 8);

  // --- Mailboxes ---
  trans_fifo_mbx             gen_agnt_mbx;  // Mailbox del Generador al Agente (pck entre Gen y Agnt)
  comando_test_agent_mbx     test_gen_mbx;  // Mailbox del Test al Generador  (tst_gen_mbx)

  // --- Parámetros configurables desde el Test ---
  int            num_transacciones; // Número de transacciones en secuencias
  int            max_retardo;       // Retardo máximo aleatorio permitido
  int            ret_spec;          // Retardo para transacción específica
  tipo_trans     tpo_spec;          // Tipo para transacción específica
  bit [width-1:0] dto_spec;         // Dato para transacción específica

  // --- Variables internas ---
  instrucciones_agente           instruccion;   // Instrucción recibida del Test
  trans_fifo #(.width(width))    transaccion;   // Transacción generada

  // -----------------------------------------------------------------------
  // Constructor: valores por defecto razonables
  // -----------------------------------------------------------------------
  function new;
    num_transacciones = 2;
    max_retardo       = 10;
    ret_spec          = 0;
    tpo_spec          = escritura;
    dto_spec          = '0;
  endfunction

  // -----------------------------------------------------------------------
  // run: espera instrucciones del Test y genera secuencias de transacciones
  // -----------------------------------------------------------------------
  task run;
    $display("[%g]  El Generador fue inicializado", $time);

    forever begin
      #1  // Pequeño retardo para ceder tiempo a otros procesos

      if (test_gen_mbx.num() > 0) begin
        $display("[%g]  Generador: se recibe instruccion del Test", $time);
        test_gen_mbx.get(instruccion);

        case (instruccion)

          // ------------------------------------------------------------------
          // Escenario 1: Llenar el FIFO y luego vaciarlo
          // Primero genera num_transacciones escrituras, luego el mismo número
          // de lecturas para cubrir la transición lleno->vacío.
          // ------------------------------------------------------------------
          llenado_aleatorio: begin
            $display("[%g]  Generador: escenario llenado_aleatorio (%0d transacciones)", $time, num_transacciones);

            // Escrituras consecutivas
            for (int i = 0; i < num_transacciones; i++) begin
              transaccion             = new;
              transaccion.max_retardo = max_retardo;
              void'(transaccion.randomize());
              transaccion.tipo        = escritura;   // Forzar escritura
              transaccion.print("Generador: escritura generada");
              gen_agnt_mbx.put(transaccion);
            end

            // Lecturas consecutivas (vaciar lo que se llenó)
            for (int i = 0; i < num_transacciones; i++) begin
              transaccion             = new;
              void'(transaccion.randomize());
              transaccion.tipo        = lectura;    // Forzar lectura
              transaccion.print("Generador: lectura generada");
              gen_agnt_mbx.put(transaccion);
            end
          end

          // ------------------------------------------------------------------
          // Escenario 2: Una sola transacción completamente aleatoria
          // Tipo, dato y retardo se aleatorizan con las constraints definidas
          // en trans_fifo.
          // ------------------------------------------------------------------
          trans_aleatoria: begin
            $display("[%g]  Generador: escenario trans_aleatoria", $time);
            transaccion             = new;
            transaccion.max_retardo = max_retardo;
            void'(transaccion.randomize());
            transaccion.print("Generador: transacción aleatoria generada");
            gen_agnt_mbx.put(transaccion);
          end

          // ------------------------------------------------------------------
          // Escenario 3: Transacción específica (caso esquina)
          // Los parámetros ret_spec, tpo_spec, dto_spec deben ser fijados
          // por el Test antes de enviar esta instrucción.
          // ------------------------------------------------------------------
          trans_especifica: begin
            $display("[%g]  Generador: escenario trans_especifica (tipo=%s, dato=%0h)", $time, tpo_spec.name(), dto_spec);
            transaccion         = new;
            transaccion.tipo    = tpo_spec;
            transaccion.dato    = dto_spec;
            transaccion.retardo = ret_spec;
            transaccion.print("Generador: transacción específica generada");
            gen_agnt_mbx.put(transaccion);
          end

          // ------------------------------------------------------------------
          // Escenario 4: Secuencia de num_transacciones transacciones aleatorias
          // Cubre mezclado aleatorio de lecturas/escrituras para verificar
          // comportamiento general del FIFO.
          // ------------------------------------------------------------------
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

          // ------------------------------------------------------------------
          // Escenario 5: Secuencia de lectura/escritura simultáneas
          // Genera num_transacciones transacciones de tipo lectura_escritura
          // para verificar el comportamiento con push y pop activos al mismo tiempo.
          // ------------------------------------------------------------------
          sec_lect_escr: begin
            $display("[%g]  Generador: escenario sec_lect_escr (%0d transacciones)", $time, num_transacciones);
            for (int i = 0; i < num_transacciones; i++) begin
              transaccion             = new;
              transaccion.max_retardo = max_retardo;
              void'(transaccion.randomize());
              transaccion.tipo        = lectura_escritura;  // Forzar simultánea
              transaccion.print("Generador: transaccion lectura_escritura generada");
              gen_agnt_mbx.put(transaccion);
            end
          end

          // ------------------------------------------------------------------
          // Prueba base: secuencia completamente aleatoria
          //
          // Garantiza al menos una transaccion de cada tipo para que ninguna
          // semilla produzca una prueba degenerada. Luego completa el resto
          // con transacciones aleatorias ponderadas:
          //   escritura        40%
          //   lectura          35%
          //   lectura_escritura 15%
          //   reset            10%
          // ------------------------------------------------------------------
          prueba_base: begin
            begin
              int num_trans_pb;

              // Numero total aleatorio entre 16 y 32 transacciones
              num_trans_pb = $urandom_range(16, 32);

              $display("[%g]  Generador: escenario prueba_base (%0d transacciones aleatorias)",
                       $time, num_trans_pb);

              // Todas las transacciones son aleatorias ponderadas:
              //   escritura        40%
              //   lectura          35%
              //   lectura_escritura 15%
              //   reset            10%
              for (int i = 0; i < num_trans_pb; i++) begin
                tipo_trans tpo_fijo;
                int peso_local;
                transaccion             = new;
                transaccion.max_retardo = max_retardo;

                peso_local = $urandom_range(0, 99);
                if      (peso_local < 40) tpo_fijo = escritura;
                else if (peso_local < 75) tpo_fijo = lectura;
                else if (peso_local < 90) tpo_fijo = lectura_escritura;
                else                      tpo_fijo = reset;

                void'(transaccion.randomize() with {tipo == tpo_fijo;});

                transaccion.print("Generador: prueba_base aleatoria");
                gen_agnt_mbx.put(transaccion);
              end
            end
          end

          default: begin
            $display("[%g]  Generador: instruccion desconocida recibida, se ignora", $time);
          end

        endcase
      end // if mailbox not empty
    end // forever
  endtask

endclass