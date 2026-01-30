defmodule Kino.MyVegaLite do
  @moduledoc "VegaLite を使った可視化ヘルパーモジュール\n\nExplorer の DataFrame や値リストから、よく使うグラフを簡単に生成できます。\n"
  alias Explorer.Series

  @doc "ヒストグラム\n\n## Example\n\n    Kino.MyVegaLite.to_histogram(df_all, \"Fare\",\n      width: 300,\n      binstep: 50,\n      x_scale: %{domain: [0, 550]},\n      y_scale: %{domain: [0, 500]},\n      y_title: \"num\"\n    )\n"
  def to_histogram(df, column, options) when is_struct(df) do
    values = Series.to_list(df[column])
    to_histogram(values, options)
  end

  def to_histogram(values, options) when is_list(values) do
    maxbins = Keyword.get(options, :maxbins, 20)
    binstep = Keyword.get(options, :binstep, nil)
    x_scale = Keyword.get(options, :x_scale, %{})
    x_title = Keyword.get(options, :x_title, "")
    y_scale = Keyword.get(options, :y_scale, %{})
    y_title = Keyword.get(options, :y_title, "count")
    width = Keyword.get(options, :width, 600)
    height = Keyword.get(options, :height, 400)
    num_values = values |> Enum.uniq() |> Enum.count()

    {x_type, bin} =
      if num_values > maxbins do
        {:quantitative, %{maxbins: maxbins, step: binstep}}
      else
        {:nominal, nil}
      end

    VegaLite.new(width: width, height: height)
    |> VegaLite.data_from_values(value: values)
    |> VegaLite.mark(:bar, tooltip: true)
    |> VegaLite.encode_field(:x, "value", type: x_type, bin: bin, title: x_title, scale: x_scale)
    |> VegaLite.encode_field(:y, "value",
      type: :quantitative,
      title: y_title,
      aggregate: :count,
      scale: y_scale
    )
  end

  @doc "線グラフ\n\nDataFrame の列から線グラフを生成します。\nx軸を指定する場合は4引数、指定しない場合（インデックスを使用）は3引数で呼び出します。\n\n## Examples\n\n    # x軸にインデックス、y軸に指定列\n    Kino.MyVegaLite.to_line(df, \"sepal_length\", width: 500, height: 100)\n\n    # x軸とy軸を両方指定\n    Kino.MyVegaLite.to_line(df, \"sepal_length\", \"sepal_width\",\n      width: 500,\n      height: 100,\n      x_title: \"width\",\n      y_title: \"length\"\n    )\n\n## Options\n\n  * `:width` - グラフの幅（デフォルト: 600）\n  * `:height` - グラフの高さ（デフォルト: 300）\n  * `:x_title` - x軸のタイトル\n  * `:y_title` - y軸のタイトル\n"
  def to_line(df, column, order_column, options) when is_struct(df) do
    y_values = Series.to_list(df[column])
    x_values = Series.to_list(df[order_column])

    Enum.zip(y_values, x_values)
    |> Enum.map(&%{"value" => elem(&1, 0), "x" => elem(&1, 1)})
    |> to_line(options)
  end

  def to_line(df, column, options) when is_struct(df) do
    y_values = Series.to_list(df[column])

    y_values
    |> Enum.with_index(1)
    |> Enum.map(&%{"value" => elem(&1, 0), "x" => elem(&1, 1)})
    |> to_line(options)
  end

  def to_line(values, options) when is_list(values) do
    width = Keyword.get(options, :width, 600)
    height = Keyword.get(options, :height, 300)
    x_title = Keyword.get(options, :x_title, "")
    y_title = Keyword.get(options, :y_title, "")

    VegaLite.new(width: width, height: height)
    |> VegaLite.data_from_values(values)
    |> VegaLite.mark(:line)
    |> VegaLite.encode_field(:x, "x", type: :quantitative, title: x_title)
    |> VegaLite.encode_field(:y, "value", type: :quantitative, title: y_title)
  end

  @doc "散布図\n\nDataFrame の2つの列から散布図を生成します。\n\n## Examples\n\n    Kino.MyVegaLite.to_scatter(df, \"sepal_width\", \"sepal_length\",\n      width: 500,\n      height: 400,\n      x_title: \"width\",\n      y_title: \"length\"\n    )\n\n    # 色分けを指定\n    Kino.MyVegaLite.to_scatter(df, \"sepal_width\", \"sepal_length\",\n      color_column: \"species\",\n      width: 500,\n      height: 400\n    )\n\n## Options\n\n  * `:width` - グラフの幅（デフォルト: 600）\n  * `:height` - グラフの高さ（デフォルト: 400）\n  * `:x_title` - x軸のタイトル\n  * `:y_title` - y軸のタイトル\n  * `:x_scale` - x軸のスケール設定（例: %{domain: [0, 10]}）\n  * `:y_scale` - y軸のスケール設定（例: %{domain: [0, 10]}）\n  * `:color_column` - 色分けに使用する列名\n"
  def to_scatter(df, x_column, y_column, options \\ []) when is_struct(df) do
    x_values = Series.to_list(df[x_column])
    y_values = Series.to_list(df[y_column])
    color_column = Keyword.get(options, :color_column, nil)

    data =
      if color_column do
        color_values = Series.to_list(df[color_column])

        Enum.zip([x_values, y_values, color_values])
        |> Enum.map(fn {x, y, c} -> %{"x" => x, "y" => y, "color" => c} end)
      else
        Enum.zip(x_values, y_values) |> Enum.map(fn {x, y} -> %{"x" => x, "y" => y} end)
      end

    to_scatter(data, options)
  end

  def to_scatter(values, options) when is_list(values) do
    width = Keyword.get(options, :width, 600)
    height = Keyword.get(options, :height, 400)
    x_title = Keyword.get(options, :x_title, "")
    y_title = Keyword.get(options, :y_title, "")
    x_scale = Keyword.get(options, :x_scale, %{})
    y_scale = Keyword.get(options, :y_scale, %{})
    has_color = Enum.any?(values, fn v -> Map.has_key?(v, "color") end)

    chart =
      VegaLite.new(width: width, height: height)
      |> VegaLite.data_from_values(values)
      |> VegaLite.mark(:point, tooltip: true)
      |> VegaLite.encode_field(:x, "x", type: :quantitative, title: x_title, scale: x_scale)
      |> VegaLite.encode_field(:y, "y", type: :quantitative, title: y_title, scale: y_scale)

    if has_color do
      chart |> VegaLite.encode_field(:color, "color", type: :nominal)
    else
      chart
    end
  end

  @doc "棒グラフ\n\nDataFrame のカテゴリ列から棒グラフを生成します。\nカウント集計または指定した数値列の値を表示できます。\n\n## Examples\n\n    # カテゴリのカウント\n    Kino.MyVegaLite.to_bar(df, \"species\", width: 400, height: 300)\n\n    # カテゴリ別の平均値\n    Kino.MyVegaLite.to_bar(df, \"species\", \"sepal_length\",\n      aggregate: :mean,\n      width: 400,\n      height: 300\n    )\n\n    # 横棒グラフ\n    Kino.MyVegaLite.to_bar(df, \"species\",\n      horizontal: true,\n      width: 400,\n      height: 300\n    )\n\n## Options\n\n  * `:width` - グラフの幅（デフォルト: 600）\n  * `:height` - グラフの高さ（デフォルト: 400）\n  * `:aggregate` - 集計方法（:count, :mean, :sum など、デフォルト: :count）\n  * `:horizontal` - 横棒グラフにする場合は true（デフォルト: false）\n  * `:x_title` - x軸のタイトル\n  * `:y_title` - y軸のタイトル\n"
  def to_bar(df, category_column, options) when is_struct(df) do
    category_values = Series.to_list(df[category_column])
    data = Enum.map(category_values, fn cat -> %{"category" => cat} end)
    do_bar(data, false, options)
  end

  def to_bar(df, category_column, value_column, options) when is_struct(df) do
    category_values = Series.to_list(df[category_column])
    value_values = Series.to_list(df[value_column])

    data =
      Enum.zip(category_values, value_values)
      |> Enum.map(fn {cat, val} -> %{"category" => cat, "value" => val} end)

    do_bar(data, true, options)
  end

  defp do_bar(values, has_value, options) do
    width = Keyword.get(options, :width, 600)
    height = Keyword.get(options, :height, 400)
    aggregate = Keyword.get(options, :aggregate, :count)
    horizontal = Keyword.get(options, :horizontal, false)
    x_title = Keyword.get(options, :x_title, "")
    y_title = Keyword.get(options, :y_title, "")

    value_field =
      if has_value do
        "value"
      else
        "category"
      end

    chart =
      VegaLite.new(width: width, height: height)
      |> VegaLite.data_from_values(values)
      |> VegaLite.mark(:bar, tooltip: true)

    if horizontal do
      chart
      |> VegaLite.encode_field(:y, "category", type: :nominal, title: y_title)
      |> VegaLite.encode_field(:x, value_field,
        type: :quantitative,
        aggregate: aggregate,
        title: x_title
      )
    else
      chart
      |> VegaLite.encode_field(:x, "category", type: :nominal, title: x_title)
      |> VegaLite.encode_field(:y, value_field,
        type: :quantitative,
        aggregate: aggregate,
        title: y_title
      )
    end
  end

  @doc "箱ひげ図\n\nDataFrame の数値列から箱ひげ図を生成します。\nカテゴリ別にグループ化して比較することもできます。\n\n## Examples\n\n    # 単一列の箱ひげ図\n    Kino.MyVegaLite.to_boxplot(df, \"sepal_length\", width: 400, height: 300)\n\n    # カテゴリ別の箱ひげ図\n    Kino.MyVegaLite.to_boxplot(df, \"sepal_length\", \"species\",\n      width: 400,\n      height: 300\n    )\n\n## Options\n\n  * `:width` - グラフの幅（デフォルト: 600）\n  * `:height` - グラフの高さ（デフォルト: 400）\n  * `:x_title` - x軸のタイトル\n  * `:y_title` - y軸のタイトル\n"
  def to_boxplot(df, value_column, options) when is_struct(df) do
    value_values = Series.to_list(df[value_column])
    data = Enum.map(value_values, fn val -> %{"category" => "", "value" => val} end)
    do_boxplot(data, options)
  end

  def to_boxplot(df, value_column, category_column, options) when is_struct(df) do
    value_values = Series.to_list(df[value_column])
    category_values = Series.to_list(df[category_column])

    data =
      Enum.zip(category_values, value_values)
      |> Enum.map(fn {cat, val} -> %{"category" => cat, "value" => val} end)

    do_boxplot(data, options)
  end

  defp do_boxplot(values, options) do
    width = Keyword.get(options, :width, 600)
    height = Keyword.get(options, :height, 400)
    x_title = Keyword.get(options, :x_title, "")
    y_title = Keyword.get(options, :y_title, "")

    VegaLite.new(width: width, height: height)
    |> VegaLite.data_from_values(values)
    |> VegaLite.mark(:boxplot, tooltip: true)
    |> VegaLite.encode_field(:x, "category", type: :nominal, title: x_title)
    |> VegaLite.encode_field(:y, "value", type: :quantitative, title: y_title)
  end

  @doc "ヒートマップ\n\nDataFrame から相関行列を計算してヒートマップを生成します。\nまたは、2次元データを直接受け取ってヒートマップを表示します。\n\n## Examples\n\n    # DataFrame から相関行列を計算\n    Kino.MyVegaLite.to_heatmap(df, [\"sepal_length\", \"sepal_width\", \"petal_length\"], [])\n\n    # 直接データを渡す\n    data = [\n      %{\"x\" => \"A\", \"y\" => \"X\", \"value\" => 0.8},\n      %{\"x\" => \"A\", \"y\" => \"Y\", \"value\" => 0.3},\n      %{\"x\" => \"B\", \"y\" => \"X\", \"value\" => 0.5},\n      %{\"x\" => \"B\", \"y\" => \"Y\", \"value\" => 0.9}\n    ]\n    Kino.MyVegaLite.to_heatmap(data, width: 400, height: 400)\n\n## Options\n\n  * `:width` - グラフの幅（デフォルト: 600）\n  * `:height` - グラフの高さ（デフォルト: 600）\n  * `:color_scheme` - 色スキーム（デフォルト: \"redblue\"、1.0=赤、-1.0=青）\n  * `:x_title` - x軸のタイトル\n  * `:y_title` - y軸のタイトル\n"
  def to_heatmap(df, columns, options) when is_struct(df) and is_list(columns) do
    data =
      for col1 <- columns,
          col2 <- columns do
        values1 = Series.to_list(df[col1])
        values2 = Series.to_list(df[col2])
        correlation = calculate_correlation(values1, values2)
        %{"x" => col1, "y" => col2, "value" => correlation}
      end

    to_heatmap(data, options)
  end

  def to_heatmap(values, options) when is_list(values) do
    width = Keyword.get(options, :width, 600)
    height = Keyword.get(options, :height, 600)
    color_scheme = Keyword.get(options, :color_scheme, "redblue")
    x_title = Keyword.get(options, :x_title, "")
    y_title = Keyword.get(options, :y_title, "")

    VegaLite.new(width: width, height: height)
    |> VegaLite.data_from_values(values)
    |> VegaLite.mark(:rect, tooltip: true)
    |> VegaLite.encode_field(:x, "x", type: :nominal, title: x_title)
    |> VegaLite.encode_field(:y, "y", type: :nominal, title: y_title)
    |> VegaLite.encode_field(:color, "value",
      type: :quantitative,
      scale: [scheme: color_scheme, domain: [1, -1]]
    )
  end

  defp calculate_correlation(values1, values2) do
    n = length(values1)

    if n == 0 do
      0
    else
      mean1 = Enum.sum(values1) / n
      mean2 = Enum.sum(values2) / n

      numerator =
        Enum.zip(values1, values2)
        |> Enum.map(fn {x, y} -> (x - mean1) * (y - mean2) end)
        |> Enum.sum()

      std1 =
        values1 |> Enum.map(fn x -> (x - mean1) * (x - mean1) end) |> Enum.sum() |> :math.sqrt()

      std2 =
        values2 |> Enum.map(fn x -> (x - mean2) * (x - mean2) end) |> Enum.sum() |> :math.sqrt()

      if std1 == 0 or std2 == 0 do
        0
      else
        numerator / (std1 * std2)
      end
    end
  end
end