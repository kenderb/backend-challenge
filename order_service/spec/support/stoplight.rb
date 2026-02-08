# frozen_string_literal: true

# Silence Stoplight circuit breaker output during specs (e.g. "Switching ... from green to red").
Stoplight.default_notifiers = []
