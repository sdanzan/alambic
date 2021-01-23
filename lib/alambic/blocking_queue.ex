# Copyright 2015 Serge Danzanvilliers <serge.danzanvilliers@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Alambic.BlockingQueue do
  @moduledoc """
  A queue hosted in a process so that other processes can access it concurrently.
  It implements the BlockingCollection protocol. Enumerating a `BlockingQueue` will
  consumes it content. Enumeration only complete when the `BlockingQueue` is empty
  and `BlockingQueue.complete/1` has been called on the `BlockingQueue`.

  It is implemented as a GenServer.

  If you need to start a named `BlockingQueue` as part of a supervision tree, you
  can directly use the `GenServer.start/start_link` functions.
  """
  @vsn 1

  use GenServer
  alias Alambic.BlockingQueue

  defstruct id: nil
  @type t :: %__MODULE__{id: nil | pid}

  @doc """
  Create a `BlockingQueue` with a given limit on the numbers of items it
  can contain.

  ## Example

      iex> %Alambic.BlockingQueue{id: pid} = Alambic.BlockingQueue.create()
      iex> is_pid(pid)
      true
  """
  @spec create(integer | :unlimited) :: t
  def create(max \\ :unlimited) do
    {:ok, pid} = GenServer.start(__MODULE__, max)
    %BlockingQueue{id: pid}
  end

  @doc """
  Create a `BlockingQueue` linked to the current process.

  ## Example

      iex> %Alambic.BlockingQueue{id: pid} = Alambic.BlockingQueue.create_link()
      iex> is_pid(pid)
      true
  """
  @spec create_link(integer | :unlimited) :: t
  def create_link(max \\ :unlimited) do
    {:ok, pid} = GenServer.start_link(__MODULE__, max)
    %BlockingQueue{id: pid}
  end

  @doc """
  Destroy a `BlockingQueue`, losing all its current messages.

  ## Example

      iex> queue = Alambic.BlockingQueue.create
      iex> Alambic.BlockingQueue.destroy(queue)
      :ok
  """
  @spec destroy(t) :: :ok
  def destroy(%BlockingQueue{id: pid}) do
    GenServer.cast(pid, :destroy)
  end

  @doc """
  Enqueue some value. If the queue currently contains the maximum
  number of elements allowed, it will block until at least one item
  has been consumed.

  ## Example

      iex> q = Alambic.BlockingQueue.create()
      iex> Alambic.BlockingQueue.enqueue(q, :some_data)
      :ok
  """
  @spec enqueue(t, term) :: :ok | :error
  def enqueue(%BlockingQueue{id: pid}, item) do
    GenServer.call(pid, {:add, item}, :infinity)
  end

  @doc """
  Try to add an item to the queue. Will never block.

  ## Example

      iex> q = Alambic.BlockingQueue.create(1)
      iex> :ok = Alambic.BlockingQueue.enqueue(q, :item)
      iex> Alambic.BlockingQueue.try_enqueue(q, :item)
      false
  """
  @spec try_enqueue(t, term) :: true | false
  def try_enqueue(%BlockingQueue{id: pid}, item) do
    GenServer.call(pid, {:try_add, item})
  end

  @doc """
  Dequeue one item from the queue. If no item is available,
  will wait until some data is available.

  ## Example

      iex> q = Alambic.BlockingQueue.create()
      iex> :ok = Alambic.BlockingQueue.enqueue(q, :data1)
      iex> :ok = Alambic.BlockingQueue.enqueue(q, :data2)
      iex> Alambic.BlockingQueue.dequeue(q)
      {:ok, :data1}
  """
  @spec dequeue(t) :: {:ok, term} | :error | :completed
  def dequeue(%BlockingQueue{id: pid}) do
    GenServer.call(pid, :take, :infinity)
  end

  @doc """
  Try to dequeue some data from the queue. If one item is available
  {true, item} is returned, false otherwise.

  ## Example

      iex> q = Alambic.BlockingQueue.create()
      iex> {false, :empty} = Alambic.BlockingQueue.try_dequeue(q)
      iex> :ok = Alambic.BlockingQueue.enqueue(q, :data)
      iex> Alambic.BlockingQueue.try_dequeue(q)
      {true, :data}
  """
  @spec try_dequeue(t) :: {true, term} | {false, :empty | :error | :completed}
  def try_dequeue(%BlockingQueue{id: pid}) do
    GenServer.call(pid, :try_take)
  end

  @doc """
  Signal the collection will no longer accept items.

  ## Example

      iex> q = Alambic.BlockingQueue.create()
      iex> :ok = Alambic.BlockingQueue.complete(q)
      iex> :completed = Alambic.BlockingQueue.dequeue(q)
      iex> {false, :completed} = Alambic.BlockingQueue.try_dequeue(q)
      iex> Alambic.BlockingQueue.enqueue(q, :item)
      :error
  """
  @spec complete(t) :: :ok
  def complete(%BlockingQueue{id: pid}) do
    GenServer.call(pid, :complete)
  end

  @doc """
  Return the number of items in the queue.

  ## Example

      iex> q = Alambic.BlockingQueue.create()
      iex> 0 = Alambic.BlockingQueue.count(q)
      iex> :ok = Alambic.BlockingQueue.enqueue(q, :data)
      iex> :ok = Alambic.BlockingQueue.enqueue(q, :data)
      iex> :ok = Alambic.BlockingQueue.enqueue(q, :data)
      iex> Alambic.BlockingQueue.count(q)
      3
  """
  def count(%BlockingQueue{id: pid}) do
    GenServer.call(pid, :count)
  end

  # -------------------
  # GenServer callbacks

  defmodule State do
    @moduledoc "State for the blocking queue."
    defstruct take: {[], []}, add: {[], []}, items: {[], []}, count: 0, max: :unlimited, completed: false
    @type t :: %__MODULE__{take: {list, list}, add: {list, list}, items: {list, list}, count: integer, max: integer | :unlimited, completed: true | false}
  end

  def init(max) when (is_integer(max) and max > 0) or max == :unlimited do
    {:ok, %State{max: max}}
  end

  def terminate(_, state = %State{}) do
    :queue.to_list(state.take) |> Enum.each(&GenServer.reply(&1, :error))
    :queue.to_list(state.add) |> Enum.each(&GenServer.reply(elem(&1, 1), :error))
  end

  # destroy
  def handle_cast(:destroy, state) do
    {:stop, :normal, state}
  end

  # count
  def handle_call(:count, _from, state = %State{count: count}) do
    {:reply, count, state}
  end

  # complete - already empty
  def handle_call(:complete, _from, state = %State{count: 0}) do
    :queue.to_list(state.take) |> Enum.each(&GenServer.reply(&1, :completed))
    {:reply, :ok, %{state | completed: true}}
  end

  # complete
  def handle_call(:complete, _from, state = %State{}) do
    {:reply, :ok, %{state | completed: true}}
  end

  # add - completed
  def handle_call({:add, _item}, _from, state = %State{completed: true}) do
    {:reply, :error, state}
  end

  # add - count == max
  def handle_call({:add, item}, from, state = %State{count: count, max: max})
  when is_integer(max) and count == max
  do
    {:noreply, %{state | add: :queue.in({item, from}, state.add)}}
  end

  # add - no waiter
  def handle_call({:add, item}, _from, state = %State{take: {[], []}}) do
    {:reply, :ok, %{state | items: :queue.in(item, state.items), count: state.count + 1}}
  end

  # add - waiters (means count == 0)
  def handle_call({:add, item}, _from, state = %State{count: 0}) do
    {{:value, taker}, take} = :queue.out(state.take)
    GenServer.reply(taker, {:ok, item})
    {:reply, :ok, %{state | take: take}}
  end

  # try_add - completed
  def handle_call({:try_add, _item}, _from, state = %State{completed: true}) do
    {:reply, false, state}
  end

  # try_add - count == max
  def handle_call({:try_add, _item}, _from, state = %State{count: count, max: max})
  when is_integer(max) and count == max
  do
    {:reply, false, state}
  end

  # try_add - no waiter
  def handle_call({:try_add, item}, _from, state = %State{take: {[], []}}) do
    {:reply, true, %{state | items: :queue.in(item, state.items), count: state.count + 1}}
  end

  # try_add - waiters (means count == 0)
  def handle_call({:try_add, item}, _from, state = %State{count: 0}) do
    {{:value, taker}, take} = :queue.out(state.take)
    GenServer.reply(taker, {:ok, item})
    {:reply, true, %{state | take: take}}
  end

  # take - empty and completed
  def handle_call(:take, _from, state = %State{count: 0, completed: true}) do
    {:reply, :completed, state}
  end

  # take - count == 0
  def handle_call(:take, from, state = %State{count: 0}) do
    {:noreply, %{state | take: :queue.in(from, state.take)}}
  end

  # take - no waiter
  def handle_call(:take, _from, state = %State{add: {[], []}}) do
    {{:value, item}, items} = :queue.out(state.items)
    {:reply, {:ok, item}, %{state | items: items, count: state.count - 1}}
  end

  # take - waiters (means count == max)
  def handle_call(:take, _from, state = %State{count: count, max: max})
  when count == max
  do
    {{:value, item}, items} = :queue.out(state.items)
    {{:value, {to_add, adder}}, add} = :queue.out(state.add)
    GenServer.reply(adder, :ok)
    {:reply, {:ok, item}, %{state | add: add, items: :queue.in(to_add, items)}}
  end

  # try_take - empty and completed
  def handle_call(:try_take, _from, state = %State{count: 0, completed: true}) do
    {:reply, {false, :completed}, state}
  end

  # try_take - count == 0
  def handle_call(:try_take, _from, state = %State{count: 0}) do
    {:reply, {false, :empty}, state}
  end

  # try_take - no waiter
  def handle_call(:try_take, _from, state = %State{add: {[], []}}) do
    {{:value, item}, items} = :queue.out(state.items)
    {:reply, {true, item}, %{state | items: items, count: state.count - 1}}
  end

  # try_take - waiters (means count == max)
  def handle_call(:try_take, _from, state = %State{count: count, max: max})
  when count == max
  do
    {{:value, item}, items} = :queue.out(state.items)
    {{:value, {to_add, adder}}, add} = :queue.out(state.add)
    GenServer.reply(adder, :ok)
    {:reply, {:true, item}, %{state | add: add, items: :queue.in(to_add, items)}}
  end
end

defimpl Alambic.BlockingCollection, for: Alambic.BlockingQueue do
  alias Alambic.BlockingQueue

  def count(q), do: BlockingQueue.count(q)
  def complete(q), do: BlockingQueue.complete(q)
  def take(q), do: BlockingQueue.dequeue(q)
  def try_take(q), do: BlockingQueue.try_dequeue(q)
  def add(q, item), do: BlockingQueue.enqueue(q, item)
  def try_add(q, item), do: BlockingQueue.try_enqueue(q, item)
end

defimpl Enumerable, for: Alambic.BlockingQueue do
  use Alambic.BlockingCollection.Enumerable
end

defimpl Collectable, for: Alambic.BlockingQueue do
  use Alambic.BlockingCollection.Collectable
end
