defmodule SocialScribe.Crm do
  @moduledoc """
  Unified CRM entrypoint for contact operations.
  """

  alias SocialScribe.Accounts.UserCredential
  alias SocialScribe.Crm.Provider

  def search_contacts(%UserCredential{} = credential, query) do
    with {:ok, api_module} <- Provider.contact_api(credential) do
      api_module.search_contacts(credential, query)
    end
  end

  def get_contact(%UserCredential{} = credential, contact_id) do
    with {:ok, api_module} <- Provider.contact_api(credential) do
      api_module.get_contact(credential, contact_id)
    end
  end

  def update_contact(%UserCredential{} = credential, contact_id, updates) do
    with {:ok, api_module} <- Provider.contact_api(credential) do
      api_module.update_contact(credential, contact_id, updates)
    end
  end
end
