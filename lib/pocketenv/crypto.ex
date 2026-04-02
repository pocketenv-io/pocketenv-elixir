defmodule Pocketenv.Crypto do
  @moduledoc false
  # Client-side encryption matching libsodium's crypto_box_seal (anonymous sealed box).
  #
  # Algorithm:
  #   1. Generate ephemeral Curve25519 (X25519) keypair via :crypto
  #   2. Derive nonce = BLAKE2b-24(eph_pk || recipient_pk)  — matches libsodium exactly
  #   3. Encrypt with NaCl crypto_box(message, nonce, eph_sk, recipient_pk)  [Kcl]
  #   4. Output = eph_pk (32 bytes) || ciphertext
  #   5. Base64url-encode without padding (matches TypeScript sodium implementation)
  #
  # The server's public key is resolved in order from:
  #   1. :public_key in the :pocketenv_ex application config
  #   2. POCKETENV_PUBLIC_KEY environment variable
  #   3. The default production key below

  @default_public_key "2bf96e12d109e6948046a7803ef1696e12c11f04f20a6ce64dbd4bcd93db9341"

  @doc """
  Encrypts `plaintext` using the server's public key via a sealed box.

  Returns `{:ok, base64url_ciphertext}`.
  """
  @spec encrypt(String.t()) :: {:ok, String.t()}
  def encrypt(plaintext) when is_binary(plaintext) do
    sealed = box_seal(plaintext, public_key())
    {:ok, Base.url_encode64(sealed, padding: false)}
  end

  @doc """
  Same as `encrypt/1` but returns the ciphertext directly.
  """
  @spec encrypt!(String.t()) :: String.t()
  def encrypt!(plaintext) do
    {:ok, ciphertext} = encrypt(plaintext)
    ciphertext
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Implements libsodium crypto_box_seal using Kcl (NaCl crypto_box) +
  # Erlang :crypto for X25519 key generation and BLAKE2b nonce derivation.
  defp box_seal(message, recipient_pk) do
    {eph_pk, eph_sk} = :crypto.generate_key(:ecdh, :x25519)

    # nonce = BLAKE2b-24(eph_pk || recipient_pk) — matches libsodium exactly
    nonce = :crypto.hash({:blake2b, 24}, eph_pk <> recipient_pk)

    {ciphertext, _state} = Kcl.box(message, nonce, eph_sk, recipient_pk)

    eph_pk <> ciphertext
  end

  defp public_key do
    hex =
      Application.get_env(:pocketenv_ex, :public_key) ||
        System.get_env("POCKETENV_PUBLIC_KEY") ||
        @default_public_key

    Base.decode16!(hex, case: :mixed)
  end
end
