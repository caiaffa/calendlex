defmodule CalendlexWeb.EventTypeLive do
  use CalendlexWeb, :live_view

  alias Timex.Duration

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket, temporary_assigns: [time_slots: []]}
  end

  @impl LiveView
  def handle_params(%{"event_type_slug" => slug} = params, _uri, socket) do
    case Calendlex.get_event_type_by_slug(slug) do
      {:ok, event_type} ->
        socket =
          socket
          |> assign(event_type: event_type)
          |> assign(page_title: event_type.name)
          |> assign_dates(params)
          |> assign_time_slots(params)

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  @impl LiveView
  def handle_info({:select_day, date}, socket) do
    socket =
      socket
      |> assign(current: date)
      |> assign_time_slots(%{"date" => date})
      |> push_patch(
        to:
          Routes.live_path(socket, CalendlexWeb.EventTypeLive, socket.assigns.event_type.slug,
            date: Date.to_iso8601(date)
          ),
        replace: true
      )

    {:noreply, socket}
  end

  defp assign_dates(socket, params) do
    current = current_from_params(params, socket)
    beginning_of_month = Timex.beginning_of_month(current)
    end_of_month = Timex.end_of_month(current)

    previous_month =
      beginning_of_month
      |> Timex.add(Duration.from_days(-1))
      |> date_to_month()

    next_month =
      end_of_month
      |> Timex.add(Duration.from_days(1))
      |> date_to_month()

    socket
    |> assign(beginning_of_month: beginning_of_month)
    |> assign(current: current)
    |> assign(end_of_month: end_of_month)
    |> assign(previous_month: previous_month)
    |> assign(next_month: next_month)
  end

  defp assign_time_slots(socket, %{"date" => _}) do
    date = socket.assigns.current
    owner_time_zone = socket.assigns.owner.time_zone
    event_duration = socket.assigns.event_type.duration

    time_slots = Calendlex.build_time_slots(date, owner_time_zone, event_duration)

    socket
    |> assign(time_slots: time_slots)
    |> assign(selected_date: date)
  end

  defp assign_time_slots(socket, _), do: socket

  defp current_from_params(%{"date" => date}, socket) do
    case Timex.parse(date, "{YYYY}-{0M}-{D}") do
      {:ok, current} ->
        NaiveDateTime.to_date(current)

      _ ->
        Timex.today(socket.assigns.time_zone)
    end
  end

  defp current_from_params(%{"month" => month}, socket) do
    case Timex.parse("#{month}-01", "{YYYY}-{0M}-{D}") do
      {:ok, current} ->
        NaiveDateTime.to_date(current)

      _ ->
        Timex.today(socket.assigns.time_zone)
    end
  end

  defp current_from_params(_, socket) do
    Timex.today(socket.assigns.time_zone)
  end

  defp date_to_month(date_time) do
    Timex.format!(date_time, "{YYYY}-{0M}")
  end
end
