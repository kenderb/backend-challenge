# Backend Challenge

Microservices project with an **Order Service** and a **Customer Service**, PostgreSQL, and RabbitMQ.

## Project structure

```
backend-challenge/
├── docker-compose.yml          # Orchestration: DBs, RabbitMQ, both Rails apps
├── order_service/             # Rails API — orders, talks to Customer Service & RabbitMQ
│   ├── app/
│   │   ├── controllers/
│   │   ├── models/
│   │   └── ...
│   ├── config/
│   │   ├── database.yml       # Uses POSTGRES_* env vars
│   │   └── ...
│   ├── db/
│   ├── spec/                  # RSpec tests
│   ├── Gemfile
│   └── Dockerfile
├── customer_service/          # Rails API — customers, seeds, orders_count
│   ├── app/
│   │   ├── controllers/
│   │   ├── models/
│   │   │   └── customer.rb
│   │   └── ...
│   ├── config/
│   │   ├── database.yml       # Uses POSTGRES_* env vars
│   │   └── ...
│   ├── db/
│   │   ├── migrate/
│   │   └── seeds.rb           # 10 Faker customers
│   ├── spec/                  # RSpec tests
│   ├── Gemfile
│   └── Dockerfile
```

### Services overview

| Service                 | Description                                      | Port(s)   |
|-------------------------|--------------------------------------------------|-----------|
| **order_service**       | Orders API (Rails)                               | 3001      |
| **order_outbox_worker** | Publishes outbox events to RabbitMQ (waits for DB + broker) | —         |
| **customer_service**    | Customers API (Rails)                            | 3002      |
| **order_db**            | PostgreSQL for Order Service                     | 5433      |
| **customer_db**         | PostgreSQL for Customer Service                  | 5434      |
| **rabbitmq**            | Message broker + management UI                   | 5672, 15672 |

All containers use the internal network `be_test_net`. Database config uses `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` (set in `docker-compose.yml`).

---

## How to run the project

### With Docker (recommended)

**Requirements:** Docker and Docker Compose.

1. From the project root:

   ```bash
   cd backend-challenge
   docker compose up --build -d
   ```

2. Wait until all services are healthy (Rails apps may take ~30–60 seconds):

   ```bash
   docker compose ps -a
   ```

3. Endpoints:

   - **Order Service:** http://localhost:3001
   - **Customer Service:** http://localhost:3002
   - **RabbitMQ Management:** http://localhost:15672 (user: `guest`, password: `guest`)

4. Stop everything:

   ```bash
   docker compose down
   ```

### Without Docker (local Rails)

1. **PostgreSQL and RabbitMQ** must be running locally (or in Docker for DB + RabbitMQ only).

2. **Order Service:**

   ```bash
   cd order_service
   export POSTGRES_HOST=localhost POSTGRES_USER=order_service POSTGRES_PASSWORD=order_service POSTGRES_DB=order_service_development
   bundle install
   rails db:create db:migrate
   rails server -p 3001
   ```

3. **Customer Service** (in another terminal):

   ```bash
   cd customer_service
   export POSTGRES_HOST=localhost POSTGRES_USER=customer_service POSTGRES_PASSWORD=customer_service POSTGRES_DB=customer_service_development
   bundle install
   rails db:create db:migrate db:seed
   rails server -p 3002
   ```

If you omit the `POSTGRES_*` variables, Rails will use default socket connection (and default DB names).

---

## How to run the specs

Both apps use **RSpec**. Run specs per service.

### With Docker

From the project root, run specs inside the app containers:

```bash
# Create test DBs and run migrations (once per service)
docker compose run --rm -e RAILS_ENV=test order_service bundle exec rails db:create db:migrate
docker compose run --rm -e RAILS_ENV=test customer_service bundle exec rails db:create db:migrate

# Run specs (always use -e RAILS_ENV=test)
docker compose run --rm -e RAILS_ENV=test order_service bundle exec rspec
docker compose run --rm -e RAILS_ENV=test customer_service bundle exec rspec
```

