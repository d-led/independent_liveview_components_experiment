defmodule MainAppWeb.PresenceTest do
  use ExUnit.Case, async: false

  alias Phoenix.Socket.Broadcast

  test "tracking a session announces it to local subscribers" do
    topic = unique_topic()
    :ok = Phoenix.PubSub.subscribe(MainApp.PubSub, topic)

    {:ok, _ref} = Cluster.Presence.track(self(), topic, "session-1", %{state: :online})

    assert_receive %Broadcast{
                     topic: ^topic,
                     event: "presence_diff",
                     payload: %{
                       joins: %{"session-1" => %{metas: [%{state: :online}]}},
                       leaves: leaves
                     }
                   },
                   1_000

    assert leaves == %{}
  end

  test "untracking a session announces it as leaving" do
    topic = unique_topic()
    :ok = Phoenix.PubSub.subscribe(MainApp.PubSub, topic)
    {:ok, _ref} = Cluster.Presence.track(self(), topic, "session-2", %{})

    assert_receive %Broadcast{event: "presence_diff", payload: %{joins: %{"session-2" => _}}},
                   1_000

    Cluster.Presence.untrack(self(), topic, "session-2")

    assert_receive %Broadcast{event: "presence_diff", payload: %{leaves: %{"session-2" => _}}},
                   1_000
  end

  test "the presence view lists tracked sessions" do
    topic = unique_topic()

    {:ok, _ref} = Cluster.Presence.track(self(), topic, "session-3", %{state: :online})

    assert Map.keys(Cluster.Presence.list(topic)) == ["session-3"]
  end

  defp unique_topic, do: "presence:test:#{System.unique_integer([:positive])}"
end
