defmodule Kaggle.Titanic do
  @moduledoc "Titanic dataset preprocessing module.\nProvides a single public API to preprocess train and test datasets.\n"
  alias Explorer.DataFrame, as: DF
  alias Explorer.Series, as: S
  require Explorer.DataFrame

  @doc "Preprocess Titanic train and test datasets.\n\nReturns tuple below:\n- df_train - processed training dataframe\n- df_test - processed test dataframe\n- feature_cols - list of feature column names\n"
  def preprocess(df_train, df_test) do
    df_train_marked = DF.mutate(df_train, is_train: 1)
    df_test_marked = df_test |> DF.mutate(Survived: -1) |> DF.mutate(is_train: 0)
    df_all = DF.concat_rows([df_train_marked, df_test_marked])

    df_all =
      df_all
      |> fill_missing_age()
      |> fill_missing_embarked()
      |> fill_missing_fare()
      |> extract_deck()

    df_all =
      df_all
      |> add_family_features()
      |> add_ticket_frequency()
      |> add_title_features()
      |> add_family_surname()
      |> add_survival_rates()
      |> encode_labels()
      |> encode_onehot()

    df_train_final = DF.filter(df_all, is_train == 1)
    df_test_final = DF.filter(df_all, is_train == 0)
    all_names = DF.names(df_all)

    feature_cols =
      ["Age", "Fare", "Is_Married", "Ticket_Frequency", "Survival_Rate", "Survival_Rate_NA"] ++
        (all_names |> Enum.filter(&String.starts_with?(&1, "Pclass_"))) ++
        (all_names |> Enum.filter(&String.starts_with?(&1, "Sex_Encoded_"))) ++
        (all_names |> Enum.filter(&String.starts_with?(&1, "Deck_Encoded_"))) ++
        (all_names |> Enum.filter(&String.starts_with?(&1, "Embarked_Encoded_"))) ++
        (all_names |> Enum.filter(&String.starts_with?(&1, "Title_Encoded_"))) ++
        (all_names |> Enum.filter(&String.starts_with?(&1, "Family_Size_Grouped_Encoded_")))

    {DF.select(df_train_final, feature_cols ++ ~w(Survived)),
     DF.select(df_test_final, feature_cols), feature_cols}
  end

  defp fill_missing_age(df) do
    medians =
      df
      |> DF.filter(not is_nil(col("Age")))
      |> DF.group_by(["Sex", "Pclass"])
      |> DF.summarise(median_age: median(col("Age")))
      |> DF.to_rows()
      |> Enum.map(fn row -> {{row["Sex"], row["Pclass"]}, row["median_age"]} end)
      |> Map.new()

    df
    |> DF.to_rows()
    |> Enum.map(fn row ->
      if is_nil(row["Age"]) do
        key = {row["Sex"], row["Pclass"]}
        Map.put(row, "Age", Map.get(medians, key, 28.0))
      else
        row
      end
    end)
    |> DF.new()
  end

  defp fill_missing_embarked(df) do
    DF.mutate(df,
      Embarked:
        if is_nil(col("Embarked")) do
          "S"
        else
          col("Embarked")
        end
    )
  end

  defp fill_missing_fare(df) do
    med_fare =
      df
      |> DF.filter(
        col("Pclass") == 3 and col("SibSp") == 0 and col("Parch") == 0 and not is_nil(col("Fare"))
      )
      |> DF.pull("Fare")
      |> S.median()

    DF.mutate(df,
      Fare:
        if is_nil(col("Fare")) do
          ^med_fare
        else
          col("Fare")
        end
    )
  end

  defp extract_deck(df) do
    deck_series =
      df["Cabin"] |> S.transform(&extract_deck_from_cabin/1) |> S.transform(&group_deck/1)

    DF.put(df, "Deck", deck_series)
  end

  defp extract_deck_from_cabin(nil) do
    "M"
  end

  defp extract_deck_from_cabin(cabin) do
    deck = String.first(cabin)

    if deck == "T" do
      "A"
    else
      deck
    end
  end

  defp group_deck(deck) do
    case deck do
      d when d in ["A", "B", "C"] -> "ABC"
      d when d in ["D", "E"] -> "DE"
      d when d in ["F", "G"] -> "FG"
      "M" -> "M"
    end
  end

  defp add_family_features(df) do
    df = DF.mutate(df, Family_Size: col("SibSp") + col("Parch") + 1)
    family_size_grouped = df["Family_Size"] |> S.transform(&group_family_size/1)
    DF.put(df, "Family_Size_Grouped", family_size_grouped)
  end

  defp group_family_size(size) do
    case size do
      1 -> "Alone"
      v when v in [2, 3, 4] -> "Small"
      v when v in [5, 6] -> "Medium"
      _ -> "Large"
    end
  end

  defp add_ticket_frequency(df) do
    ticket_counts =
      df |> DF.group_by("Ticket") |> DF.summarise(Ticket_Frequency: count(col("Ticket")))

    DF.join(df, ticket_counts, on: "Ticket")
  end

  defp add_title_features(df) do
    title_series = df["Name"] |> S.transform(&extract_title/1)

    is_married_series =
      df["Name"]
      |> S.transform(fn name ->
        case Regex.run(~r/, ([A-Za-z]+)\./, name) do
          [_, "Mrs"] -> 1
          _ -> 0
        end
      end)

    df |> DF.put("Title", title_series) |> DF.put("Is_Married", is_married_series)
  end

  defp extract_title(name) do
    case Regex.run(~r/, ([A-Za-z ]+)\./, name) do
      [_, title] -> title |> String.trim() |> normalize_title()
      nil -> "Other"
    end
  end

  defp normalize_title(title) do
    case title do
      v when v in ["Miss", "Mrs", "Ms", "Mlle", "Lady", "Mme", "the Countess", "Dona"] ->
        "Miss/Mrs/Ms"

      v when v in ["Dr", "Col", "Major", "Jonkheer", "Capt", "Sir", "Don", "Rev"] ->
        "Dr/Military/Noble/Clergy"

      v when v in ["Mrs", "Master", "Mr"] ->
        v

      _ ->
        "Other"
    end
  end

  defp add_family_surname(df) do
    family_series = df["Name"] |> S.transform(&extract_surname/1)
    DF.put(df, "Family", family_series)
  end

  defp extract_surname(name) do
    name |> String.split(",") |> List.first() |> String.replace(~r/[^\w\s]/, "") |> String.trim()
  end

  defp add_survival_rates(df) do
    {family_rate, family_rate_na} = encode_survival_rate(df, "Family")
    {ticket_rate, ticket_rate_na} = encode_survival_rate(df, "Ticket")

    df
    |> DF.put("Family_Survival_Rate", family_rate)
    |> DF.put("Family_Survival_Rate_NA", family_rate_na)
    |> DF.put("Ticket_Survival_Rate", ticket_rate)
    |> DF.put("Ticket_Survival_Rate_NA", ticket_rate_na)
    |> DF.mutate(
      Survival_Rate: (col("Family_Survival_Rate") + col("Ticket_Survival_Rate")) / 2,
      Survival_Rate_NA: (col("Family_Survival_Rate_NA") + col("Ticket_Survival_Rate_NA")) / 2
    )
  end

  defp encode_survival_rate(df_all, group_col) do
    df_train = DF.filter(df_all, is_train == 1)
    df_test = DF.filter(df_all, is_train == 0)
    train_groups = df_train[group_col] |> S.distinct() |> S.to_list() |> MapSet.new()
    test_groups = df_test[group_col] |> S.distinct() |> S.to_list() |> MapSet.new()
    common_groups = MapSet.intersection(train_groups, test_groups)

    survival_rates =
      df_train
      |> DF.filter(col(^group_col) in ^MapSet.to_list(common_groups))
      |> DF.group_by(group_col)
      |> DF.summarise(survival_rate: mean(col("Survived")), group_size: count(col("Survived")))
      |> DF.filter(group_size > 1)
      |> DF.to_rows()
      |> Enum.map(fn row -> {row[group_col], row["survival_rate"]} end)
      |> Map.new()

    mean_rate = S.mean(df_train["Survived"])

    rate_series =
      df_all[group_col] |> S.transform(fn group -> Map.get(survival_rates, group, mean_rate) end)

    na_series =
      df_all[group_col]
      |> S.transform(fn group ->
        if Map.has_key?(survival_rates, group) do
          1
        else
          0
        end
      end)

    {rate_series, na_series}
  end

  defp encode_labels(df) do
    categorical_cols = ["Embarked", "Sex", "Deck", "Title", "Family_Size_Grouped"]

    Enum.reduce(categorical_cols, df, fn col, acc_df ->
      encoded = label_encode(df[col])
      DF.put(acc_df, "#{col}_Encoded", encoded)
    end)
  end

  defp label_encode(series) do
    unique_values = series |> S.distinct() |> S.to_list() |> Enum.with_index() |> Map.new()
    S.transform(series, fn val -> Map.get(unique_values, val, 0) end)
  end

  defp encode_onehot(df) do
    onehot_cols = [
      "Pclass",
      "Sex_Encoded",
      "Deck_Encoded",
      "Embarked_Encoded",
      "Title_Encoded",
      "Family_Size_Grouped_Encoded"
    ]

    Enum.reduce(onehot_cols, df, fn col, acc_df -> onehot_encode(acc_df, col) end)
  end

  defp onehot_encode(df, column) do
    unique_vals = df[column] |> S.distinct() |> S.to_list() |> Enum.sort()

    Enum.reduce(unique_vals, df, fn val, acc_df ->
      new_col = "#{column}_#{val}"

      indicator =
        S.transform(df[column], fn v ->
          if v == val do
            1
          else
            0
          end
        end)

      DF.put(acc_df, new_col, indicator)
    end)
  end
end