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

defprotocol Alambic.Waitable do
  @moduledoc ~S"""
  A generic interface for "waitable" objects.
  """

  @vsn 1

  @doc "Wait for the resource to be available"
  def wait(waited)

  @doc "Check if the resource is free (wait would not block)"
  def free?(waited)
end
