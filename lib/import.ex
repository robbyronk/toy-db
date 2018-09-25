defmodule DB.Import do
  def add_headers({line, 0}, {}) do
    {[], {line}}
  end

  def add_headers({line, index}, {headers}) do
    {[{line, index, headers}], {headers}}
  end

  def import() do
    File.stream!("input.txt")
    |> Stream.map(&String.trim/1)
    |> Stream.map(&String.split(&1, "|"))
    |> Stream.with_index()
    |> Stream.transform({}, &add_headers/2)
    |> Stream.map(
         fn {line, _, headers} ->
           List.zip([headers, line])
           |> Enum.into(%{}) end
       )
    |> Stream.map(fn (l = %{"COUNTRY" => c, "REGION" => r}) -> {{c, r}, l} end)
    |> Enum.into(%{})
    |> Map.values()
    |> Enum.map(fn row ->
      %{
        "COUNTRY" => row["COUNTRY"], # string
        "REGION" => row["REGION"], # string
        "POPULATION" => String.to_integer(row["POPULATION"]), # integer
        "STATUS" => row["STATUS"], # string
        "VISITED" => Date.from_iso8601!(row["VISITED"]), # date, yyyy-mm-dd
        "RATING" => String.to_float(row["RATING"]), # float
      }
    end)
  end
end
