defmodule SocialScribeWeb.MeetingGenerationErrorTest do
  use SocialScribeWeb.ConnCase

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import SocialScribe.AutomationsFixtures

  alias SocialScribe.Calendar
  alias SocialScribe.Meetings

  describe "meeting generation error visibility" do
    setup %{conn: conn} do
      user = user_fixture()
      meeting = meeting_fixture(%{})
      calendar_event = Calendar.get_calendar_event!(meeting.calendar_event_id)
      {:ok, _updated_event} = Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

      {:ok, meeting} =
        Meetings.update_meeting(Meetings.get_meeting!(meeting.id), %{
          follow_up_email: nil,
          generation_error: "AI generation failed: invalid Gemini API key."
        })

      %{
        conn: log_in_user(conn, user),
        user: user,
        meeting: Meetings.get_meeting_with_details(meeting.id)
      }
    end

    test "shows generation error when follow-up email is missing", %{conn: conn, meeting: meeting} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert html =~ "AI generation failed: invalid Gemini API key."
      refute html =~ "AI-generated follow-up email will appear here once generated."
    end
  end

  describe "draft post failure messaging" do
    setup %{conn: conn} do
      user = user_fixture()
      meeting = meeting_fixture(%{})
      calendar_event = Calendar.get_calendar_event!(meeting.calendar_event_id)
      {:ok, _updated_event} = Calendar.update_calendar_event(calendar_event, %{user_id: user.id})

      automation = automation_fixture(%{user_id: user.id})

      result =
        automation_result_fixture(%{
          automation_id: automation.id,
          meeting_id: meeting.id,
          status: "generation_failed",
          generated_content: nil,
          error_message: "Gemini API error: {:error, :api_key_invalid}"
        })

      %{
        conn: log_in_user(conn, user),
        meeting: Meetings.get_meeting_with_details(meeting.id),
        result: result
      }
    end

    test "shows automation generation error in draft modal", %{conn: conn, meeting: meeting, result: result} do
      {:ok, _view, html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/draft_post/#{result.id}")

      assert html =~ "Gemini API error: {:error, :api_key_invalid}"
    end
  end
end
