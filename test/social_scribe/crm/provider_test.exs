defmodule SocialScribe.Crm.ProviderTest do
  use ExUnit.Case, async: true

  alias SocialScribe.Crm.Provider

  test "salesforce supported fields include core contact fields" do
    fields = Provider.supported_fields("salesforce")

    assert MapSet.member?(fields, "firstname")
    assert MapSet.member?(fields, "lastname")
    assert MapSet.member?(fields, "email")
    assert MapSet.member?(fields, "phone")
    refute MapSet.member?(fields, "linkedin_url")
  end
end
