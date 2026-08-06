# BubblesNotifications

`bubble_hex` is the Hex package that provides the `BubblesNotifications` client for the Bubbles Push Notifications API.

## Public API

- `BubblesNotifications.initialize/2`
- `BubblesNotifications.create_notification/2`

`initialize/2` creates a reusable client with your `app_id` and bearer `api_key`.
`create_notification/2` sends notifications for that initialized app.

## Installation

Add `bubble_hex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bubble_hex, "~> 0.1.0"}
  ]
end
```

## Configuration

Set the API base URL in your config:

```elixir
config :bubble_hex,
  base_url: "https://your-api.example.com"
```

Optional config:

```elixir
config :bubble_hex,
  headers: [{"x-request-source", "my-app"}],
  receive_timeout: 15_000
```

## Usage

```elixir
client = BubblesNotifications.initialize(42, "secret-token")

BubblesNotifications.create_notification(client, %{
  title: "New message",
  body: "You have a new notification",
  data: %{
    user_id: 123,
    type: "message"
  }
})
#=> {:ok, %{"id" => 1, "app_id" => 42, ...}}
```

## Request shape

`create_notification/2` sends this payload to `POST /api/notifications/create`:

```json
{
  "app_id": 42,
  "title": "New message",
  "body": "You have a new notification",
  "data": {
    "user_id": 123,
    "type": "message"
  }
}
```

## Response handling

- `201` returns `{:ok, notification}`
- `401` returns `{:error, %{status: 401, body: %{"error" => ...}}}`
- `422` returns `{:error, %{status: 422, body: %{"errors" => ...}}}`
- missing required input fields return `{:error, %ArgumentError{...}}`

## Publishing notes

Before publishing, replace the placeholder metadata in `mix.exs`:

- `maintainers`
- `@source_url`

## Development

Run tests with:

```sh
mix test
```
