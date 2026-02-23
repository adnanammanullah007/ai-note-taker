defmodule SocialScribe.SalesforceApiTest do
  use SocialScribe.DataCase

  alias SocialScribe.SalesforceApi

  import SocialScribe.AccountsFixtures

  describe "update_contact/3" do
    test "returns :no_updates when no Salesforce-supported fields are selected" do
      user = user_fixture()

      credential =
        salesforce_credential_fixture(%{
          user_id: user.id,
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      assert {:ok, :no_updates} =
               SalesforceApi.update_contact(credential, "003000000000001AAA", %{
                 "linkedin_url" => "https://linkedin.com/in/example",
                 "twitter_handle" => "@example"
               })
    end
  end
end
