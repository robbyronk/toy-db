defmodule DBTest do
  use ExUnit.Case
  doctest DB

  describe "group by one column" do
    setup do
      [
        rows: [
          %{
            "COUNTRY" => "USA",
            "REGION" => "Florida",
            "SONGS" => 128
          },
          %{
            "COUNTRY" => "USA",
            "REGION" => "Delaware",
            "SONGS" => 4
          },
        ]
      ]
    end

    test "group by and max", context do
      query = %{
        group: "COUNTRY",
        select: "COUNTRY,SONGS:max"
      }

      result = DB.group_by(context[:rows], query)
      expected = [%{"COUNTRY" => "USA", "SONGS:max" => 128}]
      assert result == expected
    end

    test "group by and min", context do
      query = %{
        group: "COUNTRY",
        select: "COUNTRY,SONGS:min"
      }

      result = DB.group_by(context[:rows], query)
      expected = [%{"COUNTRY" => "USA", "SONGS:min" => 4}]
      assert result == expected
    end

    test "group by and collect", context do
      query = %{
        group: "COUNTRY",
        select: "COUNTRY,REGION:collect"
      }

      result = DB.group_by(context[:rows], query)
      expected = [%{"COUNTRY" => "USA", "REGION:collect" => "[Florida,Delaware]"}]
      assert result == expected
    end
  end

  describe "group by more than one column" do
    setup do
      [
        rows: [
          %{
            "COUNTRY" => "USA",
            "REGION" => "Florida",
            "SONGS" => 128
          },
          %{
            "COUNTRY" => "USA",
            "REGION" => "Florida",
            "SONGS" => 4
          },
          %{
            "COUNTRY" => "USA",
            "REGION" => "Delaware",
            "SONGS" => 45
          },
        ]
      ]
    end

    test "group by COUNTRY and REGION and max", context do
      query = %{
        group: "COUNTRY,REGION",
        select: "COUNTRY,REGION,SONGS:max"
      }

      result = DB.group_by(context[:rows], query)
      expected = [
        %{"COUNTRY" => "USA", "REGION" => "Florida", "SONGS:max" => 128},
        %{"COUNTRY" => "USA", "REGION" => "Delaware", "SONGS:max" => 45},
      ]
      assert Enum.sort(result) == Enum.sort(expected)
    end
  end

  test "group by column collect" do
    rows = [
      %{"COUNTRY" => "USA", "REGION" => "Florida", },
      %{"COUNTRY" => "USA", "REGION" => "Alabama", },
    ]

    result = DB.group_by_column(rows, "REGION:collect")
    assert result == "[Florida,Alabama]"
  end

  test "get columns from map" do
    map = %{
      "a" => 1,
      "b" => 2,
      "c" => 3,
    }
    columns = "a,c"
    result = DB.get_columns(columns).(map)
    assert result == [1, 3]
  end

  describe "filtering" do
    test "tokenize simple" do
      filter = "aoeu=123"
      expected = [%{"field" => "aoeu", "operator" => "=", "value" => "123"}]
      assert DB.Filter.tokenize(filter) == expected
    end

    test "tokenize complex" do
      filter = "aoeu=123 AND (htns=456 OR qjkx=292)"

      expected = [
        %{"field" => "aoeu", "operator" => "=", "value" => "123"},
        :and,
        :left_paren,
        %{"field" => "htns", "operator" => "=", "value" => "456"},
        :or,
        %{"field" => "qjkx", "operator" => "=", "value" => "292"},
        :right_paren
      ]

      assert DB.Filter.tokenize(filter) == expected
    end

    test "parse simplest filter" do
      filter = "aoeu=123"
      assert DB.Filter.parse_filter(filter) == %{"field" => "aoeu", "operator" => "=", "value" => "123"}
    end

    test "parse easy filter" do
      filter = "aoeu=123 AND htns=456"
      expected = %{
        and: [
          %{"field" => "aoeu", "operator" => "=", "value" => "123"},
          %{"field" => "htns", "operator" => "=", "value" => "456"}
        ]
      }
      assert DB.Filter.parse_filter(filter) == expected
    end

    test "parse parentheses" do
      filter = "aoeu=123 AND (htns=456 OR qjkx=292)"
      expected = %{
        and: [
          %{"field" => "aoeu", "operator" => "=", "value" => "123"},
          %{
            or: [
              %{"field" => "htns", "operator" => "=", "value" => "456"},
              %{"field" => "qjkx", "operator" => "=", "value" => "292"}
            ]
          }
        ]
      }
      assert DB.Filter.parse_filter(filter) == expected
    end

    test "parse deeply nested filter" do
      filter = "aoeu=123 AND (htns=456 OR (qjkx=292 AND vwmb=987)"
      expected = %{
        and: [
          %{"field" => "aoeu", "operator" => "=", "value" => "123"},
          %{
            or: [
              %{"field" => "htns", "operator" => "=", "value" => "456"},
              %{
                and: [
                  %{"field" => "qjkx", "operator" => "=", "value" => "292"},
                  %{"field" => "vwmb", "operator" => "=", "value" => "987"}
                ]
              }
            ]
          }
        ]
      }
      assert DB.Filter.parse_filter(filter) == expected
    end

    test "make tree" do
      sample = ["a=123", :or, "b=123", :and, ["c=123", :or, "d=123"]]
      actual = DB.Filter.make_tree(sample)
      expected = %{or: ["a=123", %{and: ["b=123", %{or: ["c=123", "d=123"]}]}]}
      assert actual == expected
    end

    test "check row" do
      filter = %{
        and: [
          %{"field" => "aoeu", "operator" => "=", "value" => "123"},
          %{
            or: [
              %{"field" => "htns", "operator" => "=", "value" => "456"},
              %{"field" => "qjkx", "operator" => "=", "value" => "292"},
            ]
          }
        ]
      }
      row = %{"aoeu" => "123", "htns" => "456"}
      assert DB.Filter.check_row(filter, row) == true
      assert DB.Filter.check_row(filter, %{"aoeu" => "123"}) == false
    end
  end
end
