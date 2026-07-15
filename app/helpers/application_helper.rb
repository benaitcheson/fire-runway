module ApplicationHelper
  # Nav link that marks the current section for assistive tech (aria-current)
  # and visually. Prefix-matches so /user_assets/4/edit still lights up Assets.
  def nav_link_to(name, path)
    active = request.path == path || (path != "/" && request.path.start_with?(path))
    link_to name, path,
            class: "px-1 py-0.5 #{active ? 'text-white font-semibold border-b-2 border-white' : 'text-gray-300 hover:text-white'}",
            "aria-current": (active ? "page" : nil)
  end

  def format_currency(cents, currency = "AUD")
    return "$0.00" if cents.nil? || cents == 0
    
    # Convert cents to dollars
    amount = cents / 100.0
    
    # Format with appropriate currency symbol
    case currency
    when "AUD"
      "$#{number_with_precision(amount, precision: 2, delimiter: ',')}"
    when "USD"
      "US$#{number_with_precision(amount, precision: 2, delimiter: ',')}"
    else
      "#{currency} #{number_with_precision(amount, precision: 2, delimiter: ',')}"
    end
  end
  
  def format_date(date)
    return "" if date.nil?
    date.strftime("%d %b %Y")
  end
end
