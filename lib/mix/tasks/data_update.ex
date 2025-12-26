defmodule Mix.Tasks.EveryLotBot.DataUpdate do
  use Mix.Task

  def run(_args) do
    old_data =
      File.stream!("data.csv")
      |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)
      |> Stream.drop(1)
      |> Stream.map(fn [
                         tax_key,
                         address,
                         zip,
                         city,
                         lat,
                         lon,
                         year_built,
                         zoning,
                         geo_alder,
                         number_stories,
                         last_assessment_amount,
                         neighborhood,
                         count,
                         tweeted
                       ] ->
        {tax_key,
         %{
           tax_key: tax_key,
           address: address,
           zip: zip,
           city: city,
           lat: lat,
           lon: lon,
           year_built: year_built,
           zoning: zoning,
           geo_alder: geo_alder,
           number_stories: number_stories,
           last_assessment_amount: last_assessment_amount,
           neighborhood: neighborhood,
           count: count,
           tweeted: tweeted
         }}
      end)
      |> Enum.into(%{})

    new_data =
      File.stream!("new_data.csv")
      |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)
      |> Stream.drop(1)
      |> Stream.map(fn [
                         tax_key,
                         address,
                         zip,
                         city,
                         lat,
                         lon,
                         year_built,
                         zoning,
                         geo_alder,
                         number_stories,
                         last_assessment_amount,
                         neighborhood,
                         count,
                         tweeted
                       ] ->
        {tax_key,
         %{
           tax_key: tax_key,
           address: address,
           zip: zip,
           city: city,
           lat: lat,
           lon: lon,
           year_built: year_built,
           zoning: zoning,
           geo_alder: geo_alder,
           number_stories: number_stories,
           last_assessment_amount: last_assessment_amount,
           neighborhood: neighborhood,
           count: count,
           tweeted: tweeted
         }}
      end)
      |> Enum.into(%{})

    new_keys = MapSet.new(Map.keys(new_data))
    old_keys = MapSet.new(Map.keys(old_data))
    removed_keys = MapSet.difference(old_keys, new_keys)
    added_keys = MapSet.difference(new_keys, old_keys)

    IO.inspect("Never Been Posted")

    Enum.filter(old_data, fn {key, _map} ->
      MapSet.member?(removed_keys, key) && map.tweeted == "0"
    end)
    |> Enum.each(fn {_key, map} ->
      IO.inspect("#{map.zip} - #{map.address}")
    end)

    IO.inspect("New Keys")

    Enum.filter(new_data, fn {key, map} ->
      MapSet.member?(added_keys, key)
    end)
    |> Enum.each(fn {_key, map} ->
      IO.inspect("#{map.zip} - #{map.address}")
    end)

    updated_new =
      Enum.map(new_data, fn {key, map} ->
        old = Map.get(old_data, key)
        new_lat = parse_float(Map.get(map, :lat))
        new_lon = parse_float(Map.get(map, :lon))
        old_lat = old && parse_float(Map.get(old, :lat))
        old_lon = old && parse_float(Map.get(old, :lon))

        {lat, lon} =
          if old_lat && old_lon && abs(new_lat - old_lat) < 0.00005 &&
               abs(new_lon - old_lon) < 0.00005 do
            {old_lat, old_lon}
          else
            {new_lat, new_lon}
          end

        [
          map.tax_key,
          map.address,
          map.zip,
          map.city,
          lat,
          lon,
          map.year_built,
          map.zoning,
          map.geo_alder,
          map.number_stories,
          map.last_assessment_amount,
          map.neighborhood,
          map.count,
          (old && old.tweeted) || "0"
        ]
      end)
      |> Enum.sort_by(&hd(&1))

    header = [
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
      "neighborhood",
      "count",
      "tweeted"
    ]

    csv_content = NimbleCSV.RFC4180.dump_to_iodata([header | updated_new])
    File.write!("updated.csv", csv_content)
  end

  def parse_float(string) do
    {float, ""} = Float.parse(string)
    float
  end
end
