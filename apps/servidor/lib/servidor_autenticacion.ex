defmodule Servidor.ServidorAutenticacion do
  use GenServer

  # Interfaz Pública
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def registrar(nombre, cedula, password, tarjeta) do
    GenServer.call(__MODULE__, {:registrar, nombre, cedula, password, tarjeta})
  end

  def login(cedula, password) do
    GenServer.call(__MODULE__, {:login, cedula, password})
  end

  # Callbacks
  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:registrar, nombre, cedula, password, tarjeta}, _from, state) do
    # Validamos si ya existe el archivo de ese jugador
    case Servidor.Almacenamiento.cargar_jugador(cedula) do
      {:ok, _jugador} ->
        {:reply, {:error, "La cédula ya se encuentra registrada"}, state}
      _error ->
        nuevo_jugador = %Servidor.Modelos.Jugador{
          nombre: nombre,
          cedula: cedula,
          password: password,
          tarjeta_credito: tarjeta,
          historial_compras: []
        }
        Servidor.Almacenamiento.guardar_jugador(nuevo_jugador)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:login, cedula, password}, _from, state) do
    case Servidor.Almacenamiento.cargar_jugador(cedula) do
      {:ok, jugador} ->
        if jugador.password == password do
          {:reply, {:ok, jugador}, state}
        else
          {:reply, {:error, "Contraseña incorrecta"}, state}
        end
      {:error, _msg} ->
        {:reply, {:error, "El usuario no existe en el sistema"}, state}
    end
  end
end
