# frozen_string_literal: true

describe SearchCreneauxForAgentsService, type: :service do
  describe "all_agents" do
    subject { described_class.new(form).all_agents }

    let(:form) do
      instance_double(
        AgentCreneauxSearchForm,
        organisation: organisation,
        motif: motif,
        service: motif.service,
        agent_ids: agents.map(&:id),
        team_ids: teams.map(&:id),
        lieu_ids: lieux.map(&:id),
        date_range: Time.zone.today..(Time.zone.today + 6.days)
      )
    end

    let(:organisation) { create(:organisation) }
    let(:motif) { create :motif, organisation: organisation }

    let(:agent1) { create(:agent, basic_role_in_organisations: [organisation]) }
    let(:agent2) { create(:agent, basic_role_in_organisations: [organisation]) }
    let(:agent3) { create(:agent, basic_role_in_organisations: [organisation]) }

    let(:team1) { create(:team, agents: [agent1, agent2]) }

    let(:lieux) { [] }

    context "without agent or teams" do
      let(:agents) { [] }
      let(:teams) { [] }

      it { is_expected.to be_empty }
    end

    context "with an agent" do
      let(:agents) { [agent1] }
      let(:teams) { [] }

      it { is_expected.to contain_exactly(agent1) }
    end

    context "with a team" do
      let(:agents) { [] }
      let(:teams) { [team1] }

      it { is_expected.to contain_exactly(agent1, agent2) }
    end

    context "with agents and a team" do
      let(:agents) { [agent3] }
      let(:teams) { [team1] }

      it { is_expected.to contain_exactly(agent1, agent2, agent3) }
    end
  end

  describe "lieux" do
    subject { described_class.new(form).lieux }

    let(:form) do
      instance_double(
        AgentCreneauxSearchForm,
        organisation: organisation,
        motif: motif,
        service: motif.service,
        agent_ids: agents.map(&:id),
        team_ids: teams.map(&:id),
        lieu_ids: lieux.map(&:id),
        date_range: Time.zone.today..(Time.zone.today + 6.days)
      )
    end

    let(:organisation) { create(:organisation) }
    let(:motif) { create :motif, organisation: organisation }

    let(:agent1) { create(:agent, basic_role_in_organisations: [organisation]) }
    let(:lieu1) { create(:lieu, organisation: organisation) }
    let!(:plage_ouverture) { create(:plage_ouverture, :weekly, agent: agent1, motifs: [motif], lieu: lieu1, organisation: organisation) }

    let(:lieux) { [] }
    let(:agents) { [] }
    let(:teams) { [] }

    context "when there in only one plage" do
      context "when the lieu is unspecified" do
        let(:lieux) { [] }

        it { is_expected.to contain_exactly(lieu1) }
      end
    end

    context "when there are several plages for the motif" do
      let(:lieu2) { create(:lieu, organisation: organisation) }
      let(:agent2) { create(:agent, basic_role_in_organisations: [organisation]) }
      let!(:plage_ouverture2) { create(:plage_ouverture, :weekly, agent: agent2, lieu: lieu2, motifs: [motif], organisation: organisation) }

      context "when the lieu is unspecified" do
        it { is_expected.to contain_exactly(lieu1, lieu2) }
      end

      context "when filtering by lieu" do
        let(:lieux) { [lieu2] }

        it { is_expected.to contain_exactly(lieu2) }
      end

      context "when filtering by agent" do
        let(:agents) { [agent2] }

        it { is_expected.to contain_exactly(lieu2) }
      end

      context "when filtering by agent and by lieu" do
        let(:agents) { [agent2] }
        let(:lieux) { [lieu1] }

        it { is_expected.to eq([]) }
      end
    end
  end
end
