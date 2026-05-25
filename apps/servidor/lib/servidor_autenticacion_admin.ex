defmodule Servidor.ServidorAutenticacionAdmin do
  use GenServer

  # ── Interfaz Pública ──────────────────────────────────────────────────────

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc "Intenta autenticar un administrador. Retorna {:ok, admin} o {:error, msg}."
  def login(usuario, password) do
    GenServer.call(__MODULE__, {:login, usuario, password})
  end

  @doc "Crea un nuevo administrador."
  def registrar(usuario, password, nombre) do
    Servidor.Almacenamiento.guardar_admin(usuario, password, nombre)
  end

  @doc "Lista todos los administradores."
  def listar do
    Servidor.Almacenamiento.listar_admins()
  end

  @doc "Elimina un admin. No puedes eliminarte a ti mismo."
  def eliminar(usuario, usuario_actual) do
    Servidor.Almacenamiento.eliminar_admin(usuario, usuario_actual)
  end

  # ── Callbacks ────────────────────────────────────────────────────────────

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:login, usuario, password}, _from, state) do
    ruta = "datos/admin_#{usuario}.json"

    resultado =
      if File.exists?(ruta) do
        case File.read(ruta) do
          {:ok, contenido} ->
            case Jason.decode(contenido) do
              {:ok, admin} ->
                if admin["password"] == password do
                  {:ok, admin}
                else
                  {:error, "Contraseña incorrecta"}
                end

              _ ->
                {:error, "Error al leer datos del administrador"}
            end

          _ ->
            {:error, "No se pudo acceder al archivo del administrador"}
        end
      else
        {:error, "El usuario administrador '#{usuario}' no existe"}
      end

    # Registrar en bitácora
    case resultado do
      {:ok, admin} ->
        Servidor.Bitacora.registrar_operacion(
          "Login Admin: #{admin["usuario"]}",
          "OK"
        )

      {:error, msg} ->
        Servidor.Bitacora.registrar_operacion(
          "Login Admin: #{usuario}",
          "NEGADO - #{msg}"
        )
    end

    {:reply, resultado, state}
  end
end