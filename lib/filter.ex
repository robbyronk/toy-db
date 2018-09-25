defmodule DB.Filter do
  def tokenize([]), do: []
  def tokenize(["(" | tail]), do: [:left_paren | tokenize(tail)]
  def tokenize([")" | tail]), do: [:right_paren | tokenize(tail)]
  def tokenize([" AND " | tail]), do: [:and | tokenize(tail)]
  def tokenize([" OR " | tail]), do: [:or | tokenize(tail)]
  def tokenize([head | tail]) do
    regex = ~r/(?<field>[a-zA-Z_]+)(?<operator>[><=])"?(?<value>[^"]+)"?/
    [Regex.named_captures(regex, head) | tokenize(tail)]
  end
  def tokenize(filter) when is_binary(filter) do
    Regex.split(~r/([()]| AND | OR )/, filter, include_captures: true, trim: true)
    |> tokenize
  end

  def operator_group(group, operator) when length(group) > 1, do: %{operator => group}
  def operator_group(group, _) when length(group) == 1, do: hd(group)

  def make_tree(x) when not is_list(x), do: x
  def make_tree(tokens) do
    chunk_fun = fn
      {operator, _}, acc when operator in [:and, :or] -> {:cont, acc}
      {token, :or}, acc -> {:cont, Enum.reverse([make_tree(token) | acc]), []}
      {token, _}, acc -> {:cont, [make_tree(token) | acc]}
    end
    after_fun = fn
      [] -> {:cont, []}
      acc -> {:cont, Enum.reverse(acc), []}
    end
    Enum.with_index(tokens)
    |> Enum.map(fn {sym, ind} -> {sym, Enum.at(tokens, ind + 1)} end)
    |> Enum.chunk_while([], chunk_fun, after_fun)
    |> Enum.map(&operator_group(&1, :and))
    |> operator_group(:or)
  end

  def group_parens([:left_paren | tail]), do: [group_parens(tail)]
  def group_parens([:right_paren | tail]), do: group_parens(tail)
  def group_parens([head | tail]), do: [head | group_parens(tail)]
  def group_parens([]), do: []

  def parse_filter(filter) do
    filter
    |> tokenize
    |> group_parens
    |> make_tree
  end

  def check_row(%{and: ands}, row), do: Enum.all?(ands, &check_row(&1, row))
  def check_row(%{or: ors}, row), do: Enum.any?(ors, &check_row(&1, row))
  def check_row(%{"field" => field, "operator" => operator, "value" => value}, row) do
    case operator do
      "=" -> Map.get(row, field) == value
      ">" -> Map.get(row, field) > value
      "<" -> Map.get(row, field) < value
    end
  end
end
