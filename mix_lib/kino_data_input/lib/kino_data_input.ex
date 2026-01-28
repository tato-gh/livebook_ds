defmodule Kino.DataInput do
  def frame_data_input do
    frame = Kino.Frame.new()
    input = Kino.Input.file("data")
    Kino.Frame.append(frame, input)
    {frame, input}
  end

  def frame_data_inputs do
    frame = Kino.Frame.new()
    train_input = Kino.Input.file("train data")
    test_input = Kino.Input.file("test data")
    Kino.Frame.append(frame, train_input)
    Kino.Frame.append(frame, test_input)
    {frame, {train_input, test_input}}
  end

  def to_dataframe({train, test}) do
    {to_dataframe(train), to_dataframe(test)}
  end

  def to_dataframe(input) do
    input
    |> Kino.Input.read()
    |> Map.get(:file_ref)
    |> Kino.Input.file_path()
    |> Explorer.DataFrame.from_csv!()
  end
end