defmodule Servidor.Modelos.Premio do
  @derive Jason.Encoder
  defstruct [:nombre, :valor, :numero_ganador] # Ej: nombre: "Mayor", valor: 10000000, numero_ganador: nil
end
