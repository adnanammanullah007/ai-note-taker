defmodule SocialScribe.SalesforceTokenRefresher do
  @moduledoc """
  Refreshes Salesforce OAuth tokens.
  """

  alias SocialScribe.Accounts
  alias SocialScribe.Accounts.UserCredential

  def refresh_credential(%UserCredential{} = credential) do
    config = Application.get_env(:ueberauth, Ueberauth.Strategy.Salesforce.OAuth, [])
    site = config[:site] || "https://login.salesforce.com"

    body = %{
      grant_type: "refresh_token",
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      refresh_token: credential.refresh_token
    }

    case Tesla.post(client(site), "/services/oauth2/token", body) do
      {:ok, %Tesla.Env{status: 200, body: response}} ->
        attrs = %{
          token: response["access_token"],
          # Salesforce refresh responses may omit refresh_token. Keep existing token in that case.
          refresh_token: response["refresh_token"] || credential.refresh_token,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          instance_url: response["instance_url"] || credential.instance_url
        }

        Accounts.update_user_credential(credential, attrs)

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  def ensure_valid_token(%UserCredential{} = credential) do
    buffer_seconds = 300
    expires_at = credential.expires_at || DateTime.utc_now()

    if DateTime.compare(expires_at, DateTime.add(DateTime.utc_now(), buffer_seconds, :second)) == :lt do
      refresh_credential(credential)
    else
      {:ok, credential}
    end
  end

  defp client(site) do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, site},
      {Tesla.Middleware.FormUrlencoded,
       encode: &Plug.Conn.Query.encode/1, decode: &Plug.Conn.Query.decode/1},
      Tesla.Middleware.JSON
    ])
  end
end
