defmodule Mix.Tasks.EveryLotBot.PostUpdate do
  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    Finch.start_link(name: MyFinch)
    EveryLotBot.post_update()
  end
end
