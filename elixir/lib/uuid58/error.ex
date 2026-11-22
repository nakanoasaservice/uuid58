defmodule Uuid58.Error do
  @moduledoc """
  Raised by the bang functions (`Uuid58.encode!/1` and the rest) for invalid
  input.

  `kind` is the error kind from the specification, section 7:
  `:invalid_length`, `:invalid_character`, or `:overflow`. Messages are not
  part of the specification and may change. They do not include the input.
  """

  defexception [:kind, :message]

  @type kind :: :invalid_length | :invalid_character | :overflow
  @type t :: %__MODULE__{kind: kind(), message: String.t()}

  @impl true
  def exception(opts) when is_list(opts) do
    kind = Keyword.fetch!(opts, :kind)

    %__MODULE__{
      kind: kind,
      message: Keyword.get(opts, :message) || default_message(kind)
    }
  end

  defp default_message(:invalid_length), do: "invalid length"
  defp default_message(:invalid_character), do: "invalid character"
  defp default_message(:overflow), do: "value exceeds 128 bits"
end
