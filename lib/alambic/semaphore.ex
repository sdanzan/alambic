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

defmodule Alambic.Semaphore do
  @moduledoc """
  A simple semaphore implementation, useful when you need quick
  control around resource access and do not want to resort to the
  full OTP artillery or complex process pooling.

  This semaphore is implemented as a GenServer.
  """

  @vsn 1

  use GenServer
  alias Alambic.Semaphore

  defstruct id: nil
  @type t :: %__MODULE__{id: pid}

  @doc """
  Create a semaphore with `max` slots.

      iex> s = Alambic.Semaphore.create(3)
      iex> is_nil(s.id)
      false
  """
  @spec create(integer) :: t
  def create(max) when is_integer(max) and max > 0 do
    {:ok, pid} = GenServer.start(__MODULE__, max)
    %Semaphore{id: pid}
  end

  @doc """
  Create a semaphore with `max` slots. The semaphore is linked to
  the current process.

      iex> s = Alambic.Semaphore.create_link(3)
      iex> is_nil(s.id)
      false
  """
  @spec create_link(integer) :: t
  def create_link(max) when is_integer(max) and max > 0 do
    {:ok, pid} = GenServer.start_link(__MODULE__, max)
    %Semaphore{id: pid}
  end

  @doc """
  Destroy a semaphore. Clients waiting on `acquire` will receive
  an `:error` response.
  """
  @spec destroy(t) :: nil
  def destroy(%Semaphore{id: pid}) do
    GenServer.cast(pid, :destroy)
  end

  @doc """
  Acquire a slot in the semaphore. Will block until a slot is available
  or the semaphore is destroyed.
  """
  @spec acquire(t) :: :ok | :error
  def acquire(_ = %Semaphore{id: pid}) do
    GenServer.call(pid, :acquire, :infinity)
  end

  @doc """
  Try to acquire a slot in the semaphore but does not block if no slot
  is available. Returns `true` if a slot was acquired, `false` otherwise.
  """
  @spec try_acquire(t) :: true | false
  def try_acquire(_ = %Semaphore{id: pid}) do
    GenServer.call(pid, :try_acquire, :infinity)
  end

  @doc """
  Release a slot from the semaphore. `:error` is returned if no slot
  is currently acquired.
  """
  @spec release(t) :: :ok | :error
  def release(_ = %Semaphore{id: pid}) do
    GenServer.call(pid, :release)
  end

  @doc """
  Return `true` if no slot is available, `false` otherwise.
  """
  @spec full?(t) :: true | false
  def full?(_ = %Semaphore{id: pid}) do
    GenServer.call(pid, :full?)
  end

  ############
  ## Protocols

  defimpl Alambic.Waitable, for: Semaphore do
    @doc """
    Acquire a slot in the semaphore.
    """
    @spec wait(Semaphore.t) :: :ok | :error
    def wait(semaphore) do
      Semaphore.acquire(semaphore)
    end

    @doc """
    Check if a slot is available.
    """
    @spec free?(Semaphore.t) :: true | false
    def free?(semaphore) do
      not Semaphore.full?(semaphore)
    end
  end

  ######################
  ## GenServer callbacks

  def init(max) do
    {:ok, {:queue.new, 0, max}}
  end

  def terminate({:shutdown, :destroyed}, {waiting, _, _}) do
    :queue.to_list(waiting) |> Enum.each(&GenServer.reply(&1, :error))
  end

  def handle_cast(:destroy, state) do
    {:stop, {:shutdown, :destroyed}, state}
  end

  def handle_call(:acquire, from, {waiting, acquired, max})
  when acquired == max do
    {:noreply, {:queue.in(from, waiting), acquired, max}}
  end

  def handle_call(:acquire, _, {waiting, acquired, max})
  when acquired < max do
    {:reply, :ok, {waiting, acquired + 1, max}}
  end

  def handle_call(:try_acquire, _, state = {_, acquired, max})
  when acquired == max do
    {:reply, false, state}
  end

  def handle_call(:try_acquire, _, {waiting = {[], []}, acquired, max})
  when acquired < max do
    {:reply, true, {waiting, acquired + 1, max}}
  end

  def handle_call(:release, _, state = {_, 0, _}) do
    {:reply, :error, state}
  end

  def handle_call(:release, _, {waiting = {[], []}, acquired, max}) do
    {:reply, {:ok, max - acquired}, {waiting, acquired - 1, max}}
  end

  def handle_call(:release, _, {waiting, acquired, max}) when acquired == max do
    {{:value, waiting_pid}, waiting} = :queue.out(waiting)
    GenServer.reply(waiting_pid, :ok)
    {:reply, {:ok, 0}, {waiting, acquired, max}}
  end

  def handle_call(:full?, _, state = {_, acquired, max}) do
    {:reply, acquired == max, state}
  end
end
