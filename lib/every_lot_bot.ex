defmodule EveryLotBot do
  @moduledoc """
  Documentation for `EveryLotBot`.
  """

  @doc """
  Hello world.



    el = EveryLot(args.database,
                  logger=logger,
                  print_format=args.print_format,
                  search_format=args.search_format,
                  id_=args.id)

    if not el.lot:
        logger.error('No lot found')
        return

    logger.debug('%s addresss: %s zip: %s', el.lot['id'], el.lot.get('address'), el.lot.get('zip'))
    logger.debug('db location %s,%s', el.lot['lat'], el.lot['lon'])

    # Get the streetview image and upload it
    # ("sv.jpg" is a dummy value, since filename is a required parameter).
    image = el.get_streetview_image(api.config['streetview'])
    media = api.media_upload('sv.jpg', file=image)

    # compose an update with all the good parameters
    # including the media string.
    update = el.compose(media.media_id_string)
    logger.info(update['status'])

    if not args.dry_run:
        logger.debug("posting")
        status = api.update_status(**update)
        try:
            el.mark_as_tweeted(status.id)
        except AttributeError:
            el.mark_as_tweeted('1')
  1529 N VAN BUREN ST, 53202
  CREATE TABLE lots(
  id TEXT,
  lat REAL,
  lon REAL,
  address TEXT,
  city TEXT,
  state TEXT,
  zip INT,
  tweeted TEXT
  );

  ## Examples

      iex> EveryLotBot.hello()
      :world

  """
  def hello do
    :world
  end

  def get_streetview_image do
    Finch.start_link(name: MyFinch)
    url = "https://maps.googleapis.com/maps/api/streetview"

    params = %{
      fov: 65,
      pitch: 10,
      size: "1000x1000",
      key: "AIzaSyAnycoKRUofTlRK87nyk-qQedzJ97dJAoo",
      location: "2501 S LENOX ST, MILWAUKEE, WI",
      return_error_code: true,
      source: "outdoor"
    }

    full_url = "#{url}?#{URI.encode_query(params)}"
  end

  def post_update do
    ExTwitter.configure(
      [
        consumer_key: System.fetch_env!("TWITTER_CONSUMER_API_KEY"),
        consumer_secret: System.fetch_env!("TWITTER_CONSUMER_ACCESS_TOKEN_SECRET"),
        access_token: System.fetch_env!("TWITTER_CONSUMER_API_KEY"),
        access_token_secret: System.fetch_env!("TWITTER_CONSUMER_API_SECRET")
      ]
    )
end
