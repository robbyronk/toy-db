defmodule DB.CLI do
  def main(args) do
    {params, _, _} = OptionParser.parse(
      args,
      switches: [
        help: :boolean,
        filter: :string,
        group: :string,
        order: :string,
        select: :string,
      ],
      aliases: [
        f: :filter,
        g: :group,
        o: :order,
        s: :select,
      ]
    )
    process_args(params)
  end

  def process_args([]) do
    process_args([help: true])
  end

  def process_args([help: true]) do
    IO.puts(
      """
        Query:
          -s X,Y # select X and Y fields
          -o X,Y # order by X and Y fields
          -f 'X=3 OR Y=4' # filter where X field is 3
          -g X,Y # group by X and Y fields
      """
    )
  end

  def process_args(params) do
    params
    |> Enum.into(%{filter: nil, group: nil, order: nil})
    |> DB.query()
    |> Enum.map(&Enum.join(&1, ","))
    |> Enum.each(&IO.puts/1)
  end

end
