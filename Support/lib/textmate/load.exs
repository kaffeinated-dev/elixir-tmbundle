# Loads the bundle's Elixir files (the .ex files next to this one), compiled
# once for each Elixir version and change of the files, into a folder in the
# temporary folder.
#
#     elixir -r load.exs -S mix textmate.TASK …

sources = __ENV__.file |> Path.dirname() |> Path.join("*.ex") |> Path.wildcard() |> Enum.sort()
stats = Enum.map(sources, &{&1, File.stat!(&1).mtime, File.stat!(&1).size})
key = :erlang.phash2({System.version(), System.otp_release(), stats})
cache = Path.join([System.tmp_dir!(), "textmate-elixir", "beams-#{key}"])

unless File.dir?(cache) do
  building = "#{cache}.#{System.unique_integer([:positive])}"
  File.mkdir_p!(building)

  {:ok, _modules, _diagnostics} =
    Kernel.ParallelCompiler.compile_to_path(sources, building, return_diagnostics: true)

  # Another command may have compiled them meanwhile.
  with {:error, _} <- File.rename(building, cache), do: File.rm_rf!(building)
end

# Loaded now, as Mix may remove code paths it doesn't know.
Code.prepend_path(cache)

for beam <- Path.wildcard(Path.join(cache, "*.beam")) do
  beam |> Path.basename(".beam") |> String.to_atom() |> Code.ensure_loaded!()
end
