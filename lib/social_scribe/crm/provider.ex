defmodule SocialScribe.Crm.Provider do
  @moduledoc """
  CRM provider helpers and module resolution.
  """

  alias SocialScribe.Accounts.UserCredential

  def contact_api(%UserCredential{provider: "hubspot"}), do: {:ok, SocialScribe.HubspotApiBehaviour}
  def contact_api(%UserCredential{provider: "salesforce"}), do: {:ok, SocialScribe.SalesforceApiBehaviour}
  def contact_api(%UserCredential{provider: provider}), do: {:error, {:unsupported_provider, provider}}

  def display_name("hubspot"), do: "HubSpot"
  def display_name("salesforce"), do: "Salesforce"
  def display_name(_), do: "CRM"

  def modal_title(provider), do: "Update in #{display_name(provider)}"
  def submit_text(provider), do: "Update #{display_name(provider)}"

  def supported_fields("hubspot") do
    MapSet.new([
      "firstname",
      "lastname",
      "email",
      "phone",
      "mobilephone",
      "company",
      "jobtitle",
      "address",
      "city",
      "state",
      "zip",
      "country",
      "website",
      "linkedin_url",
      "twitter_handle"
    ])
  end

  def supported_fields("salesforce") do
    MapSet.new([
      "firstname",
      "lastname",
      "email",
      "phone",
      "mobilephone",
      "jobtitle",
      "address",
      "city",
      "state",
      "zip",
      "country"
    ])
  end

  def supported_fields(_), do: MapSet.new()
end
