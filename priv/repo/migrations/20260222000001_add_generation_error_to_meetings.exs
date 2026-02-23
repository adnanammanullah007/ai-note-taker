defmodule SocialScribe.Repo.Migrations.AddGenerationErrorToMeetings do
  use Ecto.Migration

  def change do
    alter table(:meetings) do
      add :generation_error, :text
    end
  end
end
