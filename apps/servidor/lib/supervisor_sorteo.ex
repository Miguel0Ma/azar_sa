defmodule Servidor.SupervisorSorteos do
  use DynamicSupervisor

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def iniciar_sorteo(datos_sorteo) do
    spec = {Servidor.ServidorSorteo, datos_sorteo}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        # El GenServer ya está corriendo en otro nodo (modo distribuido).
        # No es un error — simplemente lo dejamos donde está.
        {:ok, pid}

      error ->
        error
    end
  end
end
