# Backend Challenge

Microservices project: **Order Service** and **Customer Service** (Rails), PostgreSQL, and RabbitMQ.

---

## Overview

| Service                 | Description                           | Port(s)   |
|-------------------------|---------------------------------------|-----------|
| **order_service**       | Orders API                             | 3001      |
| **order_outbox_worker** | Publishes outbox events to RabbitMQ   | —         |
| **customer_service**    | Customers API                         | 3002      |
| **order_db**            | PostgreSQL (Order Service)            | 5433      |
| **customer_db**         | PostgreSQL (Customer Service)        | 5434      |
| **rabbitmq**            | Message broker + management UI        | 5672, 15672 |

All services use network `be_test_net`. DB config: `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` (see `docker-compose.yml`).

---

## Quick Start (Docker)

**Requirements:** Docker and Docker Compose.

```bash
cd backend-challenge
docker compose up --build -d
docker compose ps -a   # wait until healthy (~30–60 s for Rails)
```

**Endpoints**

| App              | URL                        |
|------------------|----------------------------|
| Order Service    | http://localhost:3001      |
| Customer Service | http://localhost:3002      |
| RabbitMQ UI      | http://localhost:15672 (guest / guest) |

**Stop:** `docker compose down`

---

## Tests and Linting

Both apps use **RSpec**. Use **`RAILS_ENV=test`** for any test command in Docker.

### Docker (stack must be running)

One-time: create test DBs and migrate:

```bash
docker compose exec order_service bundle exec rails db:create db:migrate RAILS_ENV=test
docker compose exec customer_service bundle exec rails db:create db:migrate RAILS_ENV=test
```

Then run tests or lint (use **`-e RAILS_ENV=test`** with exec so the test environment loads; otherwise the container defaults to development and request specs can get 403):

```bash
# Tests
docker compose exec -e RAILS_ENV=test order_service bundle exec rspec
docker compose exec -e RAILS_ENV=test customer_service bundle exec rspec

# Lint (Order Service)
docker compose exec order_service bundle exec rubocop
```

### Docker (one-off, no stack)

```bash
docker compose run --rm -e RAILS_ENV=test order_service bundle exec rails db:create db:migrate
docker compose run --rm -e RAILS_ENV=test order_service bundle exec rspec
# Same for customer_service
```

### Local (no Docker)

From each service directory (`order_service` or `customer_service`):

```bash
export POSTGRES_HOST=localhost POSTGRES_USER=... POSTGRES_PASSWORD=... POSTGRES_DB=..._development
bundle install
rails db:create db:migrate RAILS_ENV=test
bundle exec rspec
```

Code is mounted in containers; rebuild only when **Gemfile** or **Dockerfile** changes: `docker compose build <service>`.

---

## Architecture

### Transactional Outbox (Order Service)

**Why the Outbox pattern?**  
We use it to avoid the **dual-write problem**. Writing the order to the DB and then publishing to RabbitMQ in two steps can leave the system inconsistent (e.g. order saved but publish fails, or the reverse). The Outbox pattern gives one source of truth: the order and an outbox row are written in **one database transaction**. A worker later publishes from the outbox to RabbitMQ. If the broker is down, events stay in the outbox and can be retried without losing or duplicating business state.

**How it works**

- **`Orders::CreateOrder`** creates the order and an `OutboxEvent` in a single `ActiveRecord` transaction.
- Events live in the **`outbox_events`** table. **`Outbox::PublishingWorker`** claims rows with `FOR UPDATE SKIP LOCKED` (safe for multiple worker containers), publishes to RabbitMQ (`exchange: orders.v1`, `routing_key: order.created`) with exponential backoff, and marks them processed only after a successful publish.
- **Docker:** `order_outbox_worker` waits for `order_db` and `rabbitmq` to be healthy, then runs the publish loop (e.g. every 5s).
- **Rake:** `bundle exec rake outbox:publish_once` or `bundle exec rake "outbox:publish[5]"`.

API responses use a **Result object** (`Result::Success` / `Result::Failure`).

### Idempotency (Customer Service)

If RabbitMQ delivers the same `order.created` message twice, **`orders_count` must not be incremented twice**.

- Each message carries a unique **`event_id`** (outbox row id).
- **Customer Service** has a **`processed_order_events`** table with a unique constraint on `event_id`.
- **`Orders::ApplyOrderCreated`** skips if `event_id` is already present; otherwise it records the event and increments `orders_count`. Concurrent duplicates are handled via `RecordNotUnique`.

So **`orders_count` is incremented at most once per event**, even with duplicate deliveries.

---

## Quick Reference

| Task              | Command |
|-------------------|---------|
| Start stack      | `docker compose up --build -d` |
| Order Service tests | `docker compose exec -e RAILS_ENV=test order_service bundle exec rspec` |
| Customer Service tests | `docker compose exec -e RAILS_ENV=test customer_service bundle exec rspec` |
| Lint Order Service | `docker compose exec order_service bundle exec rubocop` |
