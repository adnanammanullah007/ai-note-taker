defmodule SocialScribe.SalesforceApi do
  @moduledoc """
  Salesforce Contact API client with token refresh support.
  Returns contacts in the app's canonical CRM field shape.
  """

  @behaviour SocialScribe.SalesforceApiBehaviour

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.SalesforceTokenRefresher

  require Logger

  @api_version "v61.0"

  @soql_fields [
    "Id",
    "FirstName",
    "LastName",
    "Email",
    "Phone",
    "MobilePhone",
    "Title",
    "MailingStreet",
    "MailingCity",
    "MailingState",
    "MailingPostalCode",
    "MailingCountry",
    "CreatedDate"
  ]

  @field_map %{
    "firstname" => "FirstName",
    "lastname" => "LastName",
    "email" => "Email",
    "phone" => "Phone",
    "mobilephone" => "MobilePhone",
    "jobtitle" => "Title",
    "address" => "MailingStreet",
    "city" => "MailingCity",
    "state" => "MailingState",
    "zip" => "MailingPostalCode",
    "country" => "MailingCountry"
  }

  @impl true
  def search_contacts(%UserCredential{} = credential, query) when is_binary(query) do
    with_token_refresh(credential, fn cred ->
      escaped = escape_soql(query)
      fields = Enum.join(@soql_fields, ", ")

      soql =
        "SELECT #{fields} FROM Contact " <>
          "WHERE (Name LIKE '%#{escaped}%' OR Email LIKE '%#{escaped}%') " <>
          "ORDER BY LastModifiedDate DESC LIMIT 10"

      url = "/services/data/#{@api_version}/query?q=#{URI.encode_www_form(soql)}"

      case Tesla.get(client(cred), url) do
        {:ok, %Tesla.Env{status: 200, body: %{"records" => records}}} ->
          {:ok, Enum.map(records, &format_contact/1)}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @impl true
  def get_contact(%UserCredential{} = credential, contact_id) do
    with_token_refresh(credential, fn cred ->
      fields = Enum.join(@soql_fields, ", ")
      soql = "SELECT #{fields} FROM Contact WHERE Id = '#{escape_soql(contact_id)}' LIMIT 1"
      url = "/services/data/#{@api_version}/query?q=#{URI.encode_www_form(soql)}"

      case Tesla.get(client(cred), url) do
        {:ok, %Tesla.Env{status: 200, body: %{"records" => [record | _]}}} ->
          {:ok, format_contact(record)}

        {:ok, %Tesla.Env{status: 200, body: %{"records" => []}}} ->
          {:error, :not_found}

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:api_error, status, body}}

        {:error, reason} ->
          {:error, {:http_error, reason}}
      end
    end)
  end

  @impl true
  def update_contact(%UserCredential{} = credential, contact_id, updates) when is_map(updates) do
    with_token_refresh(credential, fn cred ->
      payload = %{fields: map_updates(updates)}

      if map_size(payload.fields) == 0 do
        {:ok, :no_updates}
      else
        case Tesla.patch(client(cred), "/services/data/#{@api_version}/sobjects/Contact/#{contact_id}", payload.fields) do
          {:ok, %Tesla.Env{status: status}} when status in [200, 204] ->
            get_contact(cred, contact_id)

          {:ok, %Tesla.Env{status: status, body: body}} ->
            {:error, {:api_error, status, body}}

          {:error, reason} ->
            {:error, {:http_error, reason}}
        end
      end
    end)
  end

  defp map_updates(updates) do
    updates
    |> Enum.reduce(%{}, fn {field, value}, acc ->
      case @field_map[to_string(field)] do
        nil -> acc
        provider_field -> Map.put(acc, provider_field, value)
      end
    end)
  end

  defp format_contact(record) do
    %{
      id: record["Id"],
      firstname: record["FirstName"],
      lastname: record["LastName"],
      email: record["Email"],
      phone: record["Phone"],
      mobilephone: record["MobilePhone"],
      jobtitle: record["Title"],
      address: record["MailingStreet"],
      city: record["MailingCity"],
      state: record["MailingState"],
      zip: record["MailingPostalCode"],
      country: record["MailingCountry"],
      display_name: format_display_name(record)
    }
  end

  defp format_display_name(record) do
    first = record["FirstName"] || ""
    last = record["LastName"] || ""
    email = record["Email"] || ""
    name = String.trim("#{first} #{last}")
    if name == "", do: email, else: name
  end

  defp with_token_refresh(%UserCredential{} = credential, fun) do
    with {:ok, valid_credential} <- SalesforceTokenRefresher.ensure_valid_token(credential) do
      case fun.(valid_credential) do
        {:error, {:api_error, status, body}} when status in [400, 401] ->
          if token_error?(body) do
            Logger.info("Salesforce token expired, refreshing and retrying...")

            case SalesforceTokenRefresher.refresh_credential(valid_credential) do
              {:ok, refreshed} -> fun.(refreshed)
              {:error, reason} -> {:error, {:token_refresh_failed, reason}}
            end
          else
            {:error, {:api_error, status, body}}
          end

        other ->
          other
      end
    end
  end

  defp token_error?(body) when is_list(body) do
    Enum.any?(body, fn item ->
      code = item["errorCode"] || ""
      message = String.downcase(item["message"] || "")
      code in ["INVALID_SESSION_ID", "INVALID_AUTH_HEADER"] or String.contains?(message, "expired")
    end)
  end

  defp token_error?(body) when is_map(body) do
    code = body["errorCode"] || ""
    message = String.downcase(body["message"] || "")
    code in ["INVALID_SESSION_ID", "INVALID_AUTH_HEADER"] or String.contains?(message, "expired")
  end

  defp token_error?(_), do: false

  defp client(%UserCredential{} = credential) do
    base_url = credential.instance_url || "https://login.salesforce.com"

    Tesla.client([
      {Tesla.Middleware.BaseUrl, base_url},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Bearer #{credential.token}"},
         {"Content-Type", "application/json"}
       ]}
    ])
  end

  defp escape_soql(value) when is_binary(value), do: String.replace(value, "'", "\\'")
end
