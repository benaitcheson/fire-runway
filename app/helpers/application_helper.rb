module ApplicationHelper
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
