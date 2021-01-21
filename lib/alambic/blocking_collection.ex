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

defprotocol Alambic.BlockingCollection do
  @moduledoc """
  Interface to a blocking collection.

  A blocking collection is a collection of items where:

  - multiple processes can push data into the collecion
  - multiple processes can consume items from the collection
  - a blocking collection may be "completed" meaning it will not
    accept any more items.
  - getting data blocks until some data is availbale or the collection
    is "omplete" (will not receive any more data)
  - putting data may block until some room is available in the collection
    for more data (blocking collections can either accept unlimited
    amount of items or limit the number of items they can hold)

  `BlockingCollection` also implements the `Enumerable` protocol and using
  functions from the `Enum` and `Stream` module is the preferred way of
  consuming a blocking collection. Enumerating a blocking collection will
  consume its items, so if multiple processes are enumerating a blocking
  collection at the same time, they will only see a subset of the items
  added to the collection.
  """

  @vsn 1

  @doc """
  Add an item to the collection. May block until some room is available
  in the collection.

  Return `:ok` if adding was successful, `:error` if some internal error
  occured or the collection does not accept items any more.
  """
  @spec add(t, term) :: :ok | :error
  def add(bc, item)

  @doc  """
  Try to add an item in the collection. Will return `true` if the item
  was added, `false` if the collection cannot accept items at the moment.
  """
  @spec try_add(t, term) :: true | false
  def try_add(bc, item)

  @doc """
  Get an item from the collection. If no item is available, will block
  until an item is available or the collection has been completed.

  Return:
  - `{:ok, item}` when an item is available
  - `:completed` when the collection has been completed
  - `:error` if some error occurred
  """
  @spec take(t) :: :error | :completed | {:ok, term}
  def take(bc)

  @doc """
  Try to get an item from the collection. Do not block.

  Return:
  - `{true, item}` if some item was found
  - `{false, reason}` if not item could be returned.
    `reason` maybe:
    - `:completed` if the collection is completed
    - `:error` if an error occurred
    - `:empty` if the collection is currenlty empty
  """
  @spec try_take(t) :: {true, term} | {false, :completed | :error | :empty}
  def try_take(bc)

  @doc """
  Put the collection in the completed state, where it will not accept any more
  items but will serve those currently inside the collection.
  """
  @spec complete(t) :: :ok | :error
  def complete(bc)

  @doc "Return the number of items in the collection."
  @spec count(t) :: integer
  def count(bc)
end

defmodule Alambic.BlockingCollection.Enumerable do
  @moduledoc """
  Mixin for `Enumerable` implementation in blocking collections.
  """

  alias Alambic.BlockingCollection

  defmacro __using__(_) do
    quote location: :keep do
      def member?(_coll, _value), do: {:error, __MODULE__}

      def count(coll), do: {:ok, BlockingCollection.count(coll)}

      def reduce(_coll, {:halt, acc}, _fun) do
        {:halted, acc}
      end

      def reduce(collection, {:suspend, acc}, fun) do
        {:suspended, acc, &reduce(collection, &1, fun)}
      end

      def reduce(collection, {:cont, acc}, fun) do
        case BlockingCollection.take(collection) do
          {:ok, item} -> reduce(collection, fun.(item, acc), fun)
          :completed -> {:done, acc}
          :error -> {:halted, acc}
        end
      end

      def slice(_coll), do: {:error, __MODULE__}

      defoverridable [count: 1, member?: 2]
    end
  end
end

defmodule Alambic.BlockingCollection.Collectable do
  @moduledoc """
  Mixin for `Collectable` implementation in blocking collections.
  """

  alias Alambic.BlockingCollection

  defmacro __using__(_) do
    quote location: :keep do
      def into(collection) do
        {collection, fn
            c, {:cont, item} ->
              :ok = BlockingCollection.add(c, item)
              c
            c, :done -> c
            _, :halt -> :ok
        end}
      end
    end
  end
end
