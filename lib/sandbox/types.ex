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

  defmodule Secret do
    @moduledoc "Represents a secret stored in a sandbox."

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            created_at: String.t() | nil
          }

    defstruct [:id, :name, :created_at]

    @doc "Build a Secret from the raw API map."
    def from_map(map) when is_map(map) do
      %__MODULE__{
        id: map["id"],
        name: map["name"],
        created_at: map["createdAt"]
      }
    end
  end

  defmodule SshKey do
    @moduledoc "Represents an SSH key pair associated with a sandbox."

    @type t :: %__MODULE__{
            id: String.t(),
            private_key: String.t() | nil,
            public_key: String.t() | nil,
            created_at: String.t() | nil
          }

    defstruct [:id, :private_key, :public_key, :created_at]

    @doc "Build an SshKey from the raw API map."
    def from_map(map) when is_map(map) do
      %__MODULE__{
        id: map["id"],
        private_key: map["privateKey"],
        public_key: map["publicKey"],
        created_at: map["createdAt"]
      }
    end
  end

  defmodule TailscaleAuthKey do
    @moduledoc "Represents a Tailscale auth key associated with a sandbox."

    @type t :: %__MODULE__{
            id: String.t(),
            auth_key: String.t() | nil,
            created_at: String.t() | nil
          }

    defstruct [:id, :auth_key, :created_at]

    @doc "Build a TailscaleAuthKey from the raw API map."
    def from_map(map) when is_map(map) do
      %__MODULE__{
        id: map["id"],
        auth_key: map["authKey"],
        created_at: map["createdAt"]
      }
    end
  end

  defmodule Backup do
    @moduledoc "Represents a sandbox backup."

    @type t :: %__MODULE__{
            id: String.t(),
            directory: String.t(),
            description: String.t() | nil,
            expires_at: String.t() | nil,
            created_at: String.t()
          }

    defstruct [:id, :directory, :description, :expires_at, :created_at]

    @doc "Build a Backup from the raw API map."
    def from_map(map) when is_map(map) do
      %__MODULE__{
        id: map["id"],
        directory: map["directory"],
        description: map["description"],
        expires_at: map["expiresAt"],
        created_at: map["createdAt"]
      }
    end
  end
end
