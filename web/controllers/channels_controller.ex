defmodule Gateway.ChannelsController do
  require Logger
  use Gateway.Web, :controller
  alias Gateway.PresenceChannel
  alias Gateway.Endpoint
  alias Gateway.Blacklist

  def list_channels(conn, _params) do
    channels =
      "role:customer"
      |> PresenceChannel.channels_list
      |> Map.keys

    json(conn, channels)
  end

  def list_channel_connections(conn, params) do
    %{"id" => id} = params

    connections =
      "user:#{id}"
      |> PresenceChannel.channels_list
      |> Enum.map(fn(user) -> elem(user, 1).metas end)
      |> List.flatten

    json(conn, connections)
  end

  def disconnect_channel_connection(conn, %{"jti" => jti}) do
    Blacklist.add_jti(Blacklist, jti, jwt_expiry(conn))
    Endpoint.broadcast(jti, "disconnect", %{})

    conn
    |> put_status(204)
    |> json(%{})
  end

  defp jwt_expiry(conn) do
    get_req_header(conn, "authorization") |> jwt_expiry_from_tokens
  rescue
    e ->
      Logger.warn "No token (expiration) found, using default blacklist expiration timeout (#{inspect e})."
      nil
  end

  defp jwt_expiry_from_tokens([]), do: nil
  defp jwt_expiry_from_tokens([token]) do
    {:ok, %{"exp" => expiry}} = Gateway.Utils.Jwt.decode(token)
    # Comes as int, convert to string:
    Integer.to_string(expiry)
    # Parse as UTC epoch:
    |> Timex.parse!("{s-epoch}")
  end
end
