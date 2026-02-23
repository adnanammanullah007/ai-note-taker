defmodule Ueberauth.Strategy.Salesforce do
  @moduledoc """
  Salesforce OAuth strategy for Ueberauth.
  """

  use Ueberauth.Strategy,
    uid_field: :user_id,
    default_scope: "id api refresh_token",
    oauth2_module: Ueberauth.Strategy.Salesforce.OAuth

  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra
  alias Ueberauth.Auth.Info

  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    opts =
      [scope: scopes, redirect_uri: redirect_uri(conn)]
      |> with_state_param(conn)

    redirect!(conn, Ueberauth.Strategy.Salesforce.OAuth.authorize_url!(opts))
  end

  def handle_callback!(%Plug.Conn{params: %{"error" => error} = params} = conn) do
    description =
      params["error_description"] ||
        params["error_message"] ||
        "Salesforce did not provide an error description"

    set_errors!(conn, [error(error, description)])
  end

  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    opts = [redirect_uri: redirect_uri(conn)]

    case Ueberauth.Strategy.Salesforce.OAuth.get_access_token([code: code], opts) do
      {:ok, token} ->
        case Ueberauth.Strategy.Salesforce.OAuth.get_identity(token) do
          {:ok, identity} ->
            conn
            |> put_private(:salesforce_token, token)
            |> put_private(:salesforce_identity, identity)

          {:error, reason} ->
            set_errors!(conn, [error("identity_error", reason)])
        end

      {:error, {error_code, error_description}} ->
        set_errors!(conn, [error(error_code, error_description)])
    end
  end

  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  def handle_cleanup!(conn) do
    conn
    |> put_private(:salesforce_token, nil)
    |> put_private(:salesforce_identity, nil)
  end

  def uid(conn) do
    uid_field =
      conn
      |> option(:uid_field)
      |> to_string()

    conn.private.salesforce_identity[uid_field]
  end

  def credentials(conn) do
    token = conn.private.salesforce_token

    %Credentials{
      expires: true,
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.to_unix(),
      scopes: String.split(token.other_params["scope"] || "", " "),
      token: token.access_token,
      refresh_token: token.refresh_token,
      token_type: token.token_type
    }
  end

  def info(conn) do
    identity = conn.private.salesforce_identity || %{}

    %Info{
      email: identity["email"] || identity["username"] || "salesforce-user@example.com",
      name: identity["display_name"] || identity["username"] || "Salesforce User"
    }
  end

  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.salesforce_token,
        identity: conn.private.salesforce_identity
      }
    }
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end

  defp redirect_uri(conn) do
    Application.get_env(:ueberauth, Ueberauth.Strategy.Salesforce.OAuth, [])
    |> Keyword.get(:redirect_uri)
    |> case do
      uri when is_binary(uri) and uri != "" -> uri
      _ -> callback_url(conn)
    end
  end
end
