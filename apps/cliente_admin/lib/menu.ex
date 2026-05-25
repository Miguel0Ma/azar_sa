defmodule ClienteAdmin.Menu do

  # ── Punto de entrada público ──────────────────────────────────────────────
  def principal do
    ClienteAdmin.main()
  end

  # Llamado por ClienteAdmin.main() tras autenticar exitosamente.
  def iniciar(admin) do
    loop(admin)
  end

  # ── Loop interno del menú ─────────────────────────────────────────────────
  defp loop(admin) do
    IO.puts("""

    ╔══════════════════════════════════════╗
    ║  RIO — #{String.pad_trailing("Hola, #{admin["nombre"]}", 30)}║
    ╠══════════════════════════════════════╣
    ║  SORTEOS                             ║
    ║   1. Crear sorteo                    ║
    ║   2. Listar sorteos                  ║
    ║   3. Eliminar sorteo                 ║
    ║   4. Consultar clientes de sorteo    ║
    ║   5. Consultar ingresos de sorteo    ║
    ╠══════════════════════════════════════╣
    ║  PREMIOS                             ║
    ║   6. Agregar premio a sorteo         ║
    ║   7. Listar premios por sorteo       ║
    ║   8. Eliminar premio                 ║
    ╠══════════════════════════════════════╣
    ║  EJECUCIÓN                           ║
    ║   9. Ejecutar sorteo                 ║
    ║  10. Actualizar fecha del sistema    ║
    ╠══════════════════════════════════════╣
    ║  REPORTES                            ║
    ║  11. Premios entregados (pasados)    ║
    ║  12. Balance de todos los sorteos    ║
    ╠══════════════════════════════════════╣
    ║  CUENTAS                             ║
    ║  13. Crear cuenta administrador      ║
    ║  14. Listar administradores          ║
    ║  15. Eliminar administrador          ║
    ║  16. Listar jugadores                ║
    ║  17. Ver detalle de jugador          ║
    ║  18. Eliminar jugador                ║
    ╠══════════════════════════════════════╣
    ║   0. Salir                           ║
    ╚══════════════════════════════════════╝
    """)

    opcion = IO.gets("Seleccione una opción: ") |> String.trim()

    case opcion do
      "1"  -> crear_sorteo(admin)
      "2"  -> listar_sorteos(admin)
      "3"  -> eliminar_sorteo(admin)
      "4"  -> consultar_clientes(admin)
      "5"  -> consultar_ingresos(admin)
      "6"  -> agregar_premio(admin)
      "7"  -> listar_premios(admin)
      "8"  -> eliminar_premio(admin)
      "9"  -> ejecutar_sorteo(admin)
      "10" -> actualizar_fecha(admin)
      "11" -> premios_entregados(admin)
      "12" -> balance_sorteos(admin)
      "13" -> crear_admin(admin)
      "14" -> listar_admins(admin)
      "15" -> eliminar_admin(admin)
      "16" -> listar_jugadores(admin)
      "17" -> ver_jugador(admin)
      "18" -> eliminar_jugador(admin)
      "0"  -> IO.puts("¡Hasta luego!")
      _    -> IO.puts("Opción no válida."); loop(admin)
    end
  end

  # ══════════════════════════════════════════════════════════════════════════
  # GESTIÓN DE SORTEOS
  # ══════════════════════════════════════════════════════════════════════════

  defp crear_sorteo(admin) do
    IO.puts("\n--- CREAR NUEVO SORTEO ---")
    id              = IO.gets("ID único del sorteo: ")                     |> String.trim()
    nombre          = IO.gets("Nombre del sorteo: ")                       |> String.trim()
    fecha           = IO.gets("Fecha (AAAA-MM-DD): ")                      |> String.trim()
    valor           = IO.gets("Valor billete completo ($): ")              |> String.trim() |> String.to_integer()
    cant_fracciones = IO.gets("Cantidad de fracciones por billete: ")      |> String.trim() |> String.to_integer()
    cant_billetes   = IO.gets("Cantidad total de billetes: ")              |> String.trim() |> String.to_integer()

    nuevo = %Servidor.Modelos.Sorteo{
      id: id, nombre: nombre, fecha: fecha,
      valor_billete: valor, cant_fracciones: cant_fracciones, cant_billetes: cant_billetes
    }

    case Servidor.Almacenamiento.guardar_sorteo(nuevo) do
      :ok ->
        Servidor.SupervisorSorteos.iniciar_sorteo(nuevo)
        IO.puts("\n✔  Sorteo '#{nombre}' creado e iniciado.")
      _ ->
        IO.puts("\n✘  Error al guardar el sorteo.")
    end

    loop(admin)
  end

  defp listar_sorteos(admin) do
    IO.puts("\n--- LISTADO DE SORTEOS (ordenados por fecha) ---")
    sorteos = Servidor.Almacenamiento.listar_sorteos()

    if Enum.empty?(sorteos) do
      IO.puts("No hay sorteos registrados.")
    else
      Enum.each(sorteos, fn s ->
        estado_label = if s.estado == "jugado", do: "[JUGADO]", else: "[PENDIENTE]"
        IO.puts("\n  ID: #{s.id} | #{s.nombre} | Fecha: #{s.fecha} | #{estado_label}")
        IO.puts("  Billete: $#{s.valor_billete} | Fracciones: #{s.cant_fracciones} | Billetes totales: #{s.cant_billetes}")

        premios = Map.get(s, :premios, [])
        if Enum.empty?(premios) do
          IO.puts("  Premios: Sin premios registrados")
        else
          IO.puts("  Premios:")
          Enum.each(premios, fn p ->
            ganador = Map.get(p, :numero_ganador) || Map.get(p, "numero_ganador")
            nombre_p = Map.get(p, :nombre) || Map.get(p, "nombre")
            valor_p  = Map.get(p, :valor)  || Map.get(p, "valor")
            if ganador do
              IO.puts("    • #{nombre_p} ($#{valor_p}) → Ganó billete ##{ganador}")
            else
              IO.puts("    • #{nombre_p} ($#{valor_p})")
            end
          end)
        end
      end)
    end

    loop(admin)
  end

  defp eliminar_sorteo(admin) do
    IO.puts("\n--- ELIMINAR SORTEO ---")
    IO.puts("⚠  Solo se puede eliminar si el sorteo NO tiene premios.")
    id = IO.gets("ID del sorteo a eliminar: ") |> String.trim()

    case Servidor.Almacenamiento.eliminar_sorteo(id) do
      :ok           -> IO.puts("\n✔  Sorteo #{id} eliminado.")
      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    loop(admin)
  end

  defp consultar_clientes(admin) do
    IO.puts("\n--- CLIENTES DE UN SORTEO ---")
    id = IO.gets("ID del sorteo: ") |> String.trim()

    case Servidor.Almacenamiento.cargar_sorteo(id) do
      {:ok, sorteo} ->
        billetes        = Map.get(sorteo, :billetes_vendidos, %{})
        cant_fracciones = Map.get(sorteo, :cant_fracciones, 1)

        if map_size(billetes) == 0 do
          IO.puts("Este sorteo no tiene clientes aún.")
        else
          {completos, por_fraccion} =
            Enum.reduce(billetes, {MapSet.new(), MapSet.new()}, fn {_num, fracs}, {comp, frac} ->
              cedulas = Map.values(fracs)
              Enum.reduce(Enum.uniq(cedulas), {comp, frac}, fn cedula, {c, f} ->
                propias = Enum.count(cedulas, &(&1 == cedula))
                if propias == cant_fracciones and map_size(fracs) == cant_fracciones do
                  {MapSet.put(c, cedula), f}
                else
                  {c, MapSet.put(f, cedula)}
                end
              end)
            end)

          IO.puts("\n  📋 Compradores de BILLETE COMPLETO:")
          mostrar_clientes(MapSet.to_list(completos))

          IO.puts("\n  📋 Compradores por FRACCIÓN:")
          mostrar_clientes(MapSet.to_list(por_fraccion))
        end

      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    loop(admin)
  end

  defp mostrar_clientes([]), do: IO.puts("    (ninguno)")
  defp mostrar_clientes(cedulas) do
    cedulas |> Enum.sort() |> Enum.each(fn cedula ->
      nombre = case Servidor.Almacenamiento.cargar_jugador(cedula) do
        {:ok, j} -> j.nombre
        _        -> "(sin registro)"
      end
      IO.puts("    • #{nombre} — Cédula: #{cedula}")
    end)
  end

  defp consultar_ingresos(admin) do
    IO.puts("\n--- INGRESOS POR SORTEO ---")
    id = IO.gets("ID del sorteo: ") |> String.trim()

    case Servidor.Almacenamiento.cargar_sorteo(id) do
      {:ok, sorteo} ->
        total = calcular_ingresos(sorteo)
        IO.puts("\n  Sorteo: #{sorteo.nombre}")
        IO.puts("  Precio fracción: $#{precio_fraccion(sorteo)}")
        IO.puts("  Total recaudado: $#{total}")
      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    loop(admin)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # GESTIÓN DE PREMIOS
  # ══════════════════════════════════════════════════════════════════════════

  defp agregar_premio(admin) do
    IO.puts("\n--- AGREGAR PREMIO A UN SORTEO ---")
    id_sorteo = IO.gets("ID del sorteo: ")             |> String.trim()
    nombre    = IO.gets("Nombre del premio: ")          |> String.trim()
    valor     = IO.gets("Valor del premio ($): ")       |> String.trim() |> String.to_integer()

    case Servidor.ServidorSorteo.agregar_premio(id_sorteo, nombre, valor) do
      :ok           -> IO.puts("\n✔  Premio '#{nombre}' agregado al sorteo #{id_sorteo}.")
      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    loop(admin)
  end

  defp listar_premios(admin) do
    IO.puts("\n--- PREMIOS POR SORTEO (ordenados por fecha) ---")

    Servidor.Almacenamiento.listar_sorteos()
    |> Enum.each(fn s ->
      premios = Map.get(s, :premios, [])
      unless Enum.empty?(premios) do
        IO.puts("\n  #{s.nombre} (#{s.fecha}) — ID: #{s.id}")
        Enum.each(premios, fn p ->
          nombre_p = Map.get(p, :nombre) || Map.get(p, "nombre")
          valor_p  = Map.get(p, :valor)  || Map.get(p, "valor")
          IO.puts("    • #{nombre_p}: $#{valor_p}")
        end)
      end
    end)

    loop(admin)
  end

  defp eliminar_premio(admin) do
    IO.puts("\n--- ELIMINAR PREMIO ---")
    IO.puts(" Solo si el sorteo NO tiene clientes.")
    id_sorteo     = IO.gets("ID del sorteo: ")      |> String.trim()
    nombre_premio = IO.gets("Nombre del premio: ")  |> String.trim()

    case Servidor.ServidorSorteo.eliminar_premio(id_sorteo, nombre_premio) do
      :ok           -> IO.puts("\n✔  Premio '#{nombre_premio}' eliminado.")
      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    loop(admin)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # EJECUCIÓN
  # ══════════════════════════════════════════════════════════════════════════

  defp ejecutar_sorteo(admin) do
    IO.puts("\n--- EJECUTAR SORTEO ---")
    id = IO.gets("ID del sorteo a jugar: ") |> String.trim()

    case Servidor.ServidorSorteo.realizar_sorteo(id) do
      {:ok, premios} ->
        IO.puts("\n ¡SORTEO EJECUTADO!")
        Enum.each(premios, fn p ->
          nombre_p  = Map.get(p, :nombre)        || Map.get(p, "nombre")
          valor_p   = Map.get(p, :valor)          || Map.get(p, "valor")
          ganador_p = Map.get(p, :numero_ganador) || Map.get(p, "numero_ganador")
          IO.puts("  • #{nombre_p} ($#{valor_p}) → Billete ganador: ##{ganador_p}")
        end)
      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    loop(admin)
  end

  defp actualizar_fecha(admin) do
    IO.puts("\n--- ACTUALIZAR FECHA DEL SISTEMA ---")
    fecha = IO.gets("Nueva fecha simulada (AAAA-MM-DD): ") |> String.trim()

    IO.puts("\n[PROCESANDO] Ejecutando sorteos pendientes hasta #{fecha}...")
    Servidor.Almacenamiento.procesar_sorteos_por_fecha(fecha)
    IO.puts("✔  Sorteos vencidos ejecutados.")

    loop(admin)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # REPORTES
  # ══════════════════════════════════════════════════════════════════════════

  defp premios_entregados(admin) do
    IO.puts("\n--- PREMIOS ENTREGADOS EN SORTEOS PASADOS ---")

    jugados = Servidor.Almacenamiento.listar_sorteos()
              |> Enum.filter(&(&1.estado == "jugado"))

    if Enum.empty?(jugados) do
      IO.puts("No hay sorteos jugados aún.")
    else
      Enum.each(jugados, fn s ->
        ingresos = calcular_ingresos(s)
        IO.puts("\n  ══ #{s.nombre} (#{s.fecha}) ══")
        IO.puts("  Dinero recolectado: $#{ingresos}")

        premios  = Map.get(s, :premios, [])
        billetes = Map.get(s, :billetes_vendidos, %{})

        total_pagado = Enum.reduce(premios, 0, fn p, acc ->
          nombre_p  = Map.get(p, :nombre)        || Map.get(p, "nombre")
          valor_p   = Map.get(p, :valor)          || Map.get(p, "valor")
          ganador_p = Map.get(p, :numero_ganador) || Map.get(p, "numero_ganador")
          fracs_billete = Map.get(billetes, ganador_p, %{})

          if map_size(fracs_billete) > 0 do
            cedulas_ganadoras = Map.values(fracs_billete) |> Enum.uniq()
            nombres = Enum.map(cedulas_ganadoras, fn c ->
              case Servidor.Almacenamiento.cargar_jugador(c) do
                {:ok, j} -> j.nombre
                _        -> "Cédula #{c}"
              end
            end)
            IO.puts("  • #{nombre_p}: $#{valor_p} → ENTREGADO a #{Enum.join(nombres, ", ")} (billete ##{ganador_p})")
            acc + valor_p
          else
            IO.puts("  • #{nombre_p}: $#{valor_p} → Sin ganador (billete ##{ganador_p} no vendido)")
            acc
          end
        end)

        ganancia  = ingresos - total_pagado
        resultado = if ganancia >= 0, do: "GANANCIA", else: "PÉRDIDA"
        IO.puts("  Total premios pagados: $#{total_pagado}")
        IO.puts("  #{resultado}: $#{abs(ganancia)}")
      end)
    end

    loop(admin)
  end

  defp balance_sorteos(admin) do
    IO.puts("\n--- BALANCE DE TODOS LOS SORTEOS PASADOS ---")

    jugados = Servidor.Almacenamiento.listar_sorteos()
              |> Enum.filter(&(&1.estado == "jugado"))

    if Enum.empty?(jugados) do
      IO.puts("No hay sorteos jugados aún.")
    else
      total_acumulado = Enum.reduce(jugados, 0, fn s, acc_total ->
        ingresos = calcular_ingresos(s)
        premios  = Map.get(s, :premios, [])
        billetes = Map.get(s, :billetes_vendidos, %{})

        pagado = Enum.reduce(premios, 0, fn p, acc ->
          ganador_p = Map.get(p, :numero_ganador) || Map.get(p, "numero_ganador")
          valor_p   = Map.get(p, :valor)           || Map.get(p, "valor")
          if map_size(Map.get(billetes, ganador_p, %{})) > 0, do: acc + valor_p, else: acc
        end)

        ganancia  = ingresos - pagado
        resultado = if ganancia >= 0, do: "✔ GANANCIA", else: "✘ PÉRDIDA"
        IO.puts("  #{s.nombre} (#{s.fecha}): #{resultado} $#{abs(ganancia)}")
        acc_total + ganancia
      end)

      IO.puts("\n  ──────────────────────────────")
      if total_acumulado >= 0 do
        IO.puts("  GANANCIA TOTAL ACUMULADA: $#{total_acumulado}")
      else
        IO.puts("  PÉRDIDA TOTAL ACUMULADA:  $#{abs(total_acumulado)}")
      end
    end

    loop(admin)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # GESTIÓN DE CUENTAS
  # ══════════════════════════════════════════════════════════════════════════

  defp crear_admin(admin) do
    IO.puts("\n--- CREAR CUENTA ADMINISTRADOR ---")
    usuario = IO.gets("Nombre de usuario: ") |> String.trim()
    nombre  = IO.gets("Nombre completo: ")   |> String.trim()
    pass    = IO.gets("Contraseña: ")        |> String.trim()

    case Servidor.ServidorAutenticacionAdmin.registrar(usuario, pass, nombre) do
      :ok           -> IO.puts("\n✔  Administrador '#{usuario}' creado correctamente.")
      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    loop(admin)
  end

  defp listar_admins(admin) do
    IO.puts("\n--- ADMINISTRADORES REGISTRADOS ---")
    admins = Servidor.ServidorAutenticacionAdmin.listar()

    if Enum.empty?(admins) do
      IO.puts("No hay administradores registrados.")
    else
      Enum.each(admins, fn a ->
        marca = if a["usuario"] == admin["usuario"], do: " ← (tú)", else: ""
        IO.puts("  • #{a["nombre"]} | Usuario: #{a["usuario"]}#{marca}")
      end)
    end

    loop(admin)
  end

  defp eliminar_admin(admin) do
    IO.puts("\n--- ELIMINAR ADMINISTRADOR ---")
    IO.puts("⚠  No puedes eliminarte a ti mismo ni al último admin.")
    usuario = IO.gets("Usuario a eliminar: ") |> String.trim()

    case Servidor.ServidorAutenticacionAdmin.eliminar(usuario, admin["usuario"]) do
      :ok           -> IO.puts("\n✔  Administrador '#{usuario}' eliminado.")
      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    loop(admin)
  end

  defp listar_jugadores(admin) do
    IO.puts("\n--- JUGADORES REGISTRADOS ---")
    jugadores = Servidor.Almacenamiento.listar_jugadores()

    if Enum.empty?(jugadores) do
      IO.puts("No hay jugadores registrados.")
    else
      IO.puts("  #{"Nombre"          |> String.pad_trailing(25)} #{"Cédula" |> String.pad_trailing(15)} Compras")
      IO.puts("  #{String.duplicate("─", 50)}")
      Enum.each(jugadores, fn j ->
        compras = length(j.historial_compras)
        IO.puts("  #{String.pad_trailing(j.nombre, 25)} #{String.pad_trailing(j.cedula, 15)} #{compras}")
      end)
      IO.puts("\n  Total: #{length(jugadores)} jugador(es)")
    end

    loop(admin)
  end

  defp ver_jugador(admin) do
    IO.puts("\n--- DETALLE DE JUGADOR ---")
    cedula = IO.gets("Cédula del jugador: ") |> String.trim()

    case Servidor.Almacenamiento.cargar_jugador(cedula) do
      {:ok, j} ->
        IO.puts("\n  Nombre  : #{j.nombre}")
        IO.puts("  Cédula  : #{j.cedula}")
        IO.puts("  Tarjeta : #{j.tarjeta_credito}")
        IO.puts("  Compras : #{length(j.historial_compras)}")

        unless Enum.empty?(j.historial_compras) do
          IO.puts("  Historial:")
          Enum.each(j.historial_compras, fn c ->
            IO.puts("    • #{c["nombre_sorteo"]} | Billete ##{c["numero_billete"]} | #{c["fracciones"]} frac. | $#{c["monto_pagado"]}")
          end)
        end

        IO.puts("  Notificaciones: #{length(j.notificaciones)}")

      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    loop(admin)
  end

  defp eliminar_jugador(admin) do
    IO.puts("\n--- ELIMINAR JUGADOR ---")
    IO.puts("⚠  Solo si el jugador NO tiene compras registradas.")
    cedula = IO.gets("Cédula del jugador: ") |> String.trim()

    case Servidor.Almacenamiento.eliminar_jugador(cedula) do
      :ok           -> IO.puts("\n✔  Jugador eliminado correctamente.")
      {:error, msg} -> IO.puts("\n✘  #{msg}")
    end

    loop(admin)
  end

  # ══════════════════════════════════════════════════════════════════════════
  # HELPERS PRIVADOS
  # ══════════════════════════════════════════════════════════════════════════

  defp precio_fraccion(sorteo) do
    valor = Map.get(sorteo, :valor_billete)  || Map.get(sorteo, "valor_billete")  || 0
    frac  = Map.get(sorteo, :cant_fracciones) || Map.get(sorteo, "cant_fracciones") || 1
    div(valor, frac)
  end

  defp calcular_ingresos(sorteo) do
    billetes    = Map.get(sorteo, :billetes_vendidos, %{})
    precio_frac = precio_fraccion(sorteo)
    Enum.reduce(billetes, 0, fn {_num, fracs}, acc ->
      acc + map_size(fracs) * precio_frac
    end)
  end
end
