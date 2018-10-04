defmodule Mix.Tasks.DumpUserData do
  use Mix.Task

  @shortdoc "Generate dump of data from tables that require manual input"

  @moduledoc """
  Generate dump file with all the data in the tables that contain data not
  acquired through means other than indexing and upload it to a object storage

  no command line options supported
  """

  alias Explorer.UserDataDump

  @doc false
  def run(_) do
    Application.ensure_all_started(:explorer)
    UserDataDump.generate_dump()
  end
end
