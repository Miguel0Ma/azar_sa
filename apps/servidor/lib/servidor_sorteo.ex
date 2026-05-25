defmodule Servidor.ServidorSorteo do
  use GenServer
  alias Servidor.Almacenamiento

  # 1. Funciones de la Interfaz (públicas)
  def start_link(sorteo) do
    GenServer.start_link(__MODULE__, sorteo, name: via_tuple(sorteo.id))
  end

  def agregar_premio(id_sorteo, nombre_premio, valor_premio) do
    case :global.whereis_name({:sorteo, id_sorteo}) do
      :undefined ->
        {:error, "El sorteo no existe o no está activo."}
      _pid ->
        GenServer.call(via_tuple(id_sorteo), {:agregar_premio, nombre_premio, valor_premio})
    end
  end

  def consultar_estado(id) do
    case :global.whereis_name({:sorteo, id}) do
      :undefined ->
        {:error, "El sorteo con ID '#{id}' no existe."}

      _pid ->
        GenServer.call(via_tuple(id), :ver_estado)
    end
  end

  def comprar_billete(id_sorteo, numero_billete, id_jugador, fracciones) do
    # Verificamos si existe un proceso registrado globalmente con ese ID de sorteo
    case :global.whereis_name({:sorteo, id_sorteo}) do
      :undefined ->
        # Si devuelve :undefined, el sorteo no existe o no está activo
        {:error, "El sorteo con ID '#{id_sorteo}' no existe o no está activo en el servidor."}

      _pid ->
        # Si encuentra el PID, el proceso está vivo y podemos llamarlo con seguridad
        GenServer.call(via_tuple(id_sorteo), {:comprar, numero_billete, id_jugador, fracciones})
    end
  end

  def realizar_sorteo(id_sorteo) do
    GenServer.call(via_tuple(id_sorteo), :ejecutar_sorteo)
  end

  def eliminar_premio(id_sorteo, nombre_premio) do
    case :global.whereis_name({:sorteo, id_sorteo}) do
      :undefined -> {:error, "El sorteo no existe o no está activo"}
      _pid -> GenServer.call(via_tuple(id_sorteo), {:eliminar_premio, nombre_premio})
    end
  end

  def devolver_compra(id_sorteo, numero_billete, cedula) do
    case :global.whereis_name({:sorteo, id_sorteo}) do
      :undefined -> {:error, "El sorteo no existe o no está activo"}
      _pid -> GenServer.call(via_tuple(id_sorteo), {:devolver, numero_billete, cedula})
    end
  end

  # 2. El Callback Init
  @impl true
  def init(sorteo) do
    IO.puts("--- [INFO] Proceso iniciado para el sorteo: #{sorteo.nombre} ---")
    {:ok, sorteo}
  end

  # 3. BLOQUE DE HANDLE_CALLS (Todos bien juntitos aquí)
