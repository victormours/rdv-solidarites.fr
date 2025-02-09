# frozen_string_literal: true

describe SearchContext, type: :service do
  subject { described_class.new(user, search_query) }

  let!(:user) { create(:user, organisations: [organisation]) }
  let!(:invitation_token) do
    user.invite! { |u| u.skip_invitation = true }
    user.raw_invitation_token
  end
  let!(:organisation) { create(:organisation) }
  let!(:service) { create(:service) }
  let!(:motif) { create(:motif, name: "RSA orientation sur site", organisation: organisation) }
  let!(:motif2) { create(:motif, name: "RSA orientation téléphonique", organisation: organisation) }
  let!(:departement_number) { "75" }
  let!(:address) { "20 avenue de Ségur 75007 Paris" }
  let!(:city_code) { "75007" }
  let!(:latitude) { "48.3" }
  let!(:longitude) { "55.5" }
  let!(:search_query) do
    {
      organisation_ids: [organisation.id], departement: departement_number, city_code: city_code,
      latitude: latitude, longitude: longitude
    }
  end

  let!(:geo_search) { instance_double(Users::GeoSearch, available_motifs: Motif.where(id: motif.id)) }

  before do
    allow(Users::GeoSearch).to receive(:new)
      .with(departement: departement_number, city_code: city_code, street_ban_id: nil)
      .and_return(geo_search)
  end

  describe "#current_step" do
    context "when nothing is passed" do
      let!(:search_query) { {} }

      it "current step is address selection" do
        expect(subject.current_step).to eq(:address_selection)
      end
    end

    context "with an address but several motifs available" do
      let!(:geo_search) { instance_double(Users::GeoSearch, available_motifs: Motif.where(id: [motif.id, motif2.id])) }
      let!(:search_query) { { address: address, departement: departement_number, city_code: city_code } }

      it "current step is motif selection" do
        expect(subject.current_step).to eq(:motif_selection)
      end
    end

    context "with a motif and an address" do
      let!(:search_query) { { address: address, departement: departement_number, city_code: city_code } }

      it "current step is lieu selection" do
        expect(subject.current_step).to eq(:lieu_selection)
      end
    end
  end

  describe "#valid?" do
    it "is valid" do
      expect(subject.valid?).to eq(true)
    end

    context "for an invitation" do
      let!(:search_query) do
        { invitation_token: invitation_token, organisation_id: organisation.id, service: service.id }
      end

      it "is valid" do
        expect(subject.valid?).to eq(true)
      end

      context "when token is invalid" do
        let!(:search_query) { { invitation_token: "random token" } }

        it "is not valid" do
          expect(subject.valid?).to eq(false)
          expect(subject.errors).to eq(["Votre invitation n'est pas valide."])
        end
      end

      context "when current user is not invited user" do
        let!(:another_user) { create(:user) }
        let!(:another_token) do
          another_user.invite! { |u| u.skip_invitation = true }
          another_user.raw_invitation_token
        end
        let!(:search_query) { { invitation_token: another_token } }

        it "is not valid" do
          expect(subject.valid?).to eq(false)
          expect(subject.errors).to eq(["L’utilisateur connecté ne correspond pas à l’utilisateur invité. Déconnectez-vous et réessayez."])
        end
      end
    end
  end

  describe "#available_motifs" do
    it "is the geo search available motifs" do
      expect(subject.send(:available_motifs)).to eq([motif])
    end

    context "for an invitation" do
      before do
        search_query[:invitation_token] = invitation_token
        search_query[:motif_search_terms] = "RSA orientation"
      end

      context "when there are geo search available motifs for the org and service" do
        it "is the geo available_motifs" do
          expect(subject.send(:available_motifs)).to eq([motif])
        end
      end

      context "when there are no geo search available motifs" do
        let!(:geo_search) { instance_double(Users::GeoSearch, available_motifs: Motif.none) }

        before do
          allow(Motif).to receive(:available_with_plages_ouvertures)
            .and_return(Motif.where(id: motif2.id))
        end

        it "is the organisation available motif" do
          expect(subject.send(:available_motifs)).to eq([motif2])
        end
      end
    end
  end
end
