defmodule BubblesNotifications do
  @moduledoc """
  Client for the Bubbles Push Notifications API.

  Public API:

    * `initialize/2` - builds a reusable client with `app_id` and `api_key`
    * `create_notification/2` - posts a notification using that client
    * `send_push_to_device/3` - sends a push directly to a device id

  The API base URL is read from application config:

      config :bubbles_notifications,
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

  @type message_params :: %{
          required(:title) => String.t(),
          required(:body) => String.t(),
          required(:data) => map()
        }

  @type notification_params :: message_params()
  @type device_push_params :: message_params()

  @type notification :: %{required(String.t()) => term()}

  @type error_response :: %{
          required(:status) => pos_integer(),
          required(:body) => map()
        }

  @type response :: {:ok, notification()} | {:error, error_response() | Exception.t()}

  @doc """
  Initializes a notification client with the app id and API key.

  The base URL is loaded from `Application.fetch_env!(:bubbles_notifications, :base_url)`.

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
      headers: Application.get_env(:bubbles_notifications, :headers, []),
      receive_timeout: Application.get_env(:bubbles_notifications, :receive_timeout, 15_000)
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
    with {:ok, payload} <- build_message_payload(attrs) do
      payload = Map.put(payload, :app_id, client.app_id)
      Client.post(client_request_opts(client), "/api/notifications/create", payload)
    end
  end

  @doc """
  Creates a notification for the given device id.

  The payload must include:

    * `:title`
    * `:body`
    * `:data`

  `:app_id` is taken from the initialized client.
  """
  @spec send_push_to_device(t(), integer() | String.t() | charlist(), device_push_params()) ::
          response()
  def send_push_to_device(%__MODULE__{} = client, device_id, attrs) when is_map(attrs) do
    with {:ok, payload} <- build_message_payload(attrs) do
      payload = Map.put(payload, :app_id, client.app_id)
      path = "/api/notifications/send-push/#{URI.encode(normalize_resource_id(device_id))}"

      Client.post(client_request_opts(client), path, payload)
    end
  end

  @doc """
  Creates a notification for devices with the given user ID strings and
  for devices with at least one of the given alias strings.

  The payload must include:

    * `:title`
    * `:body`
    * `:data`

  `:app_id` is taken from the initialized client.
  """
  @spec create_notification_user_ids_aliases(
          t(),
          [String.t()],
          [String.t()],
          device_push_params()
        ) ::
          response()
  def create_notification_user_ids_aliases(%__MODULE__{} = client, user_ids, aliases, attrs)
      when is_map(attrs) do
    with {:ok, payload} <- build_message_payload(attrs) do
      payload = Map.put(payload, :app_id, client.app_id)
      payload = Map.put(payload, :user_ids, user_ids)
      payload = Map.put(payload, :aliases, aliases)
      Client.post(client_request_opts(client), "/api/notifications/bulk-send", payload)
    end
  end

  defp build_message_payload(attrs) do
    with {:ok, title} <- fetch_required(attrs, :title),
         {:ok, body} <- fetch_required(attrs, :body),
         {:ok, data} when is_map(data) <- fetch_required(attrs, :data) do
      {:ok, %{title: title, body: body, data: data}}
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
    Application.fetch_env!(:bubbles_notifications, :base_url)
  rescue
    error in ArgumentError ->
      raise ArgumentError,
            "missing :base_url configuration for :bubbles_notifications. Set it in config/config.exs or call Application.put_env(:bubbles_notifications, :base_url, \"https://your-api.example.com\") before initialize/2. Original error: #{Exception.message(error)}"
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

  defp normalize_resource_id(id) when is_integer(id), do: Integer.to_string(id)
  defp normalize_resource_id(id) when is_binary(id), do: id
  defp normalize_resource_id(id) when is_list(id), do: to_string(id)

  defp normalize_resource_id(_id) do
    raise ArgumentError, "resource id must be an integer, string, or charlist"
  end
end
