defmodule Alambic.BlockingCollection.Tests do
  use ExUnit.Case
  alias Alambic.BlockingCollection
  alias Alambic.BlockingQueue

  test "simple enumeration" do
    c = BlockingQueue.create()

    1..10 |> Enum.each &BlockingCollection.add(c, &1)
    BlockingCollection.complete(c)

    assert 10 == Enum.count(c)
    assert (1..10 |> Enum.sum) == Enum.sum(c)
    assert 0 == Enum.count(c)
  end

  test "take" do
    c = BlockingQueue.create()
    BlockingCollection.add(c, 0)
    BlockingCollection.add(c, 1)
    BlockingCollection.add(c, 2)
    assert 0 == (c |> Stream.take(1) |> Enum.at(0))
    assert 1 == (c |> Stream.take(1) |> Enum.at(0))
    assert 2 == (c |> Stream.take(1) |> Enum.at(0))
    assert 0 == BlockingCollection.count(c)
  end

  test "collectable" do
    c = BlockingQueue.create()
    1..10 |> Enum.into(c)
    BlockingCollection.complete(c)

    assert Enum.to_list(c) == Enum.to_list(1..10)
    assert Enum.count(c) == 0
  end

  test "producer consumer" do
    c = BlockingQueue.create(15)

    spawn(fn ->
      1..1000 |> Enum.into(c)
      BlockingCollection.complete(c)
    end)

    l = Enum.to_list(c)

    assert length(l) == 1000
    assert l == 1..1000 |> Enum.to_list
  end

  test "multiple producer consumer" do
    c = BlockingQueue.create(15)

    spawn(fn ->
      1..1000 |> Enum.into(c)
      BlockingCollection.complete(c)
    end)

    me = self
    spawn(fn ->
      l = Enum.to_list(c)
      send(me, l)
    end)

    l = Enum.to_list(c)

    l = receive do
      x -> x ++ l
    end

    assert length(l) == 1000
    assert Enum.sort(l) == Enum.to_list(1..1000)
  end
end
