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
  },
  attribute_filters: %{
    mode: "all",
    conditions: [
      %{key: "country", operator: "equals", value: "NL"}
    ]
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
  },
  "attribute_filters": {
    "mode": "all",
    "conditions": [
      {
        "key": "country",
        "operator": "equals",
        "value": "NL"
      }
    ]
  }
}
```

`attribute_filters` is optional. When omitted or set to `nil`, the payload is unchanged.

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
  "data": {},
  "attribute_filters": {
    "conditions": [
      {
        "key": "tags",
        "path": ["nutrition_notifications"],
        "operator": "equals",
        "value": "true"
      }
    ]
  }
}
```

`attribute_filters` is optional for `create_notification_user_ids_aliases/4` and is not sent by `send_push_to_device/3`.

## Attribute filters

Use `attribute_filters` to target devices by attributes stored for each device. The client forwards the filter map as-is, so atom keys and string keys are both accepted by Elixir and encoded to the same JSON field names.

```elixir
attribute_filters: %{
  mode: "all",
  conditions: [
    %{key: "country", operator: "equals", value: "NL"},
    %{key: "app_version", operator: "greater_than_or_equal", value: 12}
  ]
}
```

`mode` controls how the conditions are combined:

- `"all"` requires every condition to match. This is the default when `mode` is omitted.
- `"any"` requires at least one condition to match.

`conditions` is required when `attribute_filters` is present. It must contain 1 to 10 condition maps. Each condition needs a non-empty `key`, an `operator`, and sometimes a `value`, depending on the operator.

### Condition paths

Use `path` when the attribute value is nested JSON. Each path segment must be a non-empty string. Do not use dot notation.

```elixir
attribute_filters: %{
  conditions: [
    %{
      key: "preferences",
      path: ["notifications", "marketing"],
      operator: "equals",
      value: true
    }
  ]
}
```

This checks the nested value at `preferences.notifications.marketing`.

### Operators

Use these operators when the condition compares against a value:

- `"equals"` matches when the stored value equals `value`.
- `"not_equals"` matches when the stored value does not equal `value`.
- `"greater_than"` matches numbers larger than `value`.
- `"greater_than_or_equal"` matches numbers larger than or equal to `value`.
- `"less_than"` matches numbers smaller than `value`.
- `"less_than_or_equal"` matches numbers smaller than or equal to `value`.

Use these operators when the condition only checks whether an attribute or nested path is present:

- `"exists"` matches when the attribute or nested path exists.
- `"not_exists"` matches when the attribute or nested path is missing.

Presence operators must not include `value`:

```elixir
attribute_filters: %{
  mode: "any",
  conditions: [
    %{key: "country", operator: "not_exists"},
    %{key: "preferences", path: ["sms"], operator: "exists"}
  ]
}
```

### Comparison values

For `"equals"` and `"not_equals"`, `value` can be any JSON value: string, number, boolean, object, array, or `nil`.

```elixir
attribute_filters: %{
  conditions: [
    %{key: "plan", operator: "equals", value: "pro"},
    %{key: "beta_enabled", operator: "equals", value: true},
    %{key: "limits", operator: "not_equals", value: %{"push" => 0}}
  ]
}
```

Boolean equality also matches stored string values `"true"` and `"false"` for compatibility with existing attributes.

Numeric comparison operators require an actual number, not a numeric string:

```elixir
# Good
%{key: "sessions", operator: "greater_than", value: 10}

# Invalid, because "10" is a string
%{key: "sessions", operator: "greater_than", value: "10"}
```

### Bulk-send behavior

For `create_notification_user_ids_aliases/4`, filters narrow the targeted audience from `user_ids` and `aliases`. They do not select devices outside that existing target set.

```elixir
BubblesNotifications.create_notification_user_ids_aliases(
  client,
  [],
  ["beta"],
  %{
    title: "Beta update",
    body: "A new build is ready.",
    data: %{"screen" => "release_notes"},
    attribute_filters: %{
      conditions: [
        %{
          key: "tags",
          path: ["nutrition_notifications"],
          operator: "equals",
          value: "true"
        }
      ]
    }
  }
)
```

### Validation errors

The server validates filters. Invalid filters return `{:error, %{status: 422, body: %{"errors" => errors}}}` using the normal API error envelope.

Common validation messages include:

- `attribute_filters`: `must be an object`
- `attribute_filters.mode`: `is invalid`
- `attribute_filters.conditions`: `can't be blank`, `must be an array`, or `must contain at most 10 conditions`
- `attribute_filters.conditions.N.key`: `can't be blank`
- `attribute_filters.conditions.N.path`: `must contain only non-empty strings`
- `attribute_filters.conditions.N.operator`: `is invalid`
- `attribute_filters.conditions.N.value`: `can't be blank`, `must not be present`, or `must be a number`

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
