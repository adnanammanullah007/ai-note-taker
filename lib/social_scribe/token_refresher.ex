defmodule SocialScribe.TokenRefresher do
  @moduledoc """
  Refreshes Google tokens.
  """

  @google_token_url "https://oauth2.googleapis.com/token"

  @behaviour SocialScribe.TokenRefresherApi

  def client do
    middlewares = [
      {Tesla.Middleware.FormUrlencoded,
       encode: &Plug.Conn.Query.encode/1, decode: &Plug.Conn.Query.decode/1},
      Tesla.Middleware.JSON
    ]

    Tesla.client(middlewares)
  end

  def refresh_token(refresh_token_string) do
    client_id = Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_id]

    client_secret =
      Application.fetch_env!(:ueberauth, Ueberauth.Strategy.Google.OAuth)[:client_secret]

    body = %{
      client_id: client_id,
      client_secret: client_secret,
      refresh_token: refresh_token_string,
      grant_type: "refresh_token"
    }

    # #region agent log
    debug_log("H3", "token_refresher.refresh_token", "refresh_request_payload_shape", %{
      refresh_token_present: present?(refresh_token_string),
      client_id_present: present?(client_id),
      client_secret_present: present?(client_secret)
    })
    # #endregion

    # Use Tesla to make the POST request
    case Tesla.post(client(), @google_token_url, body, opts: [form_urlencoded: true]) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        # #region agent log
        debug_log("H5", "token_refresher.refresh_token", "google_refresh_http_error", %{
          status: status,
          error_body: inspect(error_body)
        })
        # #endregion

        {:error, {status, error_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false

  defp debug_log(hypothesis_id, location, message, data) do
    log = %{
      id: "log_" <> Integer.to_string(System.unique_integer([:positive])),
      timestamp: System.system_time(:millisecond),
      runId: "pre-fix",
      hypothesisId: hypothesis_id,
      location: location,
      message: message,
      data: data
    }

    File.write!("/Users/adnanammanullah/Desktop/learning_project/ai-note-taker/.cursor/debug.log", Jason.encode!(log) <> "\n", [:append])
  rescue
    _ -> :ok
  end
end
