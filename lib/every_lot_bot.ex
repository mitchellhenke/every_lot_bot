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

  def get_streetview_image(property) do
    search_query = "#{property.address}, #{property.city}, WI"
    url = "https://maps.googleapis.com/maps/api/streetview"

    params = %{
      fov: 65,
      pitch: 10,
      size: "1000x1000",
      key: "",
      location: search_query,
      return_error_code: true,
      source: "outdoor"
    }

    full_url = "#{url}?#{URI.encode_query(params)}"

    {status, body} =
      with req <- Finch.build(:get, full_url),
           {:ok, %{body: body, status: status}} <- Finch.request(req, MyFinch) do
        {status, body}
      end
  end

  def post_update do
    Finch.start_link(name: MyFinch)

    date =
      DateTime.now!("America/Chicago", Tzdata.TimeZoneDatabase)
      |> DateTime.to_date()

    zip = EveryLotBot.get_zip_for_date(date)
    property = EveryLotBot.get_property_by_zip(zip)
    {status, body} = EveryLotBot.get_streetview_image(property)
    status = "#{property.address}, #{property.zip}"

    ExTwitter.configure(
      [
        consumer_key: System.fetch_env!("TWITTER_CONSUMER_API_KEY"),
        consumer_secret: System.fetch_env!("TWITTER_CONSUMER_ACCESS_TOKEN_SECRET"),
        access_token: System.fetch_env!("TWITTER_CONSUMER_API_KEY"),
        access_token_secret: System.fetch_env!("TWITTER_CONSUMER_API_SECRET")
      ]
    )
    ExTwitter.update_with_media(status, body)
  end

  def get_zip_for_date(date) do
    formatted_date = Date.to_iso8601(date)
    hash = :crypto.hash(:sha, formatted_date) |> :binary.decode_unsigned()
    {:ok, conn} = Exqlite.Sqlite3.open("lots.db")

    {:ok, statement} =
      Exqlite.Sqlite3.prepare(conn, "select distinct(zip) from lots where tweeted = 0")

    {:ok, rows} = Exqlite.Sqlite3.fetch_all(conn, statement)

    zips = List.flatten(rows) |> Enum.sort()

    index = rem(hash, Enum.count(zips))
    Enum.at(zips, index)
  end

  def get_property_by_zip(zip) do
    {:ok, conn} = Exqlite.Sqlite3.open("lots.db")

    {:ok, statement} =
      Exqlite.Sqlite3.prepare(
        conn,
        "SELECT * FROM lots where tweeted = 0 ORDER BY zip <> ?, zip, tax_key ASC LIMIT 1;"
      )

    :ok = Exqlite.Sqlite3.bind(conn, statement, [zip])

    {:ok,
     [
       [
         id,
         tax_key,
         address,
         zip,
         city,
         lat,
         lng,
         year_built,
         zoning,
         alder,
         number_stories,
         tweeted
       ]
     ]} = Exqlite.Sqlite3.fetch_all(conn, statement)

    %{
      id: id,
      tax_key: tax_key,
      address: address,
      zip: zip,
      city: city,
      lat: lat,
      lng: lng,
      year_built: year_built,
      zoning: zoning,
      alder: alder,
      number_stories: number_stories,
      tweeted: tweeted
    }
  end

  def mark_as_tweeted(id, tweet_id) do
    {:ok, conn} = Exqlite.Sqlite3.open("lots.db")

    {:ok, statement} =
      Exqlite.Sqlite3.prepare(
        conn,
        "UPDATE lots set tweeted = ? where id = ?"
      )

    :ok = Exqlite.Sqlite3.bind(conn, statement, [tweet_id, id])
    result = Exqlite.Sqlite3.fetch_all(conn, statement)
  end
end

# def aim_camera(self):
#     '''Set field-of-view and pitch'''
#     fov, pitch = 65, 10
#     try:
#         floors = float(self.lot.get('floors', 0)) or 2
#     except TypeError:
#         floors = 2

#     if floors == 3:
#         fov = 72

#     if floors == 4:
#         fov, pitch = 76, 15

#     if floors >= 5:
#         fov, pitch = 81, 20

#     if floors == 6:
#         fov = 86

#     if floors >= 8:
#         fov, pitch = 90, 25

#     if floors >= 10:
#         fov, pitch = 90, 30

#     return fov, pitch
