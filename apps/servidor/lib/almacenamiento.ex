defmodule Servidor.Almacenamiento do
  alias Servidor.Modelos.Sorteo

  @doc """
  Guarda un sorteo en la carpeta 'datos' en formato JSON.
  """
  def guardar_sorteo(%Sorteo{id: id} = sorteo) do
    path = "datos/sorteo_#{id}.json"

    # Asegurar que la carpeta exista
    File.mkdir_p!("datos")

    # Convertir a JSON y guardar
    case Jason.encode(sorteo) do
      {:ok, json_string} -> File.write(path, json_string)
      {:error, _} -> {:error, "No se pudo codificar el sorteo"}
    end
  end

  def guardar_sorteo(sorteo) do
    carpeta = "datos"
    File.mkdir_p!(carpeta)
    ruta = Path.join(carpeta, "sorteo_#{sorteo.id}.json")

    case Jason.encode(sorteo) do
      {:ok, json_data} ->
        File.write(ruta, json_data)

        # --- NUEVO: Registrar en la bitácora ---
        Servidor.Bitacora.registrar_operacion("Crear/Actualizar Sorteo ID: #{sorteo.id}", "OK")
        :ok
      {:error, _reason} ->
        # --- NUEVO: Registrar fallo en la bitácora ---
        Servidor.Bitacora.registrar_operacion("Crear Sorteo ID: #{sorteo.id}", "NEGADO - Error Codificación JSON")
        {:error, "No se pudo codificar"}
    end
  end

  @doc """
  Lee un sorteo desde un archivo JSON.
  """
  def cargar_sorteo(id) do
    path = "datos/sorteo_#{id}.json"

    case File.read(path) do
      {:ok, contenido} ->
        case Jason.decode(contenido, keys: :atoms) do
          {:ok, sorteo} ->
            # Normalizar billetes_vendidos a claves string para consistencia.
            # Jason.decode con keys: :atoms convierte TODAS las claves a átomos,
            # incluso las de billetes_vendidos (ej: :"0025" en vez de "0025"),
            # lo que rompe las búsquedas que usan string como clave.
            billetes_normalizados =
              Map.get(sorteo, :billetes_vendidos, %{})
              |> Enum.into(%{}, fn {k_billete, fracs} ->
                fracs_str = Enum.into(fracs, %{}, fn {k_frac, v} ->
                  {to_string(k_frac), v}
                end)
                {to_string(k_billete), fracs_str}
              end)

            {:ok, %{sorteo | billetes_vendidos: billetes_normalizados}}

          err ->
            err
        end

      {:error, _} ->
        {:error, "No se encontró el sorteo"}
    end
  end

  def revivir_sorteos_existentes do
    carpeta = "datos"

    if File.exists?(carpeta) do
      # 1. Listamos todos los archivos dentro de la carpeta datos
      File.ls!(carpeta)
      # 2. Filtramos solo archivos de sorteos (evita cargar jugadores y admins)
      |> Enum.filter(&(String.starts_with?(&1, "sorteo_") and String.ends_with?(&1, ".json")))
      # 3. Extraemos el ID del nombre del archivo (ej: "sorteo_111.json" -> "111")
      |> Enum.each(fn archivo ->
        id =
          archivo
          |> String.replace("sorteo_", "")
          |> String.replace(".json", "")

        # 4. Cargamos el sorteo y lo metemos al Supervisor
        case cargar_sorteo(id) do
          {:ok, sorteo} ->
            Servidor.SupervisorSorteos.iniciar_sorteo(sorteo)

          _ ->
            :ok
        end
      end)
    end
  end

  # Guarda un jugador en un archivo JSON independiente (ej: datos/jugador_12345.json)
  def guardar_jugador(jugador) do
    carpeta = "datos"
    File.mkdir_p!(carpeta)
    ruta = Path.join(carpeta, "jugador_#{jugador.cedula}.json")

    case Jason.encode(jugador) do
      {:ok, json_data} ->
        File.write(ruta, json_data)
        :ok
      {:error, _reason} ->
        {:error, "No se pudo codificar el jugador"}
    end
  end

  # Carga los datos de un jugador por su cédula
  def cargar_jugador(cedula) do
    ruta = "datos/jugador_#{cedula}.json"

    if File.exists?(ruta) do
      case File.read(ruta) do
        {:ok, contenido} ->
          case Jason.decode(contenido) do
            {:ok, mapa} ->
              # Convertimos el mapa genérico de vuelta al Struct de Jugador
              jugador = %Servidor.Modelos.Jugador{
                cedula: mapa["cedula"],
                nombre: mapa["nombre"],
                password: mapa["password"],
                tarjeta_credito: mapa["tarjeta_credito"],
                historial_compras: mapa["historial_compras"] || [],
                notificaciones: mapa["notificaciones"] || []
              }
              {:ok, jugador}
            _ -> {:error, "Error al decodificar JSON"}
          end
        _ -> {:error, "Error al leer el archivo"}
      end
    else
      {:error, "El jugador no existe"}
    end
  end

  @doc "Retorna todos los sorteos ordenados por fecha."
  def listar_sorteos do
    carpeta = "datos"

    if File.exists?(carpeta) do
      File.ls!(carpeta)
      |> Enum.filter(&(String.starts_with?(&1, "sorteo_") and String.ends_with?(&1, ".json")))
      |> Enum.map(fn archivo ->
        id = archivo |> String.replace("sorteo_", "") |> String.replace(".json", "")
        case cargar_sorteo(id) do
          {:ok, sorteo} -> sorteo
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(&Map.get(&1, :fecha, ""))
    else
      []
    end
  end

  @doc "Elimina un sorteo solo si no tiene premios asociados."
  def eliminar_sorteo(id) do
    case cargar_sorteo(id) do
      {:ok, sorteo} ->
        premios = Map.get(sorteo, :premios, [])

        if Enum.empty?(premios) do
          File.rm("datos/sorteo_#{id}.json")

          case :global.whereis_name({:sorteo, id}) do
            :undefined -> :ok
            pid -> GenServer.stop(pid, :normal)
          end

          Servidor.Bitacora.registrar_operacion("Eliminar Sorteo ID: #{id}", "OK")
          :ok
        else
          Servidor.Bitacora.registrar_operacion(
            "Eliminar Sorteo ID: #{id}",
            "NEGADO - Tiene #{length(premios)} premio(s)"
          )
          {:error, "No se puede eliminar: el sorteo tiene #{length(premios)} premio(s) asociado(s)"}
        end

      {:error, msg} ->
        {:error, msg}
    end
  end

  def procesar_sorteos_por_fecha(fecha_limite) do
    carpeta = "datos"

    if File.exists?(carpeta) do
      File.ls!(carpeta)
      |> Enum.filter(&String.ends_with?(&1, ".json"))
      |> Enum.filter(&String.starts_with?(&1, "sorteo_"))
      |> Enum.each(fn archivo ->
        id = archivo |> String.replace("sorteo_", "") |> String.replace(".json", "")

        case cargar_sorteo(id) do
          {:ok, sorteo} ->
            # Si el sorteo está pendiente y su fecha es menor o igual a la ingresada...
            if sorteo.estado == "pendiente" and sorteo.fecha <= fecha_limite do
              # Le ordenamos a su GenServer que ejecute la tómbola
              case :global.whereis_name({:sorteo, id}) do
                :undefined -> :ok
                _pid -> GenServer.call({:global, {:sorteo, id}}, :ejecutar_sorteo)
              end
            end
          _ -> :ok
        end
      end)
    end
  end

  # ── Gestión de Admins ─────────────────────────────────────────────────────

  @doc "Lista todos los administradores registrados."
  def listar_admins do
    carpeta = "datos"
    if File.exists?(carpeta) do
      File.ls!(carpeta)
      |> Enum.filter(&(String.starts_with?(&1, "admin_") and String.ends_with?(&1, ".json")))
      |> Enum.map(fn archivo ->
        case File.read(Path.join(carpeta, archivo)) do
          {:ok, contenido} ->
            case Jason.decode(contenido) do
              {:ok, admin} -> admin
              _ -> nil
            end
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1["usuario"])
    else
      []
    end
  end

  @doc "Guarda un nuevo administrador en datos/admin_<usuario>.json."
  def guardar_admin(usuario, password, nombre) do
    carpeta = "datos"
    File.mkdir_p!(carpeta)
    ruta = Path.join(carpeta, "admin_#{usuario}.json")

    if File.exists?(ruta) do
      {:error, "El usuario '#{usuario}' ya existe"}
    else
      datos = %{"usuario" => usuario, "password" => password, "nombre" => nombre}
      case Jason.encode(datos) do
        {:ok, json} ->
          File.write(ruta, json)
          Servidor.Bitacora.registrar_operacion("Crear Admin: #{usuario}", "OK")
          :ok
        _ ->
          {:error, "Error al guardar el administrador"}
      end
    end
  end

  @doc "Elimina un admin. No permite eliminar al único admin restante."
  def eliminar_admin(usuario, usuario_actual) do
    if usuario == usuario_actual do
      {:error, "No puedes eliminar tu propia cuenta"}
    else
      ruta = "datos/admin_#{usuario}.json"
      if File.exists?(ruta) do
        admins = listar_admins()
        if length(admins) <= 1 do
          {:error, "No se puede eliminar: debe existir al menos un administrador"}
        else
          File.rm(ruta)
          Servidor.Bitacora.registrar_operacion("Eliminar Admin: #{usuario}", "OK")
          :ok
        end
      else
        {:error, "El administrador '#{usuario}' no existe"}
      end
    end
  end

  # ── Gestión de Jugadores (admin) ──────────────────────────────────────────

  @doc "Lista todos los jugadores registrados, ordenados por nombre."
  def listar_jugadores do
    carpeta = "datos"
    if File.exists?(carpeta) do
      File.ls!(carpeta)
      |> Enum.filter(&(String.starts_with?(&1, "jugador_") and String.ends_with?(&1, ".json")))
      |> Enum.map(fn archivo ->
        cedula = archivo |> String.replace("jugador_", "") |> String.replace(".json", "")
        case cargar_jugador(cedula) do
          {:ok, jugador} -> jugador
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.nombre)
    else
      []
    end
  end

  @doc "Elimina un jugador solo si no tiene compras registradas."
  def eliminar_jugador(cedula) do
    case cargar_jugador(cedula) do
      {:ok, jugador} ->
        if Enum.empty?(jugador.historial_compras) do
          File.rm("datos/jugador_#{cedula}.json")
          Servidor.Bitacora.registrar_operacion("Eliminar Jugador: #{cedula}", "OK")
          :ok
        else
          {:error, "No se puede eliminar: el jugador tiene #{length(jugador.historial_compras)} compra(s) registrada(s)"}
        end
      {:error, msg} ->
        {:error, msg}
    end
  end

end
