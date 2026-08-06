defmodule BubblesNotifications do
  @moduledoc """
  Client for the Bubbles Push Notifications API.

  Public API:

    * `initialize/2` - builds a reusable client with `app_id` and `api_key`
    * `create_notification/2` - posts a notification using that client

  The API base URL is read from application config:

      config :bubble_hex,
        base_url: "https://your-api.example.com"
  """

  alias BubblesNotifications.Client

  @enforce_keys [:app_id, :api_key, :base_url]
  defstruct [:app_id, :api_key, :base_url, headers: [], receive_timeout: 15_000]

  @type t :: %__MODULE__{
          app_id: integer(),
          api_key: String.t(),
          base_url: String.t(),
          headers: [{String.t(), String.t()}],
          receive_timeout: non_neg_integer()
        }

  @type notification_params :: %{
          required(:title) => String.t(),
          required(:body) => String.t(),
          required(:data) => map()
        }

  @type notification :: %{required(String.t()) => term()}

  @type error_response :: %{
          required(:status) => pos_integer(),
          required(:body) => map()
        }

  @type response :: {:ok, notification()} | {:error, error_response() | Exception.t()}

  @notification_path "/api/notifications/create"

  @doc """
  Initializes a notification client with the app id and API key.

  The base URL is loaded from `Application.fetch_env!(:bubble_hex, :base_url)`.

  ## Examples

      iex> client = BubblesNotifications.initialize(42, "secret-token")
      iex> client.app_id
      42
  """
  @spec initialize(integer() | String.t() | charlist(), String.t() | charlist()) :: t()
  def initialize(app_id, api_key) do
    %__MODULE__{
      app_id: normalize_app_id(app_id),
      api_key: normalize_api_key(api_key),
      base_url: fetch_base_url!(),
      headers: Application.get_env(:bubble_hex, :headers, []),
      receive_timeout: Application.get_env(:bubble_hex, :receive_timeout, 15_000)
    }
  end

  @doc """
  Creates a notification for the initialized app.

  The payload must include:

    * `:title`
    * `:body`
    * `:data`

  `:app_id` is taken from the initialized client.
  """
  @spec create_notification(t(), notification_params()) :: response()
  def create_notification(%__MODULE__{} = client, attrs) when is_map(attrs) do
    with {:ok, title} <- fetch_required(attrs, :title),
         {:ok, body} <- fetch_required(attrs, :body),
         {:ok, data} when is_map(data) <- fetch_required(attrs, :data) do
      payload = %{
        app_id: client.app_id,
        title: title,
        body: body,
        data: data
      }

      Client.post(client_request_opts(client), @notification_path, payload)
    else
      {:ok, invalid_data} ->
        {:error,
         ArgumentError.exception("expected :data to be a map, got: #{inspect(invalid_data)}")}

      {:error, message} ->
        {:error, ArgumentError.exception(message)}
    end
  end

  defp client_request_opts(%__MODULE__{} = client) do
    [
      base_url: client.base_url,
      api_key: client.api_key,
      headers: client.headers,
      receive_timeout: client.receive_timeout
    ]
  end

  defp fetch_base_url! do
    Application.fetch_env!(:bubble_hex, :base_url)
  rescue
    error in ArgumentError ->
      raise ArgumentError,
            "missing :base_url configuration for :bubble_hex. Set it in config/config.exs or call Application.put_env(:bubble_hex, :base_url, \"https://your-api.example.com\") before initialize/2. Original error: #{Exception.message(error)}"
  end

  defp fetch_required(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        string_key = Atom.to_string(key)

        case Map.fetch(attrs, string_key) do
          {:ok, value} -> {:ok, value}
          :error -> {:error, "missing required notification field: #{inspect(key)}"}
        end
    end
  end

  defp normalize_app_id(app_id) when is_integer(app_id), do: app_id

  defp normalize_app_id(app_id) when is_binary(app_id) do
    case Integer.parse(app_id) do
      {parsed, ""} -> parsed
      _ -> raise ArgumentError, "app_id must be an integer or integer-like string"
    end
  end

  defp normalize_app_id(app_id) when is_list(app_id),
    do: app_id |> to_string() |> normalize_app_id()

  defp normalize_app_id(_app_id) do
    raise ArgumentError, "app_id must be an integer or integer-like string"
  end

  defp normalize_api_key(api_key) when is_binary(api_key), do: api_key
  defp normalize_api_key(api_key) when is_list(api_key), do: to_string(api_key)

  defp normalize_api_key(_api_key) do
    raise ArgumentError, "api_key must be a string or charlist"
  end
end
