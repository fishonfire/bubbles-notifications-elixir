defmodule BubblesNotificationsTest do
  use ExUnit.Case, async: true

  alias BubblesNotifications

  setup do
    bypass = Bypass.open()
    base_url = "http://localhost:#{bypass.port}"

    Application.put_env(:bubbles_notifications, :base_url, base_url)

    on_exit(fn ->
      Application.delete_env(:bubbles_notifications, :base_url)
      Application.delete_env(:bubbles_notifications, :headers)
      Application.delete_env(:bubbles_notifications, :receive_timeout)
    end)

    %{bypass: bypass, base_url: base_url}
  end

  test "initialize/2 builds a client with configured base url", %{base_url: base_url} do
    client = BubblesNotifications.initialize(7, "test-api-key")

    assert client.app_id == 7
    assert client.api_key == "test-api-key"
    assert client.base_url == base_url
  end

  test "create_notification/2 sends the expected payload and bearer token", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/api/notifications/create", fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-api-key"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "app_id" => 7,
               "title" => "New message",
               "body" => "Hello from BubblesNotifications",
               "data" => %{"user_id" => 123, "type" => "message"}
             }

      Plug.Conn.resp(
        conn,
        201,
        ~s({"id":99,"app_id":7,"title":"New message","body":"Hello from BubblesNotifications","data":{"user_id":123,"type":"message"},"created_at":"2026-08-06T12:00:00Z"})
      )
    end)

    client = BubblesNotifications.initialize(7, "test-api-key")

    assert {:ok,
            %{
              "id" => 99,
              "app_id" => 7,
              "title" => "New message",
              "body" => "Hello from BubblesNotifications",
              "data" => %{"user_id" => 123, "type" => "message"},
              "created_at" => "2026-08-06T12:00:00Z"
            }} =
             BubblesNotifications.create_notification(client, %{
               title: "New message",
               body: "Hello from BubblesNotifications",
               data: %{user_id: 123, type: "message"}
             })
  end

  test "create_notification/2 returns unauthorized errors", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/api/notifications/create", fn conn ->
      Plug.Conn.resp(conn, 401, ~s({"error":"unauthorized"}))
    end)

    client = BubblesNotifications.initialize(7, "bad-key")

    assert {:error, %{status: 401, body: %{"error" => "unauthorized"}}} =
             BubblesNotifications.create_notification(client, %{
               title: "x",
               body: "y",
               data: %{}
             })
  end

  test "create_notification/2 returns validation errors", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/api/notifications/create", fn conn ->
      Plug.Conn.resp(conn, 422, ~s({"errors":{"title":["can't be blank"]}}))
    end)

    client = BubblesNotifications.initialize(7, "test-api-key")

    assert {:error, %{status: 422, body: %{"errors" => %{"title" => ["can't be blank"]}}}} =
             BubblesNotifications.create_notification(client, %{
               title: "",
               body: "Body",
               data: %{}
             })
  end

  test "create_notification/2 returns an argument error when required fields are missing" do
    client = BubblesNotifications.initialize(7, "test-api-key")

    assert {:error, %ArgumentError{message: "missing required notification field: :data"}} =
             BubblesNotifications.create_notification(client, %{
               title: "Missing data",
               body: "Body"
             })
  end

  test "send_push_to_device/3 posts to the device endpoint with the expected payload", %{
    bypass: bypass
  } do
    Bypass.expect_once(bypass, "POST", "/api/devices/device-123/send-push", fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-api-key"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "title" => "Direct push",
               "body" => "Device message",
               "data" => %{"additionalProp1" => %{}}
             }

      Plug.Conn.resp(
        conn,
        201,
        ~s({"device_id":"device-123","title":"Direct push","body":"Device message","data":{"additionalProp1":{}}})
      )
    end)

    client = BubblesNotifications.initialize(7, "test-api-key")

    assert {:ok,
            %{
              "device_id" => "device-123",
              "title" => "Direct push",
              "body" => "Device message",
              "data" => %{"additionalProp1" => %{}}
            }} =
             BubblesNotifications.send_push_to_device(client, "device-123", %{
               title: "Direct push",
               body: "Device message",
               data: %{additionalProp1: %{}}
             })
  end

  test "send_push_to_device/3 returns unauthorized errors", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/api/devices/44/send-push", fn conn ->
      Plug.Conn.resp(conn, 401, ~s({"error":"unauthorized"}))
    end)

    client = BubblesNotifications.initialize(7, "bad-key")

    assert {:error, %{status: 401, body: %{"error" => "unauthorized"}}} =
             BubblesNotifications.send_push_to_device(client, 44, %{
               title: "Direct push",
               body: "Denied",
               data: %{}
             })
  end
end
