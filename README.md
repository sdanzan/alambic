# Alambic [![Build Status](https://travis-ci.org/sdanzan/alambic.svg?branch=master)](https://travis-ci.org/sdanzan/alambic)

An Elixir collection of small utilities.

 - *Alambic.Semaphore:* a simple semaphore implementation intended for simple
   resource control scenarios.
 - *Alambic.CountDown:* a simple countdown latch implementation intended for
   simple fan in scenarios.
 - *Alambic.BlockingQueue:* a simple shared queue allowing consuming via the
   `Enum` and `Stream` modules.
 - *Alambic.BlockingCollection:* a protocol exposing standard functions to
   manipulate blocking collections.

## Installation

Add the github repository to your mix dependencies:

  1. Add alambic to your list of dependencies in `mix.exs`:

        def deps do
          [{:alambic, git: "https://github.com/sdanzan/alambic.git"}]
        end

  2. Ensure alambic is started before your application:

        def application do
          [applications: [:alambic]]
        end

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add alambic to your list of dependencies in `mix.exs`:

        def deps do
          [{:alambic, "~> 0.1.0"}]
        end

  2. Ensure alambic is started before your application:

        def application do
          [applications: [:alambic]]
        end
