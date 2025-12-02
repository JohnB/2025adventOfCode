defmodule AdventOfCode do
  @moduledoc """
  Helper module for dealing with text input from the AOC puzzles.
  Originally created for the 2021 competition.

  To use from LiveBook:
    IEx.Helpers.c("lib/advent_of_code.ex")
    alias AdventOfCode, as: AOC
  """

  alias Kino

  def inspect(thing, keyword_list \\ []) do
    IO.inspect(thing, keyword_list ++ [charlists: :as_lists])
  end

  # Grid-based helpers

  @doc """
    Creates a grid of a specified size with a specified initial values.
  """
  def as_solid_grid(width, height, initial_value \\ nil) do
    last_cell = width * height - 1

    0..last_cell
    |> Map.new(fn index -> {index, initial_value} end)
    |> Map.merge(%{
      grid_width: width,
      grid_height: height,
      infinite: false,
      max_dimension: max(width, height),
      last_cell: last_cell
    })
  end

  @doc """
    Reads in a grid of characters, returning a map
  """
  def as_grid(multiline_text, width \\ nil) do
    [line0 | _] = lines = as_single_lines(multiline_text)
    line_width = String.length(line0)
    grid_width = width || line_width
    grid_height = Enum.count(lines)
    infinite = grid_width > line_width

    lines
    |> Enum.join("")
    |> String.split("", trim: true)
    |> Enum.with_index()
    |> Map.new(fn {character, index} ->
      {grid_width * div(index, line_width) + rem(index, line_width), character}
    end)
    |> Map.merge(%{
      grid_width: grid_width,
      grid_height: grid_height,
      infinite: infinite,
      max_dimension: max(grid_width, grid_height),
      # NOTE: last_cell is meaningless for a separately-specified width
      last_cell: grid_height * grid_width - 1
    })
  end

  def as_grid_of_digits(multiline_text) do
    grid = as_grid(multiline_text)

    grid
    |> grid_cells()
    |> Enum.reduce(grid, fn key, acc ->
      value = acc[key]
      Map.put(acc, key, (is_integer(value) && value) || String.to_integer(value))
    end)
  end

  # We only want 4 neighbors, not 8
  # Order: [up, left, right, down]
  # NOTE: DOES NOT HANDLE INFINITE GRID
  def neighbors4_including_offgrid(grid, index) do
    [
      index - grid.grid_width,
      index - 1,
      index + 1,
      index + grid.grid_width
    ]
    |> Enum.map(fn neighbor ->
      cond do
        neighbor < 0 ->
          -(10_000 + neighbor)

        neighbor > grid.last_cell ->
          -(10_000 + neighbor)

        div(neighbor, grid.grid_width) == div(index, grid.grid_width) ||
            rem(neighbor, grid.grid_width) == rem(index, grid.grid_width) ->
          neighbor

        true ->
          -(10_000 + neighbor)
      end
    end)
  end

  def neighbors4(grid, index) do
    [
      index - grid.grid_width,
      index - 1,
      index + 1,
      index + grid.grid_width
    ]
    # nils are off-board
    |> Enum.filter(fn neighbor -> grid[neighbor] end)
    |> Enum.filter(fn neighbor ->
      # must be on the same row or column to ensure we don't go side-to-side
      div(neighbor, grid.grid_width) == div(index, grid.grid_width) ||
        rem(neighbor, grid.grid_width) == rem(index, grid.grid_width)
    end)
  end

  # We only want all 8 neighbors
  # NOTE: DOES NOT HANDLE INFINITE GRID
  def neighbors8(grid, index) do
    x = rem(index, grid.grid_width)
    # only worry about going off the sides - the top and bottom
    # excursions will be off-board and removed when they return nil.
    positions =
      [index - grid.grid_width, index + grid.grid_width] ++
        if x > 0 do
          [index - grid.grid_width - 1, index - 1, index + grid.grid_width - 1]
        else
          []
        end ++
        if x == grid.grid_width - 1 do
          []
        else
          [index - grid.grid_width + 1, index + 1, index + grid.grid_width + 1]
        end

    positions
    # off-board
    |> Enum.filter(fn neighbor -> grid[neighbor] end)
  end

  def grid_cells(grid) do
    0..grid.last_cell
  end

  def grid_rows(grid) do
    grid_cells(grid)
    |> Enum.chunk_every(grid.grid_width)
  end

  def grid_x(grid, cell), do: rem(cell, grid.grid_width)
  def grid_y(grid, cell), do: div(cell, grid.grid_width)
  def cell_id(grid, x, y), do: x + y * grid.grid_width

  def to_text_grid(grid) do
    grid_rows(grid)
    |> Enum.map(fn row ->
      Enum.map(row, fn x -> grid[x] end)
      |> Enum.join("")
    end)
    |> Enum.join("\n")
  end

  def invert(grid) do
    grid_cells(grid)
    |> Enum.reduce(
      %{
        grid
        | grid_width: grid.grid_height,
          grid_height: grid.grid_width,
          last_cell: grid.last_cell
      },
      fn cell, acc ->
        Map.put(acc, grid_x(grid, cell) * grid.grid_height + grid_y(grid, cell), grid[cell])
      end
    )
  end

  @doc """
    @spec on_edge_of_board?(%{}, integer, [:north | :south | :east | :west])
    on_edge_of_board?(grid, cell_id, direction)
  """
  def on_edge_of_board?(grid, cell_id, direction) do
    case direction do
      :north -> grid_y(grid, cell_id) == 0
      :west -> grid_x(grid, cell_id) == 0
      :south -> grid_y(grid, cell_id) == grid.grid_height - 1
      :east -> grid_x(grid, cell_id) == grid.grid_width - 1
    end
  end

  def build_compass(grid) do
    %{
      north: -grid.grid_width,
      east: 1,
      south: grid.grid_width,
      west: -1
    }
  end

  #  @ascii_zero 48
  #  @max_display 40
  def display_grid(grid, text \\ nil) do
    text && IO.puts("\n--- #{text}")

    0..grid.last_cell
    |> Enum.chunk_every(grid.grid_width)
    # |> IO.inspect(label: "Grid chunks")
    |> Enum.map(fn indexes ->
      line =
        indexes
        |> Enum.map(fn index ->
          # For a known-printable grid:
          grid[index]
          # For a somewhat-printable grid:
          # (grid[index] >= @max_display) && "." || (@ascii_zero + grid[index])
        end)
        |> Enum.join("")

      (String.slice("#{grid_y(grid, List.first(indexes))}   ", 0, 4) <> line)
      |> IO.puts()
    end)

    grid
  end

  # Dijkstra
  #   Implement https://en.wikipedia.org/wiki/Dijkstra's_algorithm#Algorithm
  @infinity 1_000_000_000_000
  @wall "#"
  @cost 1

  def shortest_path(grid, latest_nodes, node_map, cost_function, finish) do
    {updated_node_map, neighbor_nodes} =
      latest_nodes
      |> Enum.reduce({node_map, MapSet.new()}, fn node, {map, set} ->
        unvisited_neighbors =
          grid
          |> neighbors4(node)
          |> Enum.filter(fn neighbor ->
            neighbor in Map.keys(node_map) && node_map[neighbor].cost == @infinity
          end)

        unvisited_neighbors
        |> Enum.reduce({map, set}, fn neighbor, {map1, set1} ->
          {cost_function.(map1, node, neighbor), MapSet.put(set1, neighbor)}
        end)
      end)

    # |> inspect(label: "{updated_node_map, neighbor_nodes}")

    if updated_node_map[finish].path == [] do
      shortest_path(grid, MapSet.to_list(neighbor_nodes), updated_node_map, cost_function, finish)
    else
      updated_node_map
    end
  end

  def shortest_path(grid, start, finish) do
    # Step 1: Find the unvisited set.
    node_map =
      Enum.reject(grid_cells(grid), fn k -> grid[k] == @wall end)
      # Step 2: Assign distances to unvisited nodes. The start node will get a 0 distance.
      |> Enum.reduce(%{}, fn index, acc ->
        if index == start do
          Map.put(acc, index, %{cost: 0, path: [start]})
        else
          # Note: an empty path list means it is un-visited
          Map.put(acc, index, %{cost: @infinity, path: []})
        end
      end)

    # |> inspect(label: "node_map")

    cost_function = fn map, a, b ->
      # This handles Step 3 and Step 4: update path and distance from neighbors.
      cost_from_a = map[a].cost + @cost

      if map[b].cost < cost_from_a do
        # Nothing to do - the node already has the lower cost & path
        map
      else
        Map.put(map, b, %{cost: cost_from_a, path: map[a].path ++ [b]})
      end
    end

    shortest_path(grid, [start], node_map, cost_function, finish)
  end

  # Paragraph-based helpers
  def as_single_lines(multiline_text) do
    multiline_text
    |> String.split("\n", trim: true)
  end

  def as_integers(multiline_text) do
    multiline_text
    |> as_single_lines()
    |> Enum.map(&String.to_integer/1)
  end

  def as_doublespaced_paragraphs(multiline_text) do
    multiline_text
    |> String.split("\n\n")
  end

  def as_doublespaced_integers(multiline_text) do
    multiline_text
    |> as_doublespaced_paragraphs()
    |> Enum.map(fn paragraph ->
      paragraph
      |> as_single_lines()
      |> Enum.map(&String.to_integer/1)
    end)
  end

  # Line-based helpers
  def as_comma_separated_integers(text) do
    text
    |> String.trim()
    |> String.split(",", trim: true)
    |> Enum.map(fn digits ->
      digits
      |> String.trim()
      |> String.to_integer()
    end)
  end

  def delimited_by_spaces(text) do
    text
    |> String.split(~r/\s+/, trim: true)
  end

  def delimited_by_colons(text) do
    text
    |> String.split(~r/\:/)
  end

  # -- startup and kino-related functions
end
