# Alambic

An Elixir collection of small utilities.

 - *Alambic.Semaphore:* a simple semaphore implementation intended for simple
   resource control scenarios.

 - *Alambic.CountDown:* a simple countdown latch implementation intended for
   simple fan in scenarios.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add alambic to your list of dependencies in `mix.exs`:

        def deps do
          [{:alambic, "~> 0.0.1"}]
        end

  2. Ensure alambic is started before your application:

        def application do
          [applications: [:alambic]]
        end
