module Ilga
  class ScrapeHearingBills < Scraper
    Bill = Struct.new(
      :external_id,
      :number,
      :slip_url,
      :slip_results_url,
      :is_amendment
    )

    def call(hearing)
      info("> #{task_name}: start")
      info("  - hearing: #{hearing.id}")
      result = scrape_paged_bills(hearing, hearing.url)

      info("\n> #{task_name}: finished")
      result
    end

    def scrape_paged_bills(hearing, url, page_number = 0)
      return [] if url.nil?

      info("\n> #{task_name}: visit paged bills")
      info("  - name: #{hearing.id}")
      info("  - page: #{page_number}")

      page.visit(url)

      # short-circuit when there are no rows
      return [] if page.has_css?('.t-no-data')

      # build bills from each row on this page
      bills = page
        .find_all('#GridCurrentCommittees tbody tr')
        .map { |row| build_bill(row) }

      info("  - bills: #{bills.count}")

      # aggregate the next page's results if it's available
      next_url = find_next_page_url
      info("  - next?: #{!next_url.nil?}")
      bills + scrape_paged_bills(hearing, next_url, page_number + 1)
    end

    def build_bill(row)
      columns = row.find_all('td', visible: false)

      # scrape required data
      external_id = check!(
        columns[0]&.text(:all),
        'bill(?) is missing external id'
      )

      document_number = check!(
        columns[2]&.text,
        "bill(#{external_id}) is missing document number"
      )

      # scrape links
      slip_link = row.first('.slipiconbutton')&.[](:href)
      slip_results_link = row.first('.viewiconbutton')&.[](:href)

      if slip_link.blank?
        debug("  - bill w/o slip link: #{external_id} - #{document_number}")
      end

      # build bill
      Bill.new(
        external_id,
        document_number,
        slip_link,
        slip_results_link,
        document_number.include?(' - ')
      )
    end

    # find the next page link by searching for its icon
    def find_next_page_url
      link = page.first(:xpath, "//*[@class='t-arrow-next']/..")
      return nil if link.nil? || link[:class].include?('t-state-disabled')
      link[:href]
    end
  end
end
