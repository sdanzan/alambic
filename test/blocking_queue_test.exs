defmodule Alambic.BlockingQueue.Tests do
  use ExUnit.Case
  doctest Alambic.BlockingQueue
  alias Alambic.BlockingQueue

  test "blocking enqueue" do
    q = BlockingQueue.create(1)
    :ok = BlockingQueue.enqueue(q, :item1)

    me = self
    spawn(fn ->
      BlockingQueue.enqueue(q, :item2)
      send(me, :done)
    end)

    refute_receive _, 100

    assert {:ok, :item1} == BlockingQueue.dequeue(q)
    assert_receive :done

    assert {:ok, :item2} == BlockingQueue.dequeue(q)
  end

  test "blocking dequeue" do
    q = BlockingQueue.create(1)

    me = self
    spawn(fn ->
      {:ok, item} = BlockingQueue.dequeue(q)
      send(me, item)
    end)

    refute_receive _, 100

    BlockingQueue.enqueue(q, :item1)

    assert_receive :item1, 100
  end

  test "try with waiters" do
    q = BlockingQueue.create(1)
    me = self

    spawn(fn ->
      {:ok, item} = BlockingQueue.dequeue(q)
      send(me, item)
    end)

    refute_receive _, 100

    assert BlockingQueue.try_enqueue(q, 1)
    assert_receive 1, 100
    assert BlockingQueue.try_enqueue(q, 2)

    spawn(fn ->
      BlockingQueue.enqueue(q, 3)
      send(me, 3)
    end)

    refute_receive _, 500

    {true, 2} = BlockingQueue.try_dequeue(q)
    assert_receive 3, 100
  end

  test "completed" do
    q = BlockingQueue.create(1)
    BlockingQueue.complete(q)
    refute BlockingQueue.try_enqueue(q, 1)
  end
end
