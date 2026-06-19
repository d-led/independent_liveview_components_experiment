# Independent Phoenix LiveView Micro-UIs Experiment

## Motivation

- allow multiple teams to deploy parts of a LiveView independently with maximum simplicity
- there's no settled optimum yet, ideas are welcome

## Current Architecture

- 3 independent nodes connected in a cluster
- [main_app](./main_app/) acts as the front-end, serving the [main page](main_app/lib/main_app_web/live/main_live.ex)
- [global_service](./global_service/) and [private_service](./private_service/) [push rendered partial LiveViews](private_service/lib/private_service/private_click_aggregator_service.ex) into Pub/Sub, to which the `main_app` is subscribed, rendering them as they are, within the main view.
- the services also expose their own LiveViews for e.g. their "admin" purposes

![3 mini UIs](./docs/img/3-mini-uis.gif)

### Architecture at a Glance

#### 1. Cluster Topology & Network (High Level)
Shows how the 3 independent service nodes form a cluster and communicate using a shared clustered PubSub adapter.

```mermaid
flowchart TD
    subgraph Network ["Erlang Node Cluster (127.0.0.1)"]
        direction LR
        MainNode["main_app<br>(Port 4000)"]
        GlobalNode["global_service<br>(Port 4001)"]
        PrivateNode["private_service<br>(Port 4002)"]
        
        MainNode <--> |libcluster Gossip| GlobalNode
        MainNode <--> |libcluster Gossip| PrivateNode
        GlobalNode <--> |libcluster Gossip| PrivateNode
    end

    subgraph PubSub ["Shared Infrastructure"]
        PubSubServer["MainApp.PubSub (PG2/PG)"]
    end

    MainNode -.-> PubSubServer
    GlobalNode -.-> PubSubServer
    PrivateNode -.-> PubSubServer
```

#### 2. Click Interaction & HTML UI Update Flow
Shows the path of a click event and how micro-UI partial views are rendered and updated back to the user.

```mermaid
flowchart TD
    User([User Browser]) -->|Clicks button| MainLive["MainAppWeb.MainLive"]
    
    %% Click Event Broadcast
    MainLive -->|1. Broadcast event: 'click'| GlobalTopic["Topic: global_topic"]
    
    %% Aggregation
    GlobalTopic --> GlobalAgg["GlobalClickAggregatorService"]
    GlobalTopic --> PrivateAgg["PrivateClickAggregatorService"]
    
    %% HTML Rendering Broadcasts
    GlobalAgg -->|2. Broadcast view: :global| GlobalRender["Topic: global_rendering_topic"]
    PrivateAgg -->|3. Broadcast view: :private| PrivateRender["Topic: private_clicks::session_id"]
    
    %% LiveView rendering
    GlobalRender -->|Renders component| MainLive
    PrivateRender -->|Renders component| MainLive
    MainLive -->|Updates UI| User
```

#### 3. Session Presence & Status Tracking
Shows how Phoenix Presence tracks session IDs and replicates their online/offline state across nodes.

```mermaid
flowchart TD
    User([User Browser]) -->|Connects| MainLive["MainAppWeb.MainLive"]
    
    %% Local Tracking
    MainLive -->|1. Presence.track/4| PresenceMain["MainAppWeb.Presence (main_app)"]
    
    %% Cluster Sync
    PresenceMain <-->|2. Internal replication| PresencePrivate["MainAppWeb.Presence (private_service)"]
    
    %% Status update
    PresencePrivate -->|3. Broadcast presence_diff| PresenceTopic["Topic: presence:lobby"]
    PresenceTopic -->|4. Receives diff| PrivateLive["PrivateServiceWeb.MainLive"]
    
    %% UI display
    PrivateLive -->|5. Renders green/gray dot| AdminUI([Sessions Dashboard UI])
```

### Challenges

- very chatty/wasteful:
  - rendered partial HTML views are sent from the services, instead of the optimized configuration as known in LiveView
- current docker compose / libcluster config creates a sporadically disconnected cluster
- presence messages seem to not reach the services
  - work-around: when a main LiveView is mounted, a custom `hi` message is published into the `arrivals` channel, requesting a rendered UI from the services.

### Pending Ideas

- 3 LiveView sockets
  - potentially served via the same reverse proxy under different paths
- other approaches, unifying the LiveView socket?
- when a service goes doesn / hasn't sent updates in a while, show a `currently unavailable` message in the main view
  - custom monitor?
  - custom scheduled messages to `self()` in main LiveView?

### Failed Approaches

- trying to render the diffs only:
  - unfortunately, this failed with the diff (?) functions not being present on the `main_app`

## Start with process-compose

- install [process-compose](https://f1bonacc1.github.io/process-compose/installation/)
- `process-compose``
- &rarr; http://localhost:4000
  - http://localhost:4001
  - http://localhost:4002

## Start with docker compose

- `docker compose up` (with other options depending on the needs)
- &rarr; http://localhost:4001
  - http://localhost:4001/services/global
  - http://localhost:4001/services/private