@impl true
  def handle_call({:agregar_premio, nombre, valor}, _from, sorteo) do
    if sorteo.estado == "jugado" do
      # --- BITÁCORA ---
      Servidor.Bitacora.registrar_operacion("Agregar premio a Sorteo #{sorteo.id}", "NEGADO - Sorteo ya jugado")
      {:reply, {:error, "No se pueden añadir premios a un sorteo que ya fue jugado."}, sorteo}
    else
      nuevo_premio = %Servidor.Modelos.Premio{
        nombre: nombre,
        valor: valor,
        numero_ganador: nil
      }

      # Añadimos el premio a la lista del sorteo
      nuevos_premios = sorteo.premios ++ [nuevo_premio]

      # Actualizamos el estado completo manteniendo el Struct
      nuevo_estado = %{sorteo | premios: nuevos_premios}

      # Persistimos en el JSON
      Servidor.Almacenamiento.guardar_sorteo(nuevo_estado)

      # --- BITÁCORA ---
      Servidor.Bitacora.registrar_operacion("Agregar premio '#{nombre}' ($#{valor}) a Sorteo #{sorteo.id}", "OK")

      {:reply, :ok, nuevo_estado}
    end
  end

  @impl true
  def handle_call(:ver_estado, _from, sorteo) do
    {:reply, sorteo, sorteo}
  end

  @impl true
  def handle_call({:comprar, numero_billete, jugador_cedula, fracciones_a_comprar}, _from, sorteo) do
    # Normalizar siempre a 4 dígitos para consistencia con ver_numeros_disponibles
    numero_billete = String.pad_leading(numero_billete, 4, "0")
    numero_int = String.to_integer(numero_billete)

    cond do
      sorteo.estado == "jugado" ->
        # --- BITÁCORA ---
        Servidor.Bitacora.registrar_operacion(
          "Compra Jugador #{jugador_cedula} en Sorteo #{sorteo.id} (Num: #{numero_billete})",
          "NEGADO - Sorteo ya fue jugado"
        )

        {:reply, {:error, "El sorteo ya cerró y fue jugado. No se permiten más compras."}, sorteo}

      numero_int < 0 or numero_int >= sorteo.cant_billetes ->
        # --- BITÁCORA ---
        Servidor.Bitacora.registrar_operacion(
          "Compra Jugador #{jugador_cedula} en Sorteo #{sorteo.id} (Num: #{numero_billete})",
          "NEGADO - Número fuera de rango"
        )

        {:reply,
         {:error,
          "Número de billete fuera de rango. Máximo permitido: #{sorteo.cant_billetes - 1}"},
         sorteo}

      true ->
        fracciones_ocupadas = Map.get(sorteo.billetes_vendidos, numero_billete, %{})
        cant_ocupadas = map_size(fracciones_ocupadas)
        cant_disponibles = sorteo.cant_fracciones - cant_ocupadas

        if fracciones_a_comprar > cant_disponibles do
          # --- BITÁCORA ---
          Servidor.Bitacora.registrar_operacion(
            "Compra Jugador #{jugador_cedula} en Sorteo #{sorteo.id} (Num: #{numero_billete}, Frac: #{fracciones_a_comprar})",
            "NEGADO - Fracciones insuficientes (Disponibles: #{cant_disponibles})"
          )

          {:reply,
           {:error, "No hay suficientes fracciones disponibles. Quedan: #{cant_disponibles}"},
           sorteo}
        else
          nuevas_fracciones =
            Enum.reduce(
              (cant_ocupadas + 1)..(cant_ocupadas + fracciones_a_comprar),
              fracciones_ocupadas,
              fn i, acc ->
                Map.put(acc, "#{i}", jugador_cedula)
              end
            )

          nuevos_billetes_vendidos =
            Map.put(sorteo.billetes_vendidos, numero_billete, nuevas_fracciones)

          nuevo_estado = %Servidor.Modelos.Sorteo{
            id: sorteo.id,
            nombre: sorteo.nombre,
            fecha: sorteo.fecha,
            valor_billete: sorteo.valor_billete,
            cant_fracciones: sorteo.cant_fracciones,
            cant_billetes: sorteo.cant_billetes,
            billetes_vendidos: nuevos_billetes_vendidos,
            estado: sorteo.estado,
            premios: sorteo.premios
          }

          Servidor.Almacenamiento.guardar_sorteo(nuevo_estado)

          # Registrar en historial del jugador
          precio_frac = div(sorteo.valor_billete, sorteo.cant_fracciones)
          entrada = %{
            "id_sorteo"      => sorteo.id,
            "nombre_sorteo"  => sorteo.nombre,
            "numero_billete" => numero_billete,
            "fracciones"     => fracciones_a_comprar,
            "monto_pagado"   => fracciones_a_comprar * precio_frac
          }
          case Servidor.Almacenamiento.cargar_jugador(jugador_cedula) do
            {:ok, jugador} ->
              actualizado = %{jugador | historial_compras: jugador.historial_compras ++ [entrada]}
              Servidor.Almacenamiento.guardar_jugador(actualizado)
            _ -> :ok
          end

          # --- BITÁCORA ---
          Servidor.Bitacora.registrar_operacion(
            "Compra Jugador #{jugador_cedula} en Sorteo #{sorteo.id} (Num: #{numero_billete}, Frac: #{fracciones_a_comprar})",
            "OK"
          )

          {:reply, :ok, nuevo_estado}
        end
    end
  end

 @impl true
  def handle_call(:ejecutar_sorteo, _from, sorteo) do
    if sorteo.estado == "jugado" do
      {:reply, {:error, "Este sorteo ya fue jugado anteriormente"}, sorteo}
    else
      # 1. Recorrer cada premio y asignarle un número aleatorio de 4 cifras (ej: "0042")
      nuevos_premios = Enum.map(sorteo.premios, fn premio ->
        num_aleatorio = :rand.uniform(sorteo.cant_billetes) - 1
        num_ganador_str = String.pad_leading("#{num_aleatorio}", 4, "0")

        %{premio | numero_ganador: num_ganador_str}
      end)

      # 2. Actualizar el estado del sorteo a "jugado" con sus premios ganadores
      nuevo_estado = %{sorteo | estado: "jugado", premios: nuevos_premios}

      # 3. Persistir los resultados finales en el archivo JSON
      Servidor.Almacenamiento.guardar_sorteo(nuevo_estado)

      # --- BITÁCORA ---
      Servidor.Bitacora.registrar_operacion("Ejecución Automática de Sorteo ID: #{sorteo.id}", "OK - Sorteo Cerrado con Éxito")

      # 4. Enviar notificaciones a los ganadores
      Enum.each(nuevos_premios, fn premio ->
        fracs_billete = Map.get(sorteo.billetes_vendidos, premio.numero_ganador, %{})
        cedulas = Map.values(fracs_billete) |> Enum.uniq()
        Enum.each(cedulas, fn cedula ->
          case Servidor.Almacenamiento.cargar_jugador(cedula) do
            {:ok, jugador} ->
              notif = "🎉 Ganaste '#{premio.nombre}' ($#{premio.valor}) con el billete ##{premio.numero_ganador} en '#{sorteo.nombre}'"
              actualizado = %{jugador | notificaciones: jugador.notificaciones ++ [notif]}
              Servidor.Almacenamiento.guardar_jugador(actualizado)
            _ -> :ok
          end
        end)
      end)

      # 5. Retornar el estado actualizado para que el administrador vea quién ganó
      {:reply, {:ok, nuevos_premios}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:devolver, numero_billete, cedula}, _from, sorteo) do
    numero_billete = String.pad_leading(numero_billete, 4, "0")
    if sorteo.estado == "jugado" do
      Servidor.Bitacora.registrar_operacion(
        "Devolución Jugador #{cedula} Sorteo #{sorteo.id} (Num: #{numero_billete})",
        "NEGADO - Sorteo ya jugado"
      )
      {:reply, {:error, "No se puede devolver: el sorteo ya fue jugado"}, sorteo}
    else
      fracs = Map.get(sorteo.billetes_vendidos, numero_billete, %{})
      cedulas_en_billete = Map.values(fracs)

      if cedula not in cedulas_en_billete do
        {:reply, {:error, "No tienes fracciones en el billete ##{numero_billete}"}, sorteo}
      else
        cant_devueltas = Enum.count(cedulas_en_billete, &(&1 == cedula))
        fracs_restantes = Map.reject(fracs, fn {_k, v} -> v == cedula end)

        nuevos_billetes =
          if map_size(fracs_restantes) == 0 do
            Map.delete(sorteo.billetes_vendidos, numero_billete)
          else
            nuevas_fracs =
              fracs_restantes
              |> Map.values()
              |> Enum.with_index(1)
              |> Enum.into(%{}, fn {c, i} -> {"#{i}", c} end)
            Map.put(sorteo.billetes_vendidos, numero_billete, nuevas_fracs)
          end

        nuevo_estado = %{sorteo | billetes_vendidos: nuevos_billetes}
        Servidor.Almacenamiento.guardar_sorteo(nuevo_estado)

        # Eliminar entrada del historial del jugador
        case Servidor.Almacenamiento.cargar_jugador(cedula) do
          {:ok, jugador} ->
            nuevo_historial = Enum.reject(jugador.historial_compras, fn h ->
              h["id_sorteo"] == sorteo.id and h["numero_billete"] == numero_billete
            end)
            Servidor.Almacenamiento.guardar_jugador(%{jugador | historial_compras: nuevo_historial})
          _ -> :ok
        end

        Servidor.Bitacora.registrar_operacion(
          "Devolución Jugador #{cedula} Sorteo #{sorteo.id} (Num: #{numero_billete}, Frac: #{cant_devueltas})",
          "OK"
        )
        {:reply, {:ok, cant_devueltas}, nuevo_estado}
      end
    end
  end

  @impl true
  def handle_call({:eliminar_premio, nombre_premio}, _from, sorteo) do
    tiene_clientes = map_size(sorteo.billetes_vendidos) > 0

    if tiene_clientes do
      Servidor.Bitacora.registrar_operacion(
        "Eliminar Premio '#{nombre_premio}' de Sorteo #{sorteo.id}",
        "NEGADO - Sorteo tiene clientes"
      )
      {:reply, {:error, "No se puede eliminar: el sorteo ya tiene clientes registrados"}, sorteo}
    else
      nuevos_premios = Enum.reject(sorteo.premios, fn p ->
        nombre_p = Map.get(p, :nombre) || Map.get(p, "nombre")
        nombre_p == nombre_premio
      end)

      if length(nuevos_premios) == length(sorteo.premios) do
        {:reply, {:error, "No se encontró el premio '#{nombre_premio}'"}, sorteo}
      else
        nuevo_estado = %{sorteo | premios: nuevos_premios}
        Servidor.Almacenamiento.guardar_sorteo(nuevo_estado)
        Servidor.Bitacora.registrar_operacion(
          "Eliminar Premio '#{nombre_premio}' de Sorteo #{sorteo.id}",
          "OK"
        )
        {:reply, :ok, nuevo_estado}
      end
    end
  end

  # 4. Funciones Auxiliares Privadas (Al puro final)
  defp via_tuple(id), do: {:global, {:sorteo, id}}
end

# Fin del módulo
