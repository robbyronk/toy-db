defmodule DB do
  @doc """

  Imports the data and queries it.

  ## Examples:

    iex> DB.select([%{"a" => 1}], %{select: "a"})
    [[1]]


  """


  def query(query) do
    DB.Import.import()
    |> filter_by(query)
    |> group_by(query)
    |> order_by(query)
    |> select(query)
  end

  def group_by_column(rows, column_name) do
    case String.split(column_name, ":") do
      [name, "min"] ->
        Enum.min_by(rows, &Map.get(&1, name))
        |> Map.get(name)
      [name, "max"] ->
        Enum.max_by(rows, &Map.get(&1, name))
        |> Map.get(name)
      [name, "sum"] ->
        Enum.sum(Enum.map(rows, &Map.get(&1, name)))
      [_, "count"] ->
        length(rows)
      [name, "collect"] ->
        "[" <> Enum.map_join(rows, ",", &Map.get(&1, name)) <> "]"
      _ ->
        List.first(rows)[column_name]
    end
  end

  def group_rows(select, {_, rows}) do
    for c <- String.split(select, ","), into: %{}, do: {c, group_by_column(rows, c)}
  end

  def group_by(rows, query) do
    case query[:group] do
      group when is_binary(group) ->
        Enum.group_by(rows, &Map.take(&1, String.split(group, ",")))
        |> Enum.map(&group_rows(query[:select], &1))
      _ -> rows
    end
  end

  def filter_by(rows, query) do
    case query[:filter] do
      filter when is_binary(filter) ->
        filter_tree = DB.Filter.parse_filter(filter)
        Enum.filter(rows, &DB.Filter.check_row(filter_tree, &1))
      _ -> rows
    end
  end

  def get_columns(columns) when is_binary(columns) do
    fn row -> for col <- String.split(columns, ","), do: Map.get(row, col) end
  end

  def order_by(rows, query) do
    case query[:order] do
      order when is_binary(order) -> Enum.sort_by(rows, get_columns(order))
      _ -> rows
    end
  end

  def select(rows, %{select: select}), do: Enum.map(rows, get_columns(select))
end
