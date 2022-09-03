defmodule Mix.Tasks.EveryLotBot.PostUpdate do
  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    api_key = System.fetch_env!("TWITTER_CONSUMER_API_KEY")
    api_key_secret = System.fetch_env!("TWITTER_CONSUMER_API_SECRET")
    access_token = System.fetch_env!("TWITTER_ACCESS_TOKEN")
    access_token_secret = System.fetch_env!("TWITTER_ACCESS_TOKEN_SECRET")

    ExTwitter.configure(
      consumer_key: api_key,
      consumer_secret: api_key_secret,
      access_token: access_token,
      access_token_secret: access_token_secret
    )

    Finch.start_link(name: MyFinch)
    EveryLotBot.post_update()
  end
end
