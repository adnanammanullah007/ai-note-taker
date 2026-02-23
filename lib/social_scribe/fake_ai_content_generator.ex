defmodule SocialScribe.FakeAIContentGenerator do
  @moduledoc """
  Dev-only fake AI provider used to bypass external LLM calls.
  """

  @behaviour SocialScribe.AIContentGeneratorApi

  require Logger

  @impl SocialScribe.AIContentGeneratorApi
  def generate_follow_up_email(meeting) do
    log_mock_provider_once()

    summary = meeting_summary(meeting)
    action_items = follow_up_actions(meeting)

    email = """
    Subject: Follow-up on #{meeting_title(meeting)}

    Hi team,

    Thanks for the meeting today. Here is a quick summary:
    #{summary}

    Action items:
    #{action_items}

    Best regards,
    #{host_name(meeting)}
    """

    {:ok, String.trim(email)}
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_automation(automation, meeting) do
    log_mock_provider_once()

    platform =
      automation
      |> Map.get(:platform, "social")
      |> to_string()
      |> String.downcase()

    content =
      """
      #{platform_post_prefix(platform)}
      Discussed key updates in "#{meeting_title(meeting)}" and aligned on next steps.
      #{phone_update_line(meeting)}
      """
      |> String.trim()

    {:ok, content}
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_hubspot_suggestions(meeting) do
    log_mock_provider_once()

    suggestions =
      case detect_phone_update(meeting) do
        nil ->
          []

        %{phone: phone, context: context, timestamp: timestamp} ->
          [
            %{
              field: "phone",
              value: phone,
              context: context,
              timestamp: timestamp
            }
          ]
      end

    {:ok, suggestions}
  end

  defp log_mock_provider_once do
    key = {__MODULE__, :mock_provider_logged}

    case :persistent_term.get(key, false) do
      true ->
        :ok

      false ->
        Logger.warning("Using Fake AI provider (dev mode)")
        :persistent_term.put(key, true)
    end
  end

  defp meeting_title(meeting), do: Map.get(meeting, :title, "Meeting")

  defp host_name(meeting) do
    meeting
    |> meeting_participants()
    |> Enum.find(&Map.get(&1, :is_host, false))
    |> case do
      nil -> "Team"
      host -> Map.get(host, :name, "Team")
    end
  end

  defp meeting_summary(meeting) do
    participant_names =
      meeting
      |> meeting_participants()
      |> Enum.map(&Map.get(&1, :name, "Unknown"))
      |> Enum.reject(&(&1 == "Unknown"))
      |> Enum.uniq()

    names =
      case participant_names do
        [] -> "participants"
        list -> Enum.join(list, ", ")
      end

    "Reviewed updates with #{names} and captured follow-up actions from the call."
  end

  defp follow_up_actions(meeting) do
    base = "- Share final notes with attendees."

    case detect_phone_update(meeting) do
      nil ->
        [base, "- Confirm if any additional CRM fields need updates."]

      %{phone: phone} ->
        [
          base,
          "- Update CRM contact phone number to #{phone}.",
          "- Confirm the updated number with the contact on next touchpoint."
        ]
    end
    |> Enum.join("\n")
  end

  defp phone_update_line(meeting) do
    case detect_phone_update(meeting) do
      nil -> "No explicit phone update was captured in this transcript."
      %{phone: phone} -> "Contact update captured: phone number #{phone}."
    end
  end

  defp platform_post_prefix("linkedin"), do: "LinkedIn draft:"
  defp platform_post_prefix("facebook"), do: "Facebook draft:"
  defp platform_post_prefix(_), do: "Draft post:"

  defp detect_phone_update(meeting) do
    meeting
    |> transcript_segments()
    |> Enum.map(&segment_to_candidate/1)
    |> Enum.find(& &1)
  end

  defp segment_to_candidate(segment) do
    text = segment_text(segment)
    timestamp = segment_timestamp(segment)
    normalized_text = String.downcase(text)
    phone = normalize_phone(text)

    has_phone_keyword? =
      String.contains?(normalized_text, "phone") or
        String.contains?(normalized_text, "contact") or
        String.contains?(normalized_text, "mobile") or
        String.contains?(normalized_text, "number")

    if has_phone_keyword? and phone != nil do
      %{phone: phone, context: String.trim(text), timestamp: timestamp}
    else
      nil
    end
  end

  defp normalize_phone(text) when is_binary(text) do
    digits =
      text
      |> String.graphemes()
      |> Enum.filter(&(&1 >= "0" and &1 <= "9"))
      |> Enum.join()

    if String.length(digits) >= 7, do: digits, else: nil
  end

  defp normalize_phone(_), do: nil

  defp segment_text(segment) when is_map(segment) do
    words = Map.get(segment, "words") || Map.get(segment, :words) || []

    words
    |> Enum.map(fn word ->
      Map.get(word, "text") || Map.get(word, :text) || ""
    end)
    |> Enum.join(" ")
    |> String.trim()
  end

  defp segment_text(_), do: ""

  defp segment_timestamp(segment) when is_map(segment) do
    words = Map.get(segment, "words") || Map.get(segment, :words) || []
    first_word = List.first(words)
    start_timestamp = Map.get(first_word || %{}, "start_timestamp") || Map.get(first_word || %{}, :start_timestamp)
    seconds = extract_seconds(start_timestamp)
    format_mm_ss(seconds)
  end

  defp segment_timestamp(_), do: "00:00"

  defp extract_seconds(%{"relative" => relative}) when is_number(relative), do: relative
  defp extract_seconds(%{relative: relative}) when is_number(relative), do: relative
  defp extract_seconds(seconds) when is_number(seconds), do: seconds
  defp extract_seconds(_), do: 0

  defp format_mm_ss(seconds) do
    total = trunc(seconds)
    minutes = div(total, 60)
    secs = rem(total, 60)
    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp transcript_segments(meeting) do
    transcript = Map.get(meeting, :meeting_transcript)
    content = if is_map(transcript), do: Map.get(transcript, :content) || Map.get(transcript, "content"), else: nil
    data = if is_map(content), do: Map.get(content, "data") || Map.get(content, :data), else: nil

    if is_list(data), do: data, else: []
  end

  defp meeting_participants(meeting) do
    participants = Map.get(meeting, :meeting_participants, [])
    if is_list(participants), do: participants, else: []
  end
end
