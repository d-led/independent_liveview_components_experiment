defmodule Cluster.Presence do
  @moduledoc """
  Cluster-wide presence identity.

  `Phoenix.Presence` names the tracker after this module and derives the
  replication topic from that name
  (`phx_presence:Elixir.Cluster.Presence_shard0`). Every app declares this
  module in its own tree — same name, its own `otp_app` — so the trackers
  replicate with each other without sharing code, a package, or a deploy unit.

  Renaming it in one app only is a silent failure: a differently named module
  is a different tracker on a different topic, and every other app reports an
  empty lobby.
  """

  use Phoenix.Presence,
    otp_app: :global_service,
    pubsub_server: MainApp.PubSub
end
