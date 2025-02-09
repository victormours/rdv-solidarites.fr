# frozen_string_literal: true

module Users::CreneauxSearchConcern
  extend ActiveSupport::Concern

  def next_availability
    NextAvailabilityService.find(motif, @lieu, date_range.end, agents)
  end

  def creneaux
    SlotBuilder.available_slots(motif, @lieu, date_range, OffDays.all_in_date_range(date_range), agents)
  end

  protected

  def agents
    @agents ||= [
      follow_up_rdv_and_online_user? ? @user.agents : nil,
      geo_attributed_agents || nil
    ].compact.flatten
  end

  def follow_up_rdv_and_online_user?
    @user && motif.follow_up?
  end

  def geo_attributed_agents
    return if @geo_search.nil? || !motif.sectorisation_level_agent?

    @geo_search.attributed_agents_by_organisation[@lieu.organisation]
  end
end
