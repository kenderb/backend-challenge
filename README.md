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

| Service           | Description                    | Port(s)   |
|-------------------|--------------------------------|-----------|
| **order_service** | Orders API (Rails)             | 3001      |
| **customer_service** | Customers API (Rails)       | 3002      |
| **order_db**      | PostgreSQL for Order Service  | 5433      |
| **customer_db**   | PostgreSQL for Customer Service| 5434      |
| **rabbitmq**      | Message broker + management UI | 5672, 15672 |

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
# Order Service
docker compose run --rm order_service bundle exec rspec

# Customer Service
docker compose run --rm customer_service bundle exec rspec
```

For the test DB, the same `POSTGRES_*` env vars are used (pointing to the compose DBs). If the test DBs don’t exist yet, create them first:

```bash
docker compose run --rm order_service bundle exec rails db:create db:migrate RAILS_ENV=test
docker compose run --rm customer_service bundle exec rails db:create db:migrate RAILS_ENV=test
```

Then run the specs as above.

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

## Summary

- **Run app:** `docker compose up --build -d` from `backend-challenge`.
- **Run Order Service specs:** `docker compose run --rm order_service bundle exec rspec` or from `order_service/`: `bundle exec rspec`.
- **Run Customer Service specs:** `docker compose run --rm customer_service bundle exec rspec` or from `customer_service/`: `bundle exec rspec`.
