defmodule SocialScribe.AIContentGeneratorTest do
  use ExUnit.Case, async: true

  alias SocialScribe.AIContentGenerator

  describe "classify_gemini_response_error/2" do
    test "returns :api_key_invalid for Gemini invalid key responses" do
      error_body = %{
        "error" => %{
          "code" => 400,
          "details" => [
            %{"reason" => "API_KEY_INVALID"}
          ],
          "message" => "API key not valid. Please pass a valid API key."
        }
      }

      assert AIContentGenerator.classify_gemini_response_error(400, error_body) ==
               {:error, :api_key_invalid}
    end

    test "returns generic api error for other response failures" do
      error_body = %{"error" => %{"code" => 429, "message" => "Quota exceeded"}}

      assert AIContentGenerator.classify_gemini_response_error(429, error_body) ==
               {:error, {:api_error, 429, error_body}}
    end
  end
end
