defmodule BubblesNotifications.Client do
  @moduledoc false

  @type request_opts :: keyword()
  @type response :: BubblesNotifications.response()

  @spec post(request_opts(), String.t(), map()) :: response()
  def post(opts, path, body) do
    opts
    |> build_request()
    |> Req.post(url: path, json: body)
    |> normalize_response()
  end

  defp build_request(opts) do
    base_url = Keyword.fetch!(opts, :base_url)
    headers = Keyword.get(opts, :headers, [])
    receive_timeout = Keyword.get(opts, :receive_timeout, 15_000)

    req_options = [
      base_url: base_url,
      headers: headers,
      receive_timeout: receive_timeout
    ]

    req_options =
      case Keyword.get(opts, :api_key) do
        nil -> req_options
        api_key -> Keyword.put(req_options, :auth, {:bearer, api_key})
      end

    Req.new(req_options)
  end

  defp normalize_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, normalize_body(body)}
  end

  defp normalize_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, %{status: status, body: normalize_body(body)}}
  end

  defp normalize_response({:error, exception}) do
    {:error, exception}
  end

  defp normalize_body(body) when is_map(body), do: body

  defp normalize_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> decoded
      {:ok, decoded} -> %{"data" => decoded}
      {:error, _reason} -> %{"data" => body}
    end
  end

  defp normalize_body(body), do: %{"data" => body}
end
