defmodule GlobalService.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  require Logger

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GlobalServiceWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:global_service, :dns_cluster_query) || :ignore},
      {Cluster.Supervisor, [topologies() |> IO.inspect(label: "chosen cluster config")]},
      {Phoenix.PubSub, name: GlobalService.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: GlobalService.Finch},
      # Start a worker by calling: GlobalService.Worker.start_link(arg)
      # {GlobalService.Worker, arg},
      # Start to serve requests, typically the last entry
      GlobalServiceWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GlobalService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GlobalServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp topologies() do
    case System.get_env("ERLANG_SEED_NODES", "")
         |> String.split(",") |> Enum.reject(&String.trim(&1) == "")
         |> Enum.map(&String.to_atom/1) do
      [] ->
        [
          default: [
            strategy: Cluster.Strategy.Gossip
          ]
        ]

      seed_nodes ->
        [
          default: [
            strategy: Cluster.Strategy.Epmd,
            config: [hosts: seed_nodes]
          ]
        ]
    end
  end
end
