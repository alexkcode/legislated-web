require 'httparty'

class OpenStatesService
  include HTTParty
  base_uri 'https://openstates.org/api/v1'

  def initialize
    @options = {
      headers: {
        'X-API-KEY': ENV['OPEN_STATES_KEY']
      }
    }
  end

  def enumerate_all(fetch_by_page, query = {})
    query = parse_query(query)

    enumerator = Enumerator.new do |item|
      page_number = 1

      loop do
        page = fetch_by_page.call(page_number, query)
        break if page.blank?
        page_number += 1
        page.each { |record| item.yield(record) }
      end
    end

    enumerator.lazy
  end

  def fetch_bills(query = {})
    query = parse_query(query)

    enumerator = Enumerator.new do |y|
      page_number = 1

      loop do
        page = fetch_bills_page(page_number, query)
        break if page.blank?
        page_number += 1
        page.each { |bill| y.yield(bill) }
      end
    end

    enumerator.lazy
  end

  def fetch_legislators(query = {})
    enumerate_all(method( :fetch_legislators_page ), query)
  end

  private

  def parse_query(query)
    if updated_since ||= query[:updated_since]
      query[:updated_since] = updated_since.strftime('%Y-%m-%d') if updated_since
    end

    query
  end

  def fetch_bills_page(page_number, query)
    base_query = {
      state: 'il',
      search_window: 'session',
      page: page_number,
      per_page: 50
    }

    self.class.get('/bills', @options.deep_merge({
      query: base_query.merge(query)
    }))
  end

  def fetch_legislators_page(page_number, query)
    base_query = {
      state: 'il',
      page: page_number,
      per_page: 50
    }

    self.class.get('/legislators', @options.deep_merge({
      query: base_query.merge(query)
    }))
  end
end
