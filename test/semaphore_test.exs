defmodule Alambic.Semaphore.Tests do
  use ExUnit.Case
  doctest Alambic.Semaphore
  alias Alambic.Semaphore

  test "create semaphore" do
    s = Semaphore.create(3)
    %Semaphore{id: pid} = s
    assert is_pid(pid)
    Semaphore.destroy(s)
  end

  test "cannot create negative semaphore" do
    catch_error Semaphore.create(0)
    catch_error Semaphore.create(-6325)
  end

  setup context do
    if count = context[:count] do
      s = Semaphore.create(count)
      on_exit fn -> Semaphore.destroy(s) end
      {:ok, s: s}
    else
      :ok
    end
  end

  @tag count: 3
  test "semaphore workflow", %{s: s} do
    assert :ok = Semaphore.acquire(s)
    assert {:ok, 2} = Semaphore.release(s)
    refute Semaphore.full?(s)
    assert :ok = Semaphore.acquire(s)
    assert true == Semaphore.try_acquire(s)
    assert :ok = Semaphore.acquire(s)
    assert false == Semaphore.try_acquire(s)
    assert Semaphore.full?(s)
    assert {:ok, 0} = Semaphore.release(s)
    assert {:ok, 1} = Semaphore.release(s)
    assert {:ok, 2} = Semaphore.release(s)
    assert :error = Semaphore.release(s)
  end

  @tag count: 2
  test "release unlock", %{s: s} do
    Semaphore.acquire(s)
    Semaphore.acquire(s)

    me = self
    spawn fn -> send(me, {:one, Semaphore.acquire(s)}) end
    spawn fn -> send(me, {:two, Semaphore.acquire(s)}) end

    refute_receive _, 100

    Semaphore.release(s)
    assert_receive {:one, :ok}

    Semaphore.release(s)
    assert_receive {:two, :ok}
  end

  test "destroy unlock" do
    s = Semaphore.create(2)
    Semaphore.acquire(s)
    Semaphore.acquire(s)

    me = self
    spawn fn -> send(me, {:one, Semaphore.acquire(s)}) end
    spawn fn -> send(me, {:two, Semaphore.acquire(s)}) end

    refute_receive _, 100
    Semaphore.destroy(s)

    assert_receive {:one, :error}
    assert_receive {:two, :error}
  end
end