**Important:** You **must** pass **`-e RAILS_ENV=test`** when running rspec in Docker. Without it, the container uses `RAILS_ENV=development` (the Compose default), so the test environment is never loaded and specs can fail (e.g. request specs returning 403 due to host authorization). Always use:

- **Correct:** `docker compose run --rm -e RAILS_ENV=test customer_service bundle exec rspec`
- **Wrong:** `docker compose run --rm customer_service bundle exec rspec` (omits test env)

Using `-e RAILS_ENV=test` also ensures the test database is used. App code is mounted into the containers, so **code changes are picked up immediately**—no rebuild needed. Only rebuild when you change the **Gemfile** or **Dockerfile**: `docker compose build customer_service`.

### Docker-first: run specs and linting inside running containers

With the stack up (`docker compose up -d`), run specs and RuboCop using **exec** (no new container):

```bash
# One-time: create test DB and run migrations
docker compose exec order_service bundle exec rails db:create db:migrate RAILS_ENV=test
docker compose exec customer_service bundle exec rails db:create db:migrate RAILS_ENV=test

# Run Order Service specs
docker compose exec order_service bundle exec rspec

# Run Customer Service specs
docker compose exec customer_service bundle exec rspec

# Run RuboCop (Order Service)
docker compose exec order_service bundle exec rubocop
```

Use `docker compose exec <service> <cmd>` for any one-off command inside a running container.

### Locally (no Docker)

From each service directory, with PostgreSQL available and `POSTGRES_*` set for test if needed:

```bash
# Order Service
cd order_service
bundle install
rails db:create db:migrate RAILS_ENV=test   # if needed
bundle exec rspec

# Customer Service (in another terminal)
cd customer_service
bundle install
rails db:create db:migrate RAILS_ENV=test   # if needed
bundle exec rspec
```

Useful RSpec options:

```bash
bundle exec rspec --format documentation   # verbose output
bundle exec rspec spec/models            # only model specs
bundle exec rspec path/to/spec_file.rb   # single file
```

---

## Transactional Outbox (Order Service)

Order creation uses the **Transactional Outbox Pattern**: `Orders::CreateOrder` wraps business logic and `OutboxEvent` creation in a **single ActiveRecord transaction**, so no event is lost if RabbitMQ is down at creation time.

- **Persistence:** Events are stored in the `outbox_events` table (PostgreSQL).
- **PublishingWorker:** Uses `FOR UPDATE SKIP LOCKED` when claiming pending events so multiple worker containers can run without race conditions. Publishes to RabbitMQ (`exchange: orders.v1`, `routing_key: order.created`) with retry and exponential backoff if the broker is unreachable. Uses `RABBITMQ_HOST` (e.g. `rabbitmq` in Docker).
- **Run once:** `bundle exec rake outbox:publish_once`
- **Run in a loop (e.g. every 5s):** `bundle exec rake "outbox:publish[5]"`
- **Docker:** The `order_outbox_worker` service waits for `order_db` and `rabbitmq` to be healthy, then runs the publishing loop.

The **Customer Service** applies `order.created` events **idempotently** via `Orders::ApplyOrderCreated` (using `event_id` and a `processed_order_events` table) so duplicate deliveries do not double-increment `orders_count`. Services return a **Result object** (`Result::Success` / `Result::Failure`) for clean API response handling.

---

## Summary

- **Run app:** `docker compose up --build -d` from `backend-challenge`.
- **Run Order Service specs:** `docker compose exec order_service bundle exec rspec` (with stack up) or `docker compose run --rm -e RAILS_ENV=test order_service bundle exec rspec`.
- **Run Customer Service specs:** `docker compose exec customer_service bundle exec rspec` or `docker compose run --rm -e RAILS_ENV=test customer_service bundle exec rspec`.
- **Lint Order Service:** `docker compose exec order_service bundle exec rubocop`.
