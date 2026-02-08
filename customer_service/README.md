# Customer Service

Rails API for customers. Requires an internal API key for `GET /customers/:id`.

## Internal API key

`GET /customers/:id` is protected by the header `X-Internal-Api-Key`. The app accepts the key from (in order):

1. **`INTERNAL_API_KEY`** environment variable (used in Docker)
2. **Rails credentials** under `internal_api_key` (when not using Docker)

### Running in Docker

The default key in Compose is **`your-secret-key`**. You can see it in `docker-compose.yml` under `customer_service` → `environment` → `INTERNAL_API_KEY` (or set your own in a `.env` file).

Call the API:

```bash
curl -H "X-Internal-Api-Key: your-secret-key" http://localhost:3002/customers/1
```

To use a different key, create a `.env` in the project root (`backend-challenge/`) with:

```
INTERNAL_API_KEY=my-other-secret
```

### Running locally (no Docker)

Set the key via Rails credentials:

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

Add:

```yaml
internal_api_key: your-secret-key
```

Then:

```bash
curl -H "X-Internal-Api-Key: your-secret-key" http://localhost:3002/customers/1
```

Without the header (or with a wrong key), the endpoint returns **401 Unauthorized**.

## Running the test suite

**From this directory (local):**

```bash
bundle exec rspec
```

**From the project root via Docker:** you must set the test environment or specs will run under development and can fail (e.g. 403 in request specs):

```bash
docker compose run --rm -e RAILS_ENV=test customer_service bundle exec rspec
```

Do **not** run `docker compose run --rm customer_service bundle exec rspec` without `-e RAILS_ENV=test`.

Tests stub the credential in request specs, so no need to set credentials for the test suite.

---

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
