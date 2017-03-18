describe ImportBillsJob do
  subject { described_class.new }

  describe "#perform" do
    let(:hearing) { Hearing.first }
    let(:mock_scraper) { double("Scraper") }

    let(:existing_bill) { create(:bill, hearing: Hearing.second) }
    let(:existing_bill_attrs) { attributes_for(:bill, external_id: existing_bill.external_id) }

    let(:scraper_response) { [existing_bill_attrs] + attributes_for_list(:bill, 2) }

    before do
      allow(mock_scraper).to receive(:run).and_return(scraper_response)
      allow(subject).to receive(:scraper).and_return(mock_scraper)
      allow(ImportBillDetailsJob).to receive(:perform_later)
    end

    it "scrapes the hearing's bills" do
      subject.perform(hearing)
      expect(mock_scraper).to have_received(:run).with(hearing)
    end

    it "updates bills that already exist" do
      subject.perform(hearing)
      existing_bill.reload
      expect(existing_bill).to have_attributes(existing_bill_attrs)
    end

    it "creates bills that don't exist" do
      expect { subject.perform(hearing) }.to change(Bill, :count).by(2)
    end

    it "imports bill details for each bill" do
      subject.perform(hearing)
      expect(ImportBillDetailsJob).to have_received(:perform_later).exactly(3).times
    end

    context "after catching a scraping error" do
      before do
        allow(mock_scraper).to receive(:run).and_raise(Scraper::Task::Error)
      end

      xit "sends a slack notification" do
      end
    end

    context "after catching an active record error" do
      before do
        Bill.any_instance.stub(:save!).and_raise(ActiveRecord::ActiveRecordError)
      end

      it "does not import bills" do
        expect(ImportBillDetailsJob).to_not have_received(:perform_later)
      end

      xit "sends a slack notification" do
      end
    end
  end
end
