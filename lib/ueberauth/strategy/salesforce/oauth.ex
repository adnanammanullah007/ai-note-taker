defmodule Ueberauth.Strategy.Salesforce.OAuth do
  @moduledoc """
  OAuth2 adapter for Salesforce.
  """

  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://login.salesforce.com",
    authorize_url: "/services/oauth2/authorize",
    token_url: "/services/oauth2/token"
  ]

  def client(opts \\ []) do
    config = Application.get_env(:ueberauth, __MODULE__, [])

    opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)

    OAuth2.Client.new(opts)
  end

  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> OAuth2.Client.authorize_url!(params)
  end

  def get_access_token(params \\ [], opts \\ []) do
    case opts |> client() |> OAuth2.Client.get_token(params) do
      {:ok, %OAuth2.Client{token: %OAuth2.AccessToken{} = token}} ->
        {:ok, token}

      {:ok, %OAuth2.Client{token: nil}} ->
        {:error, {"no_token", "No token returned from Salesforce"}}

      {:error, %OAuth2.Response{body: %{"error" => error, "error_description" => description}}} ->
        {:error, {error, description}}

      {:error, %OAuth2.Error{reason: reason}} ->
        {:error, {"oauth2_error", to_string(reason)}}
    end
  end

  def get_identity(token) do
    identity_url = token.other_params["id"]

    if is_binary(identity_url) do
      case Tesla.get(http_client(token.access_token), identity_url) do
        {:ok, %Tesla.Env{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, "Failed to get identity: #{status} - #{inspect(body)}"}

        {:error, reason} ->
          {:error, "HTTP error: #{inspect(reason)}"}
      end
    else
      {:error, "Missing Salesforce identity URL in token response"}
    end
  end

  defp http_client(access_token) do
    Tesla.client([
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers, [{"Authorization", "Bearer #{access_token}"}]}
    ])
  end

  @impl OAuth2.Strategy
  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  @impl OAuth2.Strategy
  def get_token(client, params, headers) do
    client
    |> put_header("Content-Type", "application/x-www-form-urlencoded")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end
end
