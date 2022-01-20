# frozen_string_literal: true

class AgentCreneauxSearchForm
  include ActiveModel::Model

  attr_accessor :organisation_id, :service_id, :motif_id, :team_ids, :user_ids, :lieu_ids, :context
  attr_writer :from_date, :agent_ids

  validates :organisation_id, :motif_id, presence: true

  def organisation
    Organisation.find_by(id: organisation_id)
  end

  def service
    Service.find_by(id: service_id)
  end

  def motif
    organisation.motifs.find_by(id: motif_id)
  end

  def users
    organisation.users.where(id: user_ids)
  end

  def teams
    organisation.territory.teams.where(id: team_ids)
  end

  def agent_ids
    id_list = @agent_ids || []
    if @team_ids
      teams = @team_ids.map { |d| Team.find(d) }
      id_list += teams.flat_map(&:agents).map(&:id)
    end
    id_list
  end

  def date_range
    from_date..(from_date + 6.days)
  end

  def from_date
    Date.parse(@from_date)
  rescue StandardError
    Time.zone.today
  end
end
