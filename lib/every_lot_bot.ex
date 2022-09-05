defmodule EveryLotBot do
  @moduledoc """
  Documentation for `EveryLotBot`.
  """
  @number_regex ~r/\B(?=(\d{3})+(?!\d))/
  NimbleCSV.define(MyCSV, newlines: ["\n"])

  def get_streetview_image(property) do
    search_query = "#{property.address}, #{property.city}, WI"
    url = "https://maps.googleapis.com/maps/api/streetview"

    secret =
      System.fetch_env!("GOOGLE_IMAGE_API_SECRET")
      |> String.replace("-", "+")
      |> String.replace("_", "/")
      |> Base.decode64!()

    params = %{
      fov: 65,
      pitch: 10,
      size: "1000x1000",
      key: System.fetch_env!("GOOGLE_IMAGE_API_KEY"),
      location: search_query,
      return_error_code: true,
      source: "outdoor"
    }

    full_uri = URI.parse("#{url}?#{URI.encode_query(params)}")

    signature =
      :crypto.mac(:hmac, :sha, secret, "#{full_uri.path}?#{full_uri.query}")
      |> Base.encode64()
      |> String.replace("+", "-")
      |> String.replace("/", "_")

    final_url = "#{URI.to_string(full_uri)}&signature=#{signature}"

    with req <- Finch.build(:get, final_url),
         {:ok, %{body: body, status: status}} <- Finch.request(req, MyFinch),
         true <- status in [200, 404] do
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
    zoning = zoning_content(property.zoning)
    assessment = assessment_content(property)

    content =
      if property.year_built > "1" do
        """
        #{property.address}, #{property.zip}

        Year Built: #{property.year_built}\
        """
      else
        "#{property.address}, #{property.zip}\n"
      end

    content = if zoning do
      "#{content}\nZoning: #{zoning}"
    else
      content
    end

    if assessment do
      "#{content}\nAssessment: #{assessment}"
    else
      content
    end
    |> String.trim()
  end

  defp zoning_content(zoning) do
    case zoning do
      "" ->
        nil

      "C9A(A)" ->
        "Downtown High Density Residential - subdistrict A [C9A(A)]"

      "C9A(B)" ->
        "Downtown High Density Residential - subdistrict B [C9A(B)]"

      "C9B(A)" ->
        "Downtown Residential and Specialty Use - subdistrict A [C9B(A)]"

      "C9B(B)" ->
        "Downtown Residential and Specialty Use - subdistrict B [C9B(B)]"

      "C9C" ->
        "Downtown Neighborhood Retail [C9C]"

      "C9D(A)" ->
        "Downtown Civic Activity - subdistrict A [C9D(A)]"

      "C9D(B)" ->
        "Downtown Civic Activity - subdistrict B [C9D(B)]"

      "C9E" ->
        "Downtown Major Retail [C9E]"

      "C9F(A)" ->
        "Downtown Office and Service - subdistrict A [C9F(A)]"

      "C9F(B)" ->
        " - Downtown Office and Service - subdistrict B [C9F(B)]"

      "C9F(C)" ->
        "Downtown Office and Service - subdistrict C [C9F(C)]"

      "C9G" ->
        "Downtown Mixed Activity [C9G]"

      "C9H" ->
        "Downtown Warehousing and Light Manufacturing [C9H]"

      "CS" ->
        "Commercial Service [CS]"

      "IC" ->
        "Industrial-Commercial [IC]"

      "IH" ->
        "Industrial-Heavy [IH]"

      "IL1" ->
        "Industrial-Light 1 [IL1]"

      "IL2" ->
        "Industrial-Light 2 [IL2]"

      "IM" ->
        "Industrial-Mixed [IM]"

      "IO1" ->
        "Industrial-Office 1 [IO1]"

      "IO2" ->
        "Industrial-Office 2 [IO2]"

      "LB1" ->
        "Local Business 1 [LB1]"

      "LB2" ->
        "Local Business 2 [LB2]"

      "LB3" ->
        "Local Business 3 [LB3]"

      "NS1" ->
        "Neighborhood Shopping 1 [NS1]"

      "NS2" ->
        "Neighborhood Shopping 2 [NS2]"

      "PD" ->
        "Planned Development [PD]"

      "PENDING" ->
        "Pending"

      "PK" ->
        "Parks [PK]"

      "RB1" ->
        "Regional Business 1 [RB1]"

      "RB2" ->
        "Regional Business 2 [RB2]"

      "RED" ->
        "Redevelopment [RED]"

      "RM1" ->
        "Multi-Family Residential 1 [RM1]"

      "RM2" ->
        "Multi-Family Residential 2 [RM2]"

      "RM3" ->
        "Multi-Family Residential 3 [RM3]"

      "RM4" ->
        "Multi-Family Residential 4 [RM4]"

      "RM5" ->
        "Multi-Family Residential 5 [RM5]"

      "RM6" ->
        "Multi-Family Residential 6 [RM6]"

      "RM7" ->
        "Multi-Family Residential 7 [RM7]"

      "RO1" ->
        "Residential and Office 1 [RO1]"

      "RO2" ->
        "Residential and Office 2 [RO2]"

      "RS1" ->
        "Single-Family Residential 1 [RS1]"

      "RS2" ->
        "Single-Family Residential 2 [RS2]"

      "RS3" ->
        "Single-Family Residential 3 [RS3]"

      "RS4" ->
        "Single-Family Residential 4 [RS4]"

      "RS5" ->
        "Single-Family Residential 5 [RS5]"

      "RS6" ->
        "Single-Family Residential 6 [RS6]"

      "RT1" ->
        "Two-Family Residential 1 [RT1]"

      "RT2" ->
        "Two-Family Residential 2 [RT2]"

      "RT3" ->
        "Two-Family Residential 3 [RT3]"

      "RT4" ->
        "Two-Family Residential 4 [RT4]"

      "TL" ->
        "Institutional [TL]"

      "X" ->
        "X"
    end
  end

  defp assessment_content(property) do
    if property.count == "1" do
      amount = property.last_assessment_amount
      number = to_string(String.to_integer(amount))
      formatted = Regex.replace(@number_regex, number, ",")
      "$#{formatted}"
    else
      nil
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
      properties = Map.put(properties, property.tax_key, %{property | tweeted: "1"})
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
          property.last_assessment_amount,
          property.count,
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
      "last_assessment_amount",
      "count",
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

  def migrate(old_file, new_file) do
    old_properties = with {:ok, content} <- File.read(old_file),
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

    new_properties = with {:ok, content} <- File.read(new_file),
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

    updated_properties = Enum.reduce(new_properties, %{}, fn({_key, property}, acc) ->
      old = Map.get(old_properties, property.tax_key)

      if old do
        Map.put(acc, property.tax_key, %{property | tweeted: old.tweeted})
      else
        Map.put(acc, property.tax_key, property)
      end
    end)

    EveryLotBot.mark_as_tweeted(updated_properties)
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
