defmodule Servidor.Modelos.Sorteo do
  @derive Jason.Encoder
  defstruct [
    :id,
    :nombre,
    :fecha,
    :valor_billete,
    :cant_fracciones,
    :cant_billetes,
    billetes_vendidos: %{}, # Ej: %{"0042" => %{"1" => "cedula1", "2" => "cedula2"}}
    estado: "pendiente",   # "pendiente" o "jugado"
    premios: []            # Lista de números ganadores
  ]
end
