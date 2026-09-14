# BubblesNotifications

`bubbles_notifications` is the Hex package that provides the `BubblesNotifications` client for the Bubbles Push Notifications API.

## Public API

- `BubblesNotifications.initialize/2`
- `BubblesNotifications.create_notification/2`
- `BubblesNotifications.send_push_to_device/3`
- `BubblesNotifications.create_notification_user_ids_aliases/4`

`initialize/2` creates a reusable client with your `app_id` and bearer `api_key`.
`create_notification/2` sends notifications for that initialized app.
`send_push_to_device/3` sends a push directly to a device id.
`create_notification_user_ids_aliases/4` sends a push to matching user IDs and aliases.

## Installation

Add `bubbles_notifications` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bubbles_notifications, "~> 0.1.0"}
  ]
end
```

## Configuration

Set the API base URL in your config:

```elixir
config :bubbles_notifications,
  base_url: "https://your-api.example.com"
```

Optional config:

```elixir
config :bubbles_notifications,
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

BubblesNotifications.send_push_to_device(client, "device-123", %{
  title: "Direct push",
  body: "This goes to one device",
  data: %{
    additionalProp1: %{}
  }
})
#=> {:ok, %{"device_id" => "device-123", ...}}
```

## Request shapes

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

`send_push_to_device/3` sends this payload to `POST /api/notifications/send-push/{id}`:

```json
{
  "title": "string",
  "body": "string",
  "data": {
    "additionalProp1": {}
  }
}
```

`create_notification_user_ids_aliases/4` sends this payload to `POST /api/notifications/bulk-send`:

```json
{
  "app_id": 42,
  "user_ids": ["user-123"],
  "aliases": ["team:eng"],
  "title": "string",
  "body": "string",
  "data": {}
}
```

## Response handling

- `201` returns `{:ok, notification}`
- `401` returns `{:error, %{status: 401, body: %{"error" => ...}}}`
- `422` returns `{:error, %{status: 422, body: %{"errors" => ...}}}`
- missing required input fields return `{:error, %ArgumentError{...}}`


## Development

Run tests with:

```sh
mix test
```

## Example application
An example application can be found at: https://github.com/fishonfire/bubbles-notifications-elixir-example

## Contributors
- Simon de la Court (https://github.com/simondelacourt)
- Jan Deen (https://github.com/Jan-F15H)
- Menno Jongejan (https://github.com/mennolpFoF)

## Copyright and Licence
Copyright (c) 2026, Fish on Fire.

Source code is licensed under the [`GPL-3.0-only License`](https://github.com/fishonfire/bubbles-notifications-elixir/blob/develop/LICENSE).
