defmodule SocialScribe.CrmSuggestions do
  @moduledoc """
  Provider-aware suggestion formatting by combining AI output with CRM contact data.
  """

  alias SocialScribe.AIContentGeneratorApi
  alias SocialScribe.Crm.Provider

  @field_labels %{
    "firstname" => "First Name",
    "lastname" => "Last Name",
    "email" => "Email",
    "phone" => "Phone",
    "mobilephone" => "Mobile Phone",
    "company" => "Company",
    "jobtitle" => "Job Title",
    "address" => "Address",
    "city" => "City",
    "state" => "State",
    "zip" => "ZIP Code",
    "country" => "Country",
    "website" => "Website",
    "linkedin_url" => "LinkedIn",
    "twitter_handle" => "Twitter"
  }

  def generate_suggestions_from_meeting(meeting) do
    case AIContentGeneratorApi.generate_hubspot_suggestions(meeting) do
      {:ok, ai_suggestions} ->
        suggestions =
          ai_suggestions
          |> Enum.map(fn suggestion ->
            %{
              field: suggestion.field,
              label: Map.get(@field_labels, suggestion.field, suggestion.field),
              current_value: nil,
              new_value: suggestion.value,
              context: Map.get(suggestion, :context),
              timestamp: Map.get(suggestion, :timestamp),
              apply: true,
              has_change: true
            }
          end)

        {:ok, suggestions}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def merge_with_contact(suggestions, contact, provider) when is_list(suggestions) do
    allowed_fields = Provider.supported_fields(provider)

    suggestions
    |> Enum.filter(fn suggestion -> MapSet.member?(allowed_fields, suggestion.field) end)
    |> Enum.map(fn suggestion ->
      current_value = get_contact_field(contact, suggestion.field)

      %{suggestion | current_value: current_value, has_change: current_value != suggestion.new_value, apply: true}
    end)
    |> Enum.filter(fn s -> s.has_change end)
  end

  defp get_contact_field(contact, field) when is_map(contact) do
    field_atom = String.to_existing_atom(field)
    Map.get(contact, field_atom)
  rescue
    ArgumentError -> nil
  end

  defp get_contact_field(_, _), do: nil
end
