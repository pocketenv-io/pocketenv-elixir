defmodule Sandbox.Types do
  @moduledoc """
  Types and structs used by the Pocketenv Sandbox SDK.
  """

  defmodule Profile do
    @moduledoc "Represents a Pocketenv user profile."

    @type t :: %__MODULE__{
            id: String.t() | nil,
            did: String.t(),
            handle: String.t(),
            display_name: String.t() | nil,
            avatar: String.t() | nil,
            created_at: String.t() | nil,
            updated_at: String.t() | nil
          }

    defstruct [:id, :did, :handle, :display_name, :avatar, :created_at, :updated_at]

    @doc "Build a Profile from the raw API map."
    def from_map(map) when is_map(map) do
      %__MODULE__{
        id: map["id"],
        did: map["did"],
        handle: map["handle"],
        display_name: map["displayName"],
        avatar: map["avatar"],
        created_at: map["createdAt"],
        updated_at: map["updatedAt"]
      }
    end
  end

  defmodule Port do
    @moduledoc "Represents an exposed port on a sandbox."

    @type t :: %__MODULE__{
            port: integer(),
            description: String.t() | nil,
            preview_url: String.t() | nil
          }

    defstruct [:port, :description, :preview_url]

    @doc "Build a Port from the raw API map."
    def from_map(map) when is_map(map) do
      %__MODULE__{
        port: map["port"],
        description: map["description"],
        preview_url: map["previewUrl"]
      }
    end
  end

  defmodule ExecResult do
    @moduledoc "Represents the result of executing a command in a sandbox."

    @type t :: %__MODULE__{
            stdout: String.t(),
            stderr: String.t(),
            exit_code: integer()
          }

    defstruct stdout: "", stderr: "", exit_code: 0

    @doc "Build an ExecResult from the raw API map."
    def from_map(map) when is_map(map) do
      %__MODULE__{
        stdout: map["stdout"] || "",
        stderr: map["stderr"] || "",
        exit_code: map["exitCode"] || 0
      }
    end
  end
end
