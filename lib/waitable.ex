defprotocol Alambic.Waitable do
  @doc "Wait for the resource to be available"
  def wait(waited)

  @doc "Check if the resource is free (wait would not block)"
  def free?(waited)
end
