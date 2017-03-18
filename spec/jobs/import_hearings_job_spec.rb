describe ImportHearingsJob do
  subject { described_class.new }

  describe "#perform" do
    let(:chamber) { Chamber.first }
    let(:mock_scraper) { double("Scraper") }

    let(:hearing) { create(:hearing, :with_any_committee) }
    let(:hearing_attrs) { attributes_for(:hearing, external_id: hearing.external_id) }

    let(:committee) { create(:committee, :with_any_chamber) }
    let(:committee_attrs) { attributes_for(:committee, external_id: committee.external_id) }

    let(:scraper_response) {
      hearings_attrs = [hearing_attrs] + attributes_for_list(:hearing, 2)
      committees_attrs = [committee_attrs] + attributes_for_list(:committee, 2)
      committees_attrs
        .zip(hearings_attrs)
        .map { |committee, hearing|
          committee[:hearing] = hearing
          committee
        }
    }

    before do
      allow(mock_scraper).to receive(:run).and_return(scraper_response)
      allow(subject).to receive(:scraper).and_return(mock_scraper)
      allow(ImportBillsJob).to receive(:perform_later)
    end

    it "scrapes the chamber's hearings" do
      subject.perform(chamber)
      expect(mock_scraper).to have_received(:run).with(chamber)
    end

    it "updates committees that already exist" do
      subject.perform(chamber)
      committee.reload
      expect(committee).to have_attributes(committee_attrs)
    end

    it "updates hearings that already exist" do
      subject.perform(chamber)
      hearing.reload
      expect(hearing).to have_attributes(hearing_attrs)
    end


    it "creates committees that don't exist" do
      expect { subject.perform(chamber) }.to change(Committee, :count).by(2)
    end

    it "creates hearings that don't exist" do
      expect { subject.perform(chamber) }.to change(Hearing, :count).by(2)
    end

    it "import bills for each hearing" do
      subject.perform(chamber)
      expect(ImportBillsJob).to have_received(:perform_later).exactly(3).times
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
        Hearing.any_instance.stub(:save!).and_raise(ActiveRecord::ActiveRecordError)
      end

      it "does not import bills" do
        expect(ImportBillsJob).to_not have_received(:perform_later)
      end

      xit "sends a slack notification" do
      end
    end
  end
end
