defmodule EveryLotBot do
  @moduledoc """
  Documentation for `EveryLotBot`.
  """
  NimbleCSV.define(MyCSV, newlines: ["\n"])

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
  """

  def get_streetview_image(property) do
    search_query = "#{property.address}, #{property.city}, WI"
    url = "https://maps.googleapis.com/maps/api/streetview"

    params = %{
      fov: 65,
      pitch: 10,
      size: "1000x1000",
      key: System.fetch_env!("GOOGLE_IMAGE_API_KEY"),
      location: search_query,
      return_error_code: true,
      source: "outdoor"
    }

    full_url = "#{url}?#{URI.encode_query(params)}"

    with req <- Finch.build(:get, full_url),
         {:ok, %{body: body, status: status}} <- Finch.request(req, MyFinch) do
      {status, body}
    end
  end

  def post_update do
    date =
      DateTime.now!("America/Chicago", Tzdata.TimeZoneDatabase)
      |> DateTime.to_date()

    properties = EveryLotBot.load_properties()
    zip = EveryLotBot.get_zip_for_date(properties, date)
    {updated_properties, property, image} = EveryLotBot.get_valid_property_by_zip(properties, zip)
    tweet_content = make_tweet_content(property)

    tweet = ExTwitter.update_with_media(tweet_content, image)

    updated_properties =
      Map.put(updated_properties, property.tax_key, %{property | tweeted: tweet.id})

    EveryLotBot.mark_as_tweeted(updated_properties)
  end

  def make_tweet_content(property) do
    if property.year_built > "1" do
      """
      #{property.address}, #{property.zip}
      Year Built: #{property.year_built}\
      """
    else
      "#{property.address}, #{property.zip}"
    end
  end

  def get_zip_for_date(properties, date) do
    formatted_date = Date.to_iso8601(date)
    hash = :crypto.hash(:sha, formatted_date) |> :binary.decode_unsigned()

    zips =
      Map.values(properties)
      |> Enum.filter(fn property ->
        property.tweeted == "0"
      end)
      |> Enum.reduce(MapSet.new(), fn property, zips ->
        MapSet.put(zips, property.zip)
      end)

    index = rem(hash, Enum.count(zips))
    Enum.at(zips, index)
  end

  def get_valid_property_by_zip(properties, zip) do
    property = get_property_by_zip(properties, zip)
    {status, body} = get_streetview_image(property)

    if status == 200 do
      {properties, property, body}
    else
      properties = Map.put(properties, property.tweeted, %{property | tweeted: "1"})
      get_valid_property_by_zip(properties, zip)
    end
  end

  def get_property_by_zip(properties, zip) do
    Map.values(properties)
    |> Enum.filter(fn property ->
      property.tweeted == "0"
    end)
    |> Enum.sort_by(fn property ->
      {property.zip != zip, property.zip, property.tax_key}
    end)
    |> hd()
  end

  def mark_as_tweeted(properties) do
    rows =
      Map.values(properties)
      |> Enum.sort_by(& &1.tax_key)
      |> Enum.map(fn property ->
        [
          property.tax_key,
          property.address,
          property.zip,
          property.city,
          property.lat,
          property.lon,
          property.year_built,
          property.zoning,
          property.geo_alder,
          property.number_stories,
          property.tweeted
        ]
      end)

    headers = [
      "tax_key",
      "address",
      "zip",
      "city",
      "lat",
      "lon",
      "year_built",
      "zoning",
      "geo_alder",
      "number_stories",
      "tweeted"
    ]

    stream = File.stream!("data.csv")

    MyCSV.dump_to_stream([headers | rows])
    |> Stream.into(stream)
    |> Stream.run()
  end

  def load_properties do
    with {:ok, content} <- File.read("data.csv"),
         csv_rows <- MyCSV.parse_string(content, skip_headers: false) do
      {[headers], rows} = Enum.split(csv_rows, 1)
      headers = Enum.map(headers, &String.to_atom/1)

      Enum.map(rows, fn row ->
        property =
          Enum.zip(headers, row)
          |> Enum.into(%{})

        {property.tax_key, property}
      end)
      |> Enum.into(%{})
    end
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
