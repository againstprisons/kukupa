module Kukupa::Helpers::TimeHelpers
  def pretty_time(time)
    a = (Time.now - time).to_i
    future = a.negative?
    a = a.abs

    relative = nil
    case a
    when 0..59
      relative = "#{a} seconds"
    when 60..(3600 - 1)
      relative = "#{(a / 60).to_i} minutes"
    when 3600..((3600 * 24) - 1)
      relative = "#{(a / 3600).to_i} hours"
    when (3600 * 24)..(3600 * 24 * 30)
      relative = "#{(a / (3600 * 24)).to_i} days"
    else
      return time.strftime("%Y-%m-%d %H:%M")
    end

    return "in #{relative}" if future
    "#{relative} ago"
  end
end